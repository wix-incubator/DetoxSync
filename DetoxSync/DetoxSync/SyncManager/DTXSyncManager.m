//
//  DTXSyncManager.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncManager-Private.h"
#import "DTXSyncResource.h"
#import "DTXOrigDispatch.h"
#import "DTXDispatchQueueSyncResource-Private.h"
#import "DTXRunLoopSyncResource-Private.h"
#import "DTXTimerSyncResource.h"

#include <dlfcn.h>

#import "DTXLogging.h"
DTX_CREATE_LOG("SyncManager")
static BOOL _enableVerboseSystemLogging = NO;
static BOOL _enableVerboseSyncResourceLogging = NO;
#define dtx_log_verbose_sync_resource(format, ...) __extension__({ \
if(_enableVerboseSyncResourceLogging) { __dtx_log(__prepare_and_return_file_log(), OS_LOG_TYPE_DEBUG, __current_log_prefix, format, ##__VA_ARGS__); } \
})
#define dtx_log_verbose_sync_system(format, ...) __extension__({ \
if(_enableVerboseSystemLogging) { __dtx_log(__prepare_and_return_file_log(), OS_LOG_TYPE_DEBUG, __current_log_prefix, format, ##__VA_ARGS__); } \
})

@import OSLog;

typedef void (^DTXIdleBlock)(void);

@interface _DTXIdleTupple : NSObject

@property (nonatomic, copy) DTXIdleBlock block;
@property (nonatomic, strong) dispatch_queue_t queue;

@end
@implementation _DTXIdleTupple @end

static dispatch_queue_t _queue;
static NSMapTable* _resourceMapping;
static NSMutableSet* _registeredResources;
static NSMutableArray<_DTXIdleTupple*>* _pendingIdleBlocks;
static NSHashTable<NSThread*>* _trackedThreads;
static BOOL _systemWasBusy = NO;

@implementation DTXSyncManager

+ (void)superload
{
	@autoreleasepool
	{
		_enableVerboseSyncResourceLogging = [NSUserDefaults.standardUserDefaults boolForKey:@"DTXEnableVerboseSyncResources"];
		_enableVerboseSystemLogging = [NSUserDefaults.standardUserDefaults boolForKey:@"DTXEnableVerboseSyncSystem"];
		
		__detox_sync_orig_dispatch_sync = dlsym(RTLD_DEFAULT, "dispatch_sync");
		__detox_sync_orig_dispatch_async = dlsym(RTLD_DEFAULT, "dispatch_async");
		
		_queue = dispatch_queue_create("com.wix.syncmanager", NULL);
		_resourceMapping = NSMapTable.strongToStrongObjectsMapTable;
		_registeredResources = [NSMutableSet new];
		_pendingIdleBlocks = [NSMutableArray new];
		
		_trackedThreads = [NSHashTable weakObjectsHashTable];
		[_trackedThreads addObject:[NSThread mainThread]];
		
		[self _trackCFRunLoop:CFRunLoopGetMain()];
	}
}

+ (void)registerSyncResource:(DTXSyncResource*)syncResource
{
	__detox_sync_orig_dispatch_sync(_queue, ^ {
		[_registeredResources addObject:syncResource];
	});
}

+ (void)unregisterSyncResource:(DTXSyncResource*)syncResource
{
	__detox_sync_orig_dispatch_sync(_queue, ^ {
		[_registeredResources removeObject:syncResource];
		[_resourceMapping removeObjectForKey:syncResource];
		
		[self _tryIdleBlocks];
	});
}

__attribute__((__always_inline__))
static void _performUpdateFunc(void(*func)(dispatch_queue_t queue, void(^)(void)), DTXSyncResource* resource, BOOL(^block)(void))
{
	func(_queue, ^ {
		NSCAssert([_registeredResources containsObject:resource], @"Provided resource %@ is not registered", resource);
		
		__unused BOOL wasBusy = [[_resourceMapping objectForKey:resource] boolValue];
		BOOL isBusy = block();
		if(wasBusy != isBusy)
		{
			dtx_log_verbose_sync_resource(@"%@ %@", isBusy ? @"👎" : @"👍", resource);
		}
		
		[_resourceMapping setObject:@(isBusy) forKey:resource];
		
		[DTXSyncManager _tryIdleBlocks];
	});
}

+ (void)perforUpdateForResource:(DTXSyncResource*)resource block:(BOOL(^)(void))block
{
	_performUpdateFunc(__detox_sync_orig_dispatch_async, resource, block);
}

+ (void)perforUpdateAndWaitForResource:(DTXSyncResource*)resource block:(BOOL(^)(void))block
{
	_performUpdateFunc(__detox_sync_orig_dispatch_sync, resource, block);
}

+ (void)_tryIdleBlocks
{
	if(_pendingIdleBlocks.count == 0 && _enableVerboseSystemLogging == NO)
	{
		return;
	}
	
	__block BOOL systemBusy = NO;
	dtx_defer {
		_systemWasBusy = systemBusy;
	};
	
	for(NSNumber* value in _resourceMapping.objectEnumerator)
	{
		systemBusy |= value.boolValue;
		
		if(systemBusy == YES)
		{
			break;
		}
	}
	
	if(systemBusy != _systemWasBusy)
	{
		dtx_log_verbose_sync_system(systemBusy ? @"❌ Sync system is busy" : @"✅ Sync system idle");
	}
	
	if(systemBusy == YES || _pendingIdleBlocks.count == 0)
	{
		return;
	}
	
	NSArray<_DTXIdleTupple*>* pendingWork = _pendingIdleBlocks.copy;
	[_pendingIdleBlocks removeAllObjects];
	
	NSMapTable<dispatch_queue_t, NSMutableArray<DTXIdleBlock>*>* blockDispatches = [NSMapTable strongToStrongObjectsMapTable];
	
	for (_DTXIdleTupple* obj in pendingWork) {
		if(obj.queue == nil)
		{
			obj.block();
			
			continue;
		}
		
		NSMutableArray<DTXIdleBlock>* arr = [blockDispatches objectForKey:obj.queue];
		if(arr == nil)
		{
			arr = [NSMutableArray new];
		}
		[arr addObject:obj.block];
		[blockDispatches setObject:arr forKey:obj.queue];
	}
	
	for(dispatch_queue_t queue in blockDispatches.keyEnumerator)
	{
		NSMutableArray<DTXIdleBlock>* arr = [blockDispatches objectForKey:queue];
		__detox_sync_orig_dispatch_async(queue, ^ {
			for(DTXIdleBlock block in arr)
			{
				block();
			}
		});
	}
}

+ (void)enqueueIdleBlock:(void(^)(void))block;
{
	[self enqueueIdleBlock:block queue:nil];
}

+ (void)enqueueIdleBlock:(void(^)(void))block queue:(dispatch_queue_t)queue;
{
	__detox_sync_orig_dispatch_sync(_queue, ^ {
		_DTXIdleTupple* t = [_DTXIdleTupple new];
		t.block = block;
		t.queue = queue;
		
		[_pendingIdleBlocks addObject:t];
		
		[self _tryIdleBlocks];
	});
}

+ (void)trackDispatchQueue:(dispatch_queue_t)dispatchQueue
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource dispatchQueueSyncResourceWithQueue:dispatchQueue];
	[self registerSyncResource:sr];
}

+ (void)untrackDispatchQueue:(dispatch_queue_t)dispatchQueue
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:dispatchQueue];
	if(sr)
	{
		[self unregisterSyncResource:sr];
	}
}

+ (void)trackRunLoop:(NSRunLoop *)runLoop
{
	[self trackCFRunLoop:runLoop.getCFRunLoop];
}

+ (void)untrackRunLoop:(NSRunLoop *)runLoop
{
	[self untrackCFRunLoop:runLoop.getCFRunLoop];
}

+ (void)trackCFRunLoop:(CFRunLoopRef)runLoop
{
	if(runLoop == CFRunLoopGetMain())
	{
		return;
	}
	
	[self _trackCFRunLoop:runLoop];
}

+ (void)_trackCFRunLoop:(CFRunLoopRef)runLoop
{
	id sr = [DTXRunLoopSyncResource _existingSyncResourceWithRunLoop:runLoop];
	if(sr != nil)
	{
		return;
	}
	
	sr = [DTXRunLoopSyncResource runLoopSyncResourceWithRunLoop:runLoop];
	[self registerSyncResource:sr];
	[sr _startTracking];
}

+ (void)untrackCFRunLoop:(CFRunLoopRef)runLoop
{
	if(runLoop == CFRunLoopGetMain())
	{
		return;
	}
	
	[self _untrackCFRunLoop:runLoop];
}

+ (void)_untrackCFRunLoop:(CFRunLoopRef)runLoop
{
	id sr = [DTXRunLoopSyncResource _existingSyncResourceWithRunLoop:runLoop];
	if(sr == nil)
	{
		return;
	}
	
	[sr _stopTracking];
	[self unregisterSyncResource:sr];
}

+ (void)trackThread:(NSThread *)thread
{
	if([thread isMainThread])
	{
		return;
	}
	
	__detox_sync_orig_dispatch_sync(_queue, ^ {
		[_trackedThreads addObject:thread];
	});
}

+ (void)untrackThread:(NSThread *)thread
{
	if([thread isMainThread])
	{
		return;
	}
	
	__detox_sync_orig_dispatch_sync(_queue, ^ {
		[_trackedThreads removeObject:thread];
	});
}

+ (BOOL)isTrackedThread:(NSThread*)thread
{
	if(thread.isMainThread == YES)
	{
		return YES;
	}

	__block BOOL rv = NO;
	__detox_sync_orig_dispatch_sync(_queue, ^ {
		rv = [_trackedThreads containsObject:thread];
	});
	
	return rv;
}

+ (void)trackDisplayLink:(CADisplayLink*)displayLink
{
	[DTXTimerSyncResource startTrackingDisplayLink:displayLink];
}

+ (void)untrackDisplayLink:(CADisplayLink*)displayLink
{
	[DTXTimerSyncResource stopTrackingDisplayLink:displayLink];
}

+ (NSString*)_idleStatus:(BOOL)includeAll;
{
	NSMutableString* rv = [NSMutableString new];
	
	NSArray* registeredResources = [_registeredResources.allObjects sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		return [NSStringFromClass([obj1 class]) compare:NSStringFromClass([obj2 class])];
	}];
	
	NSString* prevClass = nil;
	for(DTXSyncResource* sr in registeredResources)
	{
		BOOL isBusy = [[_resourceMapping objectForKey:sr] boolValue];
		
		if(includeAll == NO && isBusy == NO)
		{
			continue;
		}
		
		NSString* newClass = NSStringFromClass(sr.class);
		if(rv.length > 0)
		{
			[rv appendString:@"\n"];
			
			if(prevClass != nil && [prevClass isEqualToString:newClass] == NO)
			{
				[rv appendFormat:@"%@\n", includeAll == YES ? [NSString stringWithFormat:@"\n%@", sr.class] : @""];
			}
		}
		else if(includeAll == YES)
		{
			[rv appendFormat:@"%@\n", sr.class];
		}
		
		prevClass = newClass;
		
		[rv appendFormat:@"• %@%@", (includeAll == NO || isBusy == YES) ? @"" : @"Idle: " , includeAll ? sr.description : sr.syncResourceDescription];
	}
	
	if(rv.length == 0)
	{
		return @"The system is idle.";
	}
	
	return [NSString stringWithFormat:@"The system is busy with the following tasks:\n\n%@", rv];
}

+ (NSString*)idleStatus
{
	return [self _idleStatus:YES];
}

+ (NSString*)syncStatus
{
	return [self _idleStatus:YES];
}

+ (void)idleStatusWithCompletionHandler:(void (^)(NSString* information))completionHandler
{
	__detox_sync_orig_dispatch_async(_queue, ^ {
		completionHandler([self _idleStatus:NO]);
	});
}

@end
