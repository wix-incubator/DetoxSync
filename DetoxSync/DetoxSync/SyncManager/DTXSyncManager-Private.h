//
//  DTXSyncManager.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncManager.h"
@class DTXSyncResource;

NS_ASSUME_NONNULL_BEGIN

@interface DTXSyncManager ()

+ (void)registerSyncResource:(DTXSyncResource*)syncResource;
+ (void)unregisterSyncResource:(DTXSyncResource*)syncResource;

+ (void)perforUpdateForResource:(DTXSyncResource*)resource block:(BOOL(^)(void))block;
+ (void)perforUpdateAndWaitForResource:(DTXSyncResource*)resource block:(BOOL(^)(void))block;

+ (BOOL)isTrackedThread:(NSThread*)thread;

+ (NSString*)idleStatus;
+ (NSString*)syncStatus;

@end

NS_ASSUME_NONNULL_END
