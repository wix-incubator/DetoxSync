//
//  DTXAnimationUpdateSyncResource.m (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2025.
//

#import "DTXAnimationUpdateSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"

@implementation DTXAnimationUpdateSyncResource {
    NSUInteger _busyCount;
}

+ (DTXAnimationUpdateSyncResource*)sharedInstance {
    static DTXAnimationUpdateSyncResource* shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [DTXAnimationUpdateSyncResource new];
        [DTXSyncManager registerSyncResource:shared];
    });

    return shared;
}

- (void)trackNodeNeedsUpdate:(id)node {
    [self performUpdateBlock:^NSUInteger{
        _busyCount++;
        return _busyCount;
    } eventIdentifier:_DTXStringReturningBlock(NSUUID.UUID.UUIDString)
            eventDescription:_DTXStringReturningBlock(@"Animation Update Started")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
       additionalDescription:nil];
}

- (void)trackNodePerformedUpdate:(id)node {
    [self performUpdateBlock:^NSUInteger{
        _busyCount = MAX(0, _busyCount - 1);
        return _busyCount;
    } eventIdentifier:_DTXStringReturningBlock(NSUUID.UUID.UUIDString)
            eventDescription:_DTXStringReturningBlock(@"Animation Update Completed")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
       additionalDescription:nil];
}

- (DTXBusyResource*)jsonDescription {
    return @{
        NSString.dtx_resourceNameKey: @"animation_updates",
        NSString.dtx_resourceDescriptionKey: @{
            @"pending_updates": @(_busyCount)
        }
    };
}

@end
