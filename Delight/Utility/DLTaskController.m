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
@synthesize controlConnection = _controlConnection;
@synthesize task = _task;
@synthesize sessionDelegate = _sessionDelegate;

- (id)init {
	self = [super init];
	
	_queue = [[NSOperationQueue alloc] init];
	
	return self;
}

- (void)dealloc {
	if ( _controlConnection ) {
		[_controlConnection cancel];
		self.controlConnection = nil;
	}
	[super dealloc];
}

- (void)requestSessionID {
	if ( _controlConnection ) return;
	
	// begin connection
	DLGetNewSessionTask * theTask = [[DLGetNewSessionTask alloc] init];
	theTask.taskController = self;
	_controlConnection = [[NSURLConnection alloc] initWithRequest:[theTask URLRequest] delegate:self];
	_task = theTask;
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
		UIBackgroundTaskIdentifier bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			// task expires. clean it up if it has not finished yet
		}];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			DLUploadVideoFileTask * theTask = [[DLUploadVideoFileTask alloc] init];
			theTask.recordingContext = aSession;
			theTask.backgroundTaskIdentifier = bgIdf;
			// make a synchronous call
			NSURLRequest * theRequest = [theTask URLRequest];
			if ( theRequest ) {
				NSHTTPURLResponse * theResponse = nil;
				NSError * error = nil;
				theTask.receivedData = (NSMutableData *)[NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&error];
				theTask.httpResponse = theResponse;
				if ( error == nil && ![theTask responseContainsError] ) {
					// upload completed successfully, notify Delight server
					[theTask processResponse];
				}
			}
		});
	}
}

#pragma mark Task Management
- (void)handleSessionTaskCompletion:(DLGetNewSessionTask *)aTask {
	[_sessionDelegate taskController:self didGetNewSessionContext:aTask.recordingContext];
	self.task = nil;
}

#pragma mark NSURLConnection delegate methods
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	_task.httpResponse = (NSHTTPURLResponse *)response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_task.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	// check if there's error
	NSString * str = [[NSString alloc] initWithData:_task.receivedData encoding:NSUTF8StringEncoding];
	NSLog(@"%@", str);
	if ( ![_task responseContainsError] ) {
		// process the data
		[_queue addOperationWithBlock:^{
			[_task processResponse];
		}];
	}
	self.controlConnection = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"error: %@", error);
}

@end
