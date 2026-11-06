//
//  TimerStressStatusPoller.m
//  ReactNativeTesterApp
//
//  Stress helper for wix/Detox#4966. Only active when the app is launched with
//  `-TimerStressAutoStart YES`. Polls +[DTXSyncManager statusWithCompletionHandler:]
//  in a loop, watches for hangs and for a busy `js_timers` resource that lists no timers.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <os/lock.h>
#import <DetoxSync/DetoxSync.h>

static NSString *const kResourceName = @"js_timers";
static const int64_t kHangThresholdNs = 10 * NSEC_PER_SEC;

@interface TimerStressStatusPoller : NSObject
@end

@implementation TimerStressStatusPoller

static dispatch_queue_t sPollQueue, sWatchdogQueue, sLogQueue;
static dispatch_source_t sWatchdog;
static NSFileHandle *sLogFile;

// Counters, guarded by sLock.
static os_unfair_lock sLock = OS_UNFAIR_LOCK_INIT;
static uint64_t sPolls, sJSTimersBusy, sEmptyTimers, sHangs, sMaxLatencyNs;
static BOOL sPending, sHangLogged;
static uint64_t sPendingSinceNs;
static int sTick;

static uint64_t nowNs(void) { return clock_gettime_nsec_np(CLOCK_UPTIME_RAW); }

static void StressLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void StressLog(NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	NSString *line = [@"[TimerStress] " stringByAppendingString:msg];
	NSLog(@"%@", line);
	fprintf(stderr, "%s\n", line.UTF8String);
	fflush(stderr);
	dispatch_async(sLogQueue, ^{
		if (sLogFile) {
			NSString *stamped = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], line];
			[sLogFile writeData:[stamped dataUsingEncoding:NSUTF8StringEncoding]];
			[sLogFile synchronizeFile];
		}
	});
}

+ (void)load
{
	@autoreleasepool {
		if (![NSUserDefaults.standardUserDefaults boolForKey:@"TimerStressAutoStart"]) {
			return;
		}
		sPollQueue = dispatch_queue_create("timerstress.poll", DISPATCH_QUEUE_SERIAL);
		sWatchdogQueue = dispatch_queue_create("timerstress.watchdog", DISPATCH_QUEUE_SERIAL);
		sLogQueue = dispatch_queue_create("timerstress.log", DISPATCH_QUEUE_SERIAL);
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), sPollQueue, ^{
			[self start];
		});
	}
}

+ (void)openLogFile
{
	NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
	NSString *path = [docs stringByAppendingPathComponent:@"timer-stress.log"];
	[NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
	sLogFile = [NSFileHandle fileHandleForWritingAtPath:path];
}

+ (NSString *)detectResourceClass
{
	Class cls = NSClassFromString(@"DTXJSTimerSyncResource");
	Class timing = NSClassFromString(@"RCTTiming");
	if (!cls) {
		return @"unknown (DTXJSTimerSyncResource class not found)";
	}
	NSString *detail = @"RCTTiming not found";
	if (timing) {
		Method m = class_getInstanceMethod(timing, NSSelectorFromString(@"createTimerForNextFrame:duration:jsSchedulingTime:repeats:"));
		if (m) {
			Dl_info info;
			if (dladdr((void *)method_getImplementation(m), &info) && info.dli_fname) {
				// imp_implementationWithBlock trampolines live in libobjc, not in the React code.
				NSString *image = [NSString stringWithUTF8String:info.dli_fname];
				BOOL swizzled = [image containsString:@"libobjc"];
				detail = [NSString stringWithFormat:@"createTimer IMP %@ (image=%@)", swizzled ? @"replaced by block" : @"NOT replaced", image.lastPathComponent];
			} else {
				detail = @"createTimer IMP image unknown";
			}
		} else {
			detail = @"RCTTiming createTimerForNextFrame method not found";
		}
	}
	return [NSString stringWithFormat:@"DTXJSTimerSyncResource (%@)", detail];
}

+ (void)start
{
	[self openLogFile];
	StressLog(@"started pid=%d", getpid());
	StressLog(@"JS_TIMER_RESOURCE=%@", [self detectResourceClass]);
	[self startOverlay];
	[self startWatchdog];
	[self poll];
}

+ (void)poll
{
	uint64_t start = nowNs();
	os_unfair_lock_lock(&sLock);
	sPending = YES;
	sHangLogged = NO;
	sPendingSinceNs = start;
	os_unfair_lock_unlock(&sLock);

	[DTXSyncManager statusWithCompletionHandler:^(NSDictionary<NSString *, id> *status) {
		uint64_t latency = nowNs() - start;
		BOOL busy = NO;
		NSDictionary *emptyResource = nil;
		NSArray *busyResources = status[@"busy_resources"];
		if ([busyResources isKindOfClass:NSArray.class]) {
			for (NSDictionary *resource in busyResources) {
				if (![resource isKindOfClass:NSDictionary.class] || ![resource[@"name"] isEqual:kResourceName]) {
					continue;
				}
				busy = YES;
				NSArray *timers = [resource[@"description"] isKindOfClass:NSDictionary.class] ? resource[@"description"][@"timers"] : nil;
				if (![timers isKindOfClass:NSArray.class] || timers.count == 0) {
					emptyResource = resource;
				}
			}
		}
		os_unfair_lock_lock(&sLock);
		sPolls++;
		sPending = NO;
		if (busy) { sJSTimersBusy++; }
		if (emptyResource) { sEmptyTimers++; }
		if (latency > sMaxLatencyNs) { sMaxLatencyNs = latency; }
		BOOL wasHang = sHangLogged;
		os_unfair_lock_unlock(&sLock);

		if (emptyResource) {
			StressLog(@"EMPTY_TIMERS resource=%@", emptyResource);
		}
		if (wasHang) {
			StressLog(@"status call finally completed after %.0f ms", latency / 1e6);
		}
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_MSEC), sPollQueue, ^{
			[self poll];
		});
	}];
}

+ (void)startWatchdog
{
	sWatchdog = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, sWatchdogQueue);
	dispatch_source_set_timer(sWatchdog, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, 50 * NSEC_PER_MSEC);
	dispatch_source_set_event_handler(sWatchdog, ^{
		sTick++;
		os_unfair_lock_lock(&sLock);
		uint64_t pendingNs = sPending ? nowNs() - sPendingSinceNs : 0;
		BOOL hang = sPending && pendingNs > kHangThresholdNs && !sHangLogged;
		if (hang) { sHangs++; sHangLogged = YES; }
		uint64_t polls = sPolls;
		os_unfair_lock_unlock(&sLock);
		if (hang) {
			StressLog(@"STATUS_HANG pendingSeconds=%.1f polls=%llu", pendingNs / 1e9, polls);
		}
		if (sTick % 5 == 0) {
			StressLog(@"%@", [self summaryString]);
		}
	});
	dispatch_resume(sWatchdog);
}

+ (NSString *)summaryString
{
	os_unfair_lock_lock(&sLock);
	uint64_t pendingNs = sPending ? nowNs() - sPendingSinceNs : 0;
	NSString *s = [NSString stringWithFormat:@"TIMER_STRESS_SUMMARY polls=%llu jsTimersBusy=%llu emptyTimers=%llu hangs=%llu maxLatencyMs=%.1f pendingMs=%.0f",
				   sPolls, sJSTimersBusy, sEmptyTimers, sHangs, sMaxLatencyNs / 1e6, pendingNs / 1e6];
	os_unfair_lock_unlock(&sLock);
	return s;
}

// Overlay: reads only the counters under sLock; UIKit calls (which DetoxSync spies on) happen outside the lock.
+ (void)startOverlay
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIWindowScene *scene = nil;
		for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
			if ([s isKindOfClass:UIWindowScene.class]) { scene = (UIWindowScene *)s; break; }
		}
		UIWindow *window = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
		window.windowLevel = UIWindowLevelAlert + 1;
		window.userInteractionEnabled = NO;
		window.backgroundColor = UIColor.clearColor;
		window.rootViewController = [UIViewController new];
		window.frame = UIScreen.mainScreen.bounds;
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8, 50, window.bounds.size.width - 16, 60)];
		label.numberOfLines = 3;
		label.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
		label.textColor = UIColor.whiteColor;
		label.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
		label.accessibilityIdentifier = @"timerStressOverlay";
		[window.rootViewController.view addSubview:label];
		window.hidden = NO;
		static UIWindow *sWindow;
		sWindow = window;
		NSTimer *timer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
			// Format under the lock, but set the label text outside it: UILabel is spied on by DetoxSync, so
			// setText: can block on the DTXSyncManager queue, whose status completion takes sLock (deadlock).
			os_unfair_lock_lock(&sLock);
			NSString *state = sHangLogged ? @"HANG" : (sPending ? @"waiting" : @"ok");
			NSString *text = [NSString stringWithFormat:@"polls=%llu jsTimersBusy=%llu\nemptyTimers=%llu hangs=%llu\nstate=%@",
							  sPolls, sJSTimersBusy, sEmptyTimers, sHangs, state];
			os_unfair_lock_unlock(&sLock);
			label.text = text;
		}];
		[NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
	});
}

@end
