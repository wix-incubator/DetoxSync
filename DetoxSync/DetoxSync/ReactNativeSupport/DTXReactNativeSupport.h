//
//  DTXReactNativeSupport.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTXReactNativeSupport : NSObject

+ (BOOL)hasReactNative;
+ (void)waitForReactNativeLoadWithCompletionHandler:(void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
