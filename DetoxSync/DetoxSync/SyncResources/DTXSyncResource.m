//
//  DTXSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncResource.h"
#import "DTXSyncManager-Private.h"

@implementation DTXSyncResource

- (void)performUpdateBlock:(BOOL(^)(void))block
{
	[DTXSyncManager perforUpdateAndWaitForResource:self block:block];
}

- (NSString*)syncResourceDescription
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

@end
