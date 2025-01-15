//
//  DTXSignpostSpy.m (DetoxSync)
//  Created by Asaf Korem (Wix.com) on 2025.
//

#import "DTXSignpostSpy.h"
#import "DTXSignpostSyncResource.h"
#import "fishhook.h"
#import <os/signpost.h>

@implementation DTXSignpostSpy

typedef void (*os_signpost_interval_begin_type)(os_log_t, os_signpost_id_t, const char* _Nonnull, const char* _Nonnull, ...);
typedef void (*os_signpost_interval_end_type)(os_log_t, os_signpost_id_t, const char* _Nonnull, const char* _Nonnull, ...);

static os_signpost_interval_begin_type __orig_os_signpost_interval_begin;
static void __dtx_os_signpost_interval_begin(os_log_t dso, os_signpost_id_t sid, const char* name, const char* fmt, ...)
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Test signpost begin" userInfo:nil];

//
//    va_list args;
//    va_start(args, fmt);
//    __orig_os_signpost_interval_begin(dso, sid, name, fmt, args);
//    va_end(args);
}

static os_signpost_interval_end_type __orig_os_signpost_interval_end;
static void __dtx_os_signpost_interval_end(os_log_t dso, os_signpost_id_t sid, const char* name, const char* fmt, ...)
{
    if(strcmp(name, "Systrace") == 0)
    {
        [[DTXSignpostSyncResource sharedInstance] trackSignpostEnd:[NSNumber numberWithUnsignedLongLong:sid]];
    }

    va_list args;
    va_start(args, fmt);
    __orig_os_signpost_interval_end(dso, sid, name, fmt, args);
    va_end(args);
}

+ (void)load
{
    @autoreleasepool
    {
        struct rebinding r[] = (struct rebinding[]) {
            {
                .name = "os_signpost_interval_begin",
                .replacement = (void*)&__dtx_os_signpost_interval_begin,
                .replaced = (void*)&__orig_os_signpost_interval_begin
            },
            {
                .name = "os_signpost_interval_end",
                .replacement = (void*)&__dtx_os_signpost_interval_end,
                .replaced = (void*)&__orig_os_signpost_interval_end
            }
        };
        rebind_symbols(r, 2);
    }
}

@end
