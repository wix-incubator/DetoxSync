//
//  CAAnimation+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "CAAnimation+DTXSpy.h"
#import "DTXUISyncResource.h"

@import ObjectiveC;

static const void* _DTXCAAnimationIsTrackingKey = &_DTXCAAnimationIsTrackingKey;
static const void* _DTXCAAnimationProxyKey = &_DTXCAAnimationProxyKey;

#pragma mark - Weak Reference Proxy

@interface _DTXAnimationDelegateProxy : NSProxy <CAAnimationDelegate>
@property (nonatomic, weak) id<CAAnimationDelegate> originalDelegate;
@property (nonatomic, strong) Class originalClass;
@end

@implementation _DTXAnimationDelegateProxy

- (instancetype)initWithDelegate:(id<CAAnimationDelegate>)delegate
{
    _originalDelegate = delegate;
    _originalClass = [delegate class];
    return self;
}

#pragma mark - CAAnimationDelegate methods (intercepted)

- (void)animationDidStart:(CAAnimation *)anim
{
    [anim __detox_sync_trackAnimation];
    
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:@selector(animationDidStart:)]) {
        [delegate animationDidStart:anim];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:@selector(animationDidStop:finished:)]) {
        [delegate animationDidStop:anim finished:flag];
    }
    
    [anim __detox_sync_untrackAnimation];
}

#pragma mark - Transparent proxy methods (mimic original delegate identity)

- (Class)class
{
    return self.originalClass ?: [super class];
}

- (BOOL)isKindOfClass:(Class)aClass
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [delegate isKindOfClass:aClass];
    }
    return self.originalClass ? [self.originalClass isSubclassOfClass:aClass] : NO;
}

- (BOOL)isMemberOfClass:(Class)aClass
{
    return self.originalClass == aClass;
}

- (BOOL)isEqual:(id)object
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [delegate isEqual:object];
    }
    return self == object;
}

- (NSUInteger)hash
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [delegate hash];
    }
    return (NSUInteger)self;
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [delegate conformsToProtocol:aProtocol];
    }
    return self.originalClass ? class_conformsToProtocol(self.originalClass, aProtocol) : NO;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if (aSelector == @selector(animationDidStart:) ||
        aSelector == @selector(animationDidStop:finished:)) {
        return YES;
    }
    
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [delegate respondsToSelector:aSelector];
    }
    return NO;
}

#pragma mark - NSProxy forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [(NSObject *)delegate methodSignatureForSelector:sel];
    }
    return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:delegate];
    }
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    // Don't forward the methods we intercept
    if (aSelector == @selector(animationDidStart:) ||
        aSelector == @selector(animationDidStop:finished:)) {
        return nil;
    }
    
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:aSelector]) {
        return delegate;
    }
    return nil;
}

- (NSString *)description
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [(NSObject *)delegate description];
    }
    NSString *className = self.originalClass ? NSStringFromClass(self.originalClass) : @"_DTXAnimationDelegateProxy";
    return [NSString stringWithFormat:@"<%@: %p (delegate deallocated)>", className, self];
}

- (NSString *)debugDescription
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate) {
        return [(NSObject *)delegate debugDescription];
    }
    return [self description];
}

@end

#pragma mark - CAAnimation Extension

@implementation CAAnimation (DTXSpy)

- (BOOL)__detox_sync_isTracking
{
    return [objc_getAssociatedObject(self, _DTXCAAnimationIsTrackingKey) boolValue];
}

- (void)__detox_sync_setTracking:(BOOL)tracking
{
    objc_setAssociatedObject(self, _DTXCAAnimationIsTrackingKey, @(tracking), OBJC_ASSOCIATION_RETAIN);
}

- (void)__detox_sync_trackAnimation
{
    [self __detox_sync_untrackAnimation];
    
    [DTXUISyncResource.sharedInstance trackCAAnimation:self];
    [self __detox_sync_setTracking:YES];
}

- (void)__detox_sync_untrackAnimation
{
    if(self.__detox_sync_isTracking == YES)
    {
        [DTXUISyncResource.sharedInstance untrackCAAnimation:self];
        [self __detox_sync_setTracking:NO];
    }
}

+ (void)load
{
    @autoreleasepool
    {
        DTXSwizzleMethod(CAAnimation.class, @selector(setDelegate:), @selector(__detox_sync_setDelegate:), NULL);
    }
}

- (void)__detox_sync_setDelegate:(id<CAAnimationDelegate>)delegate
{
    if (delegate == nil) {
        // Clear the proxy reference
        objc_setAssociatedObject(self, _DTXCAAnimationProxyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self __detox_sync_setDelegate:nil];
        return;
    }
    
    // Don't wrap if already a proxy
    if ([object_getClass(delegate) isSubclassOfClass:[_DTXAnimationDelegateProxy class]]) {
        [self __detox_sync_setDelegate:delegate];
        return;
    }
    
    // Create proxy with weak reference to original delegate
    _DTXAnimationDelegateProxy *proxy = [[_DTXAnimationDelegateProxy alloc] initWithDelegate:delegate];
    
    // Store proxy with strong reference on the animation (so it stays alive)
    objc_setAssociatedObject(self, _DTXCAAnimationProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Set proxy as the delegate
    [self __detox_sync_setDelegate:proxy];
}

@end
