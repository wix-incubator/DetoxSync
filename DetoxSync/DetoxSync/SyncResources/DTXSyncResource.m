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
{
	NSString* _history;
}

#if DEBUG
- (instancetype)init
{
	self = [super init];
	
	if(self)
	{
//		_history = [NSString stringWithFormat:@"%@", NSThread.callStackSymbols];
	}
	
	return self;
}

- (NSString*)history
{
	return _history;
}
#endif

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

- (void)dealloc
{
	[DTXSyncManager unregisterSyncResource:self];
}

@end
