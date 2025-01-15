//
//  DTXSignpostSyncResource.h (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2025.
//

#import "DTXSyncResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTXSignpostSyncResource : DTXSyncResource

@property (class, nonatomic, strong, readonly) DTXSignpostSyncResource* sharedInstance;

- (void)trackSignpostStart:(NSNumber*)sid description:(NSString*)description;
- (void)trackSignpostEnd:(NSNumber*)sid;

@end

NS_ASSUME_NONNULL_END
