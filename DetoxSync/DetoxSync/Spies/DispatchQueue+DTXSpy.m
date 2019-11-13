//
//  DispatchQueue+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DispatchQueue+DTXSpy.h"
#import "DTXDispatchQueueSyncResource-Private.h"
#import "fishhook.h"
#import "DTXOrigDispatch.h"
#import "DTXSyncManager-Private.h"

#define __dispatch_wrapper_func_2param(func, name, param1, param2) { \
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:queue]; \
	NSString* blockInfo = nil;\
	if(sr != nil) { blockInfo = [param2 debugDescription]; } \
	[sr addWorkBlock:blockInfo operation:name];\
	func(param1, ^ {\
		param2();\
		[sr removeWorkBlock:blockInfo operation:name];\
	});\
}

#define __dispatch_wrapper_func_3param(func, name, param1, param2, param3) { \
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:queue]; \
	NSString* blockInfo = nil;\
	if(sr != nil) { blockInfo = [param3 debugDescription]; } \
	[sr addWorkBlock:blockInfo operation:name];\
	func(param1, param2, ^ {\
		param3();\
		[sr removeWorkBlock:blockInfo operation:name];\
	});\
}

static void (*__orig_dispatch_sync)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param(__orig_dispatch_sync, @"dispatch_sync", queue, block);
}

static void (*__orig_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param(__orig_dispatch_async, @"dispatch_async", queue, block);
}

static void (*__orig_dispatch_async_and_wait)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_async_and_wait(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param(__orig_dispatch_async_and_wait, @"dispatch_async_and_wait", queue, block);
}

void (*__orig_dispatch_after)(dispatch_time_t when, dispatch_queue_t queue,
							  dispatch_block_t block);
static void __detox_sync_dispatch_after(dispatch_time_t when, dispatch_queue_t queue,
										dispatch_block_t block)
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:queue];
	NSString* blockInfo = nil;
	
	BOOL shouldTrack = sr != nil;
	
	if(shouldTrack && isinf(DTXSyncManager.maximumAllowedDelayedActionTrackingDuration) == NO)
	{
		dispatch_time_t maxAllowedTracked = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DTXSyncManager.maximumAllowedDelayedActionTrackingDuration * NSEC_PER_SEC));
		shouldTrack = maxAllowedTracked >= when;
	}
	
	if(shouldTrack)
	{
		blockInfo = [block debugDescription];
		[sr addWorkBlock:blockInfo operation:@"dispatch_after"];
	}
	
	__orig_dispatch_after(when, queue, ^{
		block();
		
		if(shouldTrack)
		{
			[sr removeWorkBlock:blockInfo operation:@"dispatch_after"];
		}
	});
}

static void (*__orig_dispatch_group_async)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param(__orig_dispatch_group_async, @"dispatch_group_async", group, queue, block);
}

static void (*__orig_dispatch_group_notify)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param(__orig_dispatch_group_notify, @"dispatch_group_notify", group, queue, block);
}

static dispatch_queue_t (*__orig_dispatch_queue_create)(const char *_Nullable label, dispatch_queue_attr_t _Nullable attr);
dispatch_queue_t __detox_sync_dispatch_queue_create(const char *_Nullable label, dispatch_queue_attr_t _Nullable attr)
{
	dispatch_queue_t rv = __orig_dispatch_queue_create(label, attr);
	
	if(label != NULL && strncmp(label, "com.apple.NSURLSession-work", strlen("com.apple.NSURLSession-work")) == 0)
	{
		[DTXSyncManager trackDispatchQueue:rv];
	}
	
	return rv;
}


__attribute__((constructor))
static void _install_dispatchqueue_spy(void)
{
//	dispatch_async
	struct rebinding r[] = (struct rebinding[]) {
		"dispatch_async", __detox_sync_dispatch_async, (void**)&__orig_dispatch_async,
		"dispatch_sync", __detox_sync_dispatch_sync, (void**)&__orig_dispatch_sync,
		"dispatch_async_and_wait", __detox_sync_dispatch_async_and_wait, (void**)&__orig_dispatch_async_and_wait,
		"dispatch_after", __detox_sync_dispatch_after, (void**)&__orig_dispatch_after,
		"dispatch_group_async", __detox_sync_dispatch_group_async, (void**)&__orig_dispatch_group_async,
		"dispatch_group_notify", __detox_sync_dispatch_group_notify, (void**)&__orig_dispatch_group_notify,
		"dispatch_queue_create", __detox_sync_dispatch_queue_create, (void**)&__orig_dispatch_queue_create,
	};
	rebind_symbols(r, sizeof(r) / sizeof(struct rebinding));
}
