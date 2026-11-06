//
//  DetoxSyncIdle.m
//  ReactNativeTesterApp
//
//  Swift has no +load, so this tiny Objective-C class preserves the original
//  AppDelegate's +load behavior of enqueueing an idle block at launch.
//

#import <Foundation/Foundation.h>
#import <DetoxSync/DetoxSync.h>

@interface DetoxSyncIdle : NSObject
@end

@implementation DetoxSyncIdle

+ (void)load
{
	@autoreleasepool
	{
		[DTXSyncManager enqueueIdleBlock:^{
			NSLog(@"💚 App is idle!");
		}];
	}
}

@end
