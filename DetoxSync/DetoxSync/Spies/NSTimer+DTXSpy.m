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

__attribute__((__always_inline__))
static NSTimer* _DTXTimerInit(id instance, SEL selector, BOOL track, NSDate* date, NSTimeInterval ti, id t, SEL s, id ui, BOOL rep)
{
	id (*timerInitMsgSend)(id, SEL, id, NSTimeInterval, id, SEL, id, BOOL) = (void*)objc_msgSend;
	
	if(rep == YES || date == NSDate.distantFuture)
	{
		return timerInitMsgSend(instance, selector, date, ti, t, s, ui, rep);
	}
	
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource timerProxyWithTarget:t selector:s fireDate:date interval:ti repeats:rep];
	if(track)
	{
		[trampoline track];
	}
	NSTimer* rv = timerInitMsgSend(instance, selector, date, ti, trampoline, @selector(fire:), ui, rep);
	[trampoline setTimer:rv];
	return rv;
}

//NSCFTimer (Foundation)
- (instancetype)__detox_sync_initWithFireDate:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep
{
	return _DTXTimerInit(self, @selector(__detox_sync_initWithFireDate:interval:target:selector:userInfo:repeats:), NO, date, ti, t, s, ui, rep);
}

//__NSCFTimer (CoreFoundation)
- (instancetype)__detox_sync_initWithFireDate2:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep
{
	//Need to track here because CFRunLoopAddTimer will not be intercepted in this case.
	return _DTXTimerInit(self, @selector(__detox_sync_initWithFireDate2:interval:target:selector:userInfo:repeats:), YES, date, ti, t, s, ui, rep);
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
