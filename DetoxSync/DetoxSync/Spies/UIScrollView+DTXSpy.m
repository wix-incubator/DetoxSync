//
//  UIScrollView+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/4/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIScrollView+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"

@import ObjectiveC;

static const void* _DTXScrollViewSRKey = &_DTXScrollViewSRKey;

@interface UIScrollView ()

- (void)_scrollViewWillBeginDragging;
- (void)_scrollViewDidEndDraggingWithDeceleration:(_Bool)arg1;
- (void)_scrollViewDidEndDecelerating;

@end

@implementation UIScrollView (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		Method m1 = class_getInstanceMethod(UIScrollView.class, @selector(_scrollViewWillBeginDragging));
		Method m2 = class_getInstanceMethod(UIScrollView.class, @selector(__detox_sync__scrollViewWillBeginDragging));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(UIScrollView.class, @selector(_scrollViewDidEndDraggingWithDeceleration:));
		m2 = class_getInstanceMethod(UIScrollView.class, @selector(__detox_sync__scrollViewDidEndDraggingWithDeceleration:));
		method_exchangeImplementations(m1, m2);
		
		m1 = class_getInstanceMethod(UIScrollView.class, @selector(_scrollViewDidEndDecelerating));
		m2 = class_getInstanceMethod(UIScrollView.class, @selector(__detox_sync__scrollViewDidEndDecelerating));
		method_exchangeImplementations(m1, m2);
	}
}

- (void)__detox_sync__scrollViewWillBeginDragging
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObject:self description:@"Scroll view scroll"];
	objc_setAssociatedObject(self, _DTXScrollViewSRKey, sr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self __detox_sync__scrollViewWillBeginDragging];
}

- (void)__detox_sync_resetSyncResource
{
	DTXSingleUseSyncResource* sr = objc_getAssociatedObject(self, _DTXScrollViewSRKey);
	[sr endUse];
	objc_setAssociatedObject(self, _DTXScrollViewSRKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)__detox_sync__scrollViewDidEndDraggingWithDeceleration:(bool)arg1
{
	[self __detox_sync__scrollViewDidEndDraggingWithDeceleration:arg1];
	
	if(arg1 == NO)
	{
		[self __detox_sync_resetSyncResource];
	}
}

- (void)__detox_sync__scrollViewDidEndDecelerating
{
	[self __detox_sync__scrollViewDidEndDecelerating];
	
	[self __detox_sync_resetSyncResource];
}

@end
