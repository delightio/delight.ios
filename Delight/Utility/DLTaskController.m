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
#import "DLTouch.h"
#import "DLOrientationChange.h"
#import <UIKit/UIKit.h>

@interface DLTaskController (PrivateMethods)

- (void)createUploadTasksForSession:(DLRecordingContext *)ctx priority:(NSOperationQueuePriority)aPriority;
/*!
 S3 pre-signed URL has an expiry date. If the pre-signed URL has been expired, we should get a new pre-signed URL
 */
- (void)renewUploadURLForSession:(DLRecordingContext *)ctx wtihTrack:(NSString *)trcName;
- (void)uploadSession:(DLRecordingContext *)aSession;
- (void)archiveTouchesForSession:(DLRecordingContext *)aSession;
- (void)archiveOrientationChangesForSession:(DLRecordingContext *)aSession;
- (NSString *)touchesFilePathForSession:(DLRecordingContext *)ctx;
- (NSString *)orientationFilePathForSession:(DLRecordingContext *)ctx;

@end

@implementation DLTaskController
@synthesize appToken = _appToken;
@synthesize queue = _queue;
@synthesize task = _task;
@synthesize sessionDelegate = _sessionDelegate;
@synthesize unfinishedContexts = _unfinishedContexts;
@synthesize baseDirectory = _baseDirectory;
@synthesize wifiReachability = _wifiReachability;
@synthesize containsIncompleteSessions = _containsIncompleteSessions;
@synthesize wifiConnected = _wifiConnected;
@synthesize networkStatusString;
@synthesize sessionObjectName = _sessionObjectName;

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
	[_appToken release];
    [_sessionObjectName release];
	[super dealloc];
}

- (NSOperationQueue *)queue {
	if ( _queue == nil ) {
		_queue = [[NSOperationQueue alloc] init];
	}
	return _queue;
}

- (void)archiveTouchesForSession:(DLRecordingContext *)aSession {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString * errStr = nil;
	NSArray * allTouches = aSession.touches;
	NSMutableDictionary * rootDict = [NSMutableDictionary dictionaryWithCapacity:3];
	NSMutableArray * dictTouches = [NSMutableArray arrayWithCapacity:[allTouches count]];
	for (DLTouch * theTouch in allTouches) {
		[dictTouches addObject:[theTouch dictionaryRepresentation]];
	}
	[rootDict setObject:dictTouches forKey:@"touches"];
	// set touch bounds
	[rootDict setObject:NSStringFromCGRect(aSession.touchBounds) forKey:@"touchBounds"];
	[rootDict setObject:@"0.2" forKey:@"formatVersion"];
	
	NSData * theData = [NSPropertyListSerialization dataFromPropertyList:rootDict format:NSPropertyListXMLFormat_v1_0 errorDescription:&errStr];
	NSString * touchesPath = [self touchesFilePathForSession:aSession];
	[theData writeToFile:touchesPath atomically:NO];
	// set file path
	[aSession.sourceFilePaths setObject:touchesPath forKey:DLTouchTrackKey];
	[pool release];
}

- (void)archiveOrientationChangesForSession:(DLRecordingContext *)aSession {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString * errStr = nil;
	NSArray * allOrientationChanges = aSession.orientationChanges;
	NSMutableDictionary * rootDict = [NSMutableDictionary dictionaryWithCapacity:3];
	NSMutableArray * dictOrientationChanges = [NSMutableArray arrayWithCapacity:[allOrientationChanges count]];
	for (DLOrientationChange * theOrientationChange in allOrientationChanges) {
		[dictOrientationChanges addObject:[theOrientationChange dictionaryRepresentation]];
	}
	[rootDict setObject:dictOrientationChanges forKey:@"orientationChanges"];
	
	NSData * theData = [NSPropertyListSerialization dataFromPropertyList:rootDict format:NSPropertyListXMLFormat_v1_0 errorDescription:&errStr];
	NSString * orientationPath = [self orientationFilePathForSession:aSession];
	[theData writeToFile:orientationPath atomically:NO];
	// set file path
	[aSession.sourceFilePaths setObject:orientationPath forKey:DLOrientationTrackKey];
	[pool release];
}

- (void)requestSessionIDWithAppToken:(NSString *)aToken {
	if ( _task ) return;
	
	if ( !firstReachabilityNotificationReceived || [_wifiReachability currentReachabilityStatus] == NotReachable ) {
		// signal the flag to make a connection
		pendingRequestSessionForFirstReachabilityNotification = YES;
		self.appToken = aToken;
		return;
	}
	
	// begin connection
	DLGetNewSessionTask * theTask = [[DLGetNewSessionTask alloc] initWithAppToken:aToken];
	theTask.taskController = self;
	_task = theTask;
	[self.queue addOperation:theTask];
}

- (void)prepareSessionUpload:(DLRecordingContext *)aSession {
	if ( aSession == nil ) return;
	BOOL backgroundSupported = NO;
	UIDevice* device = [UIDevice currentDevice];
	if ([device respondsToSelector:@selector(isMultitaskingSupported)]) backgroundSupported = device.multitaskingSupported;
	
	if ( backgroundSupported ) {
		bgTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			[self saveUnfinishedRecordingContext:aSession];
			[[UIApplication sharedApplication] endBackgroundTask:bgTaskIdentifier];
		}];
		[self.queue addOperationWithBlock:^{
			// save file touches file from session
			[self archiveTouchesForSession:aSession];
            [self archiveOrientationChangesForSession:aSession];
			// create tasks to upload
			[self uploadSession:aSession];
			[[UIApplication sharedApplication] endBackgroundTask:bgTaskIdentifier];
		}];
	} else {
		// if the system does not support background processing, we have to save the touches in main thread.
		[self archiveTouchesForSession:aSession];
        [self archiveOrientationChangesForSession:aSession];        
	}
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
		} else {
			self.unfinishedContexts = [NSMutableArray arrayWithObject:aSession];
		}
	}
}

- (void)updateSession:(DLRecordingContext *)aSession {
	if ( aSession == nil ) return;
	if ( _task ) return;
	DLUpdateSessionTask * theTask = [[DLUpdateSessionTask alloc] initWithAppToken:_appToken];
	_task = theTask;
	theTask.recordingContext = aSession;
	theTask.taskController = self;
	[self.queue addOperation:theTask];
}

#pragma mark Session management
- (NSString *)unfinishedRecordingContextsArchiveFilePath {
	return [self.baseDirectory stringByAppendingPathComponent:@"UnfinishedRecordingContexts.archive"];
}

- (NSString *)touchesFilePathForSession:(DLRecordingContext *)ctx {
	return [self.baseDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"touches-%@.plist", ctx.sessionID]];
}

- (NSString *)orientationFilePathForSession:(DLRecordingContext *)ctx {
    return [self.baseDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"orientation-%@.plist", ctx.sessionID]];
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
		DLUpdateSessionTask * sessTask = [[DLUpdateSessionTask alloc] initWithAppToken:_appToken];
		sessTask.sessionDidEnd = YES;
		bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			// task expires. clean it up if it has not finished yet
			[sessTask cancel];
			[self saveUnfinishedRecordingContext:ctx];
			[[UIApplication sharedApplication] endBackgroundTask:sessTask.backgroundTaskIdentifier];
		}];
		sessTask.taskController = self;
		sessTask.backgroundTaskIdentifier = bgIdf;
		sessTask.recordingContext = ctx;
		[self.queue addOperation:sessTask];
		[sessTask release];
	}
	if ( ctx.shouldRecordVideo && (!ctx.wifiUploadOnly || (_wifiConnected && ctx.wifiUploadOnly)) ) {
		// check to see if each track has been uploaded
		NSDictionary * theTracks = ctx.tracks;
		for (NSString * theKey in theTracks) {
			DLDebugLog(@"checking track: %@", theKey);
			if ( [ctx shouldUploadFileForTrackName:theKey] ) {
				DLDebugLog(@"uploading track: %@", theKey);
				// we haven't uploaded this track
				NSDictionary * curTrack = [theTracks objectForKey:theKey];
				if ( [ctx.sourceFilePaths objectForKey:theKey] && [[curTrack objectForKey:DLTrackExpiryDateKey] timeIntervalSinceNow] > 5.0 ) {
					// uplaod URL is still valid. Continue to upload
					DLUploadVideoFileTask * uploadTask = [[DLUploadVideoFileTask alloc] initWithTrack:theKey appToken:_appToken];
					bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
						// task expires. clean it up if it has not finished yet
						[uploadTask cancel];
						[self saveUnfinishedRecordingContext:ctx];
						[[UIApplication sharedApplication] endBackgroundTask:uploadTask.backgroundTaskIdentifier];
					}];
					uploadTask.taskController = self;
					uploadTask.backgroundTaskIdentifier = bgIdf;
					uploadTask.recordingContext = ctx;
					[self.queue addOperation:uploadTask];
					[uploadTask release];
				} else {
					// renew the upload URL
					[self renewUploadURLForSession:ctx wtihTrack:theKey];
				}
			} else if ( [ctx shouldPostTrackForName:theKey] ) {
				// we haven't posted the upload status to our server yet
				DLPostVideoTask * postTask = [[DLPostVideoTask alloc] initWithTrack:nil appToken:_appToken];
				bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
					// task expires. clean it up if it has not finished yet
					[postTask cancel];
					[self saveUnfinishedRecordingContext:ctx];
					[[UIApplication sharedApplication] endBackgroundTask:postTask.backgroundTaskIdentifier];
				}];
				postTask.taskController = self;
				postTask.backgroundTaskIdentifier = bgIdf;
				postTask.recordingContext = ctx;
				[self.queue addOperation:postTask];
				[postTask release];
			}
		}
	}
}

- (void)renewUploadURLForSession:(DLRecordingContext *)ctx wtihTrack:(NSString *)trcName {
	
}

#pragma mark Task Management
- (void)handleSessionTaskCompletion:(DLTask *)aTask {
	if ( [aTask isKindOfClass:[DLGetNewSessionTask class]] ) {
		DLRecordingContext * ctx = aTask.recordingContext;
		if ( _containsIncompleteSessions && ctx.shouldRecordVideo ) {
			// suppress recording flag if there's video files pending upload
			ctx.shouldRecordVideo = NO;
		}
		DLLog(@"[Delight] %@ session created: %@", ctx.shouldRecordVideo ? @"recording" : @"non-recording", ctx.sessionID);
		// notify the delegate
		[_sessionDelegate taskController:self didGetNewSessionContext:aTask.recordingContext];
	}
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

//- (void)saveRecordingContext {
//	NSString * sessFilePath = [self unfinishedRecordingContextsArchiveFilePath];
//	[NSKeyedArchiver archiveRootObject:_unfinishedContexts toFile:sessFilePath];
//	_containsIncompleteSessions = YES;
//}

#pragma mark Notification
- (void)handleReachabilityChangedNotification:(NSNotification *)aNotification {
	if ( !firstReachabilityNotificationReceived ) {
		firstReachabilityNotificationReceived = YES;
	}
    NetworkStatus netStatus = [_wifiReachability currentReachabilityStatus];
    BOOL connectionRequired = [_wifiReachability connectionRequired];
	if ( !connectionRequired ) {
		if ( netStatus == ReachableViaWiFi ) {
			// we can upload video file
			_wifiConnected = YES;
		} else {
			_wifiConnected = NO;
		}
		if ( pendingRequestSessionForFirstReachabilityNotification ) {
			pendingRequestSessionForFirstReachabilityNotification = NO;
			// create new session
			[self requestSessionIDWithAppToken:_appToken];
		}
	} else {
		// there's no network interface or no connection at all
		_wifiConnected = NO;
	}
}

- (NSString *)networkStatusString {
    NetworkStatus netStatus = [_wifiReachability currentReachabilityStatus];
	NSString * statusStr = nil;
	switch (netStatus) {
		case ReachableViaWiFi:
			statusStr = @"wifi";
			break;
			
		case ReachableViaWWAN:
			statusStr = @"wwan";
			break;
			
		default:
			statusStr = @"no_network";
			break;
	}
	return statusStr;
}

@end
