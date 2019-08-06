//
//  DTXNSTimerSyncResource.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncResource.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DTXTimerProxy <NSObject>

- (void)setTimer:(NSTimer*)timer;
- (void)fire:(NSTimer*)timer;

@end

@interface DTXNSTimerSyncResource : DTXSyncResource

+ (id<DTXTimerProxy>)timeProxyWithTarget:(id)target selector:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
