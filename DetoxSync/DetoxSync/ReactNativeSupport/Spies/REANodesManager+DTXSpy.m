//
//  REANodesManager+DTXSpy.m (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2023.
//

#import "REANodesManager+DTXSpy.h"
#import "DTXSyncManager-Private.h"

@import ObjectiveC;

@interface NSObject ()

- (void)startUpdatingOnAnimationFrame;
- (void)stopUpdatingOnAnimationFrame;
- (instancetype)initWithModule:(id)reanimatedModule uiManager:(id)uiManager;
- (void)onAnimationFrame:(CADisplayLink *)displayLink;

@end

@implementation NSObject (REANodesManagerDTXSpy)

+ (void)load {
  @autoreleasepool {
    NSError *error;

    Class REANodesManagerClass = NSClassFromString(@"REANodesManager");


    DTXSyncResourceVerboseLog(@"REANodesManager class exists: %@", REANodesManagerClass != nil ? @"YES" : @"NO");

    if (REANodesManagerClass == nil) {
      return;
    }

    DTXSwizzleMethod(REANodesManagerClass, @selector(startUpdatingOnAnimationFrame), @selector(__detox_sync_startUpdatingOnAnimationFrame), &error);
    DTXSwizzleMethod(REANodesManagerClass, @selector(stopUpdatingOnAnimationFrame), @selector(__detox_sync_stopUpdatingOnAnimationFrame), &error);
    DTXSwizzleMethod(REANodesManagerClass, @selector(initWithModule:uiManager:), @selector(__detox_sync_initWithModule:uiManager:), &error);
    DTXSwizzleMethod(REANodesManagerClass, @selector(onAnimationFrame:), @selector(__detox_sync_onAnimationFrame:), &error);
  }
}

- (void)__detox_sync_startUpdatingOnAnimationFrame {
  NSLog(@"[DTXSpy] REANodesManager - startUpdatingOnAnimationFrame called");
  [DTXSyncManager trackDisplayLink:[self valueForKey:@"displayLink"] name:@"React Native Reanimated Animations Display Link"];

  [self __detox_sync_startUpdatingOnAnimationFrame];
}

- (void)__detox_sync_stopUpdatingOnAnimationFrame {
  NSLog(@"[DTXSpy] REANodesManager - stopUpdatingOnAnimationFrame called");
  CADisplayLink *dl = [self valueForKey:@"displayLink"];
  [DTXSyncManager untrackDisplayLink:dl];

  [self __detox_sync_stopUpdatingOnAnimationFrame];
}

- (instancetype)__detox_sync_initWithModule:(id)reanimatedModule uiManager:(id)uiManager {
  NSLog(@"[DTXSpy] REANodesManager - initWithModule:uiManager: called");
  return [self __detox_sync_initWithModule:reanimatedModule uiManager:uiManager];
}

- (void)__detox_sync_onAnimationFrame:(CADisplayLink *)displayLink {
  NSLog(@"[DTXSpy] REANodesManager - onAnimationFrame: called");
  [self __detox_sync_onAnimationFrame:displayLink];
}

@end
