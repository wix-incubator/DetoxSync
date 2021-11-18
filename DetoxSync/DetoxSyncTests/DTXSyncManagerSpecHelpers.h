//
//  DTXSyncManagerSpecHelpers.h
//  DetoxSyncTests
//
//  Created by asaf korem on 18/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <DetoxSync/DTXSyncManager.h>

#import "NSString+SyncStatus.h"
#import "NSString+SyncResource.h"

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

NS_ASSUME_NONNULL_END
