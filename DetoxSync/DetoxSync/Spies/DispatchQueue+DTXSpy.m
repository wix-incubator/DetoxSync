//
//  DispatchQueue+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DispatchQueue+DTXSpy.h"
#import "DTXDispatchQueueSyncResource-Private.h"
#import "fishhook.h"
#import "DTXOrigDispatch.h"
#import "DTXSyncManager-Private.h"
@import Darwin;

#define unlikely dtx_unlikely

DTX_ALWAYS_INLINE
void __dispatch_wrapper_func_2param(void (*func)(id, id), NSString* name, dispatch_queue_t param1, dispatch_block_t param2)
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:param1];
	DTXDispatchBlockProxy* proxy = nil;
	if(sr) { proxy = [DTXDispatchBlockProxy proxyWithBlock:param2 operation:name]; }
	[sr addWorkBlockProxy:proxy operation:name];
	func(param1, ^ {
		param2();
		[sr removeWorkBlockProxy:proxy operation:name];
	});
}

void __dispatch_wrapper_func_3param(void (*func)(id, id, id), NSString* name, id param1, dispatch_queue_t param2, dispatch_block_t param3)
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:param2];
	DTXDispatchBlockProxy* proxy = nil;
	if(sr) { proxy = [DTXDispatchBlockProxy proxyWithBlock:param3 operation:name]; }
	[sr addWorkBlockProxy:proxy operation:name];
	func(param1, param2, ^ {
		param3();
		[sr removeWorkBlockProxy:proxy operation:name];
	});
}

static void (*__orig_dispatch_sync)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param((void*)__orig_dispatch_sync, @"dispatch_sync", queue, block);
}

static void (*__orig_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_async(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param((void*)__orig_dispatch_async, @"dispatch_async", queue, block);
}

static void (*__orig_dispatch_async_and_wait)(dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_async_and_wait(dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_2param((void*)__orig_dispatch_async_and_wait, @"dispatch_async_and_wait", queue, block);
}

typedef enum {
	DISPATCH_CLOCK_UPTIME,
	DISPATCH_CLOCK_MONOTONIC,
	DISPATCH_CLOCK_WALL,
#define DISPATCH_CLOCK_COUNT  (DISPATCH_CLOCK_WALL + 1)
} dispatch_clock_t;

#define DISPATCH_UP_OR_MONOTONIC_TIME_MASK	(1ULL << 63)
#define DISPATCH_WALLTIME_MASK	(1ULL << 62)
#define DISPATCH_TIME_MAX_VALUE (DISPATCH_WALLTIME_MASK - 1)

static inline uint64_t
_dispatch_get_nanoseconds(void)
{
#if TARGET_OS_MAC
	return clock_gettime_nsec_np(CLOCK_REALTIME);
#elif HAVE_DECL_CLOCK_REALTIME
	struct timespec ts;
	dispatch_assume_zero(clock_gettime(CLOCK_REALTIME, &ts));
	return _dispatch_timespec_to_nano(ts);
#elif defined(_WIN32)
	static const uint64_t kNTToUNIXBiasAdjustment = 11644473600 * NSEC_PER_SEC;
	// FILETIME is 100-nanosecond intervals since January 1, 1601 (UTC).
	FILETIME ft;
	ULARGE_INTEGER li;
	GetSystemTimePreciseAsFileTime(&ft);
	li.LowPart = ft.dwLowDateTime;
	li.HighPart = ft.dwHighDateTime;
	return li.QuadPart * 100ull - kNTToUNIXBiasAdjustment;
#else
	struct timeval tv;
	dispatch_assert_zero(gettimeofday(&tv, NULL));
	return _dispatch_timeval_to_nano(tv);
#endif
}

DISPATCH_ALWAYS_INLINE
static inline void
_dispatch_time_to_clock_and_value(dispatch_time_t time,
								  dispatch_clock_t *clock, uint64_t *value)
{
	uint64_t actual_value;
	if ((int64_t)time < 0) {
		// Wall time or mach continuous time
		if (time & DISPATCH_WALLTIME_MASK) {
			// Wall time (value 11 in bits 63, 62)
			*clock = DISPATCH_CLOCK_WALL;
			actual_value = time == DISPATCH_WALLTIME_NOW ?
			_dispatch_get_nanoseconds() : (uint64_t)-time;
		} else {
			// Continuous time (value 10 in bits 63, 62).
			*clock = DISPATCH_CLOCK_MONOTONIC;
			actual_value = time & ~DISPATCH_UP_OR_MONOTONIC_TIME_MASK;
		}
	} else {
		*clock = DISPATCH_CLOCK_UPTIME;
		actual_value = time;
	}
	
	// Range-check the value before returning.
	*value = actual_value > DISPATCH_TIME_MAX_VALUE ? DISPATCH_TIME_FOREVER
	: actual_value;
}

#define HAVE_MACH_ABSOLUTE_TIME 1

static inline uint64_t
_dispatch_uptime(void)
{
#if HAVE_MACH_ABSOLUTE_TIME
	return mach_absolute_time();
#elif HAVE_DECL_CLOCK_MONOTONIC && defined(__linux__)
	struct timespec ts;
	dispatch_assume_zero(clock_gettime(CLOCK_MONOTONIC, &ts));
	return _dispatch_timespec_to_nano(ts);
#elif HAVE_DECL_CLOCK_UPTIME && !defined(__linux__)
	struct timespec ts;
	dispatch_assume_zero(clock_gettime(CLOCK_UPTIME, &ts));
	return _dispatch_timespec_to_nano(ts);
#elif defined(_WIN32)
	ULONGLONG ullUnbiasedTime;
	_dispatch_QueryUnbiasedInterruptTimePrecise(&ullUnbiasedTime);
	return ullUnbiasedTime * 100;
#else
#error platform needs to implement _dispatch_uptime()
#endif
}

static inline uint64_t
_dispatch_monotonic_time(void)
{
#if HAVE_MACH_ABSOLUTE_TIME
	return mach_continuous_time();
#elif defined(__linux__)
	struct timespec ts;
	dispatch_assume_zero(clock_gettime(CLOCK_BOOTTIME, &ts));
	return _dispatch_timespec_to_nano(ts);
#elif HAVE_DECL_CLOCK_MONOTONIC
	struct timespec ts;
	dispatch_assume_zero(clock_gettime(CLOCK_MONOTONIC, &ts));
	return _dispatch_timespec_to_nano(ts);
#elif defined(_WIN32)
	ULONGLONG ullTime;
	_dispatch_QueryInterruptTimePrecise(&ullTime);
	return ullTime * 100ull;
#else
#error platform needs to implement _dispatch_monotonic_time()
#endif
}

#if defined(__i386__) || defined(__x86_64__) || !HAVE_MACH_ABSOLUTE_TIME
#define DISPATCH_TIME_UNIT_USES_NANOSECONDS 1
#else
#define DISPATCH_TIME_UNIT_USES_NANOSECONDS 0
#endif

#if DISPATCH_TIME_UNIT_USES_NANOSECONDS
// x86 currently implements mach time in nanoseconds
// this is NOT likely to change
DISPATCH_ALWAYS_INLINE
static inline uint64_t
_dispatch_time_mach2nano(uint64_t machtime)
{
	return machtime;
}
#else
#define DISPATCH_USE_HOST_TIME 1
typedef struct _dispatch_host_time_data_s {
	long double frac;
	bool ratio_1_to_1;
} _dispatch_host_time_data_s;

static _dispatch_host_time_data_s _dispatch_host_time_data;

static void
_dispatch_host_time_init(mach_timebase_info_data_t *tbi)
{
	_dispatch_host_time_data.frac = tbi->numer;
	_dispatch_host_time_data.frac /= tbi->denom;
	_dispatch_host_time_data.ratio_1_to_1 = (tbi->numer == tbi->denom);
}

__attribute__((constructor))
void
_dispatch_time_init(void)
{
	mach_timebase_info_data_t tbi;
	_dispatch_host_time_init(&tbi);
}

static uint64_t
_dispatch_mach_host_time_mach2nano(uint64_t machtime)
{
	_dispatch_host_time_data_s *const data = &_dispatch_host_time_data;
	if (unlikely(!machtime || data->ratio_1_to_1)) {
		return machtime;
	}
	if (machtime >= INT64_MAX) {
		return INT64_MAX;
	}
	long double big_tmp = ((long double)machtime * data->frac) + .5L;
	if (unlikely(big_tmp >= INT64_MAX)) {
		return INT64_MAX;
	}
	return (uint64_t)big_tmp;
}

static inline uint64_t
_dispatch_time_mach2nano(uint64_t machtime)
{
	return _dispatch_mach_host_time_mach2nano(machtime);
}
#endif // DISPATCH_USE_HOST_TIME

uint64_t
_dispatch_timeout(dispatch_time_t when)
{
	dispatch_time_t now;
	if (when == DISPATCH_TIME_FOREVER) {
		return DISPATCH_TIME_FOREVER;
	}
	if (when == DISPATCH_TIME_NOW) {
		return 0;
	}
	
	dispatch_clock_t clock;
	uint64_t value;
	_dispatch_time_to_clock_and_value(when, &clock, &value);
	if (clock == DISPATCH_CLOCK_WALL) {
		now = _dispatch_get_nanoseconds();
		return now >= value ? 0 : value - now;
	} else {
		if (clock == DISPATCH_CLOCK_UPTIME) {
			now = _dispatch_uptime();
		} else {
			now = _dispatch_monotonic_time();
		}
		return now >= value ? 0 : _dispatch_time_mach2nano(value - now);
	}
}

uint64_t
_dispatch_time_nanoseconds_since_epoch(dispatch_time_t when)
{
	if (when == DISPATCH_TIME_FOREVER) {
		return DISPATCH_TIME_FOREVER;
	}
	if ((int64_t)when < 0) {
		// time in nanoseconds since the POSIX epoch already
		return (uint64_t)-(int64_t)when;
	}
	
	// Up time or monotonic time.
	return _dispatch_get_nanoseconds() + _dispatch_timeout(when);
}

static void (*__orig_dispatch_after)(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
	DTXDispatchQueueSyncResource* sr = [DTXDispatchQueueSyncResource _existingSyncResourceWithQueue:queue];
	
	BOOL shouldTrack = sr != nil;
	
	uint64_t nanosecondsSinceEpoch = _dispatch_time_nanoseconds_since_epoch(when);
	NSTimeInterval secondsSinceEpoch = (double)nanosecondsSinceEpoch / (double)1000000000;
	NSTimeInterval timeFromNow = secondsSinceEpoch - [NSDate.date timeIntervalSince1970];
//	NSLog(@"🤦‍♂️ %@", @(timeFromNow));
	if(shouldTrack && isinf(DTXSyncManager.maximumAllowedDelayedActionTrackingDuration) == NO)
	{
		shouldTrack = DTXSyncManager.maximumAllowedDelayedActionTrackingDuration >= timeFromNow;
		
		if(shouldTrack == NO)
		{
			DTXSyncResourceVerboseLog(@"⏲ Ignoring dispatch_after with work block “%@”; failure reason: \"%@\"", [block debugDescription], [NSString stringWithFormat:@"duration>%@", @(timeFromNow)]);
		}
	}
	
	DTXDispatchBlockProxy* proxy = nil;
	if(shouldTrack)
	{
		proxy = [DTXDispatchBlockProxy proxyWithBlock:block operation:@"dispatch_after"];
		[sr addWorkBlockProxy:proxy operation:@"dispatch_after"];
	}
	
	__orig_dispatch_after(when, queue, ^{
		block();
		
		if(shouldTrack)
		{
			[sr removeWorkBlockProxy:proxy operation:@"dispatch_after"];
		}
	});
}
void untracked_dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
	__orig_dispatch_after(when, queue, block);
}

static void (*__orig_dispatch_group_async)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param((void*)__orig_dispatch_group_async, @"dispatch_group_async", group, queue, block);
}

static void (*__orig_dispatch_group_notify)(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
static void __detox_sync_dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
{
	__dispatch_wrapper_func_3param((void*)__orig_dispatch_group_notify, @"dispatch_group_notify", group, queue, block);
}

static dispatch_queue_t (*__orig_dispatch_queue_create)(const char *_Nullable label, dispatch_queue_attr_t _Nullable attr);
dispatch_queue_t __detox_sync_dispatch_queue_create(const char *_Nullable label, dispatch_queue_attr_t _Nullable attr)
{
	dispatch_queue_t rv = __orig_dispatch_queue_create(label, attr);
	
	if(label != NULL && strncmp(label, "com.apple.NSURLSession-work", strlen("com.apple.NSURLSession-work")) == 0)
	{
		[DTXSyncManager trackDispatchQueue:rv];
	}
	
	return rv;
}


__attribute__((constructor))
static void _install_dispatchqueue_spy(void)
{
//	dispatch_async
	struct rebinding r[] = (struct rebinding[]) {
		"dispatch_async", __detox_sync_dispatch_async, (void**)&__orig_dispatch_async,
		"dispatch_sync", __detox_sync_dispatch_sync, (void**)&__orig_dispatch_sync,
		"dispatch_async_and_wait", __detox_sync_dispatch_async_and_wait, (void**)&__orig_dispatch_async_and_wait,
		"dispatch_after", __detox_sync_dispatch_after, (void**)&__orig_dispatch_after,
		"dispatch_group_async", __detox_sync_dispatch_group_async, (void**)&__orig_dispatch_group_async,
		"dispatch_group_notify", __detox_sync_dispatch_group_notify, (void**)&__orig_dispatch_group_notify,
		"dispatch_queue_create", __detox_sync_dispatch_queue_create, (void**)&__orig_dispatch_queue_create,
	};
	rebind_symbols(r, sizeof(r) / sizeof(struct rebinding));
}
