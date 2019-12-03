//
//  UIGestureRecognizer+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/4/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIGestureRecognizer+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"

@import ObjectiveC;

static const void* _DTXGestureRecognizerSRKey = &_DTXGestureRecognizerSRKey;

@interface UIGestureRecognizer ()

- (void)_setDirty;
- (void)_resetGestureRecognizer;
- (void)setState:(UIGestureRecognizerState)state;

@end

@implementation UIGestureRecognizer (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		NSError* error;
		[self jr_swizzleMethod:@selector(_setDirty) withMethod:@selector(__detox_sync__setDirty) error:&error];
		[self jr_swizzleMethod:@selector(_resetGestureRecognizer) withMethod:@selector(__detox_sync__resetGestureRecognizer) error:&error];
		[self jr_swizzleMethod:@selector(setState:) withMethod:@selector(__detox_sync_setState:) error:&error];
	}
}

- (void)__detox_sync__setDirty
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Gesture Recognizer"];
	objc_setAssociatedObject(self, _DTXGestureRecognizerSRKey, sr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self __detox_sync__setDirty];
}

- (void)__detox_sync_resetSyncResource
{
	DTXSingleUseSyncResource* sr = objc_getAssociatedObject(self, _DTXGestureRecognizerSRKey);
	[sr endTracking];
	objc_setAssociatedObject(self, _DTXGestureRecognizerSRKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)__detox_sync__resetGestureRecognizer
{
	[self __detox_sync__resetGestureRecognizer];
	
	[self __detox_sync_resetSyncResource];
}

- (void)__detox_sync_setState:(UIGestureRecognizerState)state
{
	[self __detox_sync_setState:state];
	
	if(state == UIGestureRecognizerStateFailed)
	{
		[self __detox_sync_resetSyncResource];
	}
}

@end
