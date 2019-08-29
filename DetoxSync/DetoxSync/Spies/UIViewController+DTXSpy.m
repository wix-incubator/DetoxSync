//
//  UIViewController+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIViewController+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"

@import ObjectiveC;

@implementation UIViewController (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		Method m1 = class_getInstanceMethod(UIViewController.class, @selector(viewWillAppear:));
		Method m2 = class_getInstanceMethod(UIViewController.class, @selector(__detox_sync__viewWillAppear:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(UIViewController.class, @selector(viewWillDisappear:));
		m2 = class_getInstanceMethod(UIViewController.class, @selector(__detox_sync__viewWillDisappear:));
		method_exchangeImplementations(m1, m2);
	}
}

- (void)__detox_sync__viewWillAppear:(BOOL)animated
{
	[self __detox_sync__viewWillAppear:animated];
	
	if(self.transitionCoordinator)
	{
		DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Controller view will appear"];
		
		[self.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[sr endTracking];
		}];
	}
}

- (void)__detox_sync__viewDidAppear:(BOOL)animated
{
	[self __detox_sync__viewDidAppear:animated];
}

- (void)__detox_sync__viewWillDisappear:(BOOL)animated
{
	[self __detox_sync__viewWillDisappear:animated];
	
	if(self.transitionCoordinator)
	{
		DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Controller view will disappear"];
		
		[self.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[sr endTracking];
		}];
	}
}

- (void)__detox_sync__viewDidDisappear:(BOOL)animated
{
	[self __detox_sync__viewDidDisappear:animated];
}

@end
