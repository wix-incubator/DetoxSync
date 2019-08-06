//
//  _DTXObjectDeallocHelper.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/6/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DTXSyncResource;

NS_ASSUME_NONNULL_BEGIN

@interface _DTXObjectDeallocHelper : NSObject

- (instancetype)initWithSyncResource:(DTXSyncResource*)syncResource;
- (nullable DTXSyncResource*)syncResource;

@end

NS_ASSUME_NONNULL_END
