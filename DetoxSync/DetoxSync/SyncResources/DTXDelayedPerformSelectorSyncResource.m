//
//  DTXDelayedPerformSelectorSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXDelayedPerformSelectorSyncResource.h"
#import "DTXSyncManager-Private.h"

@interface DTXDelayedPerformSelectorSyncResource () <DTXDelayedPerformSelectorProxy>

@end

@implementation DTXDelayedPerformSelectorSyncResource
{
	id _target;
	id _obj;
	SEL _selector;
}

- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(id)obj
{
	self = [super init];
	
	if(self)
	{
		_target = target;
		_obj = obj;
		_selector = selector;
		
		[DTXSyncManager registerSyncResource:self];
		[self performUpdateBlock:^NSUInteger{
			return 1;
		} eventIdentifier:[NSString stringWithFormat:@"%p", self] eventDescription:self.syncResourceGenericDescription objectDescription:self._selectorTargetDescription additionalDescription:nil];
	}
	
	return self;
}

- (void)fire
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[_target performSelector:_selector withObject:_obj];
#pragma clang diagnostic pop
	
	[self performUpdateBlock:^NSUInteger{
		return 0;
	} eventIdentifier:[NSString stringWithFormat:@"%p", self] eventDescription:self.syncResourceGenericDescription objectDescription:self._selectorTargetDescription additionalDescription:nil];
	
	[DTXSyncManager unregisterSyncResource:self];
	
	_target = nil;
	_obj = nil;
	_selector = nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<DTXDelayedPerformSelectorSyncResource: %p %@>", self, self._selectorTargetDescription];
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"Delayed perform selector: %@", self._selectorTargetDescription];
}

- (NSString *)syncResourceGenericDescription
{
	return @"Delayed Perform Selector";
}

- (NSString*)_selectorTargetDescription
{
	return [NSString stringWithFormat:@"“%@” on “<%@: %p>”", NSStringFromSelector(_selector), [_target class], _target];
}

+ (id<DTXDelayedPerformSelectorProxy>)delayedPerformSelectorProxyWithTarget:(id)target selector:(SEL)selector object:(id)obj;
{
	return [[DTXDelayedPerformSelectorSyncResource alloc] initWithTarget:target selector:selector object:obj];
}

@end
