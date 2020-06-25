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
	NSMutableArray* _busyBlocks;
	__weak dispatch_queue_t _queue;
}

+ (void)__superload
{
	@autoreleasepool
	{
		DTXDispatchQueueSyncResource* mainQueueSync = [DTXDispatchQueueSyncResource dispatchQueueSyncResourceWithQueue:dispatch_get_main_queue()];
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
	return (id)[((_DTXObjectDeallocHelper*)objc_getAssociatedObject(queue, DTXQueueDeallocHelperKey)) syncResource];
}

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		_busyBlocks = [NSMutableArray new];
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p queue: %@ work blocks: %@>", self.class, self, _queue, _busyBlocks];
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"%lu work blocks on dispatch queue “%@”", (unsigned long)_busyCount, _queue];
}

- (NSString*)syncResourceGenericDescription
{
	return @"Dispatch Queue";
}

- (void)addWorkBlock:(id)block operation:(NSString*)operation
{
	[self performUpdateBlock:^NSUInteger{
		_busyCount += 1;
		[_busyBlocks addObject:block];
		return _busyCount;
	} eventIdentifier:[NSString stringWithFormat:@"%p", block] eventDescription:self.syncResourceGenericDescription objectDescription:[self _descriptionForOperation:operation block:block] additionalDescription:nil];
}

- (void)removeWorkBlock:(id)block operation:(NSString*)operation
{
	[self performUpdateBlock:^NSUInteger{
		_busyCount -= 1;
		[_busyBlocks removeObject:block];
		return _busyCount;
	} eventIdentifier:[NSString stringWithFormat:@"%p", block] eventDescription:self.syncResourceGenericDescription objectDescription:[self _descriptionForOperation:operation block:block] additionalDescription:nil];
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
