//
//  REASyncUpdateObserver+DTXSpy.m (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2023.
//

#import "DTXSyncManager-Private.h"
#import "REASyncUpdateObserver+DTXSpy.h"
#import "DTXSingleEventSyncResource.h"

@import ObjectiveC;

static const void* _DTXREASyncUpdateObserverSRKey = &_DTXREASyncUpdateObserverSRKey;

@protocol REASyncUpdateObserverSwizzledMethods

- (void)waitAndMountWithTimeout:(NSTimeInterval)timeout;

@end

@implementation NSObject (REASyncUpdateObserverDTXSpy)

+ (void)load {
  @autoreleasepool {
    Class REASyncUpdateObserverClass = NSClassFromString(@"REASyncUpdateObserver");


    DTXSyncResourceVerboseLog(@"REASyncUpdateObserver class exists: %@",
                              REASyncUpdateObserverClass != nil ? @"YES" : @"NO");

    if (REASyncUpdateObserverClass == nil) {
      return;
    }

    NSError* error;
    DTXSwizzleMethod(REASyncUpdateObserverClass, @selector(waitAndMountWithTimeout:), @selector(__detox_sync_waitAndMountWithTimeout:), &error);
  }
}

- (void)__detox_sync_waitAndMountWithTimeout:(NSTimeInterval)timeout {
  NSString *eventDescription = [NSString stringWithFormat:@"Reanimated Waiting (Timeout: %.2f seconds)", timeout];
  DTXSingleEventSyncResource* sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:eventDescription];
  objc_setAssociatedObject(self, _DTXREASyncUpdateObserverSRKey, sr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  void (^originalMountingBlock)(void) = nil;
  void (^swizzledMountingBlock)(void) = nil;

  // Get the original _mounting block
  originalMountingBlock = [self valueForKey:@"_mounting"];

  // Swizzle the original _mounting block to end tracking when it's called
  __weak typeof(self) weakSelf = self;
  swizzledMountingBlock = ^{
    // Restore the original _mounting block
    [weakSelf setValue:originalMountingBlock forKey:@"_mounting"];

    if (originalMountingBlock) {
      originalMountingBlock();
    }

    DTXSingleEventSyncResource* sr = objc_getAssociatedObject(weakSelf, _DTXREASyncUpdateObserverSRKey);
    [sr endTracking];
    objc_setAssociatedObject(weakSelf, _DTXREASyncUpdateObserverSRKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  };

  // Set the swizzled _mounting block
  [self setValue:swizzledMountingBlock forKey:@"_mounting"];

  [self __detox_sync_waitAndMountWithTimeout:timeout];
}

@end
