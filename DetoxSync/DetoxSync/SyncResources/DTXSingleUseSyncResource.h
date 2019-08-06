//
//  DTXSingleUseSyncResource.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncResource.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DTXSingleUsage <NSObject>

- (void)endUse;

@end

@interface DTXSingleUseSyncResource : DTXSyncResource <DTXSingleUsage>

+ (id<DTXSingleUsage>)singleUseSyncResourceWithObject:(nullable id)object description:(NSString*)description;
+ (id<DTXSingleUsage>)deallocatingSingleUseSyncResourceWithObject:(nullable id)object description:(NSString*)description;

- (void)endUse;

@end

NS_ASSUME_NONNULL_END
