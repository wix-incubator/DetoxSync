//
//  DTXAnimationUpdateSyncResource.h (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2025.
//

#import "DTXSyncResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTXAnimationUpdateSyncResource : DTXSyncResource

@property (class, nonatomic, strong, readonly) DTXAnimationUpdateSyncResource* sharedInstance;

- (void)trackNodeNeedsUpdate:(id)node;
- (void)trackNodePerformedUpdate:(id)node;
- (void)trackNodeDetached:(id)node;
- (void)trackNodeRemovedChild:(id)node child:(id)child;
- (void)trackNodeDetachedFromParent:(id)node parent:(id)parent;

@end

NS_ASSUME_NONNULL_END
