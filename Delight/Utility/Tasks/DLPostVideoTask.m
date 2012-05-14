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
@synthesize trackName = _trackName;

- (id)initWithTrack:(NSString *)trcName appToken:(NSString *)aToken {
	self = [super initWithAppToken:aToken];
	_trackName = [trcName retain];
	return self;
}

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"https://%@/%@s.xml", DL_BASE_URL, _trackName];
	// get the URL for the specified track
	NSString * paramStr = [NSString stringWithFormat:@"%@[app_session_id]=%@", _trackName, self.recordingContext.sessionID];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
	NSData * theData = [paramStr dataUsingEncoding:NSUTF8StringEncoding];
	[request setHTTPBody:theData];
	[request setValue:[NSString stringWithFormat:@"%d", [theData length]] forHTTPHeaderField:@"Content-Length"];
	[request setValue:self.appToken	forHTTPHeaderField:@"X-NB-AuthToken"];
	[request setHTTPMethod:@"POST"];
	return request;
}

- (void)processResponse {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"posted video: %@", str);
//	[str release];
	[self.recordingContext setTaskFinished:DLFinishedPostVideo];
	if ( [self.recordingContext allTasksFinished] ) {
		DLLog(@"[Delight] recording uploaded, session: %@", self.recordingContext.sessionID);
		// all tasks are done. end the background task
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
		self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
		// remove the task from incomplete array
		[self.taskController removeRecordingContext:self.recordingContext];
	}
}

@end
