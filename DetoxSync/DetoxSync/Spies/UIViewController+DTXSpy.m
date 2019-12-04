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
		NSError* error;
		
		DTXSwizzleMethod(self, @selector(viewWillAppear:), @selector(__detox_sync__viewWillAppear:), &error);
		DTXSwizzleMethod(self, @selector(viewWillDisappear:), @selector(__detox_sync__viewWillDisappear:), &error);
	}
}

- (void)__detox_sync__viewWillAppear:(BOOL)animated
{
	[self __detox_sync__viewWillAppear:animated];
	
	if(self.transitionCoordinator)
	{
		DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Controller View Will Appear"];
		
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
		DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Controller View Will Disappear"];
		
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
