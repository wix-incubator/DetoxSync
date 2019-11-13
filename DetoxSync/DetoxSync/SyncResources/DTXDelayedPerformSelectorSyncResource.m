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
		} eventDescription:self.syncResourceDescription];
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
	} eventDescription:self.syncResourceDescription];
	
	[DTXSyncManager unregisterSyncResource:self];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<DTXDelayedPerformSelectorSyncResource: %p target: %@ selector: %@>", self, _target, NSStringFromSelector(_selector)];
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"Delayed perform selector “%@” on object “%@”", NSStringFromSelector(_selector), _target];
}

+ (id<DTXDelayedPerformSelectorProxy>)delayedPerformSelectorProxyWithTarget:(id)target selector:(SEL)selector object:(id)obj;
{
	return [[DTXDelayedPerformSelectorSyncResource alloc] initWithTarget:target selector:selector object:obj];
}

@end
