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
{
	NSUInteger _viewNeedsLayoutCount;
	NSUInteger _viewNeedsDisplayCount;
	NSUInteger _layerNeedsLayoutCount;
	NSUInteger _layerNeedsDisplayCount;
	NSUInteger _viewControllerWillAppearCount;
	NSUInteger _viewControllerWillDisappearCount;
}

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

- (NSUInteger)_totalCount
{
	return _viewNeedsLayoutCount + _viewNeedsDisplayCount + _layerNeedsLayoutCount + _layerNeedsDisplayCount + _viewControllerWillAppearCount + _viewControllerWillDisappearCount;
}

NSString* _DTXPluralIfNeeded(NSString* word, NSUInteger count)
{
	return [NSString stringWithFormat:@"%lu %@%@", count, word, count == 1 ? @"" : @"s"];
}

- (NSString *)syncResourceDescription
{
	NSMutableArray<NSString*>* rvTexts = [NSMutableArray new];
	
	if(_viewNeedsLayoutCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting layout", _DTXPluralIfNeeded(@"view", _viewNeedsLayoutCount)]];
	}
	
	if(_viewNeedsDisplayCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting display", _DTXPluralIfNeeded(@"view", _viewNeedsDisplayCount)]];
	}
	
	if(_layerNeedsLayoutCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting layout", _DTXPluralIfNeeded(@"layer", _layerNeedsLayoutCount)]];
	}
	
	if(_layerNeedsDisplayCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting display", _DTXPluralIfNeeded(@"layer", _layerNeedsDisplayCount)]];
	}
	
	if(_viewControllerWillAppearCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting appearance", _DTXPluralIfNeeded(@"view controller", _viewControllerWillAppearCount)]];
	}
	
	if(_viewControllerWillDisappearCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting disappearance", _DTXPluralIfNeeded(@"view controller", _viewControllerWillDisappearCount)]];
	}
	
	if(rvTexts.count == 0)
	{
		return @"-";
	}
	
	return [rvTexts componentsJoinedByString:@"\n⏱ "];
}

- (NSString *)syncResourceGenericDescription
{
	return @"UI Elements";
}

- (void)_trackForParam:(NSUInteger*)param eventIdentifier:(NSString*)eventIdentifier eventDescription:(NSString*(^)(void))eventDescription objectDescription:(NSString*(^)(void))objectDescription
{
	[self performUpdateBlock:^NSUInteger{
		(*param)++;
		return self._totalCount;
	} eventIdentifier:eventIdentifier eventDescription:eventDescription objectDescription:objectDescription additionalDescription:nil];
}

- (void)_untrackForParam:(NSUInteger*)param eventIdentifier:(NSString*)eventIdentifier eventDescription:(NSString*(^)(void))eventDescription objectDescription:(NSString*(^)(void))objectDescription
{
	[self performUpdateBlock:^NSUInteger{
		(*param)--;
		return self._totalCount;
	} eventIdentifier:eventIdentifier eventDescription:eventDescription objectDescription:objectDescription additionalDescription:nil];
}

- (void)trackViewNeedsLayout:(UIView *)view
{
	NSString* identifier = NSUUID.UUID.UUIDString;
	
	[self _trackForParam:&_viewNeedsLayoutCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"View Layout") objectDescription:_DTXStringReturningBlock(view.__detox_sync_safeDescription)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_viewNeedsLayoutCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"View Layout") objectDescription:_DTXStringReturningBlock(view.__detox_sync_safeDescription)];
	});
}

- (void)trackViewNeedsDisplay:(UIView *)view
{
	NSString* identifier = NSUUID.UUID.UUIDString;
	
	[self _trackForParam:&_viewNeedsDisplayCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"View Display") objectDescription:_DTXStringReturningBlock(view.__detox_sync_safeDescription)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_viewNeedsDisplayCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"View Display") objectDescription:_DTXStringReturningBlock(view.__detox_sync_safeDescription)];
	});
}

- (void)trackLayerNeedsLayout:(CALayer *)layer
{
	NSString* identifier = NSUUID.UUID.UUIDString;
	
	[self _trackForParam:&_layerNeedsLayoutCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"Layer Layout") objectDescription:_DTXStringReturningBlock(layer.description)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_layerNeedsLayoutCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"Layer Layout") objectDescription:_DTXStringReturningBlock(layer.description)];
	});
}

- (void)trackLayerNeedsDisplay:(CALayer *)layer
{
	NSString* identifier = NSUUID.UUID.UUIDString;
	
	[self _trackForParam:&_layerNeedsDisplayCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"Layer Display") objectDescription:_DTXStringReturningBlock(layer.description)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_layerNeedsDisplayCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"Layer Display") objectDescription:_DTXStringReturningBlock(layer.description)];
	});
}

- (void)trackViewControllerWillAppear:(UIViewController *)vc
{
	if(vc.transitionCoordinator)
	{
		NSString* identifier = NSUUID.UUID.UUIDString;
		
		[self _trackForParam:&_viewControllerWillAppearCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"View Layout") objectDescription:_DTXStringReturningBlock(vc.description)];
		
		[vc.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[self _untrackForParam:&_viewControllerWillAppearCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"Controller View Will Appear") objectDescription:_DTXStringReturningBlock(vc.description)];
		}];
	}
}

- (void)trackViewControllerWillDisappear:(UIViewController *)vc
{
	if(vc.transitionCoordinator)
	{
		NSString* identifier = NSUUID.UUID.UUIDString;
		
		[self _trackForParam:&_viewControllerWillDisappearCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"View Layout") objectDescription:_DTXStringReturningBlock(vc.description)];
		
		[vc.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[self _untrackForParam:&_viewControllerWillDisappearCount eventIdentifier:identifier eventDescription:_DTXStringReturningBlock(@"Controller View Will Disappear") objectDescription:_DTXStringReturningBlock(vc.description)];
		}];
	}
}

@end
