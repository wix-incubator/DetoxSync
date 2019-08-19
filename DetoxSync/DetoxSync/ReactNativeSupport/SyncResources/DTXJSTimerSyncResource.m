//
//  DTXJSTimerSyncResource.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXJSTimerSyncResource.h"
#import "DTXSyncManager-Private.h"

@import ObjectiveC;

@interface DTXJSTimerSyncResource ()

- (BOOL)_isBusy;

@end

@interface _DTXJSTimerObservationWrapper : NSObject @end
@implementation _DTXJSTimerObservationWrapper
{
	NSMutableArray<NSNumber*>* _observedTimers;
	NSMutableDictionary* _timers;
	
	__weak DTXJSTimerSyncResource* _syncResource;
}

- (instancetype)initWithTimers:(NSMutableDictionary*)timers syncResource:(DTXJSTimerSyncResource*)syncResource
{
	self = [super init];
	if(self)
	{
		_timers = timers;
		_observedTimers = [NSMutableArray new];
		_syncResource = syncResource;
	}
	
	return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature* sig = [super methodSignatureForSelector:aSelector];
	
	if(sig == nil)
	{
		sig = [_timers methodSignatureForSelector:aSelector];
	}
	
	return sig;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[anInvocation invokeWithTarget:_timers];
}

- (void)addObservedTimer:(NSNumber*)observedNumber
{
	[_observedTimers addObject:observedNumber];
}

- (NSUInteger)countOfObservedTimers
{
	return _observedTimers.count;
}

- (void)removeObjectForKey:(NSNumber*)aKey
{
	[_syncResource performUpdateBlock:^BOOL{
		if([_observedTimers containsObject:aKey])
		{
			_DTXSyncResourceVerboseLog(@"⏰ Removing observed timer %@", aKey);
			[_observedTimers removeObject:aKey];
		}
		
		return [_syncResource _isBusy];
	}];
	
	[_timers removeObjectForKey:aKey];
}

@end

@implementation DTXJSTimerSyncResource
{
	NSMapTable<id, _DTXJSTimerObservationWrapper*>* _observations;
	NSTimeInterval _durationThreshold;
}

- (NSMapTable<id,id> *)observations
{
	return (id)_observations;
}

- (void)setDurationThreshold:(NSTimeInterval)durationThreshold
{
	_durationThreshold = durationThreshold;
}

- (NSString*)failuireReasonForDuration:(NSTimeInterval)duration repeats:(BOOL)repeats
{
	if(duration == 0)
	{
		return @"duration==0";
	}
	else if(repeats == YES)
	{
		return @"repeats==true";
	}
	else if(duration > _durationThreshold)
	{
		return [NSString stringWithFormat:@"duration>%@", @(_durationThreshold)];
	}
	
	return @"";
}

- (BOOL)_isBusy
{
	NSUInteger observedTimersCount = 0;
	
	for(_DTXJSTimerObservationWrapper* wrapper in _observations.objectEnumerator)
	{
		observedTimersCount += wrapper.countOfObservedTimers;
	}
	
	return observedTimersCount > 0;
}

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		_observations = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory valueOptions:NSMapTableStrongMemory];
		_durationThreshold = 10000000000;
		
		__weak __typeof(self) weakSelf = self;
		
		Class cls = NSClassFromString(@"RCTTiming");
		SEL createTimerSel = NSSelectorFromString(@"createTimer:duration:jsSchedulingTime:repeats:");
		Method m = class_getInstanceMethod(cls, createTimerSel);
		
		void (*orig_createTimer)(id, SEL, NSNumber*, NSTimeInterval, NSDate*, BOOL) = (void*)method_getImplementation(m);
		method_setImplementation(m, imp_implementationWithBlock(^(id _self, NSNumber* timerID, NSTimeInterval duration, NSDate* jsDate, BOOL repeats) {
			__strong __typeof(weakSelf) strongSelf = weakSelf;
			
			dtx_defer {
				orig_createTimer(_self, createTimerSel, timerID, duration, jsDate, repeats);
			};
			
			if(strongSelf == nil)
			{
				return;
			}
			
			[strongSelf performUpdateBlock:^BOOL{
				_DTXJSTimerObservationWrapper* _observationWrapper = [strongSelf->_observations objectForKey:_self];
				
				if(_observationWrapper == nil)
				{
					_observationWrapper = [[_DTXJSTimerObservationWrapper alloc] initWithTimers:[_self valueForKey:@"_timers"] syncResource:strongSelf];
					[_self setValue:_observationWrapper forKey:@"_timers"];
					[strongSelf->_observations setObject:_observationWrapper forKey:_self];
				}
				
				if(duration > 0 && duration <= _durationThreshold && repeats == NO)
				{
					_DTXSyncResourceVerboseLog(@"⏰ Observing timer “%@” duration: %@ repeats: %@", timerID, @(duration), @(repeats));
					
					[_observationWrapper addObservedTimer:timerID];
				}
				else
				{
					_DTXSyncResourceVerboseLog(@"⏰ Ignoring timer “%@” failure reason: \"%@\"", timerID, [strongSelf failuireReasonForDuration:duration repeats:repeats]);
				}
				
				return [self _isBusy];
			}];
		}));
	}
	return self;
}

@end
