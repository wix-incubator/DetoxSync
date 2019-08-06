//
//  NSTimer+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "NSTimer+DTXSpy.h"
#import "DTXNSTimerSyncResource.h"

@import ObjectiveC;

@implementation NSTimer (DTXSpy)

//NSCFTimer
- (instancetype)__detox_sync_initWithFireDate:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep
{
	id<DTXTimerProxy> trampoline = [DTXNSTimerSyncResource timeProxyWithTarget:t selector:s];
	NSTimer* rv = [self __detox_sync_initWithFireDate:date interval:ti target:trampoline selector:@selector(fire:) userInfo:ui repeats:rep];
	[trampoline setTimer:rv];
	return rv;
}

//__NSCFTimer
- (instancetype)__detox_sync_initWithFireDate2:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep
{
	id<DTXTimerProxy> trampoline = [DTXNSTimerSyncResource timeProxyWithTarget:t selector:s];
	NSTimer* rv = [self __detox_sync_initWithFireDate2:date interval:ti target:trampoline selector:@selector(fire:) userInfo:ui repeats:rep];
	[trampoline setTimer:rv];
	return rv;
}

void (*__orig_CFRunLoopTimerInvalidate)(CFRunLoopTimerRef timer);
void __detox_sync_CFRunLoopTimerInvalidate(CFRunLoopTimerRef timer)
{
	__orig_CFRunLoopTimerInvalidate(timer);
}

+ (void)load
{
	@autoreleasepool
	{
		Method m1 = class_getInstanceMethod(NSClassFromString(@"NSCFTimer"), @selector(initWithFireDate:interval:target:selector:userInfo:repeats:));
		Method m2 = class_getInstanceMethod(NSTimer.class, @selector(__detox_sync_initWithFireDate:interval:target:selector:userInfo:repeats:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(NSClassFromString(@"__NSCFTimer"), @selector(initWithFireDate:interval:target:selector:userInfo:repeats:));
		m2 = class_getInstanceMethod(NSTimer.class, @selector(__detox_sync_initWithFireDate2:interval:target:selector:userInfo:repeats:));
		method_exchangeImplementations(m1, m2);
	}
}

@end
