//
//  UIView+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/29/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIView+DTXSpy.h"
#import "DTXOrigDispatch.h"
#import "DTXUISyncResource.h"

@import ObjectiveC;

@interface ElementIdentifierAndFrame : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(NSString *)identifier andFrame:(CGRect)frame NS_DESIGNATED_INITIALIZER;
+ (instancetype)createWithIdentifier:(NSString *)identifier andFrame:(CGRect)frame;
@property (nonatomic, readonly) NSString* identifier;
@property (nonatomic, readonly) CGRect frame;
@end

@implementation ElementIdentifierAndFrame

- (instancetype)initWithIdentifier:(NSString *)identifier andFrame:(CGRect)frame {
  if ([super init]) {
    _identifier = identifier;
    _frame = frame;
  }
  return self;
}

+ (instancetype)createWithIdentifier:(NSString *)identifier andFrame:(CGRect)frame {
  return [[ElementIdentifierAndFrame alloc] initWithIdentifier:identifier andFrame:frame];
}

- (BOOL)isEqual:(ElementIdentifierAndFrame *)other {
  if (other == self) {
    return YES;
  } else {
    return CGRectEqualToRect(self.frame, other.frame) &&
    [self.identifier isEqualToString:other.identifier];
  }
}

- (NSUInteger)hash {
  return self.identifier.hash;
}

@end

@implementation UIView (DTXSpy)

+ (void)load
{
  @autoreleasepool
  {
    NSError* error;

    DTXSwizzleClassMethod(self, @selector(animateWithDuration:delay:options:animations:completion:), @selector(__detox_sync_animateWithDuration:delay:options:animations:completion:), &error);
    DTXSwizzleClassMethod(self, @selector(animateWithDuration:animations:completion:), @selector(__detox_sync_animateWithDuration:animations:completion:), &error);
    DTXSwizzleClassMethod(self, @selector(animateWithDuration:animations:), @selector(__detox_sync_animateWithDuration:animations:), &error);
    DTXSwizzleClassMethod(self, @selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:), @selector(__detox_sync_animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:), &error);
    DTXSwizzleClassMethod(self, @selector(transitionFromView:toView:duration:options:completion:), @selector(__detox_sync_transitionFromView:toView:duration:options:completion:), &error);
    DTXSwizzleClassMethod(self, @selector(transitionWithView:duration:options:animations:completion:), @selector(__detox_sync_transitionWithView:duration:options:animations:completion:), &error);
    DTXSwizzleClassMethod(self, @selector(animateKeyframesWithDuration:delay:options:animations:completion:), @selector(__detox_sync_animateKeyframesWithDuration:delay:options:animations:completion:), &error);

    DTXSwizzleMethod(self, @selector(setAccessibilityIdentifier:), @selector(__detox_sync_setAccessibilityIdentifier:), &error);
    DTXSwizzleMethod(self, @selector(setNeedsLayout), @selector(__detox_sync_setNeedsLayout), &error);
    DTXSwizzleMethod(self, @selector(didMoveToSuperview), @selector(__detox_sync_didMoveToSuperview), &error);
    DTXSwizzleMethod(self, @selector(didMoveToWindow), @selector(__detox_sync_didMoveToWindow), &error);
    DTXSwizzleMethod(self, @selector(removeFromSuperview), @selector(__detox_sync_removeFromSuperview), &error);
    DTXSwizzleMethod(self, @selector(setNeedsDisplay), @selector(__detox_sync_setNeedsDisplay), &error);
    DTXSwizzleMethod(self, @selector(setNeedsDisplayInRect:), @selector(__detox_sync_setNeedsDisplayInRect:), &error);
    DTXSwizzleMethod(self, @selector(accessibilityIdentifier), @selector(__detox_sync_accessibilityIdentifier), &error);
  }
}

+ (dispatch_block_t)_failSafeTrackAnimationWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(id)completion
{
  if(completion == nil)
  {
    return ^{};
  }

  NSString* identifier = [DTXUISyncResource.sharedInstance trackViewAnimationWithDuration:duration delay:delay];

  __block BOOL alreadyUntracked = NO;
  dispatch_block_t failSafeUntrack = ^ {
    if(alreadyUntracked == NO)
    {
      [DTXUISyncResource.sharedInstance untrackViewAnimation:identifier];
      alreadyUntracked = YES;
    }
  };

  //Failsafe, just in case.
  __detox_sync_orig_dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay + duration + 0.1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    failSafeUntrack();
  });

  return failSafeUntrack;
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
  dispatch_block_t failSafeUntrack = [self _failSafeTrackAnimationWithDuration:duration delay:delay completion:completion];

  [self __detox_sync_animateWithDuration:duration delay:delay options:options animations:animations completion:^(BOOL finished) {
    if(completion)
    {
      completion(finished);
    }

    failSafeUntrack();
  }];
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
  [self animateWithDuration:duration delay:0.0 options:0 animations:animations completion:completion];
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
  [self animateWithDuration:duration delay:0.0 options:0 animations:animations completion:nil];
}

+ (void)__detox_sync_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
  dispatch_block_t failSafeUntrack = [self _failSafeTrackAnimationWithDuration:duration delay:delay completion:completion];

  [self __detox_sync_animateWithDuration:duration delay:delay usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity options:options animations:animations completion:^(BOOL finished) {
    if(completion)
    {
      completion(finished);
    }

    failSafeUntrack();
  }];
}

+ (void)__detox_sync_transitionFromView:(UIView *)fromView toView:(UIView *)toView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options completion:(void (^ __nullable)(BOOL finished))completion
{
  dispatch_block_t failSafeUntrack = [self _failSafeTrackAnimationWithDuration:duration delay:0.0 completion:completion];

  [self __detox_sync_transitionFromView:fromView toView:toView duration:duration options:options completion:^(BOOL finished) {
    if(completion)
    {
      completion(finished);
    }

    failSafeUntrack();
  }];
}

+ (void)__detox_sync_transitionWithView:(UIView *)view duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options animations:(void (^ __nullable)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
  dispatch_block_t failSafeUntrack = [self _failSafeTrackAnimationWithDuration:duration delay:0.0 completion:completion];

  [self __detox_sync_transitionWithView:view duration:duration options:options animations:animations completion:^(BOOL finished) {
    if(completion)
    {
      completion(finished);
    }

    failSafeUntrack();
  }];
}

+ (void)__detox_sync_animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewKeyframeAnimationOptions)options animations:(void (^)(void))animations completion:(void (^ __nullable)(BOOL finished))completion
{
  dispatch_block_t failSafeUntrack = [self _failSafeTrackAnimationWithDuration:duration delay:delay completion:completion];

  [self __detox_sync_animateKeyframesWithDuration:duration delay:delay options:options animations:animations completion:^(BOOL finished) {
    if(completion)
    {
      completion(finished);
    }

    failSafeUntrack();
  }];
}

/* No need to swizzle, calls public API: */

//+ (void)performSystemAnimation:(UISystemAnimation)animation onViews:(NSArray<__kindof UIView *> *)views options:(UIViewAnimationOptions)options animations:(void (^ __nullable)(void))parallelAnimations completion:(void (^ __nullable)(BOOL finished))completion API_AVAILABLE(ios(7.0));

- (NSString*)__detox_sync_safeDescription
{
  if([self isKindOfClass:UISearchBar.class])
  {
    //Under iOS 14, UISearchBar gets triggered if -text is called before its initial layout 🤦‍♂️🤦‍♂️🤦‍♂️
    return [NSString stringWithFormat:@"<%@: %p; frame = (%@ %@; %@ %@); text = <redacted>; gestureRecognizers = <NSArray: %p>; layer = <CALayer: %p>>", NSStringFromClass(self.class), self, @(self.frame.origin.x), @(self.frame.origin.y), @(self.frame.size.width), @(self.frame.size.height), self.gestureRecognizers, self.layer];
  }

  return [self description];
}

- (void)__detox_sync_setNeedsLayout
{
  [DTXUISyncResource.sharedInstance trackViewNeedsLayout:self];

  [self __detox_sync_setNeedsLayout];
}

- (void)__detox_sync_setNeedsDisplay
{
  [DTXUISyncResource.sharedInstance trackViewNeedsDisplay:self];

  [self __detox_sync_setNeedsDisplay];
}

- (void)__detox_sync_setNeedsDisplayInRect:(CGRect)rect
{
  [DTXUISyncResource.sharedInstance trackViewNeedsDisplay:self];

  [self __detox_sync_setNeedsDisplayInRect:rect];

}

static NSMutableSet<ElementIdentifierAndFrame *>  * _Nullable elementsStorage;

- (void)__detox_sync_setAccessibilityIdentifier:(NSString *)identifier {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    if (elementsStorage == nil) {
      elementsStorage = [NSMutableSet<ElementIdentifierAndFrame *> new];
    }
  });


  if ([self.__detox_sync_accessibilityIdentifier isEqualToString:identifier]) {
    [self __detox_sync_setAccessibilityIdentifier:identifier];
    return;
  }

  [self removeViewIdentifiersFromStorage];

  NSString *newIdentifier = identifier ?: [NSString stringWithFormat:@"%p", self];

  if ([elementsStorage
       containsObject:[ElementIdentifierAndFrame createWithIdentifier:newIdentifier
                                                             andFrame:self.frame]]) {
    newIdentifier = [NSString stringWithFormat:@"%@_detox:%p", newIdentifier, self];
  }

  [elementsStorage addObject:[ElementIdentifierAndFrame createWithIdentifier:newIdentifier
                                                                    andFrame:self.frame]];

  [self __detox_sync_setAccessibilityIdentifier:newIdentifier];
}

- (NSString *)__detox_sync_accessibilityIdentifier {
  [self generateAccessibilityIdentifierIfMissing];
  return self.__detox_sync_accessibilityIdentifier;
}

- (void)generateAccessibilityIdentifierIfMissing {
  // In case this view has no identifier, set him one.
  // Reads the original accessibility identifier (we use swizzling).
  if (self.__detox_sync_accessibilityIdentifier == nil ||
      [self.__detox_sync_accessibilityIdentifier isEqualToString:@""]) {
    [self setAccessibilityIdentifier:[NSString stringWithFormat:@"%p", self]];
  }
}

- (void)__detox_sync_didMoveToWindow {
  [self generateAccessibilityIdentifierIfMissing];
  [self __detox_sync_didMoveToWindow];
}

- (void)__detox_sync_didMoveToSuperview {
  [self generateAccessibilityIdentifierIfMissing];
  [self __detox_sync_didMoveToSuperview];
}

- (void)__detox_sync_removeFromSuperview {
  [self removeViewAndSubviewIdentifiersFromStorage];
  [self __detox_sync_removeFromSuperview];
}

- (void)removeViewAndSubviewIdentifiersFromStorage {
  for (UIView *subview in self.subviews) {
    [subview removeViewAndSubviewIdentifiersFromStorage];
  }

  [self removeViewIdentifiersFromStorage];
}

- (void)removeViewIdentifiersFromStorage {
  if (self.__detox_sync_accessibilityIdentifier == nil ||
      [self.__detox_sync_accessibilityIdentifier isEqualToString:@""]) {
    return;
  }

  [elementsStorage removeObject:[ElementIdentifierAndFrame
                                 createWithIdentifier:self.__detox_sync_accessibilityIdentifier
                                 andFrame:self.frame]];
}

@end
