//
//  DTXNSTimerSyncResource+Private.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXNSTimerSyncResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface _DTXTimerTrampoline : NSObject <DTXTimerProxy> @end

@interface DTXNSTimerSyncResource ()

+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());

- (void)trackTimerTrampoline:(_DTXTimerTrampoline*)timerTrampoline NS_SWIFT_NAME(track(_:));
- (void)untrackTimerTrampoline:(_DTXTimerTrampoline*)timerTrampoline NS_SWIFT_NAME(untrack(_:));

@end

NS_ASSUME_NONNULL_END
