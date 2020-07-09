//
//  NSTimer+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "NSTimer+DTXSpy.h"
#import "DTXTimerSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "fishhook.h"

@import ObjectiveC;

@implementation NSTimer (DTXSpy)

static NSString* failuireReasonForTrampoline(id<DTXTimerProxy> trampoline, CFRunLoopRef rl)
{
	if([DTXSyncManager isTrackedRunLoop:rl] == NO)
	{
		return @"untracked runloop";
	}
	else if(trampoline.repeats == YES)
	{
		return @"repeats==true";
	}
	else if([trampoline.fireDate timeIntervalSinceNow] > DTXSyncManager.maximumTimerIntervalTrackingDuration)
	{
		return [NSString stringWithFormat:@"duration>%@", @([trampoline.fireDate timeIntervalSinceNow])];
	}
	
	return @"";
}

static void _DTXTrackTimerTrampolineIfNeeded(id<DTXTimerProxy> trampoline, CFRunLoopRef rl)
{
	if(trampoline != nil && [DTXSyncManager isTrackedRunLoop:rl] && trampoline.repeats != YES && [trampoline.fireDate timeIntervalSinceNow] <= DTXSyncManager.maximumTimerIntervalTrackingDuration)
	{
		[trampoline track];
	}
	else
	{
		DTXSyncResourceVerboseLog(@"⏲ Ignoring timer “%@”; failure reason: \"%@\"", trampoline.timer, failuireReasonForTrampoline(trampoline, rl));
	}
}

static void _DTXCFTimerTrampoline(CFRunLoopTimerRef timer, void *info)
{
	id<DTXTimerProxy> tp = [DTXTimerSyncResource existingTimeProxyWithTimer:NS(timer)];
	[tp fire:(__bridge NSTimer*)timer];
}

static CFRunLoopTimerRef (*__orig_CFRunLoopTimerCreate)(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, CFRunLoopTimerCallBack callout, CFRunLoopTimerContext *context);
CFRunLoopTimerRef __detox_sync_CFRunLoopTimerCreate(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, CFRunLoopTimerCallBack callout, CFRunLoopTimerContext *context)
{
	CFRunLoopTimerRef rv = __orig_CFRunLoopTimerCreate(allocator, fireDate, interval, flags, order, _DTXCFTimerTrampoline, context);
	
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource timerProxyWithCallback:callout fireDate:CFBridgingRelease(CFDateCreate(allocator, fireDate)) interval:interval repeats:interval > 0];

	[trampoline setTimer:(__bridge NSTimer*)rv];
	
	return rv;
}

static CFRunLoopTimerRef (*__orig_CFRunLoopTimerCreateWithHandler)(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, void (^block) (CFRunLoopTimerRef timer));
CFRunLoopTimerRef __detox_sync_CFRunLoopTimerCreateWithHandler(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, void (^block) (id timer))
{
	return (__bridge_retained CFRunLoopTimerRef)[[NSTimer alloc] initWithFireDate:CFBridgingRelease(CFDateCreate(allocator, fireDate)) interval:interval repeats:interval > 0 block:block];
}

static void (*__orig_CFRunLoopAddTimer)(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode);
void __detox_sync_CFRunLoopAddTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode)
{
//	NSLog(@"🤦‍♂️ addTimer: %@", NS(timer));
	
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource existingTimeProxyWithTimer:NS(timer)];
	_DTXTrackTimerTrampolineIfNeeded(trampoline, rl);
	
	__orig_CFRunLoopAddTimer(rl, timer, mode);
}

static void (*__orig_CFRunLoopRemoveTimer)(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode);
void __detox_sync_CFRunLoopRemoveTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode)
{
//	NSLog(@"🤦‍♂️ removeTimer: %@", NS(timer));
	
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource existingTimeProxyWithTimer:NS(timer)];
	[trampoline untrack];
	
	__orig_CFRunLoopRemoveTimer(rl, timer, mode);
}

static void (*__orig_CFRunLoopTimerInvalidate)(CFRunLoopTimerRef timer);
void __detox_sync_CFRunLoopTimerInvalidate(CFRunLoopTimerRef timer)
{
//	NSLog(@"🤦‍♂️ invalidate: %@", NS(timer));
	
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource existingTimeProxyWithTimer:NS(timer)];
	[trampoline untrack];
	
	__orig_CFRunLoopTimerInvalidate(timer);
}

+ (void)load
{
	@autoreleasepool
	{
		struct rebinding r[] = (struct rebinding[]) {
			"CFRunLoopAddTimer", __detox_sync_CFRunLoopAddTimer, (void*)&__orig_CFRunLoopAddTimer,
			"CFRunLoopRemoveTimer", __detox_sync_CFRunLoopRemoveTimer, (void*)&__orig_CFRunLoopRemoveTimer,
			"CFRunLoopTimerInvalidate", __detox_sync_CFRunLoopTimerInvalidate, (void*)&__orig_CFRunLoopTimerInvalidate,
			"CFRunLoopTimerCreate", __detox_sync_CFRunLoopTimerCreate, (void*)&__orig_CFRunLoopTimerCreate,
			"CFRunLoopTimerCreateWithHandler", __detox_sync_CFRunLoopTimerCreateWithHandler, (void*)&__orig_CFRunLoopTimerCreateWithHandler,
		};
		rebind_symbols(r, sizeof(r) / sizeof(struct rebinding));
	}
}

@end
