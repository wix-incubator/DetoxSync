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
#import "NSString+SyncResource.h"

static const void* _DTXCAAnimationTrackingIdentifierKey = &_DTXCAAnimationTrackingIdentifierKey;

@interface UIView ()

- (NSString*)__detox_sync_safeDescription;

@end

@implementation DTXUISyncResource
{
	NSUInteger _viewNeedsLayoutCount;
	NSUInteger _viewNeedsDisplayCount;
	NSUInteger _layerNeedsLayoutCount;
	NSUInteger _layerNeedsDisplayCount;
	NSUInteger _layerPendingAnimationCount;
	NSUInteger _viewControllerWillAppearCount;
	NSUInteger _viewControllerWillDisappearCount;
	NSUInteger _viewAnimationCount;
	NSUInteger _layerAnimationCount;
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
	return _viewNeedsLayoutCount + _viewNeedsDisplayCount + _layerNeedsLayoutCount + _layerNeedsDisplayCount + _layerPendingAnimationCount + _viewControllerWillAppearCount + _viewControllerWillDisappearCount + _viewAnimationCount + _layerAnimationCount;
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
	
	if(_layerPendingAnimationCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ pending animation", _DTXPluralIfNeeded(@"layer", _layerPendingAnimationCount)]];
	}
	
	if(_viewControllerWillAppearCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting appearance", _DTXPluralIfNeeded(@"view controller", _viewControllerWillAppearCount)]];
	}
	
	if(_viewControllerWillDisappearCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ awaiting disappearance", _DTXPluralIfNeeded(@"view controller", _viewControllerWillDisappearCount)]];
	}
	
	if(_viewAnimationCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ pending", _DTXPluralIfNeeded(@"view animation", _viewAnimationCount)]];
	}
	
	if(_layerAnimationCount > 0)
	{
		[rvTexts addObject:[NSString stringWithFormat:@"%@ pending", _DTXPluralIfNeeded(@"CA animation", _layerAnimationCount)]];
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

- (NSDictionary<NSString *, id> *)jsonDescription {
  NSDictionary<NSString *, NSNumber *> *rawDescription = [@{
    // Awaiting layout:
    @"view_needs_layout_count": @(_viewNeedsLayoutCount),
    @"layer_needs_layout_count": @(_layerNeedsLayoutCount),

    // Awaiting display:
    @"view_needs_display_count": @(_viewNeedsDisplayCount),
    @"layer_needs_display_count": @(_layerNeedsDisplayCount),

    // Pending animations:
    @"layer_pending_animation_count": @(_layerPendingAnimationCount),

    // Animations pending:
    @"view_animation_pending_count": @(_viewAnimationCount),
    @"layer_animation_pending_count": @(_layerAnimationCount),

    // View controllers appearance:
    @"view_controller_will_appear_count": @(_viewControllerWillAppearCount),
    @"view_controller_will_disappear_count": @(_viewControllerWillDisappearCount)
  } mutableCopy];

  auto resourceDescription = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
  for (NSString *key in rawDescription) {
    auto countValue = rawDescription[key];

    if (countValue.boolValue) {
      resourceDescription[key] = countValue;
    }
  }

  return @{
    NSString.dtx_resourceNameKey: @"ui",
    NSString.dtx_resourceDescriptionKey: resourceDescription
  };
}

- (nullable NSString*)_trackForParam:(NSUInteger*)param eventDescription:(NSString*(NS_NOESCAPE ^)(void))eventDescription objectDescription:(NSString*(NS_NOESCAPE ^)(void))objectDescription
{
	__block NSString* identifier = nil;
	
	[self performUpdateBlock:^NSUInteger{
		(*param)++;
		return self._totalCount;
	} eventIdentifier:^ {
		identifier = NSUUID.UUID.UUIDString;
		return identifier;
	} eventDescription:eventDescription objectDescription:objectDescription additionalDescription:nil];
	
	return identifier;
}

- (void)_untrackForParam:(NSUInteger*)param eventIdentifier:(NSString*(NS_NOESCAPE ^)(void))eventIdentifier
{
	[self performUpdateBlock:^NSUInteger{
		(*param)--;
		return self._totalCount;
	} eventIdentifier:eventIdentifier eventDescription:nil objectDescription:nil additionalDescription:nil];
}

- (void)trackViewNeedsLayout:(UIView *)view
{
	NSString* identifier = [self _trackForParam:&_viewNeedsLayoutCount eventDescription:_DTXStringReturningBlock(@"View Layout") objectDescription:_DTXStringReturningBlock(view.__detox_sync_safeDescription)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_viewNeedsLayoutCount eventIdentifier:_DTXStringReturningBlock(identifier)];
	});
}

- (void)trackViewNeedsDisplay:(UIView *)view
{
	NSString* identifier = [self _trackForParam:&_viewNeedsDisplayCount eventDescription:_DTXStringReturningBlock(@"View Display") objectDescription:_DTXStringReturningBlock(view.__detox_sync_safeDescription)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_viewNeedsDisplayCount eventIdentifier:_DTXStringReturningBlock(identifier)];
	});
}

- (void)trackLayerNeedsLayout:(CALayer *)layer
{
	NSString* identifier = [self _trackForParam:&_layerNeedsLayoutCount eventDescription:_DTXStringReturningBlock(@"Layer Layout") objectDescription:_DTXStringReturningBlock(layer.description)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_layerNeedsLayoutCount eventIdentifier:_DTXStringReturningBlock(identifier)];
	});
}

- (void)trackLayerNeedsDisplay:(CALayer *)layer
{
	NSString* identifier = [self _trackForParam:&_layerNeedsDisplayCount eventDescription:_DTXStringReturningBlock(@"Layer Display") objectDescription:_DTXStringReturningBlock(layer.description)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_layerNeedsDisplayCount eventIdentifier:_DTXStringReturningBlock(identifier)];
	});
}

- (void)trackLayerPendingAnimation:(CALayer*)layer
{
	NSString* identifier = [self _trackForParam:&_layerPendingAnimationCount eventDescription:_DTXStringReturningBlock(@"Layer Pending Animation") objectDescription:_DTXStringReturningBlock(layer.description)];
	
	__detox_sync_orig_dispatch_async(dispatch_get_main_queue(), ^ {
		[self _untrackForParam:&_layerPendingAnimationCount eventIdentifier:_DTXStringReturningBlock(identifier)];
	});
}

- (void)trackViewControllerWillAppear:(UIViewController *)vc
{
	if(vc.transitionCoordinator)
	{
		NSString* identifier = [self _trackForParam:&_viewControllerWillAppearCount eventDescription:_DTXStringReturningBlock(@"View Layout") objectDescription:_DTXStringReturningBlock(vc.description)];
		
		[vc.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[self _untrackForParam:&_viewControllerWillAppearCount eventIdentifier:_DTXStringReturningBlock(identifier)];
		}];
	}
}

- (void)trackViewControllerWillDisappear:(UIViewController *)vc
{
	if(vc.transitionCoordinator)
	{
		NSString* identifier = [self _trackForParam:&_viewControllerWillDisappearCount eventDescription:_DTXStringReturningBlock(@"View Layout") objectDescription:_DTXStringReturningBlock(vc.description)];
		
		[vc.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
			[self _untrackForParam:&_viewControllerWillDisappearCount eventIdentifier:_DTXStringReturningBlock(identifier)];
		}];
	}
}

- (nullable NSString*)trackViewAnimationWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
{
	return [self _trackForParam:&_viewAnimationCount eventDescription:_DTXStringReturningBlock(@"Animation") objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"UIView animation with duration: “%@” delay: “%@”", @(duration), @(delay)])];
}

- (void)untrackViewAnimation:(NSString*)identifier
{
	[self _untrackForParam:&_viewAnimationCount eventIdentifier:_DTXStringReturningBlock(identifier)];
}

- (void)trackCAAnimation:(CAAnimation*)animation
{
	NSString* identifier = [self _trackForParam:&_layerAnimationCount eventDescription:_DTXStringReturningBlock(@"Animation") objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"%@ with duration: “%@” delay: “%@”", animation.class, @(animation.duration), @(animation.beginTime)])];
	
	objc_setAssociatedObject(animation, _DTXCAAnimationTrackingIdentifierKey, identifier, OBJC_ASSOCIATION_RETAIN);
}

- (void)untrackCAAnimation:(CAAnimation *)animation
{
	NSString* identifier = objc_getAssociatedObject(animation, _DTXCAAnimationTrackingIdentifierKey);
	[self _untrackForParam:&_layerAnimationCount eventIdentifier:_DTXStringReturningBlock(identifier)];
	
	objc_setAssociatedObject(animation, _DTXCAAnimationTrackingIdentifierKey, nil, OBJC_ASSOCIATION_RETAIN);
}

@end
