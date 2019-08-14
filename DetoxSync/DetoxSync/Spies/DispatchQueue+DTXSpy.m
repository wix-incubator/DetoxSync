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

#define __dispatch_wrapper_func_2param(func, param1, param2) { \
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:queue]; \
	[sr increaseWorkBlocks];\
	func(param1, ^ {\
		param2();\
		[sr decreaseWorkBlocks];\
	});\
}

#define __dispatch_wrapper_func_3param(func, param1, param2, param3) { \
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:queue]; \
	[sr increaseWorkBlocks];\
	func(param1, param2, ^ {\
		param3();\
		[sr decreaseWorkBlocks];\
	});\
}

static void __detox_sync_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param(__detox_sync_orig_dispatch_sync, queue, block);
}

static void __detox_sync_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param(__detox_sync_orig_dispatch_async, queue, block);
}

static void (*__orig_dispatch_async_and_wait)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_async_and_wait(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param(__orig_dispatch_async_and_wait, queue, block);
}

void (*__orig_dispatch_after)(dispatch_time_t when, dispatch_queue_t queue,
		dispatch_block_t block);
static void __detox_sync_dispatch_after(dispatch_time_t when, dispatch_queue_t queue,
		dispatch_block_t block)
{
	__dispatch_wrapper_func_3param(__orig_dispatch_after, when, queue, block);
}

static void (*__orig_dispatch_group_async)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param(__orig_dispatch_group_async, group, queue, block);
}

static void (*__orig_dispatch_dispatch_group_notify)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param(__orig_dispatch_dispatch_group_notify, group, queue, block);
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
		"dispatch_async", __detox_sync_dispatch_async, NULL,
		"dispatch_sync", __detox_sync_dispatch_sync, NULL,
		"dispatch_async_and_wait", __detox_sync_dispatch_async_and_wait, (void**)&__orig_dispatch_async_and_wait,
		"dispatch_after", __detox_sync_dispatch_after, (void**)&__orig_dispatch_after,
		"dispatch_group_async", __detox_sync_dispatch_group_async, (void**)&__orig_dispatch_group_async,
		"dispatch_group_notify", __detox_sync_dispatch_group_notify, (void**)&__orig_dispatch_dispatch_group_notify,
		"dispatch_queue_create", __detox_sync_dispatch_queue_create, (void**)&__orig_dispatch_queue_create,
	};
	rebind_symbols(r, sizeof(r) / sizeof(struct rebinding));
}
