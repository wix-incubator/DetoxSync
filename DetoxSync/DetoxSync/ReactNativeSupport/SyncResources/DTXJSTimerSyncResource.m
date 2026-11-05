//
//  DTXJSTimerSyncResource.m
//  DetoxSync
//

#import "DTXJSTimerSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"
#import "DTXOrigDispatch.h"

#import <os/lock.h>

@import ObjectiveC;

DTX_CREATE_LOG(DTXJSTimerSyncResource);

// 1500 ms total timeout from creation
static const NSTimeInterval kTimerTimeout = 1.5;

static NSString* _prettyTimerDescription(NSNumber* timerID)
{
    return [NSString stringWithFormat:@"JavaScript Timer %@ (Native Implementation)", timerID];
}

// Hops to the main queue without going through the swizzled dispatch_async, which calls back into the sync manager's
// queue and would deadlock against a status query (wix/Detox#4966).
static void _dispatchToMainQueue(dispatch_block_t block)
{
    if (__detox_sync_orig_dispatch_async != NULL) {
        __detox_sync_orig_dispatch_async(dispatch_get_main_queue(), block);
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@implementation DTXJSTimerSyncResource {
    NSHashTable<id> *_observedInstances;
    NSMutableDictionary<NSNumber *, NSNumber *> *_pendingTimers;
    NSMutableDictionary<NSNumber *, NSDate *> *_entryTimes;
    NSMutableDictionary<NSNumber *, dispatch_source_t> *_cleanupTimers;
    dispatch_queue_t _queue;
    os_unfair_lock _snapshotLock;
    NSArray<NSDictionary *> *_snapshot;
}

+ (instancetype)sharedInstance {
    static DTXJSTimerSyncResource* shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DTXJSTimerSyncResource alloc] init];
        [DTXSyncManager registerSyncResource:shared];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _observedInstances = [NSHashTable weakObjectsHashTable];
        _pendingTimers = [NSMutableDictionary new];
        _entryTimes = [NSMutableDictionary new];
        _cleanupTimers = [NSMutableDictionary new];
        _queue = dispatch_queue_create("com.detox.sync.JSTimerSync", DISPATCH_QUEUE_SERIAL);
        _snapshotLock = OS_UNFAIR_LOCK_INIT;
        _snapshot = @[];
        [self setupTimerObservation];
    }
    return self;
}

- (void)setupTimerObservation {
    __weak __typeof(self) weakSelf = self;
    Class cls = NSClassFromString(@"RCTTiming");

    SEL createTimerForNextFrameSel = NSSelectorFromString(@"createTimerForNextFrame:duration:jsSchedulingTime:repeats:");
    Method createTimerForNextFrameMethod = class_getInstanceMethod(cls, createTimerForNextFrameSel);

    void (*orig_createTimerForNextFrame)(id, SEL, NSNumber*, NSTimeInterval, NSDate*, BOOL) = (void*)method_getImplementation(createTimerForNextFrameMethod);
    method_setImplementation(createTimerForNextFrameMethod, imp_implementationWithBlock(^(id _self, NSNumber* callbackID, NSTimeInterval duration, NSDate* jsSchedulingTime, BOOL repeats) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf observeTimerWithInstance:_self timerID:callbackID duration:duration repeats:repeats];
            orig_createTimerForNextFrame(_self, createTimerForNextFrameSel, callbackID, duration, jsSchedulingTime, repeats);
        } else {
            orig_createTimerForNextFrame(_self, createTimerForNextFrameSel, callbackID, duration, jsSchedulingTime, repeats);
        }
    }));

    SEL deleteTimerSel = NSSelectorFromString(@"deleteTimer:");
    Method deleteTimerMethod = class_getInstanceMethod(cls, deleteTimerSel);

    void (*orig_deleteTimer)(id, SEL, double) = (void*)method_getImplementation(deleteTimerMethod);
    method_setImplementation(deleteTimerMethod, imp_implementationWithBlock(^(id _self, double timerID) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf deleteTimer:@(timerID)];
        }
        orig_deleteTimer(_self, deleteTimerSel, timerID);
    }));
}

- (void)observeTimerWithInstance:(id)instance timerID:(NSNumber *)timerID duration:(NSTimeInterval)duration repeats:(BOOL)repeats {
    dispatch_async(_queue, ^{
        if (![_observedInstances containsObject:instance]) {
            [_observedInstances addObject:instance];
        }

        // Skip invalid or zero timer IDs
        if (timerID == nil || [timerID isEqualToNumber:@0]) {
            return;
        }

        if (!repeats &&
            duration <= DTXSyncManager.maximumTimerIntervalTrackingDuration &&
            duration >= DTXSyncManager.minimumTimerIntervalTrackingDuration) {
            dtx_log_info(@"[DTXJSTimerSyncResource] Observing timer %@ with duration %.2f ms", timerID, duration * 1000);
            self->_pendingTimers[timerID] = @((NSUInteger)round(duration * 1000));
            self->_entryTimes[timerID] = [NSDate date];
            [self scheduleCleanupForTimer:timerID];
            NSArray<NSDictionary *> *snapshot = [self _makeSnapshot];

            @try {
                NSUInteger pendingCount = self->_pendingTimers.count;
                _dispatchToMainQueue(^{
                    [self performUpdateBlock:^NSUInteger{
                        [self _publishSnapshot:snapshot];
                        return pendingCount;
                    } eventIdentifier:_DTXStringReturningBlock([timerID stringValue])
                            eventDescription:_DTXStringReturningBlock(@"Timer Created")
                           objectDescription:_DTXStringReturningBlock(_prettyTimerDescription(timerID))
                       additionalDescription:nil];
                });
            } @catch (NSException *exception) {
                dtx_log_error(@"[DTXJSTimerSyncResource] Exception in performUpdateBlock: %@", exception);
            }
        } else {
            dtx_log_info(@"[DTXJSTimerSyncResource] Ignoring timer %@ (duration: %.2f ms, repeats: %@)", timerID, duration * 1000, repeats ? @"YES" : @"NO");
        }
    });
}

- (void)deleteTimer:(NSNumber *)timerID {
    dispatch_async(_queue, ^{
        if (self->_pendingTimers[timerID]) {
            NSDate *entryTime = self->_entryTimes[timerID];
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:entryTime];
            dtx_log_info(@"[DTXJSTimerSyncResource] Timer %@ completed after %.2f ms", timerID, elapsed * 1000);

            dispatch_source_t cleanupTimer = self->_cleanupTimers[timerID];
            if (cleanupTimer) {
                dispatch_source_cancel(cleanupTimer);
                [self->_cleanupTimers removeObjectForKey:timerID];
            }

            [self->_pendingTimers removeObjectForKey:timerID];
            [self->_entryTimes removeObjectForKey:timerID];
            NSArray<NSDictionary *> *snapshot = [self _makeSnapshot];

            @try {
                NSUInteger pendingCount = self->_pendingTimers.count;
                _dispatchToMainQueue(^{
                    [self performUpdateBlock:^NSUInteger{
                        [self _publishSnapshot:snapshot];
                        return pendingCount;
                    } eventIdentifier:_DTXStringReturningBlock([timerID stringValue])
                            eventDescription:_DTXStringReturningBlock(@"Timer Completed")
                           objectDescription:_DTXStringReturningBlock(_prettyTimerDescription(timerID))
                       additionalDescription:nil];
                });
            } @catch (NSException *exception) {
                dtx_log_error(@"[DTXJSTimerSyncResource] Exception in performUpdateBlock (delete): %@", exception);
            }
        }
    });
}

- (void)scheduleCleanupForTimer:(NSNumber *)timerID {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kTimerTimeout * NSEC_PER_SEC)),
                              DISPATCH_TIME_FOREVER,
                              (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        if (self->_pendingTimers[timerID]) {
            NSDate *entryTime = self->_entryTimes[timerID];
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:entryTime];
            dtx_log_info(@"[DTXJSTimerSyncResource] Timer %@ timed out after %.2f ms", timerID, elapsed * 1000);
            [self->_pendingTimers removeObjectForKey:timerID];
            [self->_entryTimes removeObjectForKey:timerID];
            [self->_cleanupTimers removeObjectForKey:timerID];
            NSArray<NSDictionary *> *snapshot = [self _makeSnapshot];

            @try {
                NSUInteger pendingCount = self->_pendingTimers.count;
                _dispatchToMainQueue(^{
                    [self performUpdateBlock:^NSUInteger{
                        [self _publishSnapshot:snapshot];
                        return pendingCount;
                    } eventIdentifier:_DTXStringReturningBlock([timerID stringValue])
                            eventDescription:_DTXStringReturningBlock(@"Timer Timed Out")
                           objectDescription:_DTXStringReturningBlock(_prettyTimerDescription(timerID))
                       additionalDescription:nil];
                });
            } @catch (NSException *exception) {
                dtx_log_error(@"[DTXJSTimerSyncResource] Exception in performUpdateBlock (timeout): %@", exception);
            }
        }
    });
    self->_cleanupTimers[timerID] = timer;
    dispatch_resume(timer);
}

// Must be called on _queue after every change to the pending timers.
- (NSArray<NSDictionary *> *)_makeSnapshot {
    NSMutableArray *snapshot = [NSMutableArray new];
    for (NSNumber *timerID in _pendingTimers) {
        NSDate *entryTime = _entryTimes[timerID];
        [snapshot addObject:@{
            @"timer_id": timerID,
            @"duration": _pendingTimers[timerID],
            @"entry_time": entryTime ?: [NSNull null]
        }];
    }
    return snapshot;
}

// Called from the update block, which the sync manager runs on its own queue together with the busy count change.
// This keeps jsonDescription consistent with the busy state: a busy resource always lists its timers.
- (void)_publishSnapshot:(NSArray<NSDictionary *> *)snapshot {
    os_unfair_lock_lock(&_snapshotLock);
    _snapshot = snapshot;
    os_unfair_lock_unlock(&_snapshotLock);
}

// Never blocks on _queue: it is called from the sync manager's queue while _queue may be waiting on it.
- (DTXBusyResource *)jsonDescription {
    os_unfair_lock_lock(&_snapshotLock);
    NSArray<NSDictionary *> *snapshot = _snapshot;
    os_unfair_lock_unlock(&_snapshotLock);

    NSDate *now = [NSDate date];
    NSMutableArray *timerDescriptions = [NSMutableArray new];
    for (NSDictionary *timer in snapshot) {
        NSDate *entryTime = timer[@"entry_time"];
        NSTimeInterval elapsed = [entryTime isKindOfClass:NSDate.class] ? ([now timeIntervalSinceDate:entryTime] * 1000) : 0;
        [timerDescriptions addObject:@{
            @"timer_id": timer[@"timer_id"],
            @"duration": timer[@"duration"],
            @"elapsed": @(elapsed)
        }];
    }

    return @{
        NSString.dtx_resourceNameKey: @"js_timers",
        NSString.dtx_resourceDescriptionKey: @{
            @"timers": timerDescriptions
        }
    };
}

- (void)dealloc {
    for (dispatch_source_t timer in _cleanupTimers.allValues) {
        dispatch_source_cancel(timer);
    }
    [_cleanupTimers removeAllObjects];
}

@end
