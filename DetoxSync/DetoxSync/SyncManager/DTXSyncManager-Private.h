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

__attribute__((visibility("hidden")))
extern BOOL __detox_sync_enableVerboseSyncResourceLogging;
__attribute__((visibility("hidden")))
void __detox_sync_DTXSyncResourceVerboseLog(NSString* format, ...)  NS_FORMAT_FUNCTION(1,2);
#define DTXSyncResourceVerboseLog(...) __extension__({ if(__builtin_expect(__detox_sync_enableVerboseSyncResourceLogging == YES, NO)) { __detox_sync_DTXSyncResourceVerboseLog(__VA_ARGS__); } })

@interface DTXSyncManager ()

+ (void)registerSyncResource:(DTXSyncResource*)syncResource;
+ (void)unregisterSyncResource:(DTXSyncResource*)syncResource;

+ (void)perforUpdateAndWaitForResource:(DTXSyncResource*)resource block:(NSUInteger(^)(void))block;

+ (BOOL)isTrackedThread:(NSThread*)thread;
+ (BOOL)isTrackedRunLoop:(CFRunLoopRef)runLoop;

+ (NSString*)idleStatus;
+ (NSString*)syncStatus;

@end

NS_ASSUME_NONNULL_END
