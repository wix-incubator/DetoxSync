//
//  DTXSyncManagerSpec.m
//  DetoxSyncTests
//
//  Created by Asaf Korem on 17/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

#import "DTXSyncManagerSpecHelpers.h"

SpecBegin(DTXSyncManagerSpec)

it(@"should report delayed perform selector busy resource correctly", ^{
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

it(@"should report dispatch queue busy resource correctly", ^{
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

it(@"should report timers busy resource correctly", ^{
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

SpecEnd
