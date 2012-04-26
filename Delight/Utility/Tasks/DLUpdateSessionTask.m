//
//  DLUpdateSessionTask.m
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLUpdateSessionTask.h"
#import "DLTaskController.h"

@implementation DLUpdateSessionTask

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"http://%@/app_sessions/%@.xml", DL_BASE_URL, self.recordingContext.sessionID];
	NSString * paramStr = [NSString stringWithFormat:@"app_session[duration]=%.1f", self.recordingContext.sessionID, [self.recordingContext.endTime timeIntervalSinceDate:self.recordingContext.startTime]];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
	[request setHTTPBody:[paramStr dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPMethod:@"PUT"];
	return request;
}

- (void)processResponse {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"updated session: %@", str);
//	[str release];
	[self.recordingContext setTaskFinished:DLFinishedUpdateSession];
	if ( [self.recordingContext allTasksFinished] ) {
		// all tasks are done. end the background task
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
		self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
		if ( self.recordingContext.loadedFromArchive ) {
			// remove the task from incomplete array
			[self.taskController removeRecordingContext:self.recordingContext];
		}
	}
}

@end
