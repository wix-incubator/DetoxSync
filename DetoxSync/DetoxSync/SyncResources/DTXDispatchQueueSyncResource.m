//
//  DTXDispatchQueueSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXDispatchQueueSyncResource-Private.h"
#import "DTXSyncManager-Private.h"
#import "_DTXObjectDeallocHelper.h"

@import ObjectiveC;

static const void* DTXQueueDeallocHelperKey = &DTXQueueDeallocHelperKey;

@implementation DTXDispatchQueueSyncResource
{
	NSUInteger _busyCount;
	__weak dispatch_queue_t _queue;
}

+ (void)__superload
{
	@autoreleasepool
	{
		DTXDispatchQueueSyncResource* mainQueueSync = [DTXDispatchQueueSyncResource dispatchQueueSyncResourceWithQueue:dispatch_get_main_queue()];
		mainQueueSync.name = @"Main Queue";
		[DTXSyncManager registerSyncResource:mainQueueSync];
	}
}

+ (instancetype)dispatchQueueSyncResourceWithQueue:(dispatch_queue_t)queue
{
	DTXDispatchQueueSyncResource* rv = [self _existingSyncResourceWithQueue:queue];
	
	if(rv != nil)
	{
		return rv;
	}
	
	rv = [DTXDispatchQueueSyncResource new];
	rv->_queue = queue;
	_DTXObjectDeallocHelper* dh = [[_DTXObjectDeallocHelper alloc] initWithSyncResource:rv];
	objc_setAssociatedObject(queue, DTXQueueDeallocHelperKey, dh, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	return rv;
}

+ (instancetype)_existingSyncResourceWithQueue:(dispatch_queue_t)queue
{
	return [self _existingSyncResourceWithQueue:queue cleanup:NO];
}

+ (instancetype)_existingSyncResourceWithQueue:(dispatch_queue_t)queue cleanup:(BOOL)cleanup
{
	id rv = (id)[((_DTXObjectDeallocHelper*)objc_getAssociatedObject(queue, DTXQueueDeallocHelperKey)) syncResource];
	
	if(cleanup)
	{
		objc_setAssociatedObject(queue, DTXQueueDeallocHelperKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return rv;
}

- (instancetype)init
{
	self = [super init];
	if(self)
	{
	}
	return self;
}

static NSString* _DTXQueueDescription(dispatch_queue_t queue, NSString* name)
{	
	return [NSString stringWithFormat:@"“%@%@%@”", name != nil ? [NSString stringWithFormat:@"%@ (", name] : @"", queue, name != nil ? @")" : @""];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p queue: %@%@>", self.class, self, _DTXQueueDescription(_queue, self.name), _busyCount > 0 ? [NSString stringWithFormat:@" with %lu work blocks", _busyCount] : @""];
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"Queue: %@%@", _DTXQueueDescription(_queue, self.name), _busyCount > 0 ? [NSString stringWithFormat:@" with %lu work blocks", _busyCount] : @""];
}

- (NSString*)syncResourceGenericDescription
{
	return @"Dispatch Queue";
}

- (nullable NSString*)addWorkBlock:(id)block operation:(NSString*)operation moreInfo:(nullable NSString*)moreInfo
{
	__block NSString* identifier = nil;
	
	[self performUpdateBlock:^NSUInteger{
		_busyCount += 1;
		return _busyCount;
	} eventIdentifier:^ NSString* {
		identifier = NSUUID.UUID.UUIDString;
		return identifier;
	} eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription)
	  objectDescription:_DTXStringReturningBlock([self _descriptionForOperation:operation block:block])
	  additionalDescription:_DTXStringReturningBlock(moreInfo)];
	
	return identifier;
}

- (void)removeWorkBlock:(id)block operation:(NSString*)operation identifier:(NSString*)identifier
{
	[self performUpdateBlock:^NSUInteger{
		_busyCount -= 1;
		return _busyCount;
	}
			 eventIdentifier:_DTXStringReturningBlock(identifier)
			eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription)
		   objectDescription:_DTXStringReturningBlock([self _descriptionForOperation:operation block:block])
	   additionalDescription:nil];
}

- (NSString*)_descriptionForOperation:(NSString*)op block:(id)block
{
	return [NSString stringWithFormat:@"%@ on “%@”", op, _queue];
}

- (void)dealloc
{
	if(_queue == nil)
	{
		return;
	}
	
	objc_setAssociatedObject(_queue, DTXQueueDeallocHelperKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
