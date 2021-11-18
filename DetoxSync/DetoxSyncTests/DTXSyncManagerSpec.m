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

SpecBegin(DTXSyncManagerSpec)

it(@"should report delayed perform selector busy resource", ^{
  SEL dummySelector1 = @selector(setValue:forKey:);
  [self performSelector:dummySelector1 withObject:nil afterDelay:123];

  SEL dummySelector2 = @selector(setValue:forKey:);
  [self performSelector:dummySelector2 withObject:nil afterDelay:100];

  NSDictionary<NSString *,id> *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"delayed_perform_selector";
  expect(DTXFindResources(resourceName, status[NSString.dtx_busyResourcesKey])).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"pending_selectors": @2
    }
  }));
});

it(@"should report dispatch queue busy resource", ^{
  dispatch_queue_t dummyQueue = dispatch_queue_create("foo", 0);
  [DTXSyncManager trackDispatchQueue:dummyQueue name:@"dummyQueue"];

  __block NSDictionary<NSString *,id> * _Nullable status;
  dispatch_sync(dummyQueue, ^{
    status = DTXAwaitStatus();
  });

  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"dispatch_queue";
  expect(DTXFindResources(resourceName, status[NSString.dtx_busyResourcesKey])).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"queue": @"dummyQueue (<OS_dispatch_queue_serial: foo>)",
      @"works_count": @1
    }
  }));
});

it(@"should report native timers busy resource", ^{
  NSTimer *dummyTimer = [NSTimer scheduledTimerWithTimeInterval:15 repeats:NO
                                                          block:^(NSTimer * __unused timer) {}];

  NSDictionary<NSString *,id> * _Nullable status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSDictionary<NSString *,id> *resource =
      DTXFindResources(@"timers", status[NSString.dtx_busyResourcesKey]).firstObject;
  NSArray<NSDictionary<NSString *,id> *> *timers = DTXMapTimers(resource[NSString.dtx_resourceDescriptionKey][@"timers"]);

  expect(timers).to.contain((@{
    @"fire_date": [DTXDateFormatter() stringFromDate:dummyTimer.fireDate],
    @"time_until_fire": @15,
    @"is_recurring": @NO,
    @"repeat_interval": @0
  }));
});

it(@"should report js-timers busy resource", ^{
  DTXConnectWithJSTimerSyncResource();
  DTXCreateFakeJSTimer(12, 31.123, 21, NO);
  DTXCreateFakeJSTimer(31, 13.1, 23, NO);

  NSDictionary<NSString *,id> * _Nullable status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSDictionary<NSString *,id> *resource =
  DTXFindResources(@"js_timers", status[NSString.dtx_busyResourcesKey]).firstObject;
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
  __block NSDictionary<NSString *,id> * _Nullable status;
  __block NSRunLoop * _Nullable runLoop;

  waitUntil(^(DoneCallback done) {
    NSThread *thread = [[NSThread alloc] initWithBlock:^{
      runLoop = [NSRunLoop currentRunLoop];
      [DTXSyncManager trackRunLoop:runLoop name:@"foo"];
      status = DTXAwaitStatus();
      done();
    }];
    [thread start];
  });

  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"run_loop";
  expect(DTXFindResources(resourceName, status[NSString.dtx_busyResourcesKey])).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"name": [NSString stringWithFormat:@"foo <CFRunLoop: %p>", [runLoop getCFRunLoop]]
    }
  }));
});

it(@"should report one-time-events busy resource", ^{
  DTXRegisterSingleEvent(@"foo", @"bar");
  DTXRegisterSingleEvent(@"baz", nil);

  NSDictionary<NSString *,id> *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"one_time_events";
  expect(DTXFindResources(resourceName, status[NSString.dtx_busyResourcesKey])).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"event": @"foo",
      @"object": @"bar"
    }
  }));

  expect(DTXFindResources(resourceName, status[NSString.dtx_busyResourcesKey])).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"event": @"baz",
      @"object": [NSNull null]
    }
  }));
});

it(@"should report ui busy resource", ^{
  UIViewController *dummyController = OCMPartialMock([[UIViewController alloc] init]);
  id <UIViewControllerTransitionCoordinator> coordinator =
      OCMProtocolMock(@protocol(UIViewControllerTransitionCoordinator));
  OCMStub([dummyController transitionCoordinator]).andReturn(coordinator);

  [dummyController viewWillAppear:YES];
  [dummyController viewWillAppear:NO];
  [dummyController viewWillDisappear:YES];

  NSDictionary<NSString *,id> *status = DTXAwaitStatus();
  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSString *resourceName = @"ui";
  expect(DTXFindResources(resourceName, status[NSString.dtx_busyResourcesKey])).to.contain((@{
    NSString.dtx_resourceNameKey: resourceName,
    NSString.dtx_resourceDescriptionKey: @{
      @"view_controller_will_appear_count": @2,
      @"view_controller_will_disappear_count": @1,
    }
  }));
});

SpecEnd
