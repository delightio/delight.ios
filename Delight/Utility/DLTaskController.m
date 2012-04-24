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
#import "DLReachability.h"
#import <UIKit/UIKit.h>

@interface DLTaskController (PrivateMethods)

- (void)createUploadTasksForSession:(DLRecordingContext *)ctx priority:(NSOperationQueuePriority)aPriority;
/*!
 S3 pre-signed URL has an expiry date. If the pre-signed URL has been expired, we should get a new pre-signed URL
 */
- (void)renewUploadURLForSession:(DLRecordingContext *)ctx;

@end

@implementation DLTaskController
@synthesize queue = _queue;
@synthesize task = _task;
@synthesize sessionDelegate = _sessionDelegate;
@synthesize unfinishedContexts = _unfinishedContexts;
@synthesize baseDirectory = _baseDirectory;
@synthesize wifiReachability = _wifiReachability;
@synthesize containsIncompleteSessions = _containsIncompleteSessions;
@synthesize wifiConnected = _wifiConnected;

- (id)init {
	self = [super init];
	_containsIncompleteSessions = [[NSFileManager defaultManager] fileExistsAtPath:[self unfinishedRecordingContextsArchiveFilePath]];
	self.wifiReachability = [DLReachability reachabilityWithHostName:@"aws.amazon.com"];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleReachabilityChangedNotification:) name:kReachabilityChangedNotification object: nil];
	[_wifiReachability startNotifier];
	return self;
}

- (void)dealloc {
	[_wifiReachability stopNotifier];
	[_wifiReachability release];
	[_queue cancelAllOperations];
	[_queue release];
	[_unfinishedContexts release];
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
		// give priority to upload the current session
		[self createUploadTasksForSession:aSession priority:NSOperationQueuePriorityHigh];
		if ( _containsIncompleteSessions ) {
			// unarchive the file
			self.unfinishedContexts = [NSKeyedUnarchiver unarchiveObjectWithFile:[self unfinishedRecordingContextsArchiveFilePath]];
			for (DLRecordingContext * ctx in _unfinishedContexts) {
				[self createUploadTasksForSession:ctx priority:NSOperationQueuePriorityNormal];
			}
		}
	}
}

#pragma mark Session management
- (NSString *)unfinishedRecordingContextsArchiveFilePath {
	return [self.baseDirectory stringByAppendingPathComponent:@"UnfinishedRecordingContexts.archive"];
}

- (void)removeRecordingContext:(DLRecordingContext *)ctx {
	@synchronized(self) {
		// remove the context
		[_unfinishedContexts removeObject:ctx];
		// if there's no more items, remove the archive file
		if ( [_unfinishedContexts count] == 0 ) {
			[[NSFileManager defaultManager] removeItemAtPath:[self unfinishedRecordingContextsArchiveFilePath] error:nil];
		}
	}
}

#pragma mark Private Methods

- (void)createUploadTasksForSession:(DLRecordingContext *)ctx priority:(NSOperationQueuePriority)aPriority {
	// upload in the background
	UIBackgroundTaskIdentifier bgIdf = UIBackgroundTaskInvalid;
	if ( [ctx shouldCompleteTask:DLFinishedUpdateSession] ) {
		DLUpdateSessionTask * sessTask = [[DLUpdateSessionTask alloc] init];
		bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			// task expires. clean it up if it has not finished yet
			[sessTask cancel];
			[self saveUnfinishedRecordingContext:ctx];
			[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
		}];
		sessTask.taskController = self;
		sessTask.backgroundTaskIdentifier = bgIdf;
		sessTask.recordingContext = ctx;
		[self.queue addOperation:sessTask];
		[sessTask release];
	}
	if ( ctx.shouldRecordVideo && (!ctx.wifiUploadOnly || (_wifiConnected && ctx.wifiUploadOnly)) ) {
		if ( [ctx shouldCompleteTask:DLFinishedUploadVideoFile] ) {
			// check if the link has expired
			if ( [ctx.uploadURLExpiryDate timeIntervalSinceNow] > 5.0 ) {
				// uplaod URL is still valid. Continue to upload
				DLUploadVideoFileTask * uploadTask = [[DLUploadVideoFileTask alloc] init];
				bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
					// task expires. clean it up if it has not finished yet
					[uploadTask cancel];
					[self saveUnfinishedRecordingContext:ctx];
					[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
				}];
				uploadTask.taskController = self;
				uploadTask.backgroundTaskIdentifier = bgIdf;
				uploadTask.recordingContext = ctx;
				[self.queue addOperation:uploadTask];
				[uploadTask release];
			} else {
				// renew the upload URL
				[self renewUploadURLForSession:ctx];
			}
		} else if ( [ctx shouldCompleteTask:DLFinishedPostVideo] ) {
			DLPostVideoTask * postTask = [[DLPostVideoTask alloc] init];
			bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
				// task expires. clean it up if it has not finished yet
				[postTask cancel];
				[self saveUnfinishedRecordingContext:ctx];
				[[UIApplication sharedApplication] endBackgroundTask:bgIdf];
			}];
			postTask.taskController = self;
			postTask.backgroundTaskIdentifier = bgIdf;
			postTask.recordingContext = ctx;
			[self.queue addOperation:postTask];
			[postTask release];
		}
	}
}

- (void)renewUploadURLForSession:(DLRecordingContext *)ctx {
	
}

#pragma mark Task Management
- (void)handleSessionTaskCompletion:(DLGetNewSessionTask *)aTask {
	DLRecordingContext * ctx = aTask.recordingContext;
	if ( _containsIncompleteSessions && ctx.shouldRecordVideo ) {
		// suppress recording flag if there's video files pending upload
		ctx.shouldRecordVideo = NO;
	}
	// notify the delegate
	[_sessionDelegate taskController:self didGetNewSessionContext:aTask.recordingContext];
	self.task = nil;
}

- (void)saveUnfinishedRecordingContext:(DLRecordingContext *)ctx {
	if ( !ctx.loadedFromArchive && [ctx.finishedTaskIndex count] && !ctx.saved) {
		// contains incomplete task and require saving
		if ( _unfinishedContexts == nil ) {
			_unfinishedContexts = [[NSMutableArray alloc] initWithCapacity:4];
		}
		[self.unfinishedContexts addObject:ctx];
		NSString * sessFilePath = [self unfinishedRecordingContextsArchiveFilePath];
		ctx.saved = [NSKeyedArchiver archiveRootObject:_unfinishedContexts toFile:sessFilePath];
		_containsIncompleteSessions = YES;
	}
}

#pragma mark Notification
- (void)handleReachabilityChangedNotification:(NSNotification *)aNotification {
    NetworkStatus netStatus = [_wifiReachability currentReachabilityStatus];
//    BOOL connectionRequired = [_wifiReachability connectionRequired];
//	if ( !connectionRequired ) {
		if ( netStatus == ReachableViaWiFi ) {
			// we can upload video file
			_wifiConnected = YES;
		} else {
			_wifiConnected = NO;
		}
//	}
	//	NSLog(@"########## wifi reachable %d ###########", NM_WIFI_REACHABLE);
}

@end
