//
//  RCTNativeAnimatedNodesManager+DTXSpy.c
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "RCTNativeAnimatedNodesManager+DTXSpy.h"
#import "DTXSyncManager-Private.h"

@import ObjectiveC;

@interface NSObject ()

- (void)startAnimationLoopIfNeeded;
- (void)stopAnimationLoop;
- (void)addAnimatedEventToView:(NSNumber *)viewTag
                     eventName:(NSString *)eventName
                  eventMapping:(NSDictionary<NSString *, id> *)eventMapping;
- (void)removeAnimatedEventFromView:(NSNumber *)viewTag
                          eventName:(NSString *)eventName
                    animatedNodeTag:(NSNumber *)animatedNodeTag;

@end

@implementation NSObject (RCTNativeAnimatedNodesManagerDTXSpy)

+ (void)load
{
    @autoreleasepool
    {
        Class cls = NSClassFromString(@"RCTNativeAnimatedNodesManager");

        if(cls == nil)
        {
            return;
        }

        NSError* error;
        DTXSwizzleMethod(cls, @selector(startAnimationLoopIfNeeded), @selector(__detox_sync_startAnimationLoopIfNeeded), &error);
        DTXSwizzleMethod(cls, @selector(stopAnimationLoop), @selector(__detox_sync_stopAnimationLoop), &error);
        DTXSwizzleMethod(cls, @selector(addAnimatedEventToView:eventName:eventMapping:),
                         @selector(__detox_sync_addAnimatedEventToView:eventName:eventMapping:), &error);
        DTXSwizzleMethod(cls, @selector(removeAnimatedEventFromView:eventName:animatedNodeTag:),
                         @selector(__detox_sync_removeAnimatedEventFromView:eventName:animatedNodeTag:), &error);
    }
}

- (void)__detox_sync_startAnimationLoopIfNeeded
{
    [self __detox_sync_startAnimationLoopIfNeeded];

    CADisplayLink* dl = [self valueForKey:@"displayLink"];
    if(dl != nil) {
        [DTXSyncManager trackDisplayLink:dl name:@"React Native Animations Display Link"];
    }
}

- (void)__detox_sync_stopAnimationLoop
{
    CADisplayLink* dl = [self valueForKey:@"displayLink"];
    [self __detox_sync_stopAnimationLoop];

    if(dl != nil) {
        [DTXSyncManager untrackDisplayLink:dl];
    }
}

- (void)__detox_sync_addAnimatedEventToView:(NSNumber *)viewTag
                                  eventName:(NSString *)eventName
                               eventMapping:(NSDictionary<NSString *, id> *)eventMapping
{
    NSString* eventKey = [NSString stringWithFormat:@"%@%@", viewTag, eventName];
    id<DTXTrackedEvent> trackedEvent = [DTXSyncManager trackEventWithDescription:@"RN Animated Event"
                                                               objectDescription:[NSString stringWithFormat:@"View: %@ Event: %@", viewTag, eventName]];

    objc_setAssociatedObject(self,
                             (__bridge void *)eventKey,
                             trackedEvent,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self __detox_sync_addAnimatedEventToView:viewTag eventName:eventName eventMapping:eventMapping];
}

- (void)__detox_sync_removeAnimatedEventFromView:(NSNumber *)viewTag
                                       eventName:(NSString *)eventName
                                 animatedNodeTag:(NSNumber *)animatedNodeTag
{
    NSString* eventKey = [NSString stringWithFormat:@"%@%@", viewTag, eventName];
    id<DTXTrackedEvent> trackedEvent = objc_getAssociatedObject(self, (__bridge void *)eventKey);
    if(trackedEvent != nil) {
        [trackedEvent endTracking];
        objc_setAssociatedObject(self,
                                 (__bridge void *)eventKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [self __detox_sync_removeAnimatedEventFromView:viewTag eventName:eventName animatedNodeTag:animatedNodeTag];
}

@end
