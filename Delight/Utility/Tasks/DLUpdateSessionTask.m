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
@synthesize sessionDidEnd = _sessionDidEnd;

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"https://%@/app_sessions/%@.xml", DL_BASE_URL, self.recordingContext.sessionID];
	NSString * paramStr = nil;
	NSString * usrID = self.recordingContext.appUserID;
	if ( usrID ) {
		paramStr = [NSString stringWithFormat:@"app_session[duration]=%.1f&app_session[app_user_id]=%@", [self.recordingContext.endTime timeIntervalSinceDate:self.recordingContext.startTime], [self stringByAddingPercentEscapes:self.recordingContext.appUserID]];
	} else {
		paramStr = [NSString stringWithFormat:@"app_session[duration]=%.1f", [self.recordingContext.endTime timeIntervalSinceDate:self.recordingContext.startTime]];
	}
	// the param needs to be put in query string. Not sure why. But, if not, it doesn't work
	// check here: http://stackoverflow.com/questions/3469061/nsurlrequest-cannot-handle-http-body-when-method-is-not-post
	NSString * fstr = [NSString stringWithFormat:@"%@?%@", urlStr, paramStr];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fstr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
//	[request setHTTPBody:[paramStr dataUsingEncoding:NSUTF8StringEncoding]];
	[request setValue:self.appToken	forHTTPHeaderField:@"X-NB-AuthToken"];
	[request setHTTPMethod:@"PUT"];
	return request;
}

- (void)processResponse {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"updated session: %@", str);
//	[str release];
	if ( _sessionDidEnd ) {
		[self.recordingContext setTaskFinished:DLFinishedUpdateSession];
		if ( [self.recordingContext allTasksFinished] ) {
			// all tasks are done. end the background task
			[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
			self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
			// remove the task from incomplete array
			[self.taskController removeRecordingContext:self.recordingContext];
		}
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.taskController handleSessionTaskCompletion:self];
		});
	}
}

@end
