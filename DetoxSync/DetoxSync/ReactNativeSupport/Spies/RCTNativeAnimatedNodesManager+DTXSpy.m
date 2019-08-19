//
//  RCTNativeAnimatedNodesManager+DTXSpy.c
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "RCTNativeAnimatedNodesManager+DTXSpy.h"
#import "DTXSyncManager-Private.h"

@import ObjectiveC;

@interface NSObject ()

- (void)startAnimationLoopIfNeeded;
- (void)stopAnimationLoop;

@end

@implementation NSObject (RCTNativeAnimatedNodesManagerDTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		Class cls = NSClassFromString(@"RCTNativeAnimatedNodesManager");
		
		if(cls == nil)
		{
			return;
		}
		
		Method m11 = class_getInstanceMethod(cls, @selector(startAnimationLoopIfNeeded));
		Method m21 = class_getInstanceMethod(cls, @selector(__detox_sync_startAnimationLoopIfNeeded));
		
		Method m12 = class_getInstanceMethod(cls, @selector(stopAnimationLoop));
		Method m22 = class_getInstanceMethod(cls, @selector(__detox_sync_stopAnimationLoop));
		
		if(m11 == NULL || m12 == NULL)
		{
			return;
		}
		
		method_exchangeImplementations(m11, m21);
		method_exchangeImplementations(m12, m22);
	}
}

- (void)__detox_sync_startAnimationLoopIfNeeded
{
	[self __detox_sync_startAnimationLoopIfNeeded];
	
	[DTXSyncManager trackDisplayLink:[self valueForKey:@"_displayLink"]];
}

- (void)__detox_sync_stopAnimationLoop
{
	CADisplayLink* dl = [self valueForKey:@"_displayLink"];
	[self __detox_sync_stopAnimationLoop];

	if(dl != nil)
	{
		[DTXSyncManager untrackDisplayLink:dl];
	}
}

@end
