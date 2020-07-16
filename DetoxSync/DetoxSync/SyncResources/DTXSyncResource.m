//
//  DTXSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSyncResource-Private.h"
#import "DTXSyncManager-Private.h"
#import "DTXAddressInfo.h"
#import <execinfo.h>

#define MAX_FRAME_COUNT 50

@import ObjectiveC;

@implementation DTXSyncResource
{
	void** _symbols;
	int _symbolCount;
	
	NSString* _historyString;
}

- (instancetype)init
{
	self = [super init];
	
	if(self)
	{
		_symbols = malloc(MAX_FRAME_COUNT * sizeof(void*));
		_symbolCount = backtrace(_symbols, MAX_FRAME_COUNT);
	}
	
	return self;
}

- (NSString*)history
{
	if(_historyString)
	{
		return _historyString;
	}
	
	//Symbolicate
	NSMutableString* str = [NSMutableString new];
	for (int idx = 0; idx < _symbolCount; idx++) {
		DTXAddressInfo* addrInfo = [[DTXAddressInfo alloc] initWithAddress:(NSUInteger)_symbols[idx]];
		[str appendFormat:@"%@\n", [addrInfo formattedDescriptionForIndex:idx]];
	}
	
	_historyString = str;
	
	_symbolCount = 0;
	free(_symbols);
	_symbols = NULL;
	
	return _historyString;
}

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
	
	if(_symbols != NULL)
	{
		free(_symbols);
		_symbols = NULL;
	}
}

@end
