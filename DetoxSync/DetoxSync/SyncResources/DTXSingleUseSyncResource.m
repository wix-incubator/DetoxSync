//
//  DTXSingleUseSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSingleUseSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "_DTXObjectDeallocHelper.h"

@interface _DTXSingleUseDeallocationHelper : _DTXObjectDeallocHelper <DTXSingleUse> @end
@implementation _DTXSingleUseDeallocationHelper

- (instancetype)initWithSyncResource:(__kindof DTXSyncResource *)syncResource
{
	self = [super initWithSyncResource:syncResource];
	
	if(self)
	{
		__weak typeof(self) weakSelf = self;
		self.performOnDealloc = ^{
			[weakSelf.syncResource endUse];
		};
	}
	
	return self;
}

- (void)endUse
{
	[self.syncResource endUse];
	self.syncResource = nil;
}

@end

@implementation DTXSingleUseSyncResource
{
	NSString* _description;
	__weak id _object;
}

+ (id<DTXSingleUse>)singleUseSyncResourceWithObject:(id)object description:(NSString*)description
{
	DTXSingleUseSyncResource* rv = [[DTXSingleUseSyncResource alloc] init];
	rv->_description = description;
	rv->_object = object;
	[DTXSyncManager registerSyncResource:rv];
	[rv performUpdateBlock:^BOOL{
		return YES;
	}];
	
	_DTXSingleUseDeallocationHelper* helper = [[_DTXSingleUseDeallocationHelper alloc] initWithSyncResource:rv];
	
	return helper;
}

- (void)endUse;
{
	[self performUpdateBlock:^BOOL{
		return NO;
	}];
	
	[DTXSyncManager unregisterSyncResource:self];
}

- (NSString *)description
{
	if(_description == nil && _object == nil)
	{
		return [super description];
	}
	
	return [NSString stringWithFormat:@"<%@: %p%@%@>", self.class, self, _description ? [NSString stringWithFormat:@" description: “%@”", _description] : @"", _object ? [NSString stringWithFormat:@" object: %@", _object] : @""];
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"%@%@", _description, _object != nil ? [NSString stringWithFormat:@" (“%@”)", _object] : @""];
}

@end
