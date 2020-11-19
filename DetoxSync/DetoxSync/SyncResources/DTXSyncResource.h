//
//  DTXSyncResource.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTXSyncResource : NSObject

@property (nonatomic, copy) NSString* name;

- (void)performUpdateBlock:(NSUInteger(^)(void))block eventIdentifier:eventID eventDescription:(NSString*(^)(void))eventDescription objectDescription:(NSString*(^)(void))objectDescription additionalDescription:(nullable NSString*(^)(void))additionalDescription;
- (NSString*)syncResourceGenericDescription;
- (NSString*)syncResourceDescription;

- (NSString*)history;

@end

NS_ASSUME_NONNULL_END
