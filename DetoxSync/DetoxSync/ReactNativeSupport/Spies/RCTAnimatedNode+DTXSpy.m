//
//  NSObject+RCTAnimatedNodeDTXSpy.m
//  DetoxSync
//

#import "DTXSyncManager-Private.h"
#import "DTXAnimationUpdateSyncResource.h"

@import ObjectiveC;

@protocol RCTAnimatedNodeSwizzledMethods <NSObject>

- (void)setNeedsUpdate;
- (void)performUpdate;

@end

@implementation NSObject (RCTAnimatedNodeDTXSpy)

+ (void)load {
    @autoreleasepool {
        Class RCTAnimatedNodeClass = NSClassFromString(@"RCTAnimatedNode");

        DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] RCTAnimatedNode class exists: %@",
                                  RCTAnimatedNodeClass != nil ? @"YES" : @"NO");

        if (RCTAnimatedNodeClass == nil) {
            return;
        }

        NSError* error;
        DTXSwizzleMethod(RCTAnimatedNodeClass,
                         @selector(setNeedsUpdate),
                         @selector(__detox_sync_setNeedsUpdate),
                         &error);

        if (error) {
            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Failed to swizzle setNeedsUpdate: %@", error);
        } else {
            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Successfully swizzled setNeedsUpdate");
        }

        error = nil;
        DTXSwizzleMethod(RCTAnimatedNodeClass,
                         @selector(performUpdate),
                         @selector(__detox_sync_performUpdate),
                         &error);

        if (error) {
            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Failed to swizzle performUpdate: %@", error);
        } else {
            DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Successfully swizzled performUpdate");
        }
    }
}

- (void)__detox_sync_setNeedsUpdate {
    BOOL wasNeedingUpdate = [self valueForKey:@"_needsUpdate"];

    [self __detox_sync_setNeedsUpdate];

    if (!wasNeedingUpdate) {
        DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Node %@ needs update", self);
        [DTXAnimationUpdateSyncResource.sharedInstance trackNodeNeedsUpdate:self];
    }
}

- (void)__detox_sync_performUpdate {
    [self __detox_sync_performUpdate];

    DTXSyncResourceVerboseLog(@"[RCTAnimatedNode DTXSpy] Node %@ performed update", self);
    [DTXAnimationUpdateSyncResource.sharedInstance trackNodePerformedUpdate:self];
}

@end
