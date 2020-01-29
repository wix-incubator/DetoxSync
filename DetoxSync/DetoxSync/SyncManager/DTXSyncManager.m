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
#import "DTXSingleUseSyncResource.h"
#import "_DTXObjectDeallocHelper.h"

#include <dlfcn.h>

DTX_CREATE_LOG("SyncManager")
static BOOL _enableVerboseSystemLogging = NO;
BOOL __detox_sync_enableVerboseSyncResourceLogging = NO;
#define dtx_log_verbose_sync_system(format, ...) __extension__({ \
if(__builtin_expect(_enableVerboseSystemLogging, 0)) { __dtx_log(__prepare_and_return_file_log(), OS_LOG_TYPE_DEBUG, __current_log_prefix, format, ##__VA_ARGS__); } \
})

#define TRY_IDLE_BLOCKS() [self _tryIdleBlocksNow:_useDelayedFire == 0];

#define if_unlikely(x) if(__builtin_expect(x, 0))

typedef void (^DTXIdleBlock)(void);

@interface _DTXIdleTupple : NSObject

@property (nonatomic, copy) DTXIdleBlock block;
@property (nonatomic, strong) dispatch_queue_t queue;

@end
@implementation _DTXIdleTupple @end

void __detox_sync_DTXSyncResourceVerboseLog(NSString* format, ...)
{
	va_list argumentList;
	va_start(argumentList, format);
	__dtx_logv(__prepare_and_return_file_log(), OS_LOG_TYPE_DEBUG, __current_log_prefix, format, argumentList);
	va_end(argumentList);
}

static dispatch_queue_t _queue;
static void* _queueSpecific = &_queueSpecific;
static double _useDelayedFire;
static dispatch_source_t _delayedFire;

static NSMapTable* _resourceMapping;
static NSMutableSet* _registeredResources;
static NSMutableArray<_DTXIdleTupple*>* _pendingIdleBlocks;
static NSHashTable<NSThread*>* _trackedThreads;
static BOOL _systemWasBusy = NO;

static __weak id<DTXSyncManagerDelegate> _delegate;
static BOOL _delegate_syncSystemDidBecomeIdle = NO;
static BOOL _delegate_syncSystemDidBecomeBusy = NO;
static BOOL _delegate_syncSystemDidStartTrackingEventWithDescription = NO;
static BOOL _delegate_syncSystemDidEndTrackingEventWithDescription = NO;

static NSTimeInterval _maximumAllowedDelayedActionTrackingDuration = __builtin_inf();
static NSTimeInterval _maximumTimerIntervalTrackingDuration = __builtin_inf();

@implementation DTXSyncManager

+ (NSTimeInterval)maximumAllowedDelayedActionTrackingDuration
{
	return _maximumAllowedDelayedActionTrackingDuration;
}

+ (void)setMaximumAllowedDelayedActionTrackingDuration:(NSTimeInterval)maximumAllowedDelayedActionTrackingDuration
{
	_maximumAllowedDelayedActionTrackingDuration = maximumAllowedDelayedActionTrackingDuration;
}

+ (NSTimeInterval)maximumTimerIntervalTrackingDuration
{
	return _maximumAllowedDelayedActionTrackingDuration;
}

+ (void)setMaximumTimerIntervalTrackingDuration:(NSTimeInterval)maximumTimerIntervalTrackingDuration
{
	_maximumTimerIntervalTrackingDuration = maximumTimerIntervalTrackingDuration;
}


+ (id<DTXSyncManagerDelegate>)delegate
{
	return _delegate;
}

+ (void)setDelegate:(id<DTXSyncManagerDelegate>)delegate
{
	_delegate = delegate;
	
	_delegate_syncSystemDidBecomeIdle = [_delegate respondsToSelector:@selector(syncSystemDidBecomeIdle)];
	_delegate_syncSystemDidBecomeBusy = [_delegate respondsToSelector:@selector(syncSystemDidBecomeBusy)];
	_delegate_syncSystemDidStartTrackingEventWithDescription = [_delegate respondsToSelector:@selector(syncSystemDidStartTrackingEventWithIdentifier:description:objectDescription:additionalDescription:)];
	_delegate_syncSystemDidEndTrackingEventWithDescription = [_delegate respondsToSelector:@selector(syncSystemDidEndTrackingEventWithIdentifier:)];
	
	if(_delegate == nil)
	{
		return;
	}
	
	BOOL systemBusy = DTXIsSystemBusyNow();
	if(systemBusy && _delegate_syncSystemDidBecomeBusy)
	{
		[_delegate syncSystemDidBecomeBusy];
	}
	else if(!systemBusy && _delegate_syncSystemDidBecomeIdle)
	{
		[_delegate syncSystemDidBecomeIdle];
	}
}

+ (void)superload
{
	@autoreleasepool
	{
		__detox_sync_enableVerboseSyncResourceLogging = [NSUserDefaults.standardUserDefaults boolForKey:@"DTXEnableVerboseSyncResources"];
		_enableVerboseSystemLogging = [NSUserDefaults.standardUserDefaults boolForKey:@"DTXEnableVerboseSyncSystem"];
		
		__detox_sync_orig_dispatch_sync = dlsym(RTLD_DEFAULT, "dispatch_sync");
		__detox_sync_orig_dispatch_async = dlsym(RTLD_DEFAULT, "dispatch_async");
		__detox_sync_orig_dispatch_after = dlsym(RTLD_DEFAULT, "dispatch_after");
		
		_queue = dispatch_queue_create("com.wix.syncmanager", dispatch_queue_attr_make_with_autorelease_frequency(NULL, DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM));
		dispatch_queue_set_specific(_queue, _queueSpecific, _queueSpecific, NULL);
		NSString* DTXEnableDelayedIdleFire = [NSUserDefaults.standardUserDefaults stringForKey:@"DTXEnableDelayedIdleFire"];
		NSNumberFormatter* nf = [NSNumberFormatter new];
		NSNumber* value = [nf numberFromString:DTXEnableDelayedIdleFire];
		_useDelayedFire = [value doubleValue];
		
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
		
		TRY_IDLE_BLOCKS();
	});
}

+ (void)performUpdateWithEventIdentifier:(NSString*)eventID eventDescription:(NSString*)eventDescription objectDescription:(NSString*)objectDescription additionalDescription:(NSString*)additionalDescription syncResource:(DTXSyncResource*)resource block:(NSUInteger(^)(void))block
{
	dispatch_block_t outerBlock = ^ {
		NSCAssert([_registeredResources containsObject:resource], @"Provided resource %@ is not registered", resource);
		
		NSUInteger previousBusyCount = [[_resourceMapping objectForKey:resource] unsignedIntegerValue];
		NSUInteger busyCount = block();
		if(previousBusyCount != busyCount)
		{
			DTXSyncResourceVerboseLog(@"%@ %@ (count: %lu)", busyCount > 0 ? @"👎" : @"👍", resource, (unsigned long)busyCount);
			
			if(previousBusyCount < busyCount && __builtin_expect(_delegate_syncSystemDidStartTrackingEventWithDescription, 0))
			{
				[_delegate syncSystemDidStartTrackingEventWithIdentifier:eventID description:eventDescription objectDescription:objectDescription additionalDescription:additionalDescription];
			}
			else if(previousBusyCount > busyCount && __builtin_expect(_delegate_syncSystemDidEndTrackingEventWithDescription, 0))
			{
				[_delegate syncSystemDidEndTrackingEventWithIdentifier:eventID];
			}
		}
		
		[_resourceMapping setObject:@(busyCount) forKey:resource];
		
		TRY_IDLE_BLOCKS();
	};
	
	if(dispatch_get_specific(_queueSpecific) == _queueSpecific)
	{
		outerBlock();
		return;
	}
	
	__detox_sync_orig_dispatch_sync(_queue, outerBlock);
}

+ (void)_fireDelayedTimer
{
	if(_delayedFire != nil)
	{
		dispatch_source_set_timer(_delayedFire, dispatch_time(DISPATCH_TIME_NOW, _useDelayedFire * NSEC_PER_SEC), 0, (1ull * NSEC_PER_SEC) / 10);
		return;
	}
	
	_delayedFire = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
	dispatch_source_set_timer(_delayedFire, dispatch_time(DISPATCH_TIME_NOW, _useDelayedFire * NSEC_PER_SEC), 0, (1ull * NSEC_PER_SEC) / 10);
	dispatch_source_set_event_handler(_delayedFire, ^{
		[self _tryIdleBlocksNow:YES];
		dispatch_source_cancel(_delayedFire);
		_delayedFire = nil;
	});
	dispatch_resume(_delayedFire);
}

__attribute__((__always_inline__))
static BOOL DTXIsSystemBusyNow(void)
{
	BOOL systemBusy = NO;
	
	for(NSNumber* value in _resourceMapping.objectEnumerator)
	{
		systemBusy |= (value.unsignedIntegerValue > 0);
		
		if(systemBusy == YES)
		{
			break;
		}
	}
	
	return systemBusy;
}

+ (void)_tryIdleBlocksNow:(BOOL)now
{
	if(_pendingIdleBlocks.count == 0 && _enableVerboseSystemLogging == NO)
	{
		return;
	}
	
	__block BOOL systemBusy = NO;
	dtx_defer {
		_systemWasBusy = systemBusy;
	};
	
	systemBusy = DTXIsSystemBusyNow();
	
	if(systemBusy == YES)
	{
		if(systemBusy != _systemWasBusy)
		{
			dtx_log_verbose_sync_system(@"❌ Sync system is busy");
			if_unlikely(_delegate_syncSystemDidBecomeBusy)
			{
				[_delegate syncSystemDidBecomeBusy];
			}
		}
		return;
	}
	else
	{
		if(systemBusy != _systemWasBusy || now == YES)
		{
			BOOL isDelayed = now == NO && _pendingIdleBlocks.count > 0;
			dtx_log_verbose_sync_system(@"%@ Sync system idle%@", isDelayed ? @"↩️" : @"✅" , isDelayed ? @" (delayed)" : @"");
			if_unlikely(_delegate_syncSystemDidBecomeIdle)
			{
				[_delegate syncSystemDidBecomeIdle];
			}
		}
	}
	
	if(_pendingIdleBlocks.count == 0)
	{
		return;
	}
	
	if(now == NO)
	{
		[self _fireDelayedTimer];
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
		dispatch_async(queue, ^ {
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
	dispatch_block_t outerBlock = ^ {
		_DTXIdleTupple* t = [_DTXIdleTupple new];
		t.block = block;
		t.queue = queue;
		
		[_pendingIdleBlocks addObject:t];
		
		TRY_IDLE_BLOCKS()
	};
	
	if(dispatch_get_specific(_queueSpecific) == _queueSpecific)
	{
		__detox_sync_orig_dispatch_async(_queue, outerBlock);
		return;
	}
	
	__detox_sync_orig_dispatch_sync(_queue, outerBlock);
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

+ (BOOL)isTrackedRunLoop:(CFRunLoopRef)runLoop
{
	id sr = [DTXRunLoopSyncResource _existingSyncResourceWithRunLoop:runLoop];
	return sr != nil;
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

+ (id<DTXEventTracker>)trackEventWithDescription:(NSString*)description objectDescription:(NSString*)objectDescription
{
	return [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:objectDescription eventDescription:description];
}

+ (NSString*)_syncStatus:(BOOL)includeAll;
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
		
		[rv appendFormat:@"• %@%@", includeAll == NO ? @"" : (isBusy == YES) ? @"❌ " : @"✅ " , includeAll ? sr.description : sr.syncResourceDescription];
	}
	
	if(rv.length == 0)
	{
		return @"The system is idle.";
	}
	
	return [NSString stringWithFormat:@"The system is busy with the following tasks:\n\n%@", rv];
}

+ (NSString*)idleStatus
{
	return [self _syncStatus:YES];
}

+ (NSString*)syncStatus
{
	return [self _syncStatus:YES];
}

+ (void)syncStatusWithCompletionHandler:(void (^)(NSString* information))completionHandler
{
	__detox_sync_orig_dispatch_async(_queue, ^ {
		completionHandler([self _syncStatus:NO]);
	});
}

@end
