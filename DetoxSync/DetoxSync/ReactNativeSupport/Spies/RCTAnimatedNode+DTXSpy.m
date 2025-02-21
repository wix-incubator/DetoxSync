//
//  NSObject+RCTAnimatedNodeDTXSpy.m
//  DetoxSync
//

#import "DTXSyncManager-Private.h"
#import "DTXAnimationUpdateSyncResource.h"

DTX_CREATE_LOG(RCTAnimatedNodeDTXSpy);

@import ObjectiveC;

@protocol RCTAnimatedNodeSwizzledMethods <NSObject>

- (void)setNeedsUpdate;
- (void)performUpdate;
- (void)onDetachedFromNode:(id)parent;

@end

@implementation NSObject (RCTAnimatedNodeDTXSpy)

+ (void)load {
    @autoreleasepool {
        Class RCTAnimatedNodeClass = NSClassFromString(@"RCTAnimatedNode");

        dtx_log_info(@"[RCTAnimatedNode DTXSpy] RCTAnimatedNode class exists: %@",
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
            dtx_log_info(@"[RCTAnimatedNode DTXSpy] Failed to swizzle setNeedsUpdate: %@", error);
        }

        error = nil;
        DTXSwizzleMethod(RCTAnimatedNodeClass,
                         @selector(performUpdate),
                         @selector(__detox_sync_performUpdate),
                         &error);
        if (error) {
            dtx_log_info(@"[RCTAnimatedNode DTXSpy] Failed to swizzle performUpdate: %@", error);
        }

        error = nil;
        DTXSwizzleMethod(RCTAnimatedNodeClass,
                         @selector(onDetachedFromNode:),
                         @selector(__detox_sync_onDetachedFromNode:),
                         &error);
        if (error) {
            dtx_log_info(@"[RCTAnimatedNode DTXSpy] Failed to swizzle onDetachedFromNode: %@", error);
        }
    }
}

- (void)__detox_sync_setNeedsUpdate {
    [self __detox_sync_setNeedsUpdate];
    dtx_log_info(@"[RCTAnimatedNode DTXSpy] Node %@ needs update", self);
    [DTXAnimationUpdateSyncResource.sharedInstance trackNodeNeedsUpdate:self];
}

- (void)__detox_sync_performUpdate {
    [self __detox_sync_performUpdate];
    dtx_log_info(@"[RCTAnimatedNode DTXSpy] Node %@ performed update", self);
    [DTXAnimationUpdateSyncResource.sharedInstance trackNodePerformedUpdate:self];
}

- (void)__detox_sync_onDetachedFromNode:(id)parent {
    dtx_log_info(@"[RCTAnimatedNode DTXSpy] Node %@ is being detached from parent %@", self, parent);
    [DTXAnimationUpdateSyncResource.sharedInstance trackNodeDetachedFromParent:self parent:parent];
    [self __detox_sync_onDetachedFromNode:parent];
}

@end
