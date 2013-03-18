//
//  DLUpdateSessionTask.m
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLUpdateSessionTask.h"
#import "DLTaskController.h"
#import "DLMetrics.h"

@implementation DLUpdateSessionTask
@synthesize sessionDidEnd = _sessionDidEnd;

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"%@://%@/%@s/%@.xml", DL_BASE_SCHEME, DL_BASE_URL, self.taskController.sessionObjectName, self.recordingContext.sessionID];
    
    NSMutableString * propertyParams = [NSMutableString string];
    for (NSString * key in [self.recordingContext.userProperties allKeys]) {
        id value = [self.recordingContext.userProperties objectForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            value = [self stringByAddingPercentEscapes:value];
        }
        [propertyParams appendFormat:@"&%@[properties][%@]=%@", self.taskController.sessionObjectName, [self stringByAddingPercentEscapes:key], value];
    }
    
    NSMutableString * metricsParams = [NSMutableString string];
    if (self.recordingContext.metrics.privateViewCount) {
        [metricsParams appendFormat:@"&%@[metrics][private_view_count]=%i", self.taskController.sessionObjectName, self.recordingContext.metrics.privateViewCount];
    }
    if (self.recordingContext.metrics.keyboardHiddenCount) {
        [metricsParams appendFormat:@"&%@[metrics][keyboard_hidden_count]=%i", self.taskController.sessionObjectName, self.recordingContext.metrics.keyboardHiddenCount];
    }
    switch (self.recordingContext.metrics.stopReason) {
        case DLMetricsStopReasonBackground:
            [metricsParams appendFormat:@"&%@[metrics][stop_by_background]=1", self.taskController.sessionObjectName];
            break;
        case DLMetricsStopReasonManual:
            [metricsParams appendFormat:@"&%@[metrics][stop_by_manual]=1", self.taskController.sessionObjectName];
            break;
        case DLMetricsStopReasonTimeLimit:
            [metricsParams appendFormat:@"&%@[metrics][stop_by_recording_limit]=1", self.taskController.sessionObjectName];
            break;
    }
    
    NSString * paramStr = [NSString stringWithFormat:@"%@[duration]=%.1f%@%@", self.taskController.sessionObjectName, [self.recordingContext.endTime timeIntervalSinceDate:self.recordingContext.startTime], propertyParams, metricsParams];
    
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
			// all tasks are done
			// remove the task from incomplete array
			[self.taskController removeRecordingContext:self.recordingContext];
		}
		// end the background task
		[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
		self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.taskController handleSessionTaskCompletion:self];
		});
	}
}

@end
