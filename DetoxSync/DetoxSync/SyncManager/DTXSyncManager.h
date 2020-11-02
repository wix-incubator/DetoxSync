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

@property (class, atomic) BOOL synchronizationDisabled;
@property (class, atomic) NSTimeInterval maximumAllowedDelayedActionTrackingDuration;
@property (class, atomic) NSTimeInterval maximumTimerIntervalTrackingDuration;
@property (class, atomic, copy) NSArray<NSString*>* URLBlacklist NS_SWIFT_NAME(urlBlacklist);

@property (class, nonatomic, weak) id<DTXSyncManagerDelegate> delegate;

+ (void)enqueueIdleBlock:(dispatch_block_t)block NS_SWIFT_NAME(enqueueIdleClosure(_:));
+ (void)enqueueMainQueueIdleBlock:(dispatch_block_t)block NS_SWIFT_NAME(enqueueMainQueueIdleClosure(_:));
+ (void)enqueueIdleBlock:(dispatch_block_t)block queue:(nullable dispatch_queue_t)queue NS_SWIFT_NAME(enqueueIdleClosure(_:queue:));

+ (void)trackDispatchQueue:(dispatch_queue_t)dispatchQueue name:(nullable NSString*)name NS_SWIFT_NAME(track(dispatchQueue:name:));
+ (void)untrackDispatchQueue:(dispatch_queue_t)dispatchQueue NS_SWIFT_NAME(untrack(dispatchQueue:));

+ (void)trackRunLoop:(NSRunLoop*)runLoop name:(nullable NSString*)name NS_SWIFT_NAME(track(runLoop:name:));
+ (void)untrackRunLoop:(NSRunLoop*)runLoop NS_SWIFT_NAME(untrack(runLoop:));
+ (void)trackCFRunLoop:(CFRunLoopRef)runLoop name:(nullable NSString*)name NS_SWIFT_NAME(track(cfRunLoop:name:));
+ (void)untrackCFRunLoop:(CFRunLoopRef)runLoop NS_SWIFT_NAME(untrack(cfRunLoop:));

+ (void)trackThread:(NSThread*)thread name:(nullable NSString*)name NS_SWIFT_NAME(track(thread:name:));
+ (void)untrackThread:(NSThread*)thread NS_SWIFT_NAME(untrack(thread:));

+ (void)trackDisplayLink:(CADisplayLink*)displayLink name:(nullable NSString*)name NS_SWIFT_NAME(track(displayLink:name:));
+ (void)untrackDisplayLink:(CADisplayLink*)displayLink;

+ (id<DTXEventTracker>)trackEventWithDescription:(NSString*)description objectDescription:(nullable NSString*)objectDescription NS_SWIFT_NAME(track(eventWithdescription:objectDescription:));

+ (void)idleStatusWithCompletionHandler:(void (^)(NSString* information))completionHandler;

@end

NS_ASSUME_NONNULL_END
