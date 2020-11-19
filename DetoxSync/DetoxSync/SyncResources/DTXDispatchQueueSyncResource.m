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

@implementation DTXDispatchBlockProxy
{
	NSString* _operation;
	id _block;
	NSString* _moreInfo;
}

+ (instancetype)proxyWithBlock:(dispatch_block_t)block operation:(NSString*)operation
{
	return [self proxyWithBlock:block operation:operation moreInfo:nil];
}

+ (instancetype)proxyWithBlock:(dispatch_block_t)block operation:(NSString*)operation moreInfo:(NSString*)moreInfo
{
	DTXDispatchBlockProxy* rv = [DTXDispatchBlockProxy new];
	
	if(rv)
	{
		rv->_operation = operation;
		rv->_block = block;
		rv->_moreInfo = moreInfo;
	}
	
	return rv;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@%@ with %p", _operation, _moreInfo == nil ? @"" : [NSString stringWithFormat:@"(%@)", _moreInfo], _block];
}

- (NSString *)debugDescription
{
	return self.description;
}

- (void)dealloc
{
	
}

@end

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

- (void)addWorkBlockProxy:(DTXDispatchBlockProxy*)blockProxy operation:(NSString*)operation
{
	[self performUpdateBlock:^NSUInteger{
		_busyCount += 1;
		return _busyCount;
	}
			 eventIdentifier:[NSString stringWithFormat:@"%p", blockProxy]
			eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription)
		   objectDescription:_DTXStringReturningBlock([self _descriptionForOperation:operation block:blockProxy])
	   additionalDescription:nil];
}

- (void)removeWorkBlockProxy:(DTXDispatchBlockProxy*)blockProxy operation:(NSString*)operation
{
	[self performUpdateBlock:^NSUInteger{
		_busyCount -= 1;
		return _busyCount;
	}
			 eventIdentifier:[NSString stringWithFormat:@"%p", blockProxy]
			eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription)
		   objectDescription:_DTXStringReturningBlock([self _descriptionForOperation:operation block:blockProxy])
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
