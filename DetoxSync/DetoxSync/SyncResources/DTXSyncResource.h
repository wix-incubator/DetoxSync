//
//  DTXSyncResource.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString* _DTXPluralIfNeeded(NSString* word, NSUInteger count);

@interface DTXSyncResource : NSObject

@property (nonatomic, copy) NSString* name;

- (void)performUpdateBlock:(NSUInteger(NS_NOESCAPE ^)(void))block eventIdentifier:(NSString*(NS_NOESCAPE ^)(void))eventID eventDescription:(nullable NSString*(NS_NOESCAPE ^)(void))eventDescription objectDescription:(nullable NSString*(NS_NOESCAPE ^)(void))objectDescription additionalDescription:(nullable NSString*(NS_NOESCAPE ^)(void))additionalDescription;
- (NSString*)syncResourceGenericDescription;
- (NSString*)syncResourceDescription;

- (NSString*)history;

@end

NS_ASSUME_NONNULL_END
