//
//  DLPostVideoTask.m
//  Delight
//
//  Created by Bill So on 4/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLPostVideoTask.h"

@implementation DLPostVideoTask

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"http://%@/videos.xml", DL_BASE_URL];
	NSArray * urlComponents = [self.recordingContext.uploadURLString componentsSeparatedByString:@"?"];
	NSString * paramStr = [NSString stringWithFormat:@"video[uri]=%@&video[app_session_id]=%@", [self stringByAddingPercentEscapes:[urlComponents objectAtIndex:0]], self.recordingContext.sessionID];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
	[request setHTTPBody:[paramStr dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPMethod:@"POST"];
	return request;
}

- (void)processResponse {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"received data: %@", str);
//	[str release];
	[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
	self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
}

@end
