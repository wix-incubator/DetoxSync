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
		Method m1 = class_getInstanceMethod(self.class, @selector(setNeedsLayout));
		Method m2 = class_getInstanceMethod(self.class, @selector(__detox_sync_setNeedsLayout));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(self.class, @selector(setNeedsDisplay));
		m2 = class_getInstanceMethod(self.class, @selector(__detox_sync_setNeedsDisplay));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(self.class, @selector(setNeedsDisplayInRect:));
		m2 = class_getInstanceMethod(self.class, @selector(__detox_sync_setNeedsDisplayInRect:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(self.class, @selector(addAnimation:forKey:));
		m2 = class_getInstanceMethod(self.class, @selector(__detox_sync_addAnimation:forKey:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(self.class, @selector(removeAnimationForKey:));
		m2 = class_getInstanceMethod(self.class, @selector(__detox_sync_removeAnimationForKey:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(self.class, @selector(removeAllAnimations));
		m2 = class_getInstanceMethod(self.class, @selector(__detox_sync_removeAllAnimations));
		method_exchangeImplementations(m1, m2);
	}
}

- (void)__detox_sync_setNeedsLayout
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Layer layout"];
	
	[self __detox_sync_setNeedsLayout];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endUse];
	});
}

- (void)__detox_sync_setNeedsDisplay
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Layer display"];
	
	[self __detox_sync_setNeedsDisplay];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endUse];
	});
}

- (void)__detox_sync_setNeedsDisplayInRect:(CGRect)rect
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Layer display in rect"];
	
	[self __detox_sync_setNeedsDisplayInRect:rect];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endUse];
	});
}

- (void)__detox_sync_addAnimation:(CAAnimation *)anim forKey:(NSString *)key
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Layer pending CA animation"];
	
	[self __detox_sync_addAnimation:anim forKey:key];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endUse];
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
