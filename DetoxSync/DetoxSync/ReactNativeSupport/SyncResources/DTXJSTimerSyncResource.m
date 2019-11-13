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

- (NSUInteger)_busyCount;

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
	[_syncResource performUpdateBlock:^ {
		if([_observedTimers containsObject:aKey])
		{
			DTXSyncResourceVerboseLog(@"⏲ Removing observed timer %@", aKey);
			[_observedTimers removeObject:aKey];
		}
		
		return [_syncResource _busyCount];
	} eventIdentifier:aKey.stringValue eventDescription:[NSString stringWithFormat:@"JS timer %@", aKey]];
	
	[_timers removeObjectForKey:aKey];
}

@end

@implementation DTXJSTimerSyncResource
{
	NSMapTable<id, _DTXJSTimerObservationWrapper*>* _observations;
}

- (NSMapTable<id,id> *)observations
{
	return (id)_observations;
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
	else if(duration > DTXSyncManager.maximumTimerIntervalTrackingDuration)
	{
		return [NSString stringWithFormat:@"duration>%@", @(DTXSyncManager.maximumTimerIntervalTrackingDuration)];
	}
	
	return @"";
}

- (NSUInteger)_busyCount
{
	NSUInteger observedTimersCount = 0;
	
	for(_DTXJSTimerObservationWrapper* wrapper in _observations.objectEnumerator)
	{
		observedTimersCount += wrapper.countOfObservedTimers;
	}
	
	return observedTimersCount;
}

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		_observations = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory valueOptions:NSMapTableStrongMemory];
		
		__weak __typeof(self) weakSelf = self;
		
		Class cls = NSClassFromString(@"RCTTiming");
		SEL createTimerSel = NSSelectorFromString(@"createTimer:duration:jsSchedulingTime:repeats:");
		Method m = class_getInstanceMethod(cls, createTimerSel);
		
		// Check if the createTimer interface is using doubles or NSObjects.
		// Earlier versions of react native use NSObjects for the timer and
		// date params, while later versions use doubles for these.
		const char* timerArgType = [[cls instanceMethodSignatureForSelector:createTimerSel] getArgumentTypeAtIndex:2];
		if (strncmp(timerArgType, "d", 1) == 0)
		{
			void (*orig_createTimer)(id, SEL, double, NSTimeInterval, double, BOOL) = (void*)method_getImplementation(m);
			method_setImplementation(m, imp_implementationWithBlock(^(id _self, double timerID, NSTimeInterval duration, double jsDate, BOOL repeats) {
				__strong __typeof(weakSelf) strongSelf = weakSelf;
				[strongSelf attachObservation:_self timerID:@(timerID) duration:duration repeats:repeats];
				orig_createTimer(_self, createTimerSel, timerID, duration, jsDate, repeats);
			}));
		}
		else
		{
			void (*orig_createTimer)(id, SEL, NSNumber*, NSTimeInterval, NSDate*, BOOL) = (void*)method_getImplementation(m);
			method_setImplementation(m, imp_implementationWithBlock(^(id _self, NSNumber* timerID, NSTimeInterval duration, NSDate* jsDate, BOOL repeats) {
				__strong __typeof(weakSelf) strongSelf = weakSelf;
				[strongSelf attachObservation:_self timerID:timerID duration:duration repeats:repeats];
				orig_createTimer(_self, createTimerSel, timerID, duration, jsDate, repeats);
			}));
		}
	}
	return self;
}

- (void)attachObservation:(id)_self timerID:(NSNumber *)timerID duration:(NSTimeInterval)duration repeats:(BOOL)repeats
{
	[self performUpdateBlock:^ {
		_DTXJSTimerObservationWrapper* _observationWrapper = [self->_observations objectForKey:_self];

		if(_observationWrapper == nil)
		{
			_observationWrapper = [[_DTXJSTimerObservationWrapper alloc] initWithTimers:[_self valueForKey:@"_timers"] syncResource:self];
			[_self setValue:_observationWrapper forKey:@"_timers"];
			[self->_observations setObject:_observationWrapper forKey:_self];
		}

		if(duration > 0 && duration <= DTXSyncManager.maximumTimerIntervalTrackingDuration && repeats == NO)
		{
			DTXSyncResourceVerboseLog(@"⏲ Observing timer “%@” duration: %@ repeats: %@", timerID, @(duration), @(repeats));

			[_observationWrapper addObservedTimer:timerID];
		}
		else
		{
			DTXSyncResourceVerboseLog(@"⏲ Ignoring timer “%@” failure reason: \"%@\"", timerID, [self failuireReasonForDuration:duration repeats:repeats]);
		}

		return [self _busyCount];
	} eventIdentifier:timerID.stringValue eventDescription:[NSString stringWithFormat:@"JS timer %@", timerID]];

}

@end
