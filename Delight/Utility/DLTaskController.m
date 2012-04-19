//
//  DLTaskController.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTaskController.h"
#import "Delight.h"
#import <UIKit/UIKit.h>

@implementation DLTaskController
@synthesize queue = _queue;
@synthesize task = _task;
@synthesize sessionDelegate = _sessionDelegate;

- (void)dealloc {
	[_queue cancelAllOperations];
	[_queue release];
	[super dealloc];
}

- (NSOperationQueue *)queue {
	if ( _queue == nil ) {
		_queue = [[NSOperationQueue alloc] init];
	}
	return _queue;
}

- (void)requestSessionIDWithAppToken:(NSString *)aToken {
	if ( _task ) return;
	
	// begin connection
	DLGetNewSessionTask * theTask = [[DLGetNewSessionTask alloc] init];
	theTask.appToken = aToken;
	theTask.taskController = self;
	_task = theTask;
	[self.queue addOperation:theTask];
}

- (void)uploadSession:(DLRecordingContext *)aSession {
	// check if we can run background task
	UIDevice* device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)]) backgroundSupported = device.multitaskingSupported;
	
	if ( !backgroundSupported ) {
		// upload next time when the app is launched
		return;
	} else {
		// upload in the background
		UIBackgroundTaskIdentifier bgIdf;
		if ( ![aSession didFinishTask:DLFinishedUpdateSession] ) {
			DLUpdateSessionTask * sessTask = [[DLUpdateSessionTask alloc] init];
			bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
				// task expires. clean it up if it has not finished yet
				[sessTask cancel];
				[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
			}];
			sessTask.taskController = self;
			sessTask.backgroundTaskIdentifier = bgIdf;
			sessTask.recordingContext = aSession;
			[self.queue addOperation:sessTask];
			[sessTask release];
		}
		if ( aSession.shouldRecordVideo ) {
			if ( ![aSession didFinishTask:DLFinishedUploadVideoFile] ) {
				DLUploadVideoFileTask * uploadTask = [[DLUploadVideoFileTask alloc] init];
				bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
					// task expires. clean it up if it has not finished yet
					[uploadTask cancel];
					[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
				}];
				uploadTask.taskController = self;
				uploadTask.backgroundTaskIdentifier = bgIdf;
				uploadTask.recordingContext = aSession;
				[self.queue addOperation:uploadTask];
				[uploadTask release];
			} else if ( ![aSession didFinishTask:DLFinishedPostVideo] ) {
				DLPostVideoTask * postTask = [[DLPostVideoTask alloc] init];
				bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
					// task expires. clean it up if it has not finished yet
					[postTask cancel];
					[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
				}];
				postTask.taskController = self;
				postTask.backgroundTaskIdentifier = bgIdf;
				postTask.recordingContext = aSession;
				[self.queue addOperation:postTask];
				[postTask release];
			}
		}
	}
}

#pragma mark Task Management
- (void)handleSessionTaskCompletion:(DLGetNewSessionTask *)aTask {
	[_sessionDelegate taskController:self didGetNewSessionContext:aTask.recordingContext];
	self.task = nil;
}

//#pragma mark NSURLConnection delegate methods
//- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
//	_task.httpResponse = (NSHTTPURLResponse *)response;
//}
//
//- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
//	[_task.receivedData appendData:data];
//}
//
//- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
//	// check if there's error
////	NSString * str = [[NSString alloc] initWithData:_task.receivedData encoding:NSUTF8StringEncoding];
////	NSLog(@"%@", str);
////	[str release];
//	if ( ![_task responseContainsError] ) {
//		// process the data
//		[_queue addOperationWithBlock:^{
//			[_task processResponse];
//		}];
//	}
//	self.controlConnection = nil;
//}
//
//- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
//	NSLog(@"error: %@", error);
//}

@end
