//
//  DTXRunLoopSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/6/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXRunLoopSyncResource-Private.h"
#import "DTXSyncResource-Private.h"
#import "_DTXObjectDeallocHelper.h"

@import ObjectiveC;

static const void* DTXRunLoopDeallocHelperKey = &DTXRunLoopDeallocHelperKey;

@implementation DTXRunLoopSyncResource
{
	CFRunLoopRef _runLoop;
	id _observer;
	
	BOOL _isTracking;
}

+ (instancetype)runLoopSyncResourceWithRunLoop:(CFRunLoopRef)runLoop
{
	DTXRunLoopSyncResource* rv = [self _existingSyncResourceWithRunLoop:runLoop];
	
	if(rv != nil)
	{
		return rv;
	}
	
	rv = [DTXRunLoopSyncResource new];
	rv->_runLoop = runLoop;
	_DTXObjectDeallocHelper* dh = [[_DTXObjectDeallocHelper alloc] initWithSyncResource:rv];
	objc_setAssociatedObject((__bridge id)runLoop, DTXRunLoopDeallocHelperKey, dh, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	return rv;
}

+ (instancetype)_existingSyncResourceWithRunLoop:(CFRunLoopRef)runLoop
{
	return (id)[((_DTXObjectDeallocHelper*)objc_getAssociatedObject((__bridge id)runLoop, DTXRunLoopDeallocHelperKey)) syncResource];
}

+ (NSString*)translateRunLoopActivity:(CFRunLoopActivity)act
{
	NSMutableString* rv = [NSMutableString new];
	
	if(act & kCFRunLoopEntry)
	{
		[rv appendString:@"kCFRunLoopEntry, "];
	}
	if(act & kCFRunLoopExit)
	{
		[rv appendString:@"kCFRunLoopExit, "];
	}
	if(act & kCFRunLoopBeforeTimers)
	{
		[rv appendString:@"kCFRunLoopBeforeTimers, "];
	}
	if(act & kCFRunLoopBeforeSources)
	{
		[rv appendString:@"kCFRunLoopBeforeSources, "];
	}
	if(act & kCFRunLoopAfterWaiting)
	{
		[rv appendString:@"kCFRunLoopAfterWaiting, "];
	}
	if(act & kCFRunLoopBeforeWaiting)
	{
		[rv appendString:@"kCFRunLoopBeforeWaiting, "];
	}
	
	if(rv.length == 0)
	{
		[rv appendString:@"----"];
	}
	
	return rv;
}

- (void)_setBusy:(BOOL)isBusyNow
{
	[self performUpdateBlock:^ NSUInteger {
		self._wasPreviouslyBusy = isBusyNow;
		return isBusyNow;
	} eventIdentifier:[NSString stringWithFormat:@"%p", self] eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription) objectDescription:_DTXStringReturningBlock(_DTXCFRunLoopDescription(_runLoop, self.name)) additionalDescription:nil];
}

- (void)_startTracking
{
	if(_isTracking == YES)
	{
		return;
	}
	
	_isTracking = YES;
	
	__weak __typeof(self) weakSelf = self;
	
	_observer = CFBridgingRelease(CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopEntry | kCFRunLoopBeforeTimers | kCFRunLoopBeforeSources | kCFRunLoopBeforeWaiting | kCFRunLoopAfterWaiting | kCFRunLoopExit, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
		
		__strong __typeof(weakSelf) strongSelf = weakSelf;
		if(strongSelf == nil)
		{
			CFRunLoopObserverInvalidate(observer);
			return;
		}
		
		BOOL isBusyNow;
		
		if(activity & kCFRunLoopBeforeWaiting || activity & kCFRunLoopExit)
		{
			isBusyNow = NO;
		}
		else
		{
			isBusyNow = YES;
		}
		
		[strongSelf _setBusy:isBusyNow];
	}));
	
	CFRunLoopAddObserver(_runLoop, (__bridge CFRunLoopObserverRef)_observer, kCFRunLoopCommonModes);
	CFRunLoopAddObserver(_runLoop, (__bridge CFRunLoopObserverRef)_observer, kCFRunLoopDefaultMode);
	
	if(CFRunLoopIsWaiting(_runLoop) == NO)
	{
		self._wasPreviouslyBusy = YES;
		[self performUpdateBlock:^ NSUInteger {
			return 1;
		} eventIdentifier:[NSString stringWithFormat:@"%p", self] eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription) objectDescription:_DTXStringReturningBlock(_DTXCFRunLoopDescription(_runLoop, self.name)) additionalDescription:nil];
	}
}

- (void)_stopTracking
{
	if(_isTracking == NO)
	{
		return;
	}
	
	if(_observer != NULL)
	{
		CFRunLoopObserverInvalidate((__bridge CFRunLoopObserverRef)_observer);
		_observer = nil;
	}
	
	[self performUpdateBlock:^ NSUInteger {
		return 0;
	} eventIdentifier:[NSString stringWithFormat:@"%p", self] eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription) objectDescription:_DTXStringReturningBlock(_DTXCFRunLoopDescription(_runLoop, self.name)) additionalDescription:nil];
	
	_isTracking = NO;
}

- (void)dealloc
{
	if(_runLoop == nil)
	{
		return;
	}
	
	[self _stopTracking];
	
	objc_setAssociatedObject((__bridge id)_runLoop, DTXRunLoopDeallocHelperKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p runLoop: “%@”>", self.class, self, _runLoop == CFRunLoopGetMain() ? @"Main Run Loop" : _DTXCFRunLoopDescription(_runLoop, self.name)];
}

- (NSString *)syncResourceDescription
{
	return [NSString stringWithFormat:@"“%@”", _DTXCFRunLoopDescription(_runLoop, self.name)];
}

- (NSString*)syncResourceGenericDescription
{
	return @"Run Loop";
}

@end
