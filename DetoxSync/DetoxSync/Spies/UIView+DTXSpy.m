//
//  UIView+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIView+DTXSpy.h"
#import "DTXSingleEventSyncResource.h"
#import "DTXOrigDispatch.h"

@import ObjectiveC;

@interface UIView ()

+ (void)_setupAnimationWithDuration:(double)arg1 delay:(double)arg2 view:(id)arg3 options:(unsigned long long)arg4 factory:(id)arg5 animations:(id)arg6 start:(id)arg7 animationStateGenerator:(id)arg8 completion:(id)arg9;

@end

@implementation UIView (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		NSError* error;
		
		DTXSwizzleClassMethod(self, @selector(animateWithDuration:delay:options:animations:completion:), @selector(__detox_sync_animateWithDuration:delay:options:animations:completion:), &error);
		DTXSwizzleClassMethod(self, @selector(animateWithDuration:animations:completion:), @selector(__detox_sync_animateWithDuration:animations:completion:), &error);
		DTXSwizzleClassMethod(self, @selector(animateWithDuration:animations:), @selector(__detox_sync_animateWithDuration:animations:), &error);
		DTXSwizzleClassMethod(self, @selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:), @selector(__detox_sync_animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:), &error);
		DTXSwizzleClassMethod(self, @selector(transitionFromView:toView:duration:options:completion:), @selector(__detox_sync_transitionFromView:toView:duration:options:completion:), &error);
		DTXSwizzleClassMethod(self, @selector(transitionWithView:duration:options:animations:completion:), @selector(__detox_sync_transitionWithView:duration:options:animations:completion:), &error);
		DTXSwizzleClassMethod(self, @selector(animateKeyframesWithDuration:delay:options:animations:completion:), @selector(__detox_sync_animateKeyframesWithDuration:delay:options:animations:completion:), &error);
		
		DTXSwizzleMethod(self, @selector(setNeedsLayout), @selector(__detox_sync_setNeedsLayout), &error);
		DTXSwizzleMethod(self, @selector(setNeedsDisplay), @selector(__detox_sync_setNeedsDisplay), &error);
		DTXSwizzleMethod(self, @selector(setNeedsDisplayInRect:), @selector(__detox_sync_setNeedsDisplayInRect:), &error);
	}
}

DTX_ALWAYS_INLINE
static DTXSingleEventSyncResource* _DTXSRForAnimation(NSTimeInterval duration, NSTimeInterval delay)
{
	return [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:[NSString stringWithFormat:@"UIView animation with duration: “%@” delay: “%@”", @(duration), @(delay)] eventDescription:@"Animation"];
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
	DTXSingleEventSyncResource* sr = _DTXSRForAnimation(duration, delay);
//	BOOL isTheOne = [NSThread.callStackSymbols.description containsString:@"_UIRefreshControlModernContentView"];
//	if(isTheOne)
//	{
//		NSLog(@"");
//	}
	
	__block BOOL wasEnded;
	
	[self __detox_sync_animateWithDuration:duration delay:delay options:options animations:animations completion:^(BOOL finished) {
		if(completion)
		{
			completion(finished);
		}
//
//		if(isTheOne == YES)
//		{
//			NSLog(@"");
//		}
		
		[sr endTracking];
		
		wasEnded = YES;
	}];
	
	//Failsafe, just in case.
	__detox_sync_orig_dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay + duration + 0.1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[sr endTracking];
	});
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
	[self animateWithDuration:duration delay:0.0 options:0 animations:animations completion:completion];
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
	[self animateWithDuration:duration delay:0.0 options:0 animations:animations completion:nil];
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
	DTXSingleEventSyncResource* sr = _DTXSRForAnimation(duration, delay);
	
	[self __detox_sync_animateWithDuration:duration delay:delay usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity options:options animations:animations completion:^(BOOL finished) {
		if(completion)
		{
			completion(finished);
		}
		
		[sr endTracking];
	}];
}

+ (void)__detox_sync_transitionFromView:(UIView *)fromView toView:(UIView *)toView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options completion:(void (^ __nullable)(BOOL finished))completion
{
	DTXSingleEventSyncResource* sr = _DTXSRForAnimation(duration, 0.0);
	
	[self __detox_sync_transitionFromView:fromView toView:toView duration:duration options:options completion:^(BOOL finished) {
		if(completion)
		{
			completion(finished);
		}
		
		[sr endTracking];
	}];
}

+ (void)__detox_sync_transitionWithView:(UIView *)view duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options animations:(void (^ __nullable)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
	DTXSingleEventSyncResource* sr = _DTXSRForAnimation(duration, 0.0);
	
	[self __detox_sync_transitionWithView:view duration:duration options:options animations:animations completion:^(BOOL finished) {
		if(completion)
		{
			completion(finished);
		}
		
		[sr endTracking];
	}];
}

+ (void)__detox_sync_animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewKeyframeAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
	DTXSingleEventSyncResource* sr = _DTXSRForAnimation(duration, delay);
	
	[self __detox_sync_animateKeyframesWithDuration:duration delay:delay options:options animations:animations completion:^(BOOL finished) {
		if(completion)
		{
			completion(finished);
		}
		
		[sr endTracking];
	}];
}

/* No need to swizzle, calls public API: */

//+ (void)performSystemAnimation:(UISystemAnimation)animation onViews:(NSArray<__kindof UIView *> *)views options:(UIViewAnimationOptions)options animations:(void (^ __nullable)(void))parallelAnimations completion:(void (^ __nullable)(BOOL finished))completion API_AVAILABLE(ios(7.0));


- (void)__detox_sync_setNeedsLayout
{
	DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"View Layout"];
	
	[self __detox_sync_setNeedsLayout];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_setNeedsDisplay
{
	DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"View Display"];
	
	[self __detox_sync_setNeedsDisplay];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_setNeedsDisplayInRect:(CGRect)rect
{
	DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"View Display"];
	
	[self __detox_sync_setNeedsDisplayInRect:rect];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

@end
