//
//  NSURLSession+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/4/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "NSURLSession+DTXSpy.h"
#import "NSURLSessionTask+DTXSpy.h"

@interface NSURLSession ()

- (id)_dataTaskWithTaskForClass:(id)arg1;

@end

@import ObjectiveC;

@implementation NSURLSession (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		NSError* error;
		if(NSProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13)
		{
			Class cls = NSClassFromString(@"__NSURLSessionLocal");
			Method m2 = class_getInstanceMethod(NSURLSession.class, @selector(__detox_sync__dataTaskWithTaskForClass:));
			class_addMethod(cls, @selector(__detox_sync__dataTaskWithTaskForClass:), method_getImplementation(m2), method_getTypeEncoding(m2));
			
			[cls jr_swizzleMethod:@selector(_dataTaskWithTaskForClass:) withMethod:@selector(__detox_sync__dataTaskWithTaskForClass:) error:&error];
		}
		else
		{
			[NSURLSession.class jr_swizzleMethod:@selector(dataTaskWithRequest:completionHandler:) withMethod:@selector(__detox_sync_dataTaskWithRequest:completionHandler:) error:&error];
		}
	}
}

- (NSURLSessionDataTask *)__detox_sync__dataTaskWithTaskForClass:(id)arg1
{
	id rv = [self __detox_sync__dataTaskWithTaskForClass:arg1];
	
	return rv;
}

- (NSURLSessionDataTask *)__detox_sync_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler
{
	id rv = [self __detox_sync_dataTaskWithRequest:request completionHandler:completionHandler];
	
	return rv;
}

@end
