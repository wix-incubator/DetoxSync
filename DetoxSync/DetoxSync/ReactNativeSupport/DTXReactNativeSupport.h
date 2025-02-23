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

/// Returns whether the app has React Native.
+ (BOOL)hasReactNative;

/// Waits for React Native to load, and calls the completion handler on the main queue.
/// @param completionHandler The completion handler to call when React Native has finished loading.
+ (void)waitForReactNativeLoadWithCompletionHandler:(void (^)(void))completionHandler;

// Returns whether the React Native new architecture is enabled.
+ (BOOL)isNewArchEnabled;

@end

NS_ASSUME_NONNULL_END
