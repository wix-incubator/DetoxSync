//
//  DTXSyncManagerSpecHelpers.h
//  DetoxSyncTests
//
//  Created by asaf korem on 18/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

/// Category provides mapped timer dictionary for a timer resource representation.
@interface NSDictionary (RoundedTimer)

/// Maps the timer by replacing the \c time_until_fire value with a rounded value.
- (NSDictionary<NSString *,id> *)roundedTimerValue;

@end

/// Await for synchronization status and return the fetched status.
NSDictionary<NSString *,id> *DTXAwaitStatus(void);

/// Find busy-resources with \c name from a list of \c resources.
NSArray<NSDictionary<NSString *,id> *> *DTXFindResources(
    NSString *name, NSArray<NSDictionary<NSString *,id> *> *resources);

/// Format date to Detox date-format.
NSDateFormatter *DTXDateFormatter(void);

/// Maps timers to a new list of timers with rounded float values.
NSArray<NSDictionary<NSString *,id> *> *DTXMapTimers(NSArray<NSDictionary<NSString *,id> *> *timers);

/// Connects \c DTXSyncManager with JS-timers sync resource.
void DTXConnectWithJSTimerSyncResource(void);

/// Create fake JS timer with given params.
void DTXCreateFakeJSTimer(double callbackID, NSTimeInterval duration, double schedulingTime,
                          BOOL repeats);

/// Register a new single (one-time) event.
void DTXRegisterSingleEvent(NSString *event, NSString * _Nullable object);

NS_ASSUME_NONNULL_END
