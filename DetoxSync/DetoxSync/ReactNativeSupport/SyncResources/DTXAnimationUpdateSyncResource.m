//
//  DTXAnimationUpdateSyncResource.m
//  DetoxSync
//

#import "DTXAnimationUpdateSyncResource.h"
#import "DTXSyncManager-Private.h"
#import "NSString+SyncResource.h"
#import "NSArray+Functional.h"

DTX_CREATE_LOG(DTXAnimationUpdateSyncResource);

@interface PendingAnimationNode : NSObject

@property (nonatomic, weak) id node;
@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, assign) BOOL isDetaching;
@property (nonatomic, strong) NSMutableSet* detachingChildren;
@property (nonatomic, strong) NSMutableSet* detachingParents;

- (instancetype)initWithNode:(id)node;

@end

@implementation PendingAnimationNode

- (instancetype)initWithNode:(id)node {
    if ((self = [super init])) {
        _node = node;
        _identifier = [NSUUID UUID].UUIDString;
        _isDetaching = NO;
        _detachingChildren = [NSMutableSet new];
        _detachingParents = [NSMutableSet new];
    }
    return self;
}

@end

@implementation DTXAnimationUpdateSyncResource {
    NSMutableArray<PendingAnimationNode*>* _pendingNodes;
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

- (instancetype)init {
    self = [super init];
    if (self) {
        _pendingNodes = [NSMutableArray new];
        _busyCount = 0;
    }
    return self;
}

- (void)_removeNodeFromTracking:(id)node {
    dtx_log_info(@"[AnimationUpdateSyncResource] Removing node %@ from tracking", node);

    // Simple removal from pending nodes
    _pendingNodes = [[_pendingNodes filter:^BOOL(PendingAnimationNode* pendingNode) {
        return pendingNode.node != node;
    }] mutableCopy];

    // Update busy count since we modified the list
    _busyCount = _pendingNodes.count;
}

- (void)_cleanupDetachedNodes {
    NSMutableArray* nodesToRemove = [NSMutableArray new];

    // First identify all nodes that need removal
    for (PendingAnimationNode* pendingNode in _pendingNodes) {
        if (!pendingNode.node) {
            dtx_log_info(@"[AnimationUpdateSyncResource] Found deallocated node to remove");
            [nodesToRemove addObject:pendingNode];
            continue;
        }

        if (pendingNode.isDetaching) {
            NSMapTable* parentNodes = [pendingNode.node valueForKey:@"_parentNodes"];
            NSMapTable* childNodes = [pendingNode.node valueForKey:@"_childNodes"];

            if ((!parentNodes || parentNodes.count == 0) && (!childNodes || childNodes.count == 0)) {
                dtx_log_info(@"[AnimationUpdateSyncResource] Found fully detached node to remove: %@", pendingNode.node);
                [nodesToRemove addObject:pendingNode];
            }
        }
    }

    // Then remove them if any were found
    if (nodesToRemove.count > 0) {
        NSSet* nodesToRemoveSet = [NSSet setWithArray:[nodesToRemove valueForKey:@"node"]];

        _pendingNodes = [[_pendingNodes filter:^BOOL(PendingAnimationNode* pendingNode) {
            return ![nodesToRemoveSet containsObject:pendingNode.node];
        }] mutableCopy];

        _busyCount = _pendingNodes.count;

        dtx_log_info(@"[AnimationUpdateSyncResource] Cleaned up %lu nodes, new busy count: %lu",
                     (unsigned long)nodesToRemove.count, (unsigned long)_busyCount);
    }
}

- (void)_handleChildRemoval:(id)childNode {
    dtx_log_info(@"[AnimationUpdateSyncResource] Handling removal of child node %@", childNode);

    // Remove the child node if we're tracking it
    [self _removeNodeFromTracking:childNode];

    // Get its children using KVC
    NSMapTable* childNodes = [childNode valueForKey:@"_childNodes"];
    if (!childNodes) {
        return;
    }

    // Remove each child that we're tracking
    NSArray* children = childNodes.objectEnumerator.allObjects;
    dtx_log_info(@"[AnimationUpdateSyncResource] Found %lu child nodes to clean up", (unsigned long)children.count);

    for (id child in children) {
        [self _removeNodeFromTracking:child];
    }
}

- (PendingAnimationNode*)_findOrCreatePendingNodeForNode:(id)node createIfNeeded:(BOOL)createIfNeeded {
    dtx_log_info(@"[AnimationUpdateSyncResource] Looking for node %@ in pending nodes (createIfNeeded: %@)",
                 node, createIfNeeded ? @"YES" : @"NO");

    PendingAnimationNode* pendingNode = [[_pendingNodes filter:^BOOL(PendingAnimationNode* existing) {
        return existing.node == node;
    }] firstObject];

    if (!pendingNode && createIfNeeded) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Creating new pending node for %@", node);
        pendingNode = [[PendingAnimationNode alloc] initWithNode:node];
        [_pendingNodes addObject:pendingNode];
        _busyCount = _pendingNodes.count;
    } else if (pendingNode) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Found existing pending node for %@", node);
    } else {
        dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ not found and not creating new one", node);
    }

    return pendingNode;
}

- (void)trackNodeNeedsUpdate:(id)node {
    dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ needs update", node);
    PendingAnimationNode* pendingNode = [self _findOrCreatePendingNodeForNode:node createIfNeeded:YES];

    [self performUpdateBlock:^NSUInteger{
        [self _cleanupDetachedNodes];
        dtx_log_info(@"[AnimationUpdateSyncResource] Added node %@ to pending animations (busy count: %lu)",
                     node, (unsigned long)self->_busyCount);
        return self->_busyCount;
    } eventIdentifier:_DTXStringReturningBlock(pendingNode.identifier)
            eventDescription:_DTXStringReturningBlock(@"Animation Update Started")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
       additionalDescription:nil];
}

- (void)trackNodePerformedUpdate:(id)node {
    dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ performed update", node);

    PendingAnimationNode* pendingNode = [self _findOrCreatePendingNodeForNode:node createIfNeeded:NO];
    if (!pendingNode) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ not being tracked, ignoring update", node);
        return;
    }

    [self performUpdateBlock:^NSUInteger{
        if (!pendingNode.isDetaching) {
            [self _handleChildRemoval:node];
            [self _cleanupDetachedNodes];
        }
        return self->_busyCount;
    } eventIdentifier:_DTXStringReturningBlock(NSUUID.UUID.UUIDString)
            eventDescription:_DTXStringReturningBlock(@"Animation Update Completed")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
       additionalDescription:nil];
}

- (void)trackNodeRemovedChild:(id)node child:(id)child {
    dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ removing child %@", node, child);

    PendingAnimationNode* parentNode = [self _findOrCreatePendingNodeForNode:node createIfNeeded:NO];
    if (!parentNode) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Parent node %@ not being tracked, ignoring child removal", node);
        return;
    }

    [self performUpdateBlock:^NSUInteger{
        [parentNode.detachingChildren addObject:[NSValue valueWithNonretainedObject:child]];
        [self _handleChildRemoval:child];
        [self _cleanupDetachedNodes];

        NSMapTable* remainingChildren = [node valueForKey:@"_childNodes"];
        dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ removed child %@ (remaining children: %lu)",
                     node, child, (unsigned long)(remainingChildren ? remainingChildren.count : 0));

        return self->_busyCount;
    } eventIdentifier:_DTXStringReturningBlock(NSUUID.UUID.UUIDString)
            eventDescription:_DTXStringReturningBlock(@"Child Node Removed")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Parent <%@: %p>, Child <%@: %p>", [node class], node, [child class], child])
       additionalDescription:nil];
}

- (void)trackNodeDetached:(id)node {
    dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ detachment started", node);

    PendingAnimationNode* pendingNode = [self _findOrCreatePendingNodeForNode:node createIfNeeded:NO];
    if (!pendingNode) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ not being tracked, ignoring detachment", node);
        return;
    }

    [self performUpdateBlock:^NSUInteger{
        pendingNode.isDetaching = YES;
        [pendingNode.detachingChildren removeAllObjects];
        [pendingNode.detachingParents removeAllObjects];

        NSMapTable* parentNodes = [node valueForKey:@"_parentNodes"];
        NSMapTable* childNodes = [node valueForKey:@"_childNodes"];

        dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ detachment in progress (parents: %lu, children: %lu)",
                     node,
                     (unsigned long)(parentNodes ? parentNodes.count : 0),
                     (unsigned long)(childNodes ? childNodes.count : 0));

        [self _cleanupDetachedNodes];
        return self->_busyCount;
    } eventIdentifier:_DTXStringReturningBlock(NSUUID.UUID.UUIDString)
            eventDescription:_DTXStringReturningBlock(@"Node Detachment Started")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Node <%@: %p>", [node class], node])
       additionalDescription:nil];
}

- (void)trackNodeDetachedFromParent:(id)node parent:(id)parent {
    dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ detaching from parent %@", node, parent);

    PendingAnimationNode* childNode = [self _findOrCreatePendingNodeForNode:node createIfNeeded:NO];
    if (!childNode) {
        dtx_log_info(@"[AnimationUpdateSyncResource] Child node %@ not being tracked, ignoring parent detachment", node);
        return;
    }

    [self performUpdateBlock:^NSUInteger{
        [childNode.detachingParents addObject:[NSValue valueWithNonretainedObject:parent]];
        [self _cleanupDetachedNodes];

        NSMapTable* remainingParents = [node valueForKey:@"_parentNodes"];
        dtx_log_info(@"[AnimationUpdateSyncResource] Node %@ detached from parent %@ (remaining parents: %lu)",
                     node, parent, (unsigned long)(remainingParents ? remainingParents.count : 0));

        return self->_busyCount;
    } eventIdentifier:_DTXStringReturningBlock(NSUUID.UUID.UUIDString)
            eventDescription:_DTXStringReturningBlock(@"Node Detached From Parent")
           objectDescription:_DTXStringReturningBlock([NSString stringWithFormat:@"Child <%@: %p>, Parent <%@: %p>", [node class], node, [parent class], parent])
       additionalDescription:nil];
}

- (NSUInteger)_busyCount {
    unsigned long deallocatedNodes = [[_pendingNodes filter:^BOOL(PendingAnimationNode* node) {
        return node.node == nil;
    }] count];

    unsigned long allocatedNodes = [[_pendingNodes filter:^BOOL(PendingAnimationNode* node) {
        return node.node != nil;
    }] count];

    unsigned long currentlyDetachingNodes = [[_pendingNodes filter:^BOOL(PendingAnimationNode* node) {
        return node.node != nil && node.isDetaching;
    }] count];

    dtx_log_info(@"[AnimationUpdateSyncResource] busyCount: %lu, deallocatedNodes: %lu, allocatedNodes: %lu, currentlyDetachingNodes: %lu",
                 (unsigned long)self->_busyCount, deallocatedNodes, allocatedNodes, currentlyDetachingNodes);

    return _busyCount;
}

- (NSString*)syncResourceDescription {
    NSMutableArray<NSString*>* descriptions = [NSMutableArray new];
    for (PendingAnimationNode* pendingNode in _pendingNodes) {
        if (pendingNode.node) {
            NSString* status = pendingNode.isDetaching ? @"(detaching)" : @"(updating)";
            NSMapTable* parentNodes = [pendingNode.node valueForKey:@"_parentNodes"];
            NSMapTable* childNodes = [pendingNode.node valueForKey:@"_childNodes"];

            [descriptions addObject:[NSString stringWithFormat:@"Node <%@: %p> %@ [parents: %lu, children: %lu]",
                                     [pendingNode.node class],
                                     pendingNode.node,
                                     status,
                                     (unsigned long)(parentNodes ? parentNodes.count : 0),
                                     (unsigned long)(childNodes ? childNodes.count : 0)]];
        }
    }
    return [descriptions componentsJoinedByString:@"\n"];
}

- (DTXBusyResource*)jsonDescription {
    return @{
        NSString.dtx_resourceNameKey: @"animation_updates",
        NSString.dtx_resourceDescriptionKey: @{
            @"pending_updates": @(_busyCount),
            @"updating_nodes": @([[_pendingNodes filter:^BOOL(PendingAnimationNode* node) {
                return !node.isDetaching && node.node != nil;
            }] count]),
            @"detaching_nodes": @([[_pendingNodes filter:^BOOL(PendingAnimationNode* node) {
                return node.isDetaching && node.node != nil;
            }] count])
        }
    };
}

@end
