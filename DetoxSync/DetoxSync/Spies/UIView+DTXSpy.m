//
//  UIView+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIView+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"
#import "DTXOrigDispatch.h"

@import ObjectiveC;

@interface UIView ()

+ (void)_setupAnimationWithDuration:(double)arg1 delay:(double)arg2 view:(id)arg3 options:(unsigned long long)arg4 factory:(id)arg5 animations:(id)arg6 start:(id)arg7 animationStateGenerator:(id)arg8 completion:(id)arg9;

@end

@implementation UIView (DTXSpy)

+ (void)__detox_sync__setupAnimationWithDuration:(double)arg1 delay:(double)arg2 view:(id)arg3 options:(unsigned long long)arg4 factory:(id)arg5 animations:(id)arg6 start:(id)arg7 animationStateGenerator:(id)arg8 completion:(void (^)(BOOL finished))completion
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:[NSString stringWithFormat:@"UIView animation with duration: “%@” delay: “%@”", @(arg1), @(arg2)] eventDescription:@"Animation"];
	
	[self __detox_sync__setupAnimationWithDuration:arg1 delay:arg2 view:arg3 options:arg4 factory:arg5 animations:arg6 start:arg7 animationStateGenerator:arg8 completion:^(BOOL finished) {
		if(completion)
		{
			completion(finished);
		}
		
		[sr endTracking];
	}];
	
	//Failsafe—sometimes UIKit does not call the completion handler.
	__detox_sync_orig_dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((arg1 + arg2) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[sr endTracking];
	});
}

+ (void)load
{
	@autoreleasepool
	{
		NSError* error;
		[self jr_swizzleMethod:@selector(_setupAnimationWithDuration:delay:view:options:factory:animations:start:animationStateGenerator:completion:) withMethod:@selector(__detox_sync__setupAnimationWithDuration:delay:view:options:factory:animations:start:animationStateGenerator:completion:) error:&error];
		[self jr_swizzleMethod:@selector(setNeedsLayout) withMethod:@selector(__detox_sync_setNeedsLayout) error:&error];
		[self jr_swizzleMethod:@selector(setNeedsDisplay) withMethod:@selector(__detox_sync_setNeedsDisplay) error:&error];
		[self jr_swizzleMethod:@selector(setNeedsDisplayInRect:) withMethod:@selector(__detox_sync_setNeedsDisplayInRect:) error:&error];
	}
}

- (void)__detox_sync_setNeedsLayout
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"View Layout"];
	
	[self __detox_sync_setNeedsLayout];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_setNeedsDisplay
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"View Display"];
	
	[self __detox_sync_setNeedsDisplay];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)__detox_sync_setNeedsDisplayInRect:(CGRect)rect
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"View Display in Rect"];
	
	[self __detox_sync_setNeedsDisplayInRect:rect];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

@end
