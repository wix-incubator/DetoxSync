//
//  CADisplayLink+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "CADisplayLink+DTXSpy.h"
#import "DTXTimerSyncResource.h"

@import ObjectiveC;

static const void* _DTXDisplayLinkRunLoopKey = &_DTXDisplayLinkRunLoopKey;

@interface CADisplayLink ()

+ (instancetype)displayLinkWithDisplay:(id)arg1 target:(id)arg2 selector:(SEL)arg3;

@end

@implementation CADisplayLink (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		NSError* error;
		
		DTXSwizzleClassMethod(self, @selector(displayLinkWithDisplay:target:selector:), @selector(__detox_sync_displayLinkWithDisplay:target:selector:), &error);
		
		DTXSwizzleMethod(self, @selector(addToRunLoop:forMode:), @selector(__detox_sync_addToRunLoop:forMode:), &error);
		DTXSwizzleMethod(self, @selector(removeFromRunLoop:forMode:), @selector(__detox_sync_removeFromRunLoop:forMode:), &error);
		DTXSwizzleMethod(self, @selector(invalidate), @selector(__detox_sync_invalidate), &error);
		DTXSwizzleMethod(self, @selector(setPaused:), @selector(__detox_sync_setPaused:), &error);
	}
}

- (NSInteger)__detox_sync_numberOfRunloops
{
	return [objc_getAssociatedObject(self, _DTXDisplayLinkRunLoopKey) integerValue];
}

- (void)__detox_sync_setNumberOfRunloops:(NSInteger)__detox_sync_numberOfRunloops
{
	objc_setAssociatedObject(self, _DTXDisplayLinkRunLoopKey, @(__detox_sync_numberOfRunloops), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (id)__detox_sync_displayLinkWithDisplay:(id)arg1 target:(id)arg2 selector:(SEL)arg3;
{
	return [self __detox_sync_displayLinkWithDisplay:arg1 target:arg2 selector:arg3];
}

- (void)__detox_sync_addToRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode
{
	self.__detox_sync_numberOfRunloops += 1;
	
	if(self.isPaused == NO)
	{
		id<DTXTimerProxy> proxy = [DTXTimerSyncResource existingTimeProxyWithDisplayLink:self];
		[proxy track];
	}
	
	[self __detox_sync_addToRunLoop:runloop forMode:mode];
}

- (void)__detox_sync_setPaused:(BOOL)paused
{
	id<DTXTimerProxy> proxy = [DTXTimerSyncResource existingTimeProxyWithDisplayLink:self];
	if(paused == YES)
	{
		[proxy untrack];
	}
	else
	{
		if(self.__detox_sync_numberOfRunloops > 0)
		{
			[proxy track];
		}
	}
	
	[self __detox_sync_setPaused:paused];
}

- (void)__detox_sync_removeFromRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode
{
	[self __detox_sync_removeFromRunLoop:runloop forMode:mode];
	
	self.__detox_sync_numberOfRunloops -= 1;
	
	if(self.__detox_sync_numberOfRunloops == 0)
	{
		id<DTXTimerProxy> proxy = [DTXTimerSyncResource existingTimeProxyWithDisplayLink:self];
		[proxy untrack];
	}
}

- (void)__detox_sync_invalidate
{
	[self __detox_sync_invalidate];
	
	id<DTXTimerProxy> proxy = [DTXTimerSyncResource existingTimeProxyWithDisplayLink:self];
	[proxy untrack];
	[DTXTimerSyncResource clearExistingTimeProxyWithDisplayLink:self];
}

@end
