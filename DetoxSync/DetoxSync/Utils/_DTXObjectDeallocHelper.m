//
//  _DTXObjectDeallocHelper.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/6/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "_DTXObjectDeallocHelper.h"
#import "DTXSyncResource.h"
#import "DTXSyncManager-Private.h"

@implementation _DTXObjectDeallocHelper
{
	__weak DTXSyncResource* _syncResource;
}

- (instancetype)initWithSyncResource:(DTXSyncResource*)syncResource
{
	self = [super init];
	if(self) { _syncResource = syncResource; }
	return self;
}

- (nullable DTXSyncResource*)syncResource
{
	return _syncResource;
}

- (void)dealloc
{
	if(_syncResource != nil)
	{
		[DTXSyncManager unregisterSyncResource:_syncResource];
	}
}

@end
