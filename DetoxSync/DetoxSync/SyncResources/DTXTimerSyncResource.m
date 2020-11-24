//
//  DTXTimerSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXTimerSyncResource-Private.h"
#import "NSTimer+DTXSpy.h"
#import "DTXSyncManager-Private.h"
#import "CADisplayLink+DTXSpy.h"
#import "_DTXTimerTrampoline.h"

@import ObjectiveC;

@implementation DTXTimerSyncResource
{
	NSHashTable* _timers;
}

+ (id<DTXTimerProxy>)timerProxyWithTarget:(id)target selector:(SEL)selector fireDate:(NSDate*)fireDate interval:(NSTimeInterval)ti repeats:(BOOL)rep
{
	return [[_DTXTimerTrampoline alloc] initWithTarget:target selector:selector fireDate:fireDate interval:ti repeats:rep];
}

+ (id<DTXTimerProxy>)timerProxyWithCallback:(CFRunLoopTimerCallBack)callback fireDate:(NSDate*)fireDate interval:(NSTimeInterval)ti repeats:(BOOL)rep
{
	return [[_DTXTimerTrampoline alloc] initWithCallback:callback fireDate:fireDate interval:ti repeats:rep];
}

+ (id<DTXTimerProxy>)existingTimerProxyWithTimer:(NSTimer*)timer
{
	return objc_getAssociatedObject(timer, __DTXTimerTrampolineKey);
}

+ (void)clearExistingTimerProxyWithTimer:(NSTimer *)timer
{
	objc_setAssociatedObject(timer, __DTXTimerTrampolineKey, nil, OBJC_ASSOCIATION_RETAIN);
}

+ (id<DTXTimerProxy>)_timerProxyWithDisplayLink:(CADisplayLink *)displayLink
{
	_DTXTimerTrampoline* rv = [[_DTXTimerTrampoline alloc] initWithTarget:nil selector:nil fireDate:nil interval:0 repeats:YES];
	[rv setDisplayLink:displayLink];
	return rv;
}

+ (id<DTXTimerProxy>)existingTimerProxyWithDisplayLink:(CADisplayLink *)displayLink create:(BOOL)create
{
	id rv = objc_getAssociatedObject(displayLink, __DTXTimerTrampolineKey);
	if(rv == nil && create == YES)
	{
		rv = [self _timerProxyWithDisplayLink:displayLink];
		objc_setAssociatedObject(displayLink, __DTXTimerTrampolineKey, rv, OBJC_ASSOCIATION_RETAIN);
	}
	return rv;
}

+ (void)clearExistingTimerProxyWithDisplayLink:(CADisplayLink *)displayLink
{
	id rv = objc_getAssociatedObject(displayLink, __DTXTimerTrampolineKey);
	[rv untrack];
	objc_setAssociatedObject(displayLink, __DTXTimerTrampolineKey, nil, OBJC_ASSOCIATION_RETAIN);
}

- (instancetype)init
{
	self = [super init];
	
	if(self)
	{
		_timers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
	}
	
	return self;
}

+ (instancetype)sharedInstance
{
	static DTXTimerSyncResource* shared;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [DTXTimerSyncResource new];
		[DTXSyncManager registerSyncResource:shared];
	});
	
	return shared;
}

/// Ugly hack for rare occasions where NSTimer gets released, but its associated objects are not released.
static NSUInteger _DTXCleanTimersAndReturnCount(NSHashTable* _timers)
{	
	for (_DTXTimerTrampoline* trampoline in _timers.copy) {
		if((trampoline.timer == nil && trampoline.displayLink == nil) || [DTXSyncManager isRunLoopTracked:trampoline.runLoop] == NO)
		{
			[_timers removeObject:trampoline];
		}
	}
	
	return _timers.count;
}

- (void)clearTimerTrampolinesForCFRunLoop:(CFRunLoopRef)cfRunLoop
{
	[self performUpdateBlock:^{
		return _DTXCleanTimersAndReturnCount(_timers);
	} eventIdentifier:_DTXStringReturningBlock(@"") eventDescription:nil objectDescription:nil additionalDescription:nil];
}

- (void)trackTimerTrampoline:(_DTXTimerTrampoline *)trampoline
{
	[self performUpdateBlock:^{
		[_timers addObject:trampoline];
		return _DTXCleanTimersAndReturnCount(_timers);
	} eventIdentifier:_DTXStringReturningBlock([NSString stringWithFormat:@"%p", trampoline]) eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription) objectDescription:_DTXStringReturningBlock(trampoline.syncResourceDescription) additionalDescription:nil];
}

- (void)untrackTimerTrampoline:(_DTXTimerTrampoline *)trampoline
{
	[self performUpdateBlock:^{
		[_timers removeObject:trampoline];
		return _DTXCleanTimersAndReturnCount(_timers);
	} eventIdentifier:_DTXStringReturningBlock([NSString stringWithFormat:@"%p", trampoline]) eventDescription:_DTXStringReturningBlock(self.syncResourceGenericDescription) objectDescription:_DTXStringReturningBlock(trampoline.syncResourceDescription) additionalDescription:nil];
}

- (NSString *)description
{
	id x = nil;
	
	@try {
		x = [NSString stringWithFormat:@"<%@: %p%@>", self.class, self, _timers.count > 0 ? [NSString stringWithFormat:@"  timers: %@", [_timers.allObjects valueForKey:@"description"]] : @""];
	} @catch (NSException *exception) {
		return [super description];
	}
	
	return x;
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"Timers: %@", _timers.count > 0 ? [_timers.allObjects valueForKey:@"syncResourceDescription"] : @"-"];
}

- (NSString*)syncResourceGenericDescription
{
	return @"Timer";
}

+ (void)clearTimersForCFRunLoop:(CFRunLoopRef)cfRunLoop
{
	[DTXTimerSyncResource.sharedInstance clearTimerTrampolinesForCFRunLoop:cfRunLoop];
}

@end
