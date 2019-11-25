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

@import ObjectiveC;

static const void* _DTXTimerTrampolineKey = &_DTXTimerTrampolineKey;

@implementation _DTXTimerTrampoline
{
	id _target;
	SEL _sel;
	
	//NSTimer
	__weak NSTimer* _timer;
	
	//CFRunLoopTimer
	CFRunLoopTimerCallBack _callBack;
	void* _info;
    const void* (*_retain)(const void* info);
    void (*_release)(const void* info);
	
	//CADisplayLink
	__weak CADisplayLink* _displayLink;
	
	BOOL _tracking;
}

@synthesize fireDate=_fireDate;
@synthesize interval=_ti;
@synthesize repeats=_repeats;
@synthesize timer=_timer;
@synthesize displayLink=_displayLink;

- (instancetype)initWithTarget:(id)target selector:(SEL)selector fireDate:(NSDate*)fireDate interval:(NSTimeInterval)ti repeats:(BOOL)rep
{
	self = [super init];
	if(self)
	{
		_target = target;
		_sel = selector;
		
		_fireDate = fireDate;
		_ti = ti;
		_repeats = rep;
	}
	return self;
}

- (instancetype)initWithCallBack:(CFRunLoopTimerCallBack)callBack context:(CFRunLoopTimerContext*)context fireDate:(NSDate*)fireDate interval:(NSTimeInterval)ti repeats:(BOOL)rep
{
	self = [super init];
	if(self)
	{
		_callBack = callBack;
		if(context)
		{
			_info = context->info;
			_retain = context->retain;
			_release = context->release;
		}
		
		_fireDate = fireDate;
		_ti = ti;
		_repeats = rep;
	}
	return self;
}

- (void)retainContext
{
	if(_retain)
	{
		_retain(_info);
	}
}

- (void)releaseContext
{
	if(_release)
	{
		_release(_info);
	}
}

- (void)dealloc
{
	[self untrack];
	
	_target = nil;
	objc_setAssociatedObject(_timer, _DTXTimerTrampolineKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (void)setTimer:(NSTimer*)timer
{
	_timer = timer;
	objc_setAssociatedObject(timer, _DTXTimerTrampolineKey, self, OBJC_ASSOCIATION_ASSIGN);
}

- (void)setDisplayLink:(CADisplayLink*)displayLink
{
	_displayLink = displayLink;
	objc_setAssociatedObject(_displayLink, _DTXTimerTrampolineKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)fire:(id)timer
{
	if(_callBack)
	{
		_callBack((__bridge CFRunLoopTimerRef)timer, _info);
		return;
	}
	
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[_target performSelector:_sel withObject:timer];
	#pragma clang diagnostic pop
}

- (void)track
{
	if(_tracking == YES)
	{
		return;
	}
	
	_tracking = YES;
	[DTXTimerSyncResource.sharedInstance trackTimerTrampoline:self];
}

- (void)untrack
{
	if(_tracking == NO)
	{
		return;
	}
	
	[DTXTimerSyncResource.sharedInstance untrackTimerTrampoline:self];
	_tracking = NO;
}

+ (NSDateFormatter*)_descriptionDateFormatter
{
	static NSDateFormatter* _dateFormatter;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_dateFormatter = [NSDateFormatter new];
		_dateFormatter.locale = NSLocale.autoupdatingCurrentLocale;
		_dateFormatter.dateFormat = @"YYYY-MM-dd HH:mm:ss Z";
	});
	return _dateFormatter;
}

- (NSString *)description
{
	
	
	if(_displayLink != nil)
	{
		return _displayLink.description;
	}
	
	return [NSString stringWithFormat:@"<%@: %p fireDate: %@ interval: %@ repeats: %@>", _timer.class, _timer, [_DTXTimerTrampoline._descriptionDateFormatter stringFromDate:_fireDate], @(_ti), _repeats ? @"YES" : @"NO"];
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"Timer with fireDate: “%@” interval: “%@” repeats: “%@”", [_DTXTimerTrampoline._descriptionDateFormatter stringFromDate:_fireDate], @(_ti), _repeats ? @"YES" : @"NO"];
}

- (NSString*)syncResourceGenericDescription
{
	return @"Timer";
}

@end

@implementation DTXTimerSyncResource
{
	dispatch_queue_t _queue;
	NSHashTable* _timers;
}

+ (id<DTXTimerProxy>)timerProxyWithTarget:(id)target selector:(SEL)selector fireDate:(NSDate*)fireDate interval:(NSTimeInterval)ti repeats:(BOOL)rep
{
	return [[_DTXTimerTrampoline alloc] initWithTarget:target selector:selector fireDate:fireDate interval:ti repeats:rep];
}

+ (id<DTXTimerProxy>)timerProxyWithCallBack:(CFRunLoopTimerCallBack)callBack context:(CFRunLoopTimerContext*)context fireDate:(NSDate*)fireDate interval:(NSTimeInterval)ti repeats:(BOOL)rep
{
	return [[_DTXTimerTrampoline alloc] initWithCallBack:callBack context:context fireDate:fireDate interval:ti repeats:rep];
}

+ (id<DTXTimerProxy>)existingTimeProxyWithTimer:(NSTimer*)timer
{
	return objc_getAssociatedObject(timer, _DTXTimerTrampolineKey);
}

+ (void)clearExistingTimeProxyWithTimer:(NSTimer *)timer
{
	objc_setAssociatedObject(timer, _DTXTimerTrampolineKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

+ (void)startTrackingDisplayLink:(CADisplayLink *)displayLink
{
	id<DTXTimerProxy> proxy = [self _timerProxyWithDisplayLink:displayLink];
	[proxy setDisplayLink:displayLink];
	
	if(displayLink.isPaused == NO && displayLink.__detox_sync_numberOfRunloops > 0)
	{
		[proxy track];
	}
}

+ (void)stopTrackingDisplayLink:(CADisplayLink *)displayLink
{
	id<DTXTimerProxy> proxy = [self existingTimeProxyWithDisplayLink:displayLink];
	[proxy untrack];
	[self clearExistingTimeProxyWithDisplayLink:displayLink];
}

+ (id<DTXTimerProxy>)_timerProxyWithDisplayLink:(CADisplayLink *)displayLink
{
	return [[_DTXTimerTrampoline alloc] initWithTarget:nil selector:nil fireDate:nil interval:0 repeats:YES];
}

+ (id<DTXTimerProxy>)existingTimeProxyWithDisplayLink:(CADisplayLink *)displayLink
{
	return objc_getAssociatedObject(displayLink, _DTXTimerTrampolineKey);
}

+ (void)clearExistingTimeProxyWithDisplayLink:(CADisplayLink *)displayLink
{
	objc_setAssociatedObject(displayLink, _DTXTimerTrampolineKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

- (void)trackTimerTrampoline:(_DTXTimerTrampoline *)trampoline
{
	[self performUpdateBlock:^{
		[_timers addObject:trampoline];
		return _timers.count;
	} eventIdentifier:[NSString stringWithFormat:@"%p", trampoline] eventDescription:self.syncResourceGenericDescription objectDescription:trampoline.syncResourceDescription additionalDescription:nil];
}

- (void)untrackTimerTrampoline:(_DTXTimerTrampoline *)trampoline
{
	[self performUpdateBlock:^{
		[_timers removeObject:trampoline];
		return _timers.count;
	} eventIdentifier:[NSString stringWithFormat:@"%p", trampoline] eventDescription:self.syncResourceGenericDescription objectDescription:trampoline.syncResourceDescription additionalDescription:nil];
}

- (NSString *)description
{
	id x = nil;
	
	@try {
		x = [NSString stringWithFormat:@"<%@: %p timers: %@", self.class, self, [_timers.allObjects valueForKey:@"description"]];
	} @catch (NSException *exception) {
		return [super description];
	}
	
	return x;
}

- (NSString*)syncResourceDescription
{
	return [NSString stringWithFormat:@"Timers: %@", [_timers.allObjects valueForKey:@"syncResourceDescription"]];
}

- (NSString*)syncResourceGenericDescription
{
	return @"Timer";
}

@end
