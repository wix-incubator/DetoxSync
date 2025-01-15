//
//  DTXSignpostSyncResource.m (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2025.
//


#import "DTXSignpostSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"

@interface DTXSignpostSyncResource ()

- (NSUInteger)_totalCount;

@end

@implementation DTXSignpostSyncResource
{
    NSMutableDictionary<NSNumber*, NSString*>* _activeSignposts;
}

+ (DTXSignpostSyncResource*)sharedInstance
{
    static DTXSignpostSyncResource* shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [DTXSignpostSyncResource new];
        [DTXSyncManager registerSyncResource:shared];
    });

    return shared;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _activeSignposts = [NSMutableDictionary new];
    }
    return self;
}

- (void)trackSignpostStart:(NSNumber*)sid description:(NSString*)description
{
    [self performUpdateBlock:^{
        self->_activeSignposts[sid] = description;
        return [self _totalCount];
    }
             eventIdentifier:_DTXStringReturningBlock([sid stringValue])
            eventDescription:_DTXStringReturningBlock(self.resourceName)
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Signpost Timer: %@", description])
       additionalDescription:nil];
}

- (void)trackSignpostEnd:(NSNumber*)sid
{
    [self performUpdateBlock:^{
        [self->_activeSignposts removeObjectForKey:sid];
        return [self _totalCount];
    }
             eventIdentifier:_DTXStringReturningBlock([sid stringValue])
            eventDescription:_DTXStringReturningBlock(self.resourceName)
           objectDescription:_DTXStringReturningBlock(@"Signpost Timer End")
       additionalDescription:nil];
}

- (NSUInteger)_totalCount
{
    return _activeSignposts.count;
}

- (NSDictionary<NSString*, NSNumber*>*)resourceDescription
{
    return @{
        @"active_signposts_count": @(_activeSignposts.count)
    };
}

- (DTXBusyResource*)jsonDescription
{
    return @{
        NSString.dtx_resourceNameKey: @"signpost_timers",
        NSString.dtx_resourceDescriptionKey: [self resourceDescription]
    };
}

@end
