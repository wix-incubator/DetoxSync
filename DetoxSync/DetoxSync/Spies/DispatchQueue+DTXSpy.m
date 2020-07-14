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
#import "dispatch_time.h"

@import Darwin;

#define unlikely dtx_unlikely

DTX_ALWAYS_INLINE
void __dispatch_wrapper_func_2param(void (*func)(id, id), NSString* name, dispatch_queue_t param1, dispatch_block_t param2)
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:param1];
	DTXDispatchBlockProxy* proxy = nil;
	if(sr) { proxy = [DTXDispatchBlockProxy proxyWithBlock:param2 operation:name]; }
	[sr addWorkBlockProxy:proxy operation:name];
	func(param1, ^ {
		param2();
		[sr removeWorkBlockProxy:proxy operation:name];
	});
}

void __dispatch_wrapper_func_3param(void (*func)(id, id, id), NSString* name, id param1, dispatch_queue_t param2, dispatch_block_t param3)
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:param2];
	DTXDispatchBlockProxy* proxy = nil;
	if(sr) { proxy = [DTXDispatchBlockProxy proxyWithBlock:param3 operation:name]; }
	[sr addWorkBlockProxy:proxy operation:name];
	func(param1, param2, ^ {
		param3();
		[sr removeWorkBlockProxy:proxy operation:name];
	});
}

static void (*__orig_dispatch_sync)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param((void*)__orig_dispatch_sync, @"dispatch_sync", queue, block);
}

static void (*__orig_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param((void*)__orig_dispatch_async, @"dispatch_async", queue, block);
}

static void (*__orig_dispatch_async_and_wait)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_async_and_wait(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param((void*)__orig_dispatch_async_and_wait, @"dispatch_async_and_wait", queue, block);
}

static void (*__orig_dispatch_after)(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:queue];
	
	BOOL shouldTrack = sr != nil;
	
	uint64_t nanosecondsSinceEpoch = _dispatch_time_nanoseconds_since_epoch(when);
	NSTimeInterval secondsSinceEpoch = (double)nanosecondsSinceEpoch / (double)1000000000;
	NSTimeInterval timeFromNow = secondsSinceEpoch - [NSDate.date timeIntervalSince1970];
//	NSLog(@"🤦‍♂️ %@", @(timeFromNow));
	if(shouldTrack && isinf(DTXSyncManager.maximumAllowedDelayedActionTrackingDuration) == NO)
	{
		shouldTrack = DTXSyncManager.maximumAllowedDelayedActionTrackingDuration >= timeFromNow;
		
		if(shouldTrack == NO)
		{
			DTXSyncResourceVerboseLog(@"⏲ Ignoring dispatch_after with work block “%@”; failure reason: \"%@\"", [block debugDescription], [NSString stringWithFormat:@"duration>%@", @(timeFromNow)]);
		}
	}
	
	DTXDispatchBlockProxy* proxy = nil;
	if(shouldTrack)
	{
		proxy = [DTXDispatchBlockProxy proxyWithBlock:block operation:@"dispatch_after" moreInfo:@(DTXDoubleWithMaxFractionLength(timeFromNow, 3)).description];
		[sr addWorkBlockProxy:proxy operation:@"dispatch_after"];
	}
	
	__orig_dispatch_after(when, queue, ^{
		block();
		
		if(shouldTrack)
		{
			[sr removeWorkBlockProxy:proxy operation:@"dispatch_after"];
		}
	});
}
void untracked_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
	__orig_dispatch_after(when, queue, block);
}

static void (*__orig_dispatch_group_async)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param((void*)__orig_dispatch_group_async, @"dispatch_group_async", group, queue, block);
}

static void (*__orig_dispatch_group_notify)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param((void*)__orig_dispatch_group_notify, @"dispatch_group_notify", group, queue, block);
}

static dispatch_queue_t (*__orig_dispatch_queue_create)(const char *_Nullable label, dispatch_queue_attr_t _Nullable attr);
dispatch_queue_t __detox_sync_dispatch_queue_create(const char *_Nullable label, dispatch_queue_attr_t _Nullable attr)
{
	dispatch_queue_t rv = __orig_dispatch_queue_create(label, attr);
	
	if(label != NULL && strncmp(label, "com.apple.NSURLSession-work", strlen("com.apple.NSURLSession-work")) == 0)
	{
		[DTXSyncManager trackDispatchQueue:rv];
	}
	
	if(label != NULL && strncmp(label, "com.apple.NSURLSession-delegate", strlen("com.apple.NSURLSession-delegate")) == 0)
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
