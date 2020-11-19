//
//  DTXUISyncResource.h
//  DetoxSync
//
//  Created by Leo Natan on 11/19/20.
//  Copyright © 2020 wix. All rights reserved.
//

#import "DTXSyncResource.h"
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface DTXUISyncResource : DTXSyncResource

@property (class, nonatomic, strong, readonly) DTXUISyncResource* sharedInstance;

- (void)trackViewNeedsDisplay:(UIView*)view;
- (void)trackViewNeedsLayout:(UIView*)view;

- (void)trackLayerNeedsDisplay:(CALayer*)layer;
- (void)trackLayerNeedsLayout:(CALayer*)layer;

- (void)trackViewControllerWillAppear:(UIViewController*)vc;
- (void)trackViewControllerWillDisappear:(UIViewController*)vc;

@end

NS_ASSUME_NONNULL_END
