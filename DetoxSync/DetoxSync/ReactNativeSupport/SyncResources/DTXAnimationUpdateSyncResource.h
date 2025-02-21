//
//  DTXAnimationUpdateSyncResource.h (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2025.
//

#import "DTXSyncResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTXAnimationUpdateSyncResource : DTXSyncResource

+ (instancetype)sharedInstance;

- (void)trackNodeNeedsUpdate:(nullable id)node;
- (void)trackNodePerformedUpdate:(nullable id)node;
- (void)trackNodeDetachedFromParent:(nullable id)node parent:(nullable id)parent;

@end

NS_ASSUME_NONNULL_END
