//
//  DTXTimerSyncResource.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncResource.h"
#import <QuartzCore/QuartzCore.h>


NS_ASSUME_NONNULL_BEGIN

@protocol DTXTimerProxy <NSObject>

- (void)setTimer:(NSTimer*)timer;
- (void)fire:(NSTimer*)timer;

- (void)setDisplayLink:(CADisplayLink*)displayLink;

- (void)track;
- (void)untrack;

@end

@interface DTXTimerSyncResource : DTXSyncResource

+ (id<DTXTimerProxy>)timerProxyWithTarget:(id)target selector:(SEL)selector fireDate:(NSDate*)fireDate interval:(NSTimeInterval)ti repeats:(BOOL)rep;
+ (id<DTXTimerProxy>)existingTimeProxyWithTimer:(NSTimer*)timer;
+ (void)clearExistingTimeProxyWithTimer:(NSTimer*)timer;

+ (void)startTrackingDisplayLink:(CADisplayLink*)displayLink;
+ (void)stopTrackingDisplayLink:(CADisplayLink*)displayLink;
//+ (id<DTXTimerProxy>)timerProxyWithDisplayLink:(CADisplayLink*)displayLink;
+ (id<DTXTimerProxy>)existingTimeProxyWithDisplayLink:(CADisplayLink*)displayLink;
+ (void)clearExistingTimeProxyWithDisplayLink:(CADisplayLink*)displayLink;

@end

NS_ASSUME_NONNULL_END
