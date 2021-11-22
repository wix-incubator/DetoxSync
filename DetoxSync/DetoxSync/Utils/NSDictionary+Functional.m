//
//  NSDictionary+Functional.m
//  DetoxSync
//
//  Created by asaf korem on 22/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

#import "NSDictionary+Functional.h"

@implementation NSDictionary (Functional)

- (NSDictionary *)filter:(FilterBlock)block {
  NSDictionary *dictionary = [self copy];
  NSMutableDictionary *filterredDictionary = [NSMutableDictionary new];

  for (id key in dictionary) {
    id object = dictionary[key];
    if (block(object)) {
      filterredDictionary[key] = object;
    }
  }

  return filterredDictionary;
}

- (NSDictionary *)map:(MapBlock)block {
  NSDictionary *dictionary = [self copy];
  NSMutableDictionary *mappedDictionary = [NSMutableDictionary new];

  for (id key in dictionary) {
    id object = dictionary[key];
    mappedDictionary[key] = block(object);
  }

  return mappedDictionary;
}

@end
