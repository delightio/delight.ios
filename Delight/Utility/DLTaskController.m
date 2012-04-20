//
//  DLTaskController.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTaskController.h"
#import "Delight.h"
#import "DLRecordingContext.h"
#import <UIKit/UIKit.h>

@implementation DLTaskController
@synthesize queue = _queue;
@synthesize task = _task;
@synthesize sessionDelegate = _sessionDelegate;
@synthesize incompleteSessions = _incompleteSessions;
@synthesize baseDirectory = _baseDirectory;

- (void)dealloc {
	[_queue cancelAllOperations];
	[_queue release];
	[_incompleteSessions release];
	[_task release];
	[_baseDirectory release];
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
		UIBackgroundTaskIdentifier bgIdf = UIBackgroundTaskInvalid;
		if ( [aSession shouldCompleteTask:DLFinishedUpdateSession] ) {
			DLUpdateSessionTask * sessTask = [[DLUpdateSessionTask alloc] init];
			bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
				// task expires. clean it up if it has not finished yet
				[sessTask cancel];
				[self saveIncompleteSession:aSession];
				[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
			}];
			sessTask.taskController = self;
			sessTask.backgroundTaskIdentifier = bgIdf;
			sessTask.recordingContext = aSession;
			[self.queue addOperation:sessTask];
			[sessTask release];
		}
		if ( aSession.shouldRecordVideo ) {
			if ( [aSession shouldCompleteTask:DLFinishedUploadVideoFile] ) {
				DLUploadVideoFileTask * uploadTask = [[DLUploadVideoFileTask alloc] init];
				bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
					// task expires. clean it up if it has not finished yet
					[uploadTask cancel];
					[self saveIncompleteSession:aSession];
					[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
				}];
				uploadTask.taskController = self;
				uploadTask.backgroundTaskIdentifier = bgIdf;
				uploadTask.recordingContext = aSession;
				[self.queue addOperation:uploadTask];
				[uploadTask release];
			} else if ( [aSession shouldCompleteTask:DLFinishedPostVideo] ) {
				DLPostVideoTask * postTask = [[DLPostVideoTask alloc] init];
				bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
					// task expires. clean it up if it has not finished yet
					[postTask cancel];
					[self saveIncompleteSession:aSession];
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

- (void)saveIncompleteSession:(DLRecordingContext *)ctx {
	if ( [ctx.finishedTaskIndex count] && !ctx.saved) {
		// contains incomplete task and require saving
		
	}
}



@end
