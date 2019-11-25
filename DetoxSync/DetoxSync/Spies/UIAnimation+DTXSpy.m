//
//  UIAnimation+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/31/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIAnimation+DTXSpy.h"
#import "CALayer+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"

static const void* _DTXUIAnimationSRKey = &_DTXUIAnimationSRKey;

@import ObjectiveC;

@implementation UIAnimation (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		Method m1 = class_getInstanceMethod(UIAnimation.class, @selector(markStart:));
		Method m2 = class_getInstanceMethod(UIAnimation.class, @selector(__detox_sync_markStart:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(UIAnimation.class, @selector(markStop));
		m2 = class_getInstanceMethod(UIAnimation.class, @selector(__detox_sync_markStop));
		method_exchangeImplementations(m1, m2);
	}
}

- (void)__detox_sync_markStart:(double)arg1
{
	DTXSingleUseSyncResource* sr = objc_getAssociatedObject(self, _DTXUIAnimationSRKey);
	NSParameterAssert(sr == nil);
	sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"UI Animation"];
	objc_setAssociatedObject(self, _DTXUIAnimationSRKey, sr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self __detox_sync_markStart:arg1];
}

- (void)__detox_sync_markStop
{
	[self __detox_sync_markStop];
	
	DTXSingleUseSyncResource* sr = objc_getAssociatedObject(self, _DTXUIAnimationSRKey);
	[sr endTracking];
}

@end
