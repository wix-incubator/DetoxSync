//
//  NSObject+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "NSObject+DTXSpy.h"
#import "DTXDelayedPerformSelectorSyncResource.h"
#import "DTXSyncManager-Private.h"

@import ObjectiveC;

@implementation NSObject (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		Method m1 = class_getInstanceMethod(NSObject.class, @selector(performSelector:withObject:afterDelay:inModes:));
		Method m2 = class_getInstanceMethod(NSObject.class, @selector(__detox_sync_performSelector:withObject:afterDelay:inModes:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(NSObject.class, @selector(performSelector:onThread:withObject:waitUntilDone:modes:));
		m2 = class_getInstanceMethod(NSObject.class, @selector(__detox_sync_performSelector:onThread:withObject:waitUntilDone:modes:));
		method_exchangeImplementations(m1, m2);
	}
}


- (void)__detox_sync_performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay inModes:(NSArray<NSRunLoopMode> *)modes
{
	if([DTXSyncManager isTrackedThread:NSThread.currentThread] == NO || delay > DTXSyncManager.maximumAllowedDelayedActionTrackingDuration)
	{
		[self __detox_sync_performSelector:aSelector withObject:anArgument afterDelay:delay inModes:modes];
		return;
	}
	
	id trampoline = [DTXDelayedPerformSelectorSyncResource delayedPerformSelectorProxyWithTarget:self selector:aSelector object:anArgument];
	
	[trampoline __detox_sync_performSelector:@selector(fire) withObject:nil afterDelay:delay inModes:modes];
}

- (void)__detox_sync_performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray<NSString *> *)array
{
	if([DTXSyncManager isTrackedThread:thr] == NO)
	{
		[self __detox_sync_performSelector:aSelector onThread:thr withObject:arg waitUntilDone:wait modes:array];
		return;
	}
	
	id trampoline = [DTXDelayedPerformSelectorSyncResource delayedPerformSelectorProxyWithTarget:self selector:aSelector object:arg];
	
	[trampoline __detox_sync_performSelector:@selector(fire) onThread:thr withObject:nil waitUntilDone:wait modes:array];
}

@end
