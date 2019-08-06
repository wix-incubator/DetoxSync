//
//  DTXNSTimerSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXNSTimerSyncResource-Private.h"
#import "NSTimer+DTXSpy.h"
#import "DTXSyncManager-Private.h"

@implementation _DTXTimerTrampoline
{
	id _target;
	SEL _sel;
	NSString* _timerDescription;
}

- (instancetype)initWithTarget:(id)target selector:(SEL)selector
{
	self = [super init];
	if(self)
	{
		_target = target;
		_sel = selector;
		[DTXNSTimerSyncResource.sharedInstance trackTimerTrampoline:self];
	}
	return self;
}

- (void)dealloc
{
	[DTXNSTimerSyncResource.sharedInstance untrackTimerTrampoline:self];
	_target = nil;
}

- (void)setTimer:(NSTimer*)timer
{
	_timerDescription = [timer description];
}

- (void)fire:(id)timer
{
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[_target performSelector:_sel withObject:timer];
	#pragma clang diagnostic pop
}

@end

@implementation DTXNSTimerSyncResource
{
	dispatch_queue_t _queue;
	NSHashTable* _timers;
}

+ (id<DTXTimerProxy>)timeProxyWithTarget:(id)target selector:(SEL)selector
{
	return [[_DTXTimerTrampoline alloc] initWithTarget:target selector:selector];
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
	static DTXNSTimerSyncResource* shared;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [DTXNSTimerSyncResource new];
		[DTXSyncManager registerSyncResource:shared];
	});
	
	return shared;
}

- (void)trackTimerTrampoline:(_DTXTimerTrampoline *)trampoline
{
	[self performUpdateBlock:^{
		[_timers addObject:trampoline];
		return YES;
	}];
}

- (void)untrackTimerTrampoline:(_DTXTimerTrampoline *)trampoline
{
	[self performUpdateBlock:^{
		[_timers removeObject:trampoline];
		return (BOOL)(_timers.count != 0);
	}];
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"Timers: %@", [_timers.allObjects valueForKey:@"timerDescription"]];
}

@end
