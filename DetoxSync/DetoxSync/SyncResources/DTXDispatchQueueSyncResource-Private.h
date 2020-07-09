//
//  DTXDispatchQueueSyncResource+Private.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXDispatchQueueSyncResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTXDispatchBlockProxy : NSObject

+ (instancetype)proxyWithBlock:(dispatch_block_t)block operation:(NSString*)operation;
+ (instancetype)proxyWithBlock:(dispatch_block_t)block operation:(NSString*)operation moreInfo:(nullable NSString*)moreInfo;

@end

@interface DTXDispatchQueueSyncResource ()

+ (nullable instancetype)_existingSyncResourceWithQueue:(dispatch_queue_t)queue;

- (void)addWorkBlockProxy:(DTXDispatchBlockProxy*)blockProxy operation:(NSString*)operation;
- (void)removeWorkBlockProxy:(DTXDispatchBlockProxy*)blockProxy operation:(NSString*)operation;

@end

NS_ASSUME_NONNULL_END
