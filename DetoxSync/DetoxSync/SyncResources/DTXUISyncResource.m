//
//  DTXUISyncResource.m
//  DetoxSync
//
//  Created by Leo Natan on 11/19/20.
//  Copyright © 2020 wix. All rights reserved.
//

#import "DTXUISyncResource.h"
#import "DTXSyncManager-Private.h"
#import "DTXSingleEventSyncResource.h"
#import "DTXOrigDispatch.h"

@interface UIView ()

- (NSString*)__detox_sync_safeDescription;

@end

@implementation DTXUISyncResource

+ (instancetype)sharedInstance
{
	static DTXUISyncResource* shared;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [DTXUISyncResource new];
		[DTXSyncManager registerSyncResource:shared];
	});
	
	return shared;
}

- (void)trackViewNeedsLayout:(UIView *)view
{
	DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:view.__detox_sync_safeDescription eventDescription:@"View Layout"];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)trackViewNeedsDisplay:(UIView *)view
{
	DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:view.__detox_sync_safeDescription eventDescription:@"View Display"];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)trackLayerNeedsLayout:(CALayer *)layer
{
	DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:layer.description eventDescription:@"Layer Layout"];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)trackLayerNeedsDisplay:(CALayer *)layer
{
	DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:layer.description eventDescription:@"Layer Display"];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[sr endTracking];
	});
}

- (void)trackViewControllerWillAppear:(UIViewController *)vc
{
	if(vc.transitionCoordinator)
	{
		DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:vc.description eventDescription:@"Controller View Will Appear"];
		
		[vc.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[sr endTracking];
		}];
	}
}

- (void)trackViewControllerWillDisappear:(UIViewController *)vc
{
	if(vc.transitionCoordinator)
	{
		DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:vc.description eventDescription:@"Controller View Will Disappear"];
		
		[vc.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[sr endTracking];
		}];
	}
}

@end
