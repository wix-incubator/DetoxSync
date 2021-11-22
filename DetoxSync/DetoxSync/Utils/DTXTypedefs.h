//
//  DTXTypedefs.h
//  DetoxSync
//
//  Created by asaf korem on 21/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

/// Type of busy sync resource.
typedef NSDictionary<NSString *, id> DTXBusyResource;

/// Type of busy-resources array.
typedef NSArray<DTXBusyResource *> DTXBusyResources;

/// Type of synchronization status result.
typedef NSDictionary<NSString *, id> DTXSyncStatus;

NS_ASSUME_NONNULL_END
