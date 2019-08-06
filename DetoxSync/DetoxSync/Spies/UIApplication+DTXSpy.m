//
//  UIApplication+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/4/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIApplication+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"

@import ObjectiveC;

static const void* _DTXApplicationIgnoringEventsSRKey = &_DTXApplicationIgnoringEventsSRKey;

@implementation UIApplication (DTXSpy)

+ (void)load
{
	@autoreleasepool {
		Method m1 = class_getInstanceMethod(UIScrollView.class, @selector(beginIgnoringInteractionEvents));
		Method m2 = class_getInstanceMethod(UIScrollView.class, @selector(__detox_sync_beginIgnoringInteractionEvents));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(UIScrollView.class, @selector(endIgnoringInteractionEvents));
		m2 = class_getInstanceMethod(UIScrollView.class, @selector(__detox_sync_endIgnoringInteractionEvents));
		method_exchangeImplementations(m1, m2);
	}
}

- (void)__detox_sync_resetSyncResource
{
	DTXSingleUseSyncResource* sr = objc_getAssociatedObject(self, _DTXApplicationIgnoringEventsSRKey);
	[sr endUse];
	objc_setAssociatedObject(self, _DTXApplicationIgnoringEventsSRKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)__detox_sync_beginIgnoringInteractionEvents
{
	BOOL wasIgnoring = self.isIgnoringInteractionEvents;
	
	[self __detox_sync_beginIgnoringInteractionEvents];
	
	if(wasIgnoring == NO)
	{
		DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Application ignoring interaction events"];
		objc_setAssociatedObject(self, _DTXApplicationIgnoringEventsSRKey, sr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

- (void)__detox_sync_endIgnoringInteractionEvents
{
	[self __detox_sync_endIgnoringInteractionEvents];
	
	if(self.isIgnoringInteractionEvents == NO)
	{
		[self __detox_sync_resetSyncResource];
	}
}

@end
