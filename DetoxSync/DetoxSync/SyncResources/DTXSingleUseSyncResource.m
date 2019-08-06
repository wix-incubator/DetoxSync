//
//  DTXSingleUseSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXSingleUseSyncResource.h"
#import "DTXSyncManager-Private.h"

@interface _DTXSingleUseDeallocationHelper : NSObject <DTXSingleUsage> @end
@implementation _DTXSingleUseDeallocationHelper
{
	id<DTXSingleUsage> _underlying;
}

- (instancetype)initWithUnderlying:(id<DTXSingleUsage>)underlying
{
	self = [super init];
	if(self) { _underlying = underlying; }
	return self;
}

- (void)endUse
{
	[_underlying endUse];
	_underlying = nil;
}

- (void)dealloc
{
	[self endUse];
}

@end

@implementation DTXSingleUseSyncResource
{
	NSString* _description;
	__weak id _object;
}

+ (instancetype)singleUseSyncResourceWithObject:(id)object description:(NSString*)description
{
	DTXSingleUseSyncResource* rv = [[DTXSingleUseSyncResource alloc] init];
	rv->_description = description;
	rv->_object = object;
	[DTXSyncManager registerSyncResource:rv];
	[rv performUpdateBlock:^BOOL{
		return YES;
	}];
	
	return rv;
}

+ (id<DTXSingleUsage>)deallocatingSingleUseSyncResourceWithObject:(nullable id)object description:(NSString*)description
{
	id<DTXSingleUsage> sr = [self singleUseSyncResourceWithObject:object description:description];
	_DTXSingleUseDeallocationHelper* helper = [[_DTXSingleUseDeallocationHelper alloc] initWithUnderlying:sr];
	
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
