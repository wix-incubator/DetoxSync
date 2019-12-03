//
//  CALayer+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "CALayer+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"
#import "DTXOrigDispatch.h"
#import "CAAnimation+DTXSpy.h"

@import ObjectiveC;

@implementation CALayer (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		NSError* error;
		[self jr_swizzleMethod:@selector(setNeedsLayout) withMethod:@selector(__detox_sync_setNeedsLayout) error:&error];
		[self jr_swizzleMethod:@selector(setNeedsDisplay) withMethod:@selector(__detox_sync_setNeedsDisplay) error:&error];
		[self jr_swizzleMethod:@selector(setNeedsDisplayInRect:) withMethod:@selector(__detox_sync_setNeedsDisplayInRect:) error:&error];
		[self jr_swizzleMethod:@selector(addAnimation:forKey:) withMethod:@selector(__detox_sync_addAnimation:forKey:) error:&error];
		[self jr_swizzleMethod:@selector(removeAnimationForKey:) withMethod:@selector(__detox_sync_removeAnimationForKey:) error:&error];
		[self jr_swizzleMethod:@selector(removeAllAnimations) withMethod:@selector(__detox_sync_removeAllAnimations) error:&error];
	}
}

- (void)__detox_sync_setNeedsLayout
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Layer Layout"];
	
	[self __detox_sync_setNeedsLayout];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_setNeedsDisplay
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Layer Display"];
	
	[self __detox_sync_setNeedsDisplay];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_setNeedsDisplayInRect:(CGRect)rect
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Layer Display in Rect"];
	
	[self __detox_sync_setNeedsDisplayInRect:rect];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_addAnimation:(CAAnimation *)anim forKey:(NSString *)key
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Layer Pending Animation"];
	
	[self __detox_sync_addAnimation:anim forKey:key];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_removeAnimationForKey:(NSString *)key
{
	CAAnimation* anim = [self animationForKey:key];
	
	[anim __detox_sync_untrackAnimation];
	
	[self __detox_sync_removeAnimationForKey:key];
}

- (void)__detox_sync_removeAllAnimations
{
	[self.animationKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
		CAAnimation* anim = [self animationForKey:key];
	
		[anim __detox_sync_untrackAnimation];
	}];
	
	[self __detox_sync_removeAllAnimations];
}

@end
