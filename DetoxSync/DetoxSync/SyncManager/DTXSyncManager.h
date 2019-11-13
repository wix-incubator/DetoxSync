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

- (void)syncSystemDidStartTrackingEventWithDescription:(NSString*)description;
- (void)syncSystemDidEndTrackingEventWithDescription:(NSString*)description;

@end

@protocol DTXEventTracker <NSObject>

- (void)endTracking;

@end

@interface DTXSyncManager : NSObject

@property (class, nonatomic) NSTimeInterval maximumAllowedDelayedActionTrackingDuration;
@property (class, nonatomic) NSTimeInterval maximumTimerIntervalTrackingDuration;

@property (class, nonatomic, weak) id<DTXSyncManagerDelegate> delegate;

+ (void)enqueueIdleBlock:(dispatch_block_t)block;
+ (void)enqueueIdleBlock:(dispatch_block_t)block queue:(nullable dispatch_queue_t)queue;

+ (void)trackDispatchQueue:(dispatch_queue_t)dispatchQueue NS_SWIFT_NAME(track(dispatchQueue:));
+ (void)untrackDispatchQueue:(dispatch_queue_t)dispatchQueue NS_SWIFT_NAME(untrack(dispatchQueue:));

+ (void)trackRunLoop:(NSRunLoop*)runLoop NS_SWIFT_NAME(track(runLoop:));
+ (void)untrackRunLoop:(NSRunLoop*)runLoop NS_SWIFT_NAME(untrack(runLoop:));
+ (void)trackCFRunLoop:(CFRunLoopRef)runLoop NS_SWIFT_NAME(track(cfRunLoop:));
+ (void)untrackCFRunLoop:(CFRunLoopRef)runLoop NS_SWIFT_NAME(untrack(cfRunLoop:));

+ (void)trackThread:(NSThread*)thread NS_SWIFT_NAME(track(thread:));
+ (void)untrackThread:(NSThread*)thread NS_SWIFT_NAME(untrack(thread:));

+ (void)trackDisplayLink:(CADisplayLink*)displayLink NS_SWIFT_NAME(track(displayLink:));
+ (void)untrackDisplayLink:(CADisplayLink*)displayLink NS_SWIFT_NAME(untrack(displayLink:));

+ (id<DTXEventTracker>)trackEventWithObject:(nullable id)object description:(NSString*)description NS_SWIFT_NAME(track(eventWithObject:description:));

+ (void)syncStatusWithCompletionHandler:(void (^)(NSString* information))completionHandler;

@end

NS_ASSUME_NONNULL_END
