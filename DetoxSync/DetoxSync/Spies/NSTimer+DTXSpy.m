//
//  NSTimer+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "NSTimer+DTXSpy.h"
#import "DTXTimerSyncResource.h"
#import "fishhook.h"

@import ObjectiveC;

@implementation NSTimer (DTXSpy)

//NSCFTimer (Foundation)
- (instancetype)__detox_sync_initWithFireDate:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep
{
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource timerProxyWithTarget:t selector:s fireDate:date interval:ti repeats:rep];
	NSTimer* rv = [self __detox_sync_initWithFireDate:date interval:ti target:trampoline selector:@selector(fire:) userInfo:ui repeats:rep];
	[trampoline setTimer:rv];
	return rv;
}

//__NSCFTimer (CoreFoundation)
- (instancetype)__detox_sync_initWithFireDate2:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep
{
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource timerProxyWithTarget:t selector:s fireDate:date interval:ti repeats:rep];
	//Need to track here because CFRunLoopAddTimer will not be intercepted in this case.
	[trampoline track];
	NSTimer* rv = [self __detox_sync_initWithFireDate2:date interval:ti target:trampoline selector:@selector(fire:) userInfo:ui repeats:rep];
	[trampoline setTimer:rv];
	return rv;
}

static void (*__orig_CFRunLoopAddTimer)(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode);
void __detox_sync_CFRunLoopAddTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode)
{
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource existingTimeProxyWithTimer:(__bridge NSTimer*)timer];
	if(trampoline)
	{
		[trampoline track];
	}
	
	__orig_CFRunLoopAddTimer(rl, timer, mode);
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
		
		struct rebinding r[] = (struct rebinding[]) {
			"CFRunLoopAddTimer", __detox_sync_CFRunLoopAddTimer, (void*)&__orig_CFRunLoopAddTimer,
		};
		rebind_symbols(r, sizeof(r) / sizeof(struct rebinding));
	}
}

@end
