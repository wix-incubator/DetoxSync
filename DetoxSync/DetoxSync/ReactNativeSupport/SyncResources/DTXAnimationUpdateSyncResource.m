//
//  DTXAnimationUpdateSyncResource.m
//  DetoxSync
//

#import "DTXAnimationUpdateSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"

DTX_CREATE_LOG(DTXAnimationUpdateSyncResource);

// Timeout for considering an animation as too long (in seconds)
static const NSTimeInterval kNodeAnimationTimeout = 1.5;

@implementation DTXAnimationUpdateSyncResource {
    NSHashTable<id>* _pendingNodes;
    NSMapTable<id, dispatch_source_t>* _cleanupTimers;
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
        _cleanupTimers = [NSMapTable weakToStrongObjectsMapTable];
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
        dtx_log_info(@"[AnimationUpdateSyncResource] Removed node <%@: %p> from pending due to %@: %@",
                     [node class], node, reason, node);
    }
}

- (void)_scheduleCleanupForNode:(id)node {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kNodeAnimationTimeout * NSEC_PER_SEC)),
                              DISPATCH_TIME_FOREVER, // One-shot timer
                              (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        if ([self->_pendingNodes containsObject:node]) {
            dtx_log_info(@"[AnimationUpdateSyncResource] Ignoring node <%@: %p> due to timeout: %@",
                         [node class], node, node);
            [self->_pendingNodes removeObject:node];
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
        return;
    }

    // Only track RCTStyleAnimatedNode and RCTPropsAnimatedNode
    Class styleNodeClass = NSClassFromString(@"RCTStyleAnimatedNode");
    Class propsNodeClass = NSClassFromString(@"RCTPropsAnimatedNode");
    if (![node isKindOfClass:styleNodeClass] && ![node isKindOfClass:propsNodeClass]) {
        return;
    }

    NSMapTable* parentNodes = [node valueForKey:@"_parentNodes"];
    BOOL hasParents = parentNodes && parentNodes.count > 0;

    if (!hasParents) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> has no parents, not tracking", [node class], node);
        return;
    }

    // If node is already pending, reset its timer
    if ([_pendingNodes containsObject:node]) {
        dispatch_source_t existingTimer = [_cleanupTimers objectForKey:node];
        if (existingTimer) {
            dispatch_source_cancel(existingTimer);
            [_cleanupTimers removeObjectForKey:node];
            dtx_log_info(@"[AnimationUpdateSyncResource] Revoked existing timer for node <%@: %p>", [node class], node);
        }
        [self _scheduleCleanupForNode:node];
        dtx_log_info(@"[AnimationUpdateSyncResource] Reset timeout for node <%@: %p>", [node class], node);
    } else {
        // Add new node
        dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> needs update", [node class], node);
        [_pendingNodes addObject:node];
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
        return;
    }

    dtx_log_info(@"[AnimationUpdateSyncResource] Node <%@: %p> detaching from parent <%@: %p>",
                 [node class], node, [parent class], parent);

    NSMapTable* parentNodes = [node valueForKey:@"_parentNodes"];
    if (!parentNodes || parentNodes.count == 0) {
        [self _removeNodeFromPending:node reason:@"no remaining parents"];
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
    NSMutableArray<NSString*>* descriptions = [NSMutableArray new];
    for (id node in _pendingNodes) {
        NSMapTable* parentNodes = [node valueForKey:@"_parentNodes"];
        NSMapTable* childNodes = [node valueForKey:@"_childNodes"];
        [descriptions addObject:[NSString stringWithFormat:@"Node <%@: %p> (pending update) [parents: %lu, children: %lu]",
                                 [node class],
                                 node,
                                 (unsigned long)(parentNodes ? parentNodes.count : 0),
                                 (unsigned long)(childNodes ? childNodes.count : 0)]];
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
