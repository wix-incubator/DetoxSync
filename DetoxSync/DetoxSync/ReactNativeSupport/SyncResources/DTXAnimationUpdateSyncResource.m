//
//  DTXAnimationUpdateSyncResource.m
//  DetoxSync
//

#import "DTXAnimationUpdateSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"

DTX_CREATE_LOG(DTXAnimationUpdateSyncResource);

// Timeout for considering an animation as recurring / too-long (in seconds)
static const NSTimeInterval kNodeAnimationTimeout = 1.5;

@implementation DTXAnimationUpdateSyncResource {
    NSHashTable<id>* _pendingNodes;
    NSMapTable<id, NSNumber*>* _entryTimes;
    NSMapTable<id, dispatch_source_t>* _cleanupTimers;
    NSHashTable<id>* _recentlyDetachedNodes;
    dispatch_queue_t _cleanupQueue;
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

- (instancetype)init {
    self = [super init];
    if (self) {
        _pendingNodes = [NSHashTable weakObjectsHashTable];
        _entryTimes = [NSMapTable weakToStrongObjectsMapTable];
        _cleanupTimers = [NSMapTable weakToStrongObjectsMapTable];
        _recentlyDetachedNodes = [NSHashTable weakObjectsHashTable];
        _cleanupQueue = dispatch_queue_create("com.detox.sync.animation.cleanup", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)_removeNodeFromPending:(id)node reason:(NSString*)reason {
    if ([_pendingNodes containsObject:node]) {
        // Cancel the associated timer
        dispatch_source_t timer = [_cleanupTimers objectForKey:node];
        if (timer) {
            dispatch_source_cancel(timer);
            [_cleanupTimers removeObjectForKey:node];
        }

        [_pendingNodes removeObject:node];
        [_entryTimes removeObjectForKey:node];
        dtx_log_info(@"[AnimationUpdateSyncResource] Removed node <%@: %p> from pending due to %@: %@",
                     [node class], node, reason, node);
    }
}

- (void)_scheduleCleanupForNode:(id)node {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kNodeAnimationTimeout * NSEC_PER_SEC)),
                              DISPATCH_TIME_FOREVER,
                              (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        if ([self->_pendingNodes containsObject:node]) {
            dtx_log_info(@"[AnimationUpdateSyncResource] Ignoring node <%@: %p> due to timeout (likely recurring animation): %@",
                         [node class], node, node);
            [self->_pendingNodes removeObject:node];
            [self->_entryTimes removeObjectForKey:node];
            [self->_cleanupTimers removeObjectForKey:node];

            [self performUpdateBlock:^NSUInteger{
                return self->_pendingNodes.count;
            } eventIdentifier:_DTXStringReturningBlock([NSUUID UUID].UUIDString)
                    eventDescription:_DTXStringReturningBlock(@"Node Timed Out")
                   objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
               additionalDescription:nil];
        }
    });
    [_cleanupTimers setObject:timer forKey:node];
    dispatch_resume(timer);
}

- (void)trackNodeNeedsUpdate:(nullable id)node {
    if (node == nil) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Attempted to track nil node for update, ignoring");
        return;
    }

    if ([_recentlyDetachedNodes containsObject:node]) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Ignoring update for recently detached node <%@: %p>",
                     [node class], node);
        return;
    }

    NSMapTable* parentNodes = [node valueForKey:@"_parentNodes"];
    BOOL hasParents = parentNodes && parentNodes.count > 0;

    if ([_pendingNodes containsObject:node] && !hasParents) {
        [self _removeNodeFromPending:node reason:@"no parents"];
        [_recentlyDetachedNodes addObject:node];

        dispatch_async(_cleanupQueue, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self->_recentlyDetachedNodes removeObject:node];
                dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> cleared from recently detached set",
                             [node class], node);
            });
        });

        [self performUpdateBlock:^NSUInteger{
            return self->_pendingNodes.count;
        } eventIdentifier:_DTXStringReturningBlock([NSUUID UUID].UUIDString)
                eventDescription:_DTXStringReturningBlock(@"Node Removed Due to No Parents")
               objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
           additionalDescription:nil];
        return;
    }

    if (!hasParents) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> has no parents, not tracking update",
                     [node class], node);
        return;
    }

    if (![_pendingNodes containsObject:node]) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> needs update", [node class], node);
        [_pendingNodes addObject:node];
        [_entryTimes setObject:@(CFAbsoluteTimeGetCurrent()) forKey:node];
        [self _scheduleCleanupForNode:node];

        [self performUpdateBlock:^NSUInteger{
            return self->_pendingNodes.count;
        } eventIdentifier:_DTXStringReturningBlock([NSUUID UUID].UUIDString)
                eventDescription:_DTXStringReturningBlock(@"Animation Update Started")
               objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
           additionalDescription:nil];
    }
}

- (void)trackNodePerformedUpdate:(nullable id)node {
    if (node == nil) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Attempted to track nil node for performed update, ignoring");
        return;
    }

    dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> performed update", [node class], node);
    [self _removeNodeFromPending:node reason:@"update performed"];

    [self performUpdateBlock:^NSUInteger{
        return self->_pendingNodes.count;
    } eventIdentifier:_DTXStringReturningBlock([NSUUID UUID].UUIDString)
            eventDescription:_DTXStringReturningBlock(@"Animation Update Completed")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
       additionalDescription:nil];
}

- (void)trackNodeDetachedFromParent:(nullable id)node parent:(nullable id)parent {
    if (node == nil) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Attempted to track detachment of nil node, ignoring");
        return;
    }

    dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> detaching from parent <%@: %p>",
                 [node class], node, [parent class], parent);

    NSMapTable* parentNodes = [node valueForKey:@"_parentNodes"];
    if (!parentNodes || parentNodes.count == 0) {
        [self _removeNodeFromPending:node reason:@"no remaining parents"];
        [_recentlyDetachedNodes addObject:node];

        dispatch_async(_cleanupQueue, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self->_recentlyDetachedNodes removeObject:node];
                dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> cleared from recently detached set",
                             [node class], node);
            });
        });

        [self performUpdateBlock:^NSUInteger{
            return self->_pendingNodes.count;
        } eventIdentifier:_DTXStringReturningBlock([NSUUID UUID].UUIDString)
                eventDescription:_DTXStringReturningBlock(@"Node Fully Detached")
               objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
           additionalDescription:nil];
    } else {
        dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> still has %lu parents, keeping in tracking",
                     [node class], node, (unsigned long)parentNodes.count);
    }
}

- (NSUInteger)_busyCount {
    NSUInteger count = _pendingNodes.count;
    dtx_log_info(@"[AnimationUpdateSyncResource] busyCount: %lu", (unsigned long)count);
    return count;
}

- (NSString*)syncResourceDescription {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    NSMutableArray<NSString*>* descriptions = [NSMutableArray new];
    for (id node in _pendingNodes) {
        NSMapTable* parentNodes = [node valueForKey:@"_parentNodes"];
        NSMapTable* childNodes = [node valueForKey:@"_childNodes"];
        NSNumber* entryTime = [_entryTimes objectForKey:node];
        NSTimeInterval elapsed = entryTime ? (now - entryTime.doubleValue) : 0;
        [descriptions addObject:[NSString stringWithFormat:@"Node <%@: %p> (pending update) [parents: %lu, children: %lu, elapsed: %.2fs]",
                                 [node class],
                                 node,
                                 (unsigned long)(parentNodes ? parentNodes.count : 0),
                                 (unsigned long)(childNodes ? childNodes.count : 0),
                                 elapsed]];
    }
    return [descriptions componentsJoinedByString:@"\n"];
}

- (DTXBusyResource*)jsonDescription {
    return @{
        NSString.dtx_resourceNameKey: @"animation_updates",
        NSString.dtx_resourceDescriptionKey: @{
            @"pending_updates": @(_pendingNodes.count)
        }
    };
}

- (void)dealloc {
    for (dispatch_source_t timer in [_cleanupTimers objectEnumerator]) {
        dispatch_source_cancel(timer);
    }
    [_cleanupTimers removeAllObjects];
}

@end
