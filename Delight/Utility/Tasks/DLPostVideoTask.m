//
//  DLPostVideoTask.m
//  Delight
//
//  Created by Bill So on 4/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLPostVideoTask.h"
#import "DLTaskController.h"

@implementation DLPostVideoTask

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"http://%@/videos.xml", DL_BASE_URL];
	NSArray * urlComponents = [self.recordingContext.uploadURLString componentsSeparatedByString:@"?"];
	NSString * paramStr = [NSString stringWithFormat:@"video[uri]=%@&video[app_session_id]=%@", [self stringByAddingPercentEscapes:[urlComponents objectAtIndex:0]], self.recordingContext.sessionID];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
	NSData * theData = [paramStr dataUsingEncoding:NSUTF8StringEncoding];
	[request setHTTPBody:theData];
	[request setValue:[NSString stringWithFormat:@"%d", [theData length]] forHTTPHeaderField:@"Content-Length"];
	[request setHTTPMethod:@"POST"];
	return request;
}

- (void)processResponse {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"posted video: %@", str);
//	[str release];
	[self.recordingContext setTaskFinished:DLFinishedPostVideo];
	if ( [self.recordingContext allTasksFinished] ) {
		DLDebugLog(@"recording uploaded, session: %@", self.recordingContext.sessionID);
		// all tasks are done. end the background task
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
		self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
		// remove the task from incomplete array
		[self.taskController removeRecordingContext:self.recordingContext];
	}
}

@end
