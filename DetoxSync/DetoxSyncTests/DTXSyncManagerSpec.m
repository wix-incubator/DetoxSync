//
//  DTXSyncManagerSpec.m
//  DetoxSyncTests
//
//  Created by Asaf Korem on 17/11/2021.
//  Copyright © 2021 wix. All rights reserved.
//

#import <DetoxSync/DTXSyncManager.h>

#import <JavaScriptCore/JavaScriptCore.h>

#import "NSString+SyncStatus.h"
#import "NSString+SyncResource.h"

/// Await for synchronization status and return the fetched status.
NSDictionary<NSString *,id> *DTXAwaitStatus(void) {
  __block NSDictionary<NSString *,id> * _Nullable syncStatus;
  waitUntil(^(DoneCallback done) {
    [DTXSyncManager statusWithCompletionHandler:^(NSDictionary<NSString *,id> *status) {
      syncStatus = status;
      done();
    }];
  });

  assert(syncStatus);
  return syncStatus;
}

/// Find busy-resources with \c name from a list of \c resources.
NSArray<NSDictionary<NSString *,id> *> * DTXFindResources(
    NSString *name, NSArray<NSDictionary<NSString *,id> *> *resources) {
  NSMutableArray<NSDictionary<NSString *,id> *> *matchingResources = [NSMutableArray array];
  for (NSDictionary<NSString *,id> *resource in resources) {
    if ([resource[NSString.dtx_resourceNameKey] isEqualToString:name]) {
      [matchingResources addObject:resource];
    }
  }
  return matchingResources;
}

/// Round all timers resources in the given \c timers list.
NSArray<NSDictionary<NSString *,id> *> *DTXRoundTimers(
    NSArray<NSDictionary<NSString *,id> *> *timers) {
  NSMutableArray<NSDictionary<NSString *,id> *> *mappedTimers = [NSMutableArray array];
  for (NSDictionary<NSString *,id> *timer in timers) {
    [mappedTimers addObject:@{
      @"time_until_fire": @(floorf([timer[@"time_until_fire"] floatValue] + 0.5f)),
      @"is_recurring": timer[@"is_recurring"],
      @"repeat_interval": timer[@"repeat_interval"]
    }];
  }

  return mappedTimers;
}

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
  [NSTimer scheduledTimerWithTimeInterval:15 repeats:NO block:^(NSTimer * __unused timer) {}];
  NSDictionary<NSString *,id> * _Nullable status = DTXAwaitStatus();

  expect(status[NSString.dtx_appStatusKey]).to.equal(@"busy");

  NSDictionary<NSString *,id> *resource =
      DTXFindResources(@"timers", status[NSString.dtx_busyResourcesKey]).firstObject;
  NSArray<NSDictionary<NSString *,id> *> *timers =
      DTXRoundTimers(resource[NSString.dtx_resourceDescriptionKey][@"timers"]);

  expect(timers).to.contain((@{
    @"time_until_fire": @15,
    @"is_recurring": @NO,
    @"repeat_interval": @0
  }));
});

SpecEnd
