//
//  ReactNativeSupport.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "ReactNativeSupport.h"
#import "ReactNativeHeaders.h"
#import "DTXSyncManager-Private.h"
#import <dlfcn.h>
#import <stdatomic.h>
#import <fishhook.h>

@import UIKit;
@import ObjectiveC;
@import Darwin;

DTX_CREATE_LOG(ReactNativeSupport);

_Atomic(CFRunLoopRef) __RNRunLoop;
_Atomic(const void*) __RNThread;
static void (*orig_runRunLoopThread)(id, SEL) = NULL;
static void swz_runRunLoopThread(id self, SEL _cmd)
{
	CFRunLoopRef oldRunloop = atomic_load(&__RNRunLoop);
	
	CFRunLoopRef current = CFRunLoopGetCurrent();
	atomic_store(&__RNRunLoop, current);
	
	//This will take the old thread and release it by transfering ownership to ObjC.
	NSThread* oldThread = CFBridgingRelease(atomic_load(&__RNThread));
	oldThread = nil;
	
	atomic_store(&__RNThread, CFBridgingRetain([NSThread currentThread]));

	[DTXSyncManager trackCFRunLoop:current];
	[DTXSyncManager untrackCFRunLoop:oldRunloop];
	
	orig_runRunLoopThread(self, _cmd);
}

static NSMutableArray* _observedQueues;

static int (*__orig__UIApplication_run_orig)(id self, SEL _cmd);
static int __detox_sync_UIApplication_run(id self, SEL _cmd)
{
	Class cls = NSClassFromString(@"RCTJSCExecutor");
	Method m = NULL;
	if(cls != NULL)
	{
		//Legacy RN
		m = class_getClassMethod(cls, NSSelectorFromString(@"runRunLoopThread"));
		dtx_log_info(@"Found legacy class RCTJSCExecutor");
	}
	else
	{
		//Modern RN
		cls = NSClassFromString(@"RCTCxxBridge");
		m = class_getClassMethod(cls, NSSelectorFromString(@"runRunLoop"));
		if(m == NULL)
		{
			m = class_getInstanceMethod(cls, NSSelectorFromString(@"runJSRunLoop"));
			dtx_log_info(@"Found modern class RCTCxxBridge, method runJSRunLoop");
		}
		else
		{
			dtx_log_info(@"Found modern class RCTCxxBridge, method runRunLoop");
		}
	}
	
	if(m != NULL)
	{
		orig_runRunLoopThread = (void(*)(id, SEL))method_getImplementation(m);
		method_setImplementation(m, (IMP)swz_runRunLoopThread);
	}
	else
	{
		dtx_log_info(@"Method runRunLoop not found");
	}
	
	return __orig__UIApplication_run_orig(self, _cmd);
}


@implementation ReactNativeSupport

+ (BOOL)hasReactNative
{
	return (NSClassFromString(@"RCTBridge") != nil);
}

+ (void)superload
{
	@autoreleasepool
	{
		Class cls = NSClassFromString(@"RCTModuleData");
		if(cls == nil)
		{
			return;
		}

		_observedQueues = [NSMutableArray new];

		//Add an idling resource for each module queue.
		Method m = class_getInstanceMethod(cls, NSSelectorFromString(@"setUpMethodQueue"));
		void(*orig_setUpMethodQueue_imp)(id, SEL) = (void(*)(id, SEL))method_getImplementation(m);
		method_setImplementation(m, imp_implementationWithBlock(^(id _self) {
			orig_setUpMethodQueue_imp(_self, NSSelectorFromString(@"setUpMethodQueue"));
			
			dispatch_queue_t queue = object_getIvar(_self, class_getInstanceVariable(cls, "_methodQueue"));
			
			if(queue != nil && [queue isKindOfClass:[NSNull class]] == NO && queue != dispatch_get_main_queue() && [_observedQueues containsObject:queue] == NO)
			{
				NSString* queueName = [[NSString alloc] initWithUTF8String:dispatch_queue_get_label(queue) ?: queue.description.UTF8String];
				
				[_observedQueues addObject:queue];
				
				dtx_log_info(@"Adding idling resource for queue: %@", queueName);
				
				[DTXSyncManager trackDispatchQueue:queue];
			}
		}));

		//Cannot just extern this function - we are not linked with RN, so linker will fail. Instead, look for symbol in runtime.
		dispatch_queue_t (*RCTGetUIManagerQueue)(void) = dlsym(RTLD_DEFAULT, "RCTGetUIManagerQueue");

		//Must be performed in +load and not in +setUp in order to correctly catch the ui queue, runloop and display link initialization by RN.
		dispatch_queue_t queue = RCTGetUIManagerQueue();
		[_observedQueues addObject:queue];

		dtx_log_info(@"Adding idling resource for RCTUIManagerQueue");

		[DTXSyncManager trackDispatchQueue:queue];
		
		m = class_getInstanceMethod(UIApplication.class, NSSelectorFromString(@"_run"));
		__orig__UIApplication_run_orig = (void*)method_getImplementation(m);
		method_setImplementation(m, (void*)__detox_sync_UIApplication_run);

		dtx_log_info(@"Adding idling resource for JS timers");

		//TODO:
//		[[GREYUIThreadExecutor sharedInstance] registerIdlingResource:[WXJSTimerObservationIdlingResource new]];

		dtx_log_info(@"Adding idling resource for RN load");

		//TODO:
//		[[GREYUIThreadExecutor sharedInstance] registerIdlingResource:[WXRNLoadIdlingResource new]];

		//TODO:
//		if([WXAnimatedDisplayLinkIdlingResource isAvailable]) {
//			dtx_log_info(@"Adding idling resource for Animated display link");
//
//			[[GREYUIThreadExecutor sharedInstance] registerIdlingResource:[WXAnimatedDisplayLinkIdlingResource new]];
//		}
	}
}

@end
