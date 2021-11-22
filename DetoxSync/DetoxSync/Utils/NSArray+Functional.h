//
//  NSArray+Functional.h
//  DetoxSync
//
//  Created by asaf korem on 22/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Category for functional methods on arrays.
@interface NSArray (Functional)

/// Filters objects in the array using the given \c block.
- (NSArray *)filter:(FilterBlock)block;

/// Maps objects in the array using the given \c block. ------ -------s
- (NSArray *)map:(MapBlock)block; // todos: something

@end

NS_ASSUME_NONNULL_END
