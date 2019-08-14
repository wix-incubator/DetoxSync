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

@interface DTXSyncManager : NSObject

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

+ (void)enqueueIdleBlock:(void(^)(void))block;
+ (void)enqueueIdleBlock:(void(^)(void))block queue:(nullable dispatch_queue_t)queue;

+ (void)idleStatusWithCompletionHandler:(void (^)(NSString* information))completionHandler;

@end

NS_ASSUME_NONNULL_END
