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
		
		DTXSwizzleMethod(self, @selector(setNeedsLayout), @selector(__detox_sync_setNeedsLayout), &error);
		DTXSwizzleMethod(self, @selector(setNeedsDisplay), @selector(__detox_sync_setNeedsDisplay), &error);
		DTXSwizzleMethod(self, @selector(setNeedsDisplayInRect:), @selector(__detox_sync_setNeedsDisplayInRect:), &error);
		DTXSwizzleMethod(self, @selector(addAnimation:forKey:), @selector(__detox_sync_addAnimation:forKey:), &error);
		DTXSwizzleMethod(self, @selector(removeAnimationForKey:), @selector(__detox_sync_removeAnimationForKey:), &error);
		DTXSwizzleMethod(self, @selector(removeAllAnimations), @selector(__detox_sync_removeAllAnimations), &error);
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
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Layer Display"];
	
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
