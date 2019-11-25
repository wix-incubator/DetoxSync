//
//  DTXSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncResource-Private.h"
#import "DTXSyncManager-Private.h"

@import ObjectiveC;

@implementation DTXSyncResource

- (void)performUpdateBlock:(NSUInteger(^)(void))block eventIdentifier:eventID eventDescription:(NSString*)eventDescription objectDescription:(NSString*)objectDescription additionalDescription:(nullable NSString*)additionalDescription
{
	[DTXSyncManager performUpdateWithEventIdentifier:eventID eventDescription:eventDescription objectDescription:objectDescription additionalDescription:additionalDescription syncResource:self block:block];
}

- (NSString*)syncResourceDescription
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSString*)syncResourceGenericDescription
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

@end
