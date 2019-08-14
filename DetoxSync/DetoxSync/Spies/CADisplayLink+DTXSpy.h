//
//  CADisplayLink+DTXSpy.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface CADisplayLink (DTXSpy)

@property (nonatomic, assign, getter=__detox_sync_numberOfRunloops, setter=__detox_sync_setNumberOfRunloops:) NSInteger __detox_sync_numberOfRunloops;

@end

NS_ASSUME_NONNULL_END
