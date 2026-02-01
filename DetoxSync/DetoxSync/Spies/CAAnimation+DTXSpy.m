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

@interface _DTXAnimationDelegateProxy : NSObject <CAAnimationDelegate>
@property (nonatomic, weak) id<CAAnimationDelegate> originalDelegate;
@end

@implementation _DTXAnimationDelegateProxy

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

// Forward any other delegate methods
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
    return [super respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    id<CAAnimationDelegate> delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:aSelector]) {
        return delegate;
    }
    return [super forwardingTargetForSelector:aSelector];
}

@end

#pragma mark - CAAnimation Extension

@interface CAAnimation ()
- (BOOL)_setCARenderAnimation:(void*)arg1 layer:(id)arg2;
@end

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
    if ([delegate isKindOfClass:[_DTXAnimationDelegateProxy class]]) {
        [self __detox_sync_setDelegate:delegate];
        return;
    }
    
    // Create proxy with weak reference to original delegate
    _DTXAnimationDelegateProxy *proxy = [[_DTXAnimationDelegateProxy alloc] init];
    proxy.originalDelegate = delegate;
    
    // Store proxy with strong reference on the animation (so it stays alive)
    objc_setAssociatedObject(self, _DTXCAAnimationProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Set proxy as the delegate
    [self __detox_sync_setDelegate:proxy];
}

@end
