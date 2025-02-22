//
//  DTXReactNativeSupport.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXReactNativeSupport.h"
#import "ReactNativeHeaders.h"
#import "DTXSyncManager-Private.h"
#import "DTXJSTimerSyncResource.h"
#import "DTXJSTimerSyncResourceOldArch.h"
#import "DTXAnimationUpdateSyncResource.h"

#import "DTXSingleEventSyncResource.h"
#import "fishhook.h"
#import <dlfcn.h>
#import <stdatomic.h>

@import UIKit;
@import ObjectiveC;
@import Darwin;

DTX_CREATE_LOG(DTXSyncReactNativeSupport);

typedef void (^RCTSourceLoadBlock)(NSError *error, id source);

@interface DTXReactNativeSupport ()

+ (NSMutableArray*)observedQueues;

+ (void)cleanupBeforeReload;
+ (void)setupJavaScriptThread;
+ (void)setupModuleQueues;
+ (void)setupTimers;
+ (void)setupBundleLoader;
+ (void)setupUIApplication;
+ (void)disableFlexNetworkObserver;

@end

// Static variables
static NSMutableArray* _observedQueues;
atomic_cfrunloop __RNRunLoop = ATOMIC_VAR_INIT(NULL);
atomic_constvoidptr __RNThread = ATOMIC_VAR_INIT(NULL);
static void (*orig_runRunLoopThread)(id, SEL) = NULL;
static int (*__orig__UIApplication_run_orig)(id self, SEL _cmd);
static void (*__orig_loadBundleAtURL_onProgress_onComplete)(id self, SEL _cmd, NSURL* url, id onProgress, RCTSourceLoadBlock onComplete);

#pragma mark - JavaScript Thread Management

static void swz_runRunLoopThread(id self, SEL _cmd) {
    CFRunLoopRef oldRunloop = atomic_load(&__RNRunLoop);
    NSThread* oldThread = CFBridgingRelease(atomic_load(&__RNThread));
    [DTXSyncManager untrackThread:oldThread];
    [DTXSyncManager untrackCFRunLoop:oldRunloop];

    CFRunLoopRef current = CFRunLoopGetCurrent();
    atomic_store(&__RNRunLoop, current);
    atomic_store(&__RNThread, CFBridgingRetain([NSThread currentThread]));

    [DTXSyncManager trackThread:[NSThread currentThread] name:@"JavaScript Thread"];
    [DTXSyncManager trackCFRunLoop:current name:@"JavaScript RunLoop"];

    oldThread = nil;
    orig_runRunLoopThread(self, _cmd);
}

static void _DTXTrackUIManagerQueue(void) {
    dispatch_queue_t (*RCTGetUIManagerQueue)(void) = dlsym(RTLD_DEFAULT, "RCTGetUIManagerQueue");
    dispatch_queue_t queue = RCTGetUIManagerQueue();
    if (queue == nil) {
        return;
    }

    NSString* queueName = [[NSString alloc] initWithUTF8String:dispatch_queue_get_label(queue) ?: queue.description.UTF8String];
    DTXSyncResourceVerboseLog(@"Adding sync resource for RCTUIManagerQueue: %@ %p", queueName, queue);
    [_observedQueues addObject:queue];
    [DTXSyncManager trackDispatchQueue:queue name:@"RN Module: UIManager"];
}

static int __detox_sync_UIApplication_run(id self, SEL _cmd) {
    [DTXReactNativeSupport setupJavaScriptThread];
    return __orig__UIApplication_run_orig(self, _cmd);
}

static void __detox_sync_loadBundleAtURL_onProgress_onComplete(id self, SEL _cmd, NSURL* url, id onProgress, RCTSourceLoadBlock onComplete) {
    [DTXReactNativeSupport cleanupBeforeReload];

    dtx_log_info(@"Adding idling resource for RN load");

    id<DTXSingleEvent> sr = [DTXSingleEventSyncResource singleUseSyncResourceWithObjectDescription:nil eventDescription:@"React Native (bundle load)"];

    [DTXReactNativeSupport waitForReactNativeLoadWithCompletionHandler:^{
        [sr endTracking];
    }];

    __orig_loadBundleAtURL_onProgress_onComplete(self, _cmd, url, onProgress, onComplete);
}

@implementation DTXReactNativeSupport

#pragma mark - Property Accessors

+ (NSMutableArray*)observedQueues {
    return _observedQueues;
}

#pragma mark - Initialization

__attribute__((constructor))
static void _setupRNSupport(void) {
    @autoreleasepool {
        if (![DTXReactNativeSupport hasReactNative]) {
            return;
        }

        _observedQueues = [NSMutableArray new];

        [DTXReactNativeSupport setupModuleQueues];
        [DTXReactNativeSupport setupUIApplication];
        [DTXReactNativeSupport setupTimers];
        [DTXReactNativeSupport setupAnimationUpdates];
        [DTXReactNativeSupport setupBundleLoader];
        [DTXReactNativeSupport disableFlexNetworkObserver];
    }
}

#pragma mark - Setup Methods

+ (void)setupJavaScriptThread {
    Class cls = NSClassFromString(@"RCTJSCExecutor");
    Method m = NULL;

    if (cls != NULL) {
        m = class_getClassMethod(cls, NSSelectorFromString(@"runRunLoopThread"));
        dtx_log_info(@"Found legacy class RCTJSCExecutor");
    } else {
        if (DTXReactNativeSupport.isNewArchEnabled) {
            cls = NSClassFromString(@"RCTJSThreadManager");
        } else {
            cls = NSClassFromString(@"RCTCxxBridge");
        }

        m = class_getClassMethod(cls, NSSelectorFromString(@"runRunLoop"));
        if (m == NULL) {
            m = class_getInstanceMethod(cls, NSSelectorFromString(@"runJSRunLoop"));
            dtx_log_info(@"Found modern class %@, method runJSRunLoop", NSStringFromClass(cls));
        } else {
            dtx_log_info(@"Found modern class %@, method runRunLoop", NSStringFromClass(cls));
        }
    }

    if (m != NULL) {
        orig_runRunLoopThread = (void(*)(id, SEL))method_getImplementation(m);
        method_setImplementation(m, (IMP)swz_runRunLoopThread);
    } else {
        dtx_log_info(@"Method runRunLoop not found");
    }
}

+ (void)setupModuleQueues {
    Class cls = NSClassFromString(@"RCTModuleData");
    if (cls == nil) {
        return;
    }

    Method m = class_getInstanceMethod(cls, NSSelectorFromString(@"setUpMethodQueue"));
    void(*orig_setUpMethodQueue_imp)(id, SEL) = (void(*)(id, SEL))method_getImplementation(m);

    method_setImplementation(m, imp_implementationWithBlock(^(id _self) {
        orig_setUpMethodQueue_imp(_self, NSSelectorFromString(@"setUpMethodQueue"));

        dispatch_queue_t queue = object_getIvar(_self, class_getInstanceVariable(cls, "_methodQueue"));

        if (queue != nil &&
            [queue isKindOfClass:NSNull.class] == NO &&
            queue != dispatch_get_main_queue() &&
            ![_observedQueues containsObject:queue]) {

            NSString* queueName = [[NSString alloc] initWithUTF8String:dispatch_queue_get_label(queue) ?: queue.description.UTF8String];
            [_observedQueues addObject:queue];

            DTXSyncResourceVerboseLog(@"Adding sync resource for queue: %@ %p", queueName, queue);

            NSString* moduleName = [_self valueForKey:@"name"];
            if (moduleName.length == 0) {
                moduleName = [_self description];
            }

            [DTXSyncManager trackDispatchQueue:queue name:[NSString stringWithFormat:@"RN Module: %@", moduleName]];
        }
    }));

    _DTXTrackUIManagerQueue();
}

+ (void)setupUIApplication {
    Method m = class_getInstanceMethod(UIApplication.class, NSSelectorFromString(@"_run"));
    __orig__UIApplication_run_orig = (void*)method_getImplementation(m);
    method_setImplementation(m, (void*)__detox_sync_UIApplication_run);
}

+ (void)setupTimers {
    DTXSyncResourceVerboseLog(@"Adding sync resource for JS timers");
    if ([DTXReactNativeSupport isNewArchEnabled]) {
        DTXJSTimerSyncResource* jsTimerResource = [DTXJSTimerSyncResource sharedInstance];
        [DTXSyncManager registerSyncResource:jsTimerResource];
    } else {
        DTXJSTimerSyncResourceOldArch* jsTimerResource = [DTXJSTimerSyncResourceOldArch new];
        [DTXSyncManager registerSyncResource:jsTimerResource];
    }
}

+ (void)setupAnimationUpdates {
    DTXSyncResourceVerboseLog(@"Adding sync resource for node animations");
    DTXAnimationUpdateSyncResource* resource = [DTXAnimationUpdateSyncResource sharedInstance];
    [DTXSyncManager registerSyncResource:resource];
}

+ (void)setupBundleLoader {
    Class cls = NSClassFromString(@"RCTJavaScriptLoader");
    if (cls == nil) {
        return;
    }

    Method m = class_getClassMethod(cls, NSSelectorFromString(@"loadBundleAtURL:onProgress:onComplete:"));
    if (m == NULL) {
        return;
    }

    __orig_loadBundleAtURL_onProgress_onComplete = (void*)method_getImplementation(m);
    method_setImplementation(m, (void*)__detox_sync_loadBundleAtURL_onProgress_onComplete);
}

+ (void)disableFlexNetworkObserver {
    Class cls = NSClassFromString(@"FLEXNetworkObserver") ?: NSClassFromString(@"SKFLEXNetworkObserver");
    if (cls == nil) {
        return;
    }

    Method m = class_getClassMethod(cls, NSSelectorFromString(@"injectIntoAllNSURLConnectionDelegateClasses"));
    method_setImplementation(m, imp_implementationWithBlock(^(id _self) {
        NSLog(@"%@ has been disabled by DetoxSync", NSStringFromClass(cls));
    }));
}

#pragma mark - Public Methods

+ (BOOL)hasReactNative {
    return (NSClassFromString(@"RCTView") != nil);
}

+ (void)waitForReactNativeLoadWithCompletionHandler:(void (^)(void))handler {
    NSParameterAssert(handler != nil);

    __block __weak id observer;
    __block __weak id observer2;

    observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"RCTContentDidAppearNotification"
                                                                 object:nil
                                                                  queue:nil
                                                             usingBlock:^(NSNotification * _Nonnull note) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];

        dispatch_async(dispatch_get_main_queue(), ^{
            handler();
        });
    }];

    observer2 = [[NSNotificationCenter defaultCenter] addObserverForName:@"RCTJavaScriptDidFailToLoadNotification"
                                                                  object:nil
                                                                   queue:nil
                                                              usingBlock:^(NSNotification * _Nonnull note) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        [[NSNotificationCenter defaultCenter] removeObserver:observer2];

        dispatch_async(dispatch_get_main_queue(), ^{
            handler();
        });
    }];
}

+ (void)cleanupBeforeReload {
    dtx_log_info(@"Cleaning idling resource before RN load");

    for (dispatch_queue_t queue in _observedQueues) {
        NSString* queueName = [[NSString alloc] initWithUTF8String:dispatch_queue_get_label(queue) ?: queue.description.UTF8String];
        DTXSyncResourceVerboseLog(@"Removing sync resource for queue: %@ %p", queueName, queue);
        [DTXSyncManager untrackDispatchQueue:queue];
    }

    [_observedQueues removeAllObjects];

    // Adding delay before re-tracking so the resource dealloc won't trigger unregisteration (preventing race condition)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        _DTXTrackUIManagerQueue();
    });
}

static BOOL _isNewArchEnabled = NO;
static dispatch_once_t onceToken;

+ (BOOL)isNewArchEnabled
{
    dispatch_once(&onceToken, ^{
        Class delegateClass = NSClassFromString(@"RCTAppDelegate");
        SEL selector = NSSelectorFromString(@"newArchEnabled");
        Method originalMethod = class_getInstanceMethod(delegateClass, selector);

        if (delegateClass && originalMethod) {
            _isNewArchEnabled = ((BOOL (*)(id, SEL))method_getImplementation(originalMethod))(NULL, selector);
        }
    });

    return _isNewArchEnabled;
}

@end
