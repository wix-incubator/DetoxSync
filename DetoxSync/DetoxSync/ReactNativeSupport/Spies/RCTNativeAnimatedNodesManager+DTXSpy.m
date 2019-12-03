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
		
		NSError* error;
		[cls jr_swizzleMethod:@selector(startAnimationLoopIfNeeded) withMethod:@selector(__detox_sync_startAnimationLoopIfNeeded) error:&error];
		[cls jr_swizzleMethod:@selector(stopAnimationLoop) withMethod:@selector(__detox_sync_stopAnimationLoop) error:&error];
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
