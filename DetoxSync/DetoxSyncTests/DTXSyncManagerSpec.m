//
//  DTXSyncManagerSpec.m
//  DetoxSyncTests
//
//  Created by Asaf Korem on 17/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

#import "DTXSyncManagerSpecHelpers.h"

#import <DetoxSync/DTXSyncManager.h>

#import "NSString+SyncStatus.h"
#import "NSString+SyncResource.h"
#import "DTXJSTimerSyncResource.h"
#import "RCTFakes.h"

SpecBegin(DTXSyncManager)

it(@"should report delayed perform selector busy resource", ^{
  DTXPerformSelectorAfterDelay();
  DTXPerformSelectorAfterDelay();

  DTXSyncStatus *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"delayed_perform_selector";
  NSArray *resources = [status busyResourcesWithName:resourceName];
  expect(resources).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"pending_selectors": @2
    }
  }));
});

it(@"should report dispatch queue busy resource", ^{
  __block DTXSyncStatus *status;
  DTXDispatcSyncOnArbitraryQueue(^{
    status = DTXAwaitStatus();
  });

  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"dispatch_queue";
  NSArray *resources = [status busyResourcesWithName:resourceName];
  expect(resources).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"queue": @"bar (<OS_dispatch_queue_serial: foo>)",
      @"works_count": @1
    }
  }));
});

// TODO: Investigate why this test is failing on iOS 16 and above.
xit(@"should report native timers busy resource", ^{
  NSString *fireDate = DTXScheduleTimer(NO, 15);

  DTXSyncStatus *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  DTXBusyResource *resource = [status busyResourcesWithName:@"timers"].firstObject;
  NSArray<NSDictionary<NSString *,id> *> *timers = DTXMapTimers(resource[NSString.dtx_resourceDescriptionKey][@"timers"]);

  expect(timers).to.contain((@{
    @"fire_date": fireDate,
    @"time_until_fire": @15,
    @"is_recurring": @NO,
    @"repeat_interval": @0
  }));
});

it(@"should not report native timers with repeats as busy resource", ^{
  DTXScheduleTimer(YES, 10);

  DTXSyncStatus *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  DTXBusyResource * _Nullable resource = [status busyResourcesWithName:@"timers"].firstObject;
  NSArray<NSNumber *> * _Nullable timesUntilFire = 
      [DTXMapTimers(resource[NSString.dtx_resourceDescriptionKey][@"timers"])
       valueForKey:@"time_until_fire"];

  expect(timesUntilFire ?: @[]).notTo.contain((@10));
});

it(@"should report js-timers busy resource", ^{
  DTXConnectWithJSTimerSyncResource();
  DTXCreateFakeJSTimer(12, 31.123, 21, NO);
  DTXCreateFakeJSTimer(31, 13.1, 23, NO);

  DTXSyncStatus *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  DTXBusyResource *resource = [status busyResourcesWithName:@"js_timers"].firstObject;
  NSArray<NSDictionary<NSString *,NSNumber *> *> *timers =
      resource[NSString.dtx_resourceDescriptionKey][@"timers"];

  expect([NSSet setWithArray:timers]).to.equal([NSSet setWithObjects:
    @{
      @"timer_id": @12,
      @"duration": @31.123,
      @"is_recurring": @NO
    },
    @{
      @"timer_id": @31,
      @"duration": @13.1,
      @"is_recurring": @NO
    },
    nil
  ]);
});

it(@"should report run-loop busy resource", ^{
  __block DTXSyncStatus *status;
  CFRunLoopRef runLoop = DTXExecuteOnArbitraryThread(^{
    status = DTXAwaitStatus();
  });

  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"run_loop";
  NSArray *resources = [status busyResourcesWithName:resourceName];
  expect(resources).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"name": [NSString stringWithFormat:@"foo <CFRunLoop: %p>", runLoop]
    }
  }));
});

it(@"should report one-time-events busy resource", ^{
  DTXRegisterSingleEvent(@"foo", @"bar");
  DTXRegisterSingleEvent(@"baz", nil);

  DTXSyncStatus *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"one_time_events";
  NSArray *resources = [status busyResourcesWithName:resourceName];
  expect(resources).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"event": @"foo",
      @"object": @"bar"
    }
  }));

  expect(resources).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"event": @"baz",
      @"object": [NSNull null]
    }
  }));
});

it(@"should report ui busy resource", ^{
  UIViewController *dummyController = DTXCreateDummyViewController();

  [dummyController viewWillAppear:YES];
  [dummyController viewWillAppear:NO];
  [dummyController viewWillDisappear:YES];

  DTXSyncStatus *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"ui";
  NSArray *resources = [status busyResourcesWithName:resourceName];
  expect(resources).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"view_controller_will_appear_count": @2,
      @"view_controller_will_disappear_count": @1,
    }
  }));
});

it(@"should answer status queries while js timers are being created and deleted (wix/Detox#4966)", ^{
  // Another spec may have left the old-architecture js_timers resource behind.
  DTXDisconnectJSTimerSyncResource();
  [DTXJSTimerSyncResource sharedInstance];

  RCTTiming *fakeTiming = [[RCTTiming alloc] init];
  dispatch_queue_t hammerQueue = dispatch_queue_create("hammer", DISPATCH_QUEUE_CONCURRENT);
  dispatch_group_t hammerGroup = dispatch_group_create();
  __block volatile BOOL stop = NO;

  for (NSUInteger thread = 0; thread < 4; thread++) {
    dispatch_group_async(hammerGroup, hammerQueue, ^{
      double timerID = (thread + 1) * 1000000;
      while (!stop) {
        timerID += 1;
        [fakeTiming createTimerForNextFrame:@(timerID) duration:0.05 jsSchedulingTime:[NSDate date] repeats:NO];
        if ((NSUInteger)timerID % 3 != 0) {
          // The others are left to be cleaned up by the resource's own timeout.
          [fakeTiming deleteTimer:timerID];
        }
        // Keeps the timer queue from building up a backlog that outlasts the spec.
        usleep(5000);
      }
    });
  }

  __block BOOL allAnswered = YES;
  __block BOOL allTimersListed = YES;
  waitUntilTimeout(60, ^(DoneCallback done) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      // Long enough for the resource's own 1.5s timeouts to fire while timers are being created.
      NSDate *end = [NSDate dateWithTimeIntervalSinceNow:3];
      while ([end timeIntervalSinceNow] > 0) {
        dispatch_semaphore_t answered = dispatch_semaphore_create(0);
        [DTXSyncManager statusWithCompletionHandler:^(NSDictionary<NSString *,id> *status) {
          // A busy js_timers resource must list its timers, Detox rejects an empty list.
          for (NSDictionary *resource in status[NSString.dtx_busyResourcesKey]) {
            if ([resource[NSString.dtx_resourceNameKey] isEqualToString:@"js_timers"]) {
              NSArray *timers = resource[NSString.dtx_resourceDescriptionKey][@"timers"];
              if (timers.count == 0) {
                allTimersListed = NO;
              }
            }
          }
          dispatch_semaphore_signal(answered);
        }];

        if (dispatch_semaphore_wait(answered, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) != 0) {
          allAnswered = NO;
          break;
        }
      }
      done();
    });
  });

  stop = YES;
  dispatch_group_wait(hammerGroup, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

  // Let the leftover timers time out, so they don't show up in the js_timers resource of the following specs.
  NSDate *drainEnd = [NSDate dateWithTimeIntervalSinceNow:20];
  while ([drainEnd timeIntervalSinceNow] > 0 && [DTXAwaitStatus() busyResourcesWithName:@"js_timers"].count > 0) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }

  expect(allAnswered).to.beTruthy();
  expect(allTimersListed).to.beTruthy();
});

SpecEnd
