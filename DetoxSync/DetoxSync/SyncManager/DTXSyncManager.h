//
//  DTXSyncManager.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@class DTXSyncResource;

NS_ASSUME_NONNULL_BEGIN

@protocol DTXSyncManagerDelegate <NSObject>

@optional

- (void)syncSystemDidBecomeIdle;
- (void)syncSystemDidBecomeBusy;

- (void)syncSystemDidStartTrackingEventWithIdentifier:(NSString*)identifier description:(NSString*)description objectDescription:(NSString*)objectDescription additionalDescription:(nullable NSString*)additionalDescription;
- (void)syncSystemDidEndTrackingEventWithIdentifier:(NSString*)identifier;

@end

@protocol DTXEventTracker <NSObject>

- (void)endTracking;

@end

__attribute__((weak_import))
@interface DTXSyncManager : NSObject

@property (class, nonatomic) NSTimeInterval maximumAllowedDelayedActionTrackingDuration;
@property (class, nonatomic) NSTimeInterval maximumTimerIntervalTrackingDuration;

@property (class, nonatomic, weak) id<DTXSyncManagerDelegate> delegate;

+ (void)enqueueIdleBlock:(dispatch_block_t)block;
+ (void)enqueueMainQueueIdleBlock:(dispatch_block_t)block;
+ (void)enqueueIdleBlock:(dispatch_block_t)block queue:(nullable dispatch_queue_t)queue;

+ (void)trackDispatchQueue:(dispatch_queue_t)dispatchQueue NS_SWIFT_NAME(track(dispatchQueue:));
+ (void)untrackDispatchQueue:(dispatch_queue_t)dispatchQueue NS_SWIFT_NAME(untrack(dispatchQueue:));

+ (void)trackRunLoop:(NSRunLoop*)runLoop NS_SWIFT_NAME(track(runLoop:));
+ (void)untrackRunLoop:(NSRunLoop*)runLoop NS_SWIFT_NAME(untrack(runLoop:));
+ (void)trackCFRunLoop:(CFRunLoopRef)runLoop NS_SWIFT_NAME(track(cfRunLoop:));
+ (void)untrackCFRunLoop:(CFRunLoopRef)runLoop NS_SWIFT_NAME(untrack(cfRunLoop:));

+ (void)trackThread:(NSThread*)thread NS_SWIFT_NAME(track(thread:));
+ (void)untrackThread:(NSThread*)thread NS_SWIFT_NAME(untrack(thread:));

+ (id<DTXEventTracker>)trackEventWithDescription:(NSString*)description objectDescription:(NSString*)objectDescription NS_SWIFT_NAME(track(description:objectDescription:));

+ (void)syncStatusWithCompletionHandler:(void (^)(NSString* information))completionHandler;

@end

NS_ASSUME_NONNULL_END
