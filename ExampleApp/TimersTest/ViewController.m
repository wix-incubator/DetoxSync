//
//  ViewController.m
//  TimersTest
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "ViewController.h"
@import DetoxSync;

#define print_sync_resources(sync) do {\
	if([NSUserDefaults.standardUserDefaults boolForKey:@"ExamplePrintSyncResources"] == NO) { break; } \
	dispatch_group_t __await_response = dispatch_group_create();\
	if(sync) { dispatch_group_enter(__await_response); }\
	[DTXSyncManager idleStatusWithCompletionHandler:^(NSString* response) {\
		printf("⚠️⚠️⚠️ %s\n", response.UTF8String);\
		if(sync) { dispatch_group_leave(__await_response); }\
	}];\
} while(false);


@interface NSRunLoop ()

+ (id)_new:(id)arg1;

@end

@interface ViewController () <CAAnimationDelegate, NSURLSessionDataDelegate>
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topLayoutConstraintRed;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topLayoutConstraintGreen;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topLayoutConstraintBlue;
@property (weak, nonatomic) IBOutlet UIView *greenView;

@end

@implementation ViewController
{
	NSURLSession* _urlSession;
	CABasicAnimation* _animation;
}

- (void)_timer2:(NSTimer*)timer
{
	NSLog(@"⏰ Timer 2");
}

- (void)_timer3:(NSTimer*)timer
{
	NSLog(@"⏰ Timer 3");
}

- (void)onMain
{
	NSLog(@"⏰ performSelectorOnMainThread");
}

- (void)goAwayNow
{
	[self performSelectorOnMainThread:@selector(onMain) withObject:nil waitUntilDone:NO];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self performSelector:@selector(goAwayNow) onThread:NSThread.mainThread withObject:nil waitUntilDone:NO];
	
	[DTXSyncManager queueIdleBlock:^{
		NSLog(@"✅ Idle!");
	}];
	
	[DTXSyncManager queueIdleBlock:^{
		NSLog(@"✅ Idle on main queue!");
	} queue:dispatch_get_main_queue()];
	
	[DTXSyncManager trackRunLoop:NSRunLoop.mainRunLoop];
	print_sync_resources(YES);
//	[DTXSyncManager untrackRunLoop:NSRunLoop.mainRunLoop];
	
	_urlSession = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:self delegateQueue:nil];
	
	[NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
		NSLog(@"⏰ Timer 1");
	}];
	
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(_timer2:) userInfo:nil repeats:NO];
	
	NSTimer* timer3 = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(_timer3:) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:timer3 forMode:NSDefaultRunLoopMode];
	[timer3 invalidate];
	CFRunLoopTimerInvalidate((__bridge CFRunLoopTimerRef)timer3);
	
	NSTimer* timer4 = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0] interval:1.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
		NSLog(@"⏰ Timer 4");
	}];
	[[NSRunLoop mainRunLoop] addTimer:timer4 forMode:NSDefaultRunLoopMode];
	
	[NSOperationQueue.mainQueue addOperationWithBlock:^{
		NSLog(@"🔄 Operation 1");
	}];
	
	print_sync_resources(YES);
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		self.topLayoutConstraintRed.constant = 400;
		[UIView animateWithDuration:5 animations:^{
			[self.view layoutIfNeeded];
		}];

		self.topLayoutConstraintGreen.constant = 400;
		[UIView animateWithDuration:5 animations:^{
			[self.view layoutIfNeeded];
		} completion:^(BOOL finished) {
			NSLog(@"📱 Animation 2");
		}];

		self.topLayoutConstraintBlue.constant = 400;
		[UIView animateWithDuration:5 delay:0.0 usingSpringWithDamping:500 initialSpringVelocity:0.0 options:0 animations:^{
			[self.view layoutIfNeeded];
		} completion:^(BOOL finished) {
			NSLog(@"📱 Animation 3");
			
			NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.ynet.co.il"]];
			req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
			
			id task = [_urlSession dataTaskWithRequest:req];
			[task resume];
			print_sync_resources(YES);
		}];
	});
	
	print_sync_resources(YES);
}

- (void)animationDidStart:(CAAnimation *)anim
{
	NSLog(@"📱 CAAnimation start");
	
	print_sync_resources(YES);
}

- (void)selectorForBackground
{
	dispatch_queue_t customQueue = dispatch_queue_create("com.wix.test", DISPATCH_QUEUE_CONCURRENT);
	
	[DTXSyncManager trackDispatchQueue:customQueue];
	
	dispatch_group_t serviceGroup = dispatch_group_create();
	
	dispatch_group_async(serviceGroup, customQueue, ^{
		NSLog(@"⏰ Custom Queue 1");
		[NSThread sleepForTimeInterval:1.0];
	});
	
	dispatch_group_async(serviceGroup, customQueue, ^{
		NSLog(@"⏰ Custom Queue 2");
		[NSThread sleepForTimeInterval:1.0];
	});
	
	dispatch_group_async(serviceGroup, customQueue, ^{
		NSLog(@"⏰ Custom Queue 3");
		[NSThread sleepForTimeInterval:1.0];
	});
	
	dispatch_group_async(serviceGroup, customQueue, ^{
		NSLog(@"⏰ Custom Queue 4");
		[NSThread sleepForTimeInterval:1.0];
	});
	
	dispatch_group_async(serviceGroup, customQueue, ^{
		NSLog(@"⏰ Custom Queue 5");
		[NSThread sleepForTimeInterval:1.0];
	});

	dispatch_group_enter(serviceGroup);
	dispatch_async(customQueue, ^{
		NSLog(@"⏰ Custom Queue 6");
		[NSThread sleepForTimeInterval:1.0];
		dispatch_group_leave(serviceGroup);
	});
	
	print_sync_resources(YES);
	
	dispatch_group_notify(serviceGroup, dispatch_get_main_queue(), ^{
		[self performSegueWithIdentifier:@"Modal" sender:nil];
	});
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
	NSLog(@"📱 CAAnimation stop");
	
	[self performSelectorOnMainThread:@selector(selectorForBackground) withObject:nil waitUntilDone:NO];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	NSLog(@"📰 Network response 1");
	
	NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.ynet.co.il"]];
	req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
	
	[[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSLog(@"📰 Network response 2");
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			_animation = [CABasicAnimation animationWithKeyPath:@"transform"];
			_animation.fromValue = @(CATransform3DIdentity);
			_animation.toValue = @(CATransform3DMakeScale(4.0, 4.0, 4.0));
			_animation.duration = 5.0;
			_animation.fillMode = kCAFillModeForwards;
			_animation.removedOnCompletion = NO;
			_animation.delegate = self;

			[_greenView.layer addAnimation:_animation forKey:@"basic"];
			
			print_sync_resources(YES);
		});
	}] resume];
}

@end
