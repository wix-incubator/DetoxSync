//
//  DTXSingleUseSyncResource.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncResource.h"
#import "DTXSyncManager.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DTXSingleUse <DTXEventTracker>

- (void)endTracking;

@end

@interface DTXSingleUseSyncResource : DTXSyncResource <DTXSingleUse>

+ (id<DTXSingleUse>)singleUseSyncResourceWithObjectDescription:(NSString*)object eventDescription:(NSString*)description;

- (void)endTracking;

@end

NS_ASSUME_NONNULL_END
