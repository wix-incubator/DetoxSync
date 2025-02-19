//
//  NSObject+RCTNetworkingDTXSpy.m
//  DetoxSync
//

#import "DTXSyncManager-Private.h"
#import "DTXSingleEventSyncResource.h"
#import "NSURL+DetoxSyncUtils.h"

@import ObjectiveC;

static const void* _DTXRCTNetworkingRequestSRKey = &_DTXRCTNetworkingRequestSRKey;

@protocol RCTNetworkingSwizzledMethods

- (void)sendRequest:(NSURLRequest *)request
       responseType:(NSString *)responseType
 incrementalUpdates:(BOOL)incrementalUpdates
     responseSender:(void (^)(NSArray *))responseSender;

- (void)sendEventWithName:(NSString *)eventName body:(id)body;

@end

@implementation NSObject (RCTNetworkingDTXSpy)

+ (void)load
{
    @autoreleasepool {
        Class RCTNetworkingClass = NSClassFromString(@"RCTNetworking");

        DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] RCTNetworking class exists: %@",
                                  RCTNetworkingClass != nil ? @"YES" : @"NO");

        if (RCTNetworkingClass == nil) {
            return;
        }

        NSError* error;
        DTXSwizzleMethod(RCTNetworkingClass,
                         @selector(sendRequest:responseType:incrementalUpdates:responseSender:),
                         @selector(__detox_sync_sendRequest:responseType:incrementalUpdates:responseSender:),
                         &error);

        if (error) {
            DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Failed to swizzle sendRequest: %@", error);
        }

        DTXSwizzleMethod(RCTNetworkingClass,
                         @selector(sendEventWithName:body:),
                         @selector(__detox_sync_sendEventWithName:body:),
                         &error);

        if (error) {
            DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Failed to swizzle sendEventWithName: %@", error);
        }

        DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Successfully swizzled RCTNetworking methods");
    }
}

- (void)__detox_sync_sendRequest:(NSURLRequest *)request
                    responseType:(NSString *)responseType
              incrementalUpdates:(BOOL)incrementalUpdates
                  responseSender:(void (^)(NSArray *))responseSender
{
    DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Intercepted request: %@ (type: %@, incremental: %@)",
                              request.URL,
                              responseType,
                              incrementalUpdates ? @"YES" : @"NO");

    if (![request.URL detox_sync_shouldTrack]) {
        DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Skipping request tracking for URL: %@", request.URL);
        [self __detox_sync_sendRequest:request
                          responseType:responseType
                    incrementalUpdates:incrementalUpdates
                        responseSender:responseSender];
        return;
    }

    DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource
                                      singleUseSyncResourceWithObjectDescription:[NSString stringWithFormat:@"RN Network Request: \"%@\"", request.URL.absoluteString]
                                      eventDescription:@"Network Request"];

    DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Created sync resource for request: %@", request.URL);

    objc_setAssociatedObject(request, _DTXRCTNetworkingRequestSRKey, sr,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [sr resumeTracking];
    DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Started tracking request: %@", request.URL);

    [self __detox_sync_sendRequest:request
                      responseType:responseType
                incrementalUpdates:incrementalUpdates
                    responseSender:responseSender];
}

- (void)__detox_sync_sendEventWithName:(NSString *)eventName body:(id)body
{
    DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Received event: %@ with body: %@", eventName, body);

    [self __detox_sync_sendEventWithName:eventName body:body];

    if (![eventName isEqualToString:@"didCompleteNetworkResponse"]) {
        return;
    }

    if (![body isKindOfClass:[NSArray class]] || [(NSArray*)body count] < 1) {
        DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Invalid completion event body format");
        return;
    }

    NSNumber *requestID = body[0];
    NSString *error = body[1];
    BOOL timedOut = [body[2] boolValue];

    DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Processing completion for request ID: %@ (error: %@, timedOut: %@)",
                              requestID,
                              error ?: @"none",
                              timedOut ? @"YES" : @"NO");

    // Find the sync resource by looking through all active tasks
    NSDictionary *tasksByRequestID = [self valueForKey:@"_tasksByRequestID"];
    NSURLRequest *request = [[[tasksByRequestID objectForKey:requestID] valueForKey:@"request"] copy];

    if (!request) {
        DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Could not find request for ID: %@", requestID);
        return;
    }

    DTXSingleEventSyncResource* sr = objc_getAssociatedObject(request, _DTXRCTNetworkingRequestSRKey);
    if (!sr) {
        DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] No sync resource found for request: %@", request.URL);
        return;
    }

    [sr endTracking];
    DTXSyncResourceVerboseLog(@"[RCTNetworking DTXSpy] Ended tracking for request: %@", request.URL);

    objc_setAssociatedObject(request, _DTXRCTNetworkingRequestSRKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
