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
		DTXSyncResourceVerboseLog(@"⏲ Ignoring timer “%@” failure reason: \"%@\"", trampoline.timer, failuireReasonForTrampoline(trampoline, rl));
	}
}

static const void* _DTXCFTimerTrampolineRetain(const void* info)
{
	const void* rv = CFRetain(info);
	id<DTXTimerProxy> tp = (__bridge id)info;
	[tp retainContext];
	
	return rv;
}

static void _DTXCFTimerTrampolineRelease(const void* info)
{
	id<DTXTimerProxy> tp = (__bridge id)info;
	[tp retainContext];
	CFRelease(info);
}

static void _DTXCFTimerTrampoline(CFRunLoopTimerRef timer, void *info)
{
	id<DTXTimerProxy> tp = (__bridge id)info;
	[tp fire:(__bridge NSTimer*)timer];
}

static CFRunLoopTimerRef (*__orig_CFRunLoopTimerCreate)(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, CFRunLoopTimerCallBack callout, CFRunLoopTimerContext *context);
CFRunLoopTimerRef __detox_sync_CFRunLoopTimerCreate(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, CFRunLoopTimerCallBack callout, CFRunLoopTimerContext *context)
{
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource timerProxyWithCallBack:callout context:context fireDate:CFBridgingRelease(CFDateCreate(allocator, fireDate)) interval:interval repeats:interval > 0];
	
	BOOL freeContext = NO;
	if(context == NULL)
	{
		context = malloc(sizeof(CFRunLoopTimerContext));
		freeContext = YES;
	}
	
	context->info=(__bridge void*)trampoline;
	context->retain = _DTXCFTimerTrampolineRetain;
	context->release = _DTXCFTimerTrampolineRelease;
	context->copyDescription = NULL;
	
	CFRunLoopTimerRef rv = __orig_CFRunLoopTimerCreate(allocator, fireDate, interval, flags, order, _DTXCFTimerTrampoline, context);
	
	if(freeContext)
	{
		free(context);
	}
	
	[trampoline setTimer:(__bridge NSTimer*)rv];
	
	return rv;
}

static CFRunLoopTimerRef (*__orig_CFRunLoopTimerCreateWithHandler)(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, void (^block) (CFRunLoopTimerRef timer));
CFRunLoopTimerRef __detox_sync_CFRunLoopTimerCreateWithHandler(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags, CFIndex order, void (^block) (id timer))
{
	return (__bridge_retained CFRunLoopTimerRef)[[NSTimer alloc] initWithFireDate:CFBridgingRelease(CFDateCreate(allocator, fireDate)) interval:interval repeats:interval > 0 block:block];
}

//__attribute__((__always_inline__))
//static NSTimer* _DTXTimerInit(id instance, SEL selector, BOOL track, NSDate* date, NSTimeInterval ti, id t, SEL s, id ui, BOOL rep)
//{
//	id (*timerInitMsgSend)(id, SEL, id, NSTimeInterval, id, SEL, id, BOOL) = (void*)objc_msgSend;
//
//	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource timerProxyWithTarget:t selector:s fireDate:date interval:ti repeats:rep];
//	if(track)
//	{
//		[trampoline track];
//	}
//	NSTimer* rv = timerInitMsgSend(instance, selector, date, ti, trampoline, @selector(fire:), ui, rep);
//	[trampoline setTimer:rv];
//	return rv;
//}
//
////__NSCFTimer (CoreFoundation)
//- (instancetype)__detox_sync_initWithFireDate2:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep
//{
//	//Need to track here because CFRunLoopTimerCreate/CFRunLoopAddTimer will not be intercepted in this case.
//	return _DTXTimerInit(self, @selector(__detox_sync_initWithFireDate2:interval:target:selector:userInfo:repeats:), YES, date, ti, t, s, ui, rep);
//}

static void (*__orig_CFRunLoopAddTimer)(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode);
void __detox_sync_CFRunLoopAddTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFRunLoopMode mode)
{
	id<DTXTimerProxy> trampoline = [DTXTimerSyncResource existingTimeProxyWithTimer:(__bridge NSTimer*)timer];
	
	_DTXTrackTimerTrampolineIfNeeded(trampoline, rl);
	
	__orig_CFRunLoopAddTimer(rl, timer, mode);
}

+ (void)load
{
	@autoreleasepool
	{
		struct rebinding r[] = (struct rebinding[]) {
			"CFRunLoopAddTimer", __detox_sync_CFRunLoopAddTimer, (void*)&__orig_CFRunLoopAddTimer,
			"CFRunLoopTimerCreate", __detox_sync_CFRunLoopTimerCreate, (void*)&__orig_CFRunLoopTimerCreate,
			"CFRunLoopTimerCreateWithHandler", __detox_sync_CFRunLoopTimerCreateWithHandler, (void*)&__orig_CFRunLoopTimerCreateWithHandler,
		};
		rebind_symbols(r, sizeof(r) / sizeof(struct rebinding));
	}
}

@end
