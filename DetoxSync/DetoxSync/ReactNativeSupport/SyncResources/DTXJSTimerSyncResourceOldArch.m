//
//  DTXJSTimerSyncResourceOldArch.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXJSTimerSyncResourceOldArch.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"
#import "NSArray+Functional.h"
#import "_DTXTimerTrampoline.h"
#import "DTXReactNativeSupport.h"

@import ObjectiveC;

static NSString* _prettyTimerDescription(NSNumber* timerID)
{
    return [NSString stringWithFormat:@"JavaScript Timer %@ (Native Implementation)", timerID];
}

#pragma mark - Timer Model

@interface JSTimer : NSObject

@property (nonatomic, readonly) NSNumber *timerID;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) BOOL isRecurring;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTimerID:(NSNumber *)timerID duration:(NSTimeInterval)duration isRecurring:(BOOL)isRecurring NS_DESIGNATED_INITIALIZER;

@end

@implementation JSTimer

- (instancetype)initWithTimerID:(NSNumber *)timerID duration:(NSTimeInterval)duration isRecurring:(BOOL)isRecurring {
    if ((self = [super init])) {
        _timerID = timerID;
        _duration = duration;
        _isRecurring = isRecurring;
    }
    return self;
}

@end

#pragma mark - Timer Dictionary

@interface TimerDictionary : NSMutableDictionary

@property (nonatomic, strong) NSMutableDictionary *storage;
@property (nonatomic, strong) NSMutableArray<JSTimer *> *activeTimers;
@property (nonatomic, weak) DTXJSTimerSyncResourceOldArch *syncResource;

- (instancetype)initWithSyncResource:(DTXJSTimerSyncResourceOldArch *)syncResource;
- (void)addObservedTimer:(JSTimer *)timer;
- (void)removeObservedTimer:(NSNumber *)timerID;

@end

@implementation TimerDictionary

- (instancetype)initWithSyncResource:(DTXJSTimerSyncResourceOldArch *)syncResource {
    if ((self = [super init])) {
        _storage = [NSMutableDictionary new];
        _activeTimers = [NSMutableArray new];
        _syncResource = syncResource;
    }
    return self;
}

#pragma mark NSMutableDictionary Required Methods

- (NSUInteger)count {
    return _storage.count;
}

- (id)objectForKey:(id)aKey {
    return [_storage objectForKey:aKey];
}

- (NSEnumerator *)keyEnumerator {
    return [_storage keyEnumerator];
}

- (void)setObject:(id)anObject forKey:(id)aKey {
    [_storage setObject:anObject forKey:aKey];
}

- (void)removeObjectForKey:(id)aKey {
    [self removeObservedTimer:aKey];
    [_storage removeObjectForKey:aKey];
}

- (NSArray *)allValues {
    return [_storage allValues];
}

- (NSArray *)allKeys {
    return [_storage allKeys];
}

- (void)removeAllObjects {
    [_storage removeAllObjects];
    [_activeTimers removeAllObjects];
}

#pragma mark Timer Observation Methods

- (void)addObservedTimer:(JSTimer *)timer {
    [_syncResource performUpdateBlock:^NSUInteger{
        [_activeTimers addObject:timer];
        return [self.syncResource _busyCount];
    } eventIdentifier:_DTXStringReturningBlock([timer.timerID stringValue])
                     eventDescription:_DTXStringReturningBlock([self.syncResource resourceName])
                    objectDescription:_DTXStringReturningBlock(_prettyTimerDescription(timer.timerID))
                additionalDescription:nil];
}

- (void)removeObservedTimer:(NSNumber *)timerID {
    [_syncResource performUpdateBlock:^NSUInteger{
        self.activeTimers = [[self.activeTimers filter:^BOOL(JSTimer *timer) {
            if ([timer.timerID isEqual:timerID]) {
                DTXSyncResourceVerboseLog(@"⏲ Removing observed timer: (%@)", timer);
                return NO;
            }
            return YES;
        }] mutableCopy];

        return [self.syncResource _busyCount];
    } eventIdentifier:_DTXStringReturningBlock([timerID stringValue])
                     eventDescription:_DTXStringReturningBlock([self.syncResource resourceName])
                    objectDescription:_DTXStringReturningBlock(_prettyTimerDescription(timerID))
                additionalDescription:nil];
}

@end

@interface DTXJSTimerSyncResourceOldArch ()

@property (nonatomic, strong) NSMapTable<id, TimerDictionary *> *observations;

@end

@implementation DTXJSTimerSyncResourceOldArch {
    NSMapTable<id, TimerDictionary *> *_observations;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _observations = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory valueOptions:NSMapTableStrongMemory];
        [self setupTimerObservation];
    }
    return self;
}

- (void)setupTimerObservation {
    __weak __typeof(self) weakSelf = self;

    Class cls = NSClassFromString(@"RCTTiming");

    if ([DTXReactNativeSupport isNewArchEnabled]) {
        // New Architecture: Only swizzle createTimerForNextFrame
        SEL createTimerForNextFrameSel = NSSelectorFromString(@"createTimerForNextFrame:duration:jsSchedulingTime:repeats:");
        Method createTimerForNextFrameMethod = class_getInstanceMethod(cls, createTimerForNextFrameSel);

        void (*orig_createTimerForNextFrame)(id, SEL, NSNumber*, NSTimeInterval, NSDate*, BOOL) = (void*)method_getImplementation(createTimerForNextFrameMethod);
        method_setImplementation(createTimerForNextFrameMethod, imp_implementationWithBlock(^(id _self, NSNumber* callbackID, NSTimeInterval duration, NSDate* jsSchedulingTime, BOOL repeats) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf observeTimerWithInstance:_self timerID:callbackID duration:duration repeats:repeats];
            }

            orig_createTimerForNextFrame(_self, createTimerForNextFrameSel, callbackID, duration, jsSchedulingTime, repeats);
        }));
    } else {
        // Legacy Architecture: Only swizzle createTimer
        SEL createTimerSel = NSSelectorFromString(@"createTimer:duration:jsSchedulingTime:repeats:");
        Method createTimerMethod = class_getInstanceMethod(cls, createTimerSel);

        const char* timerArgType = [[cls instanceMethodSignatureForSelector:createTimerSel] getArgumentTypeAtIndex:2];
        if (strncmp(timerArgType, "d", 1) == 0) {
            void (*orig_createTimer)(id, SEL, double, NSTimeInterval, double, BOOL) = (void*)method_getImplementation(createTimerMethod);
            method_setImplementation(createTimerMethod, imp_implementationWithBlock(^(id _self, double timerID, NSTimeInterval duration, double jsDate, BOOL repeats) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf observeTimerWithInstance:_self timerID:@(timerID) duration:duration repeats:repeats];
                }
                orig_createTimer(_self, createTimerSel, timerID, duration, jsDate, repeats);
            }));
        } else {
            void (*orig_createTimer)(id, SEL, NSNumber*, NSTimeInterval, NSDate*, BOOL) = (void*)method_getImplementation(createTimerMethod);
            method_setImplementation(createTimerMethod, imp_implementationWithBlock(^(id _self, NSNumber* timerID, NSTimeInterval duration, NSDate* jsDate, BOOL repeats) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf observeTimerWithInstance:_self timerID:timerID duration:duration repeats:repeats];
                }

                orig_createTimer(_self, createTimerSel, timerID, duration, jsDate, repeats);
            }));
        }
    }

    // Swizzle deleteTimer: (common for both architectures)
    SEL deleteTimerSel = NSSelectorFromString(@"deleteTimer:");
    Method deleteTimerMethod = class_getInstanceMethod(cls, deleteTimerSel);

    void (*orig_deleteTimer)(id, SEL, double) = (void*)method_getImplementation(deleteTimerMethod);
    method_setImplementation(deleteTimerMethod, imp_implementationWithBlock(^(id _self, double timerID) {
        orig_deleteTimer(_self, deleteTimerSel, timerID);

        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf != nil) {
            TimerDictionary *timerDict = [strongSelf.observations objectForKey:_self];
            if (timerDict != nil) {
                [timerDict removeObservedTimer:@(timerID)];
            }
        }
    }));
}

- (void)observeTimerWithInstance:(id)instance timerID:(NSNumber *)timerID duration:(NSTimeInterval)duration repeats:(BOOL)repeats {
    TimerDictionary *timerDict = [_observations objectForKey:instance];
    if(timerDict == nil) {
        timerDict = [[TimerDictionary alloc] initWithSyncResource:self];
        [instance setValue:timerDict forKey:@"_timers"];
        [_observations setObject:timerDict forKey:instance];
    }
    if(duration > DTXSyncManager.minimumTimerIntervalTrackingDuration && duration <= DTXSyncManager.maximumTimerIntervalTrackingDuration && repeats == NO) {
        DTXSyncResourceVerboseLog(@"⏲ Observing timer \"%@\" duration: %@ repeats: %@", timerID, @(duration), @(repeats));

        [timerDict addObservedTimer:[[JSTimer alloc] initWithTimerID:timerID duration:duration isRecurring:repeats]];
    } else {
        DTXSyncResourceVerboseLog(@"⏲ Ignoring timer \"%@\" failure reason: \"%@\"", timerID, [self failureReasonForDuration:duration repeats:repeats]);
    }
}

- (NSString*)failureReasonForDuration:(NSTimeInterval)duration repeats:(BOOL)repeats {
    if(duration < DTXSyncManager.minimumTimerIntervalTrackingDuration) {
        return [NSString stringWithFormat:@"duration(%@)<%@", @(duration), @(DTXSyncManager.minimumTimerIntervalTrackingDuration)];
    } else if(repeats == YES) {
        return @"repeats==true";
    } else if(duration > DTXSyncManager.maximumTimerIntervalTrackingDuration) {
        return [NSString stringWithFormat:@"duration(%@)>%@", @(duration), @(DTXSyncManager.maximumTimerIntervalTrackingDuration)];
    }
    return @"";
}

- (NSUInteger)_busyCount {
    NSUInteger count = 0;
    for (TimerDictionary *dict in _observations.objectEnumerator) {
        count += dict.activeTimers.count;
    }
    return count;
}

- (NSString*)syncResourceDescription {
    NSMutableArray<NSString*>* descriptions = [NSMutableArray new];
    for (TimerDictionary *dict in _observations.objectEnumerator) {
        for (JSTimer *timer in dict.activeTimers) {
            [descriptions addObject:timer.description];
        }
    }
    return [descriptions componentsJoinedByString:@"\n⏱ "];
}

- (DTXBusyResource *)jsonDescription {
    NSMutableArray *timerDescriptions = [NSMutableArray new];
    for (TimerDictionary *dict in _observations.objectEnumerator) {
        for (JSTimer *timer in dict.activeTimers) {
            [timerDescriptions addObject:@{
                @"timer_id": timer.timerID,
                @"duration": @(timer.duration),
            }];
        }
    }

    return @{
        NSString.dtx_resourceNameKey: @"js_timers",
        NSString.dtx_resourceDescriptionKey: @{
            @"timers": timerDescriptions
        }
    };
}

@end
