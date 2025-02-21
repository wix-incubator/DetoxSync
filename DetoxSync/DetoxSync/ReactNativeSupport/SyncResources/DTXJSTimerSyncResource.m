//
//  DTXJSTimerSyncResource.m
//  DetoxSync
//

#import "DTXJSTimerSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"

@import ObjectiveC;

DTX_CREATE_LOG(DTXJSTimerSyncResource);

// 1500 ms total timeout from creation
static const NSTimeInterval kTimerTimeout = 1.5;

static NSString* _prettyTimerDescription(NSNumber* timerID)
{
    return [NSString stringWithFormat:@"JavaScript Timer %@ (Native Implementation)", timerID];
}

@implementation DTXJSTimerSyncResource {
    NSHashTable<id> *_observedInstances;
    NSMutableDictionary<NSNumber *, NSNumber *> *_pendingTimers;
    NSMutableDictionary<NSNumber *, NSDate *> *_entryTimes;
    NSMutableDictionary<NSNumber *, dispatch_source_t> *_cleanupTimers;
    dispatch_queue_t _queue;
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
            dtx_log_info(@"[DTXJSTimerSyncResource] Before observing timer %@", callbackID);
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
            dtx_log_info(@"[DTXJSTimerSyncResource] Deleting timer %@", @(timerID));
            [strongSelf deleteTimer:@(timerID)];
        }
        orig_deleteTimer(_self, deleteTimerSel, timerID);
    }));
}

- (void)observeTimerWithInstance:(id)instance timerID:(NSNumber *)timerID duration:(NSTimeInterval)duration repeats:(BOOL)repeats {
    dispatch_async(_queue, ^{
        if (![_observedInstances containsObject:instance]) {
            [_observedInstances addObject:instance];
            dtx_log_info(@"[DTXJSTimerSyncResource] Observing new RCTTiming instance: %p", instance);
        }

        // Skip invalid or zero timer IDs
        if (timerID == nil || [timerID isEqualToNumber:@0]) {
            dtx_log_info(@"[DTXJSTimerSyncResource] Skipping invalid or zero timer ID: %@", timerID);
            return;
        }

        if (!repeats && duration <= kTimerTimeout) {
            dtx_log_info(@"[DTXJSTimerSyncResource] Observing timer %@ with duration %.2f ms", timerID, duration * 1000);
            self->_pendingTimers[timerID] = @((NSUInteger)round(duration * 1000));
            self->_entryTimes[timerID] = [NSDate date];
            [self scheduleCleanupForTimer:timerID];

            dtx_log_info(@"[DTXJSTimerSyncResource] Performing update for timer %@", timerID);
            @try {
                // Perform update block asynchronously on the main queue to avoid blocking
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performUpdateBlock:^NSUInteger{
                        return [self _busyCount];
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
        dtx_log_info(@"[DTXJSTimerSyncResource] Dispatched timer observation for %@", timerID);
    });
}

- (void)deleteTimer:(NSNumber *)timerID {
    dispatch_async(_queue, ^{
        if (self->_pendingTimers[timerID]) {
            NSDate *entryTime = self->_entryTimes[timerID];
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:entryTime];
            dtx_log_info(@"[DTXJSTimerSyncResource] Timer %@ completed after %.2f ms", timerID, elapsed * 1000);

            // Cancel the cleanup timer if it exists
            dispatch_source_t cleanupTimer = self->_cleanupTimers[timerID];
            if (cleanupTimer) {
                dispatch_source_cancel(cleanupTimer);
                [self->_cleanupTimers removeObjectForKey:timerID];
                dtx_log_info(@"[DTXJSTimerSyncResource] Revoked cleanup timer for timer %@", timerID);
            }

            [self->_pendingTimers removeObjectForKey:timerID];
            [self->_entryTimes removeObjectForKey:timerID];

            dtx_log_info(@"[DTXJSTimerSyncResource] Before perform update for timer deletion %@", timerID);
            @try {
                // Perform update block asynchronously on the main queue to avoid blocking
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performUpdateBlock:^NSUInteger{
                        return [self _busyCount];
                    } eventIdentifier:_DTXStringReturningBlock([timerID stringValue])
                            eventDescription:_DTXStringReturningBlock(@"Timer Completed")
                           objectDescription:_DTXStringReturningBlock(_prettyTimerDescription(timerID))
                       additionalDescription:nil];
                    dtx_log_info(@"[DTXJSTimerSyncResource] After performUpdateBlock for timer deletion %@", timerID);
                });
            } @catch (NSException *exception) {
                dtx_log_error(@"[DTXJSTimerSyncResource] Exception in performUpdateBlock (delete): %@", exception);
            }
        } else {
            dtx_log_info(@"[DTXJSTimerSyncResource] Timer %@ not found in pending timers", timerID);
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

            dtx_log_info(@"[DTXJSTimerSyncResource] Before performing update for timer timeout %@", timerID);
            @try {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performUpdateBlock:^NSUInteger{
                        return [self _busyCount];
                    } eventIdentifier:_DTXStringReturningBlock([timerID stringValue])
                            eventDescription:_DTXStringReturningBlock(@"Timer Timed Out")
                           objectDescription:_DTXStringReturningBlock(_prettyTimerDescription(timerID))
                       additionalDescription:nil];
                    dtx_log_info(@"[DTXJSTimerSyncResource] After performUpdateBlock for timer timeout %@", timerID);
                });
            } @catch (NSException *exception) {
                dtx_log_error(@"[DTXJSTimerSyncResource] Exception in performUpdateBlock (timeout): %@", exception);
            }
        }
    });
    self->_cleanupTimers[timerID] = timer;
    dispatch_resume(timer);
}

- (NSUInteger)_busyCount {
    return self->_pendingTimers.count;
}

- (NSString*)syncResourceDescription {
    __block NSMutableArray<NSString*>* descriptions = [NSMutableArray new];
    dispatch_sync(_queue, ^{
        for (NSNumber *timerID in self->_pendingTimers) {
            NSNumber *duration = self->_pendingTimers[timerID];
            NSDate *entryTime = self->_entryTimes[timerID];
            NSTimeInterval elapsed = entryTime ? ([[NSDate date] timeIntervalSinceDate:entryTime] * 1000) : 0;
            [descriptions addObject:[NSString stringWithFormat:@"Timer %@ (duration: %.2f ms, elapsed: %.2f ms)", timerID, duration.doubleValue * 1000, elapsed]];
        }
    });
    return [descriptions componentsJoinedByString:@"\n"];
}

- (DTXBusyResource *)jsonDescription {
    __block NSMutableArray *timerDescriptions = [NSMutableArray new];
    dispatch_sync(_queue, ^{
        for (NSNumber *timerID in self->_pendingTimers) {
            NSNumber *duration = self->_pendingTimers[timerID];
            NSDate *entryTime = self->_entryTimes[timerID];
            NSTimeInterval elapsed = entryTime ? ([[NSDate date] timeIntervalSinceDate:entryTime] * 1000) : 0;
            [timerDescriptions addObject:@{
                @"timer_id": timerID,
                @"duration": duration,
                @"elapsed": @(elapsed)
            }];
        }
    });

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
