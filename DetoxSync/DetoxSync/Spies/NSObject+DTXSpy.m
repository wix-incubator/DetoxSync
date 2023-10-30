//
//  NSObject+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

/**
 *    ██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗
 *    ██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝
 *    ██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
 *    ██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║
 *    ╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝
 *     ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝
 *
 *
 * WARNING: This file compiles with ARC disabled! Take extra care when modifying or adding functionality.
 */

#import "NSObject+DTXSpy.h"
#import "DTXDelayedPerformSelectorSyncResource.h"
#import "DTXSyncManager-Private.h"

@import ObjectiveC;

@implementation NSObject (DTXSpy)

+ (void)load
{
  @autoreleasepool
  {
    NSError* error;

    DTXSwizzleMethod(self, @selector(performSelector:withObject:afterDelay:inModes:), @selector(__detox_sync_performSelector:withObject:afterDelay:inModes:), &error);
    DTXSwizzleMethod(self, @selector(performSelector:onThread:withObject:waitUntilDone:modes:), @selector(__detox_sync_performSelector:onThread:withObject:waitUntilDone:modes:), &error);
  }
}


- (void)__detox_sync_performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay inModes:(NSArray<NSRunLoopMode> *)modes
{
  if([DTXSyncManager isThreadTracked:NSThread.currentThread] == NO ||
     delay > DTXSyncManager.maximumAllowedDelayedActionTrackingDuration ||
     [self shouldDisableTrackingForDelayedSelector:aSelector withTarget:self object:anArgument])
  {
    [self __detox_sync_performSelector:aSelector withObject:anArgument afterDelay:delay inModes:modes];
    return;
  }

  id trampoline = [DTXDelayedPerformSelectorSyncResource delayedPerformSelectorProxyWithTarget:self selector:aSelector object:anArgument];
  [trampoline __detox_sync_performSelector:@selector(fire) withObject:nil afterDelay:delay inModes:modes];
}

- (BOOL)shouldDisableTrackingForDelayedSelector:(SEL)aSelector withTarget:(id)target object:(id)obj
{
  // This is a workaround to ignore special edge case of delayed gesture recognizer cancelation
  //  from react-native-gesture-handler.
  if (target &&
      [NSStringFromClass([target class]) isEqualToString:@"RNBetterTapGestureRecognizer"] &&
      [NSStringFromSelector(aSelector) isEqualToString:@"cancel"]) {
    return YES;
  }

  return NO;
}

- (void)__detox_sync_performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray<NSString *> *)array
{
  if([DTXSyncManager isThreadTracked:thr] == NO)
  {
    [self __detox_sync_performSelector:aSelector onThread:thr withObject:arg waitUntilDone:wait modes:array];
    return;
  }

  id trampoline = [DTXDelayedPerformSelectorSyncResource delayedPerformSelectorProxyWithTarget:self selector:aSelector object:arg];
  [trampoline __detox_sync_performSelector:@selector(fire) onThread:thr withObject:nil waitUntilDone:wait modes:array];
}

@end
