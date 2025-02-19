//
//  NSObject+RCTAnimatedNodeDTXSpy.m
//  DetoxSync
//

#import "DTXSyncManager-Private.h"
#import "DTXSingleEventSyncResource.h"

@import ObjectiveC;

static const void* _DTXRCTAnimatedNodeSRKey = &_DTXRCTAnimatedNodeSRKey;

@protocol RCTAnimatedNodeSwizzledMethods

@property (nonatomic, readonly) BOOL needsUpdate;

@end

@implementation NSObject (RCTAnimatedNodeDTXSpy)

+ (void)load
{
    @autoreleasepool {
        Class RCTAnimatedNodeClass = NSClassFromString(@"RCTAnimatedNode");

        DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] RCTAnimatedNode class exists: %@",
                                  RCTAnimatedNodeClass != nil ? @"YES" : @"NO");

        if (RCTAnimatedNodeClass == nil) {
            return;
        }

        NSError* error;
        DTXSwizzleMethod(RCTAnimatedNodeClass,
                         @selector(needsUpdate),
                         @selector(__detox_sync_needsUpdate),
                         &error);

        if (error) {
            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Failed to swizzle needsUpdate: %@", error);
        } else {
            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Successfully swizzled needsUpdate");
        }
    }
}

- (BOOL)__detox_sync_needsUpdate
{
    BOOL needsUpdate = [self __detox_sync_needsUpdate];

    DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] needsUpdate accessed for node: %@ (value: %@)",
                              self,
                              needsUpdate ? @"YES" : @"NO");

    if (needsUpdate) {
        DTXSingleEventSyncResource* existingSR = objc_getAssociatedObject(self, _DTXRCTAnimatedNodeSRKey);

        if (!existingSR) {
            DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource
                                              singleUseSyncResourceWithObjectDescription:[NSString stringWithFormat:@"RCTAnimatedNode: %@", self]
                                              eventDescription:@"Animation Update"];

            objc_setAssociatedObject(self, _DTXRCTAnimatedNodeSRKey, sr,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Started tracking animation update for node: %@", self);
            [sr resumeTracking];
        }
    } else {
        DTXSingleEventSyncResource* sr = objc_getAssociatedObject(self, _DTXRCTAnimatedNodeSRKey);
        if (sr) {
            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Ended tracking animation update for node: %@", self);
            [sr endTracking];
            objc_setAssociatedObject(self, _DTXRCTAnimatedNodeSRKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    return needsUpdate;
}

@end
