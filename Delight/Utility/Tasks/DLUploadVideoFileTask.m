//
//  DLUploadVideoFileTask.m
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLUploadVideoFileTask.h"
#import "DLPostVideoTask.h"
#import "DLTaskController.h"

@implementation DLUploadVideoFileTask
@synthesize trackName = _trackName;

- (id)initWithTrack:(NSString *)trcName appToken:(NSString *)aToken {
	self = [super initWithAppToken:aToken];
	_trackName = [trcName retain];
	return self;
}

- (void)dealloc {
	[_trackName release];
	[super dealloc];
}

- (NSURLRequest *)URLRequest {
	NSDictionary * theDict = [self.recordingContext.tracks objectForKey:_trackName];
	NSString * fPath = [self.recordingContext.sourceFilePaths objectForKey:_trackName];
	NSInputStream * theStream = [NSInputStream inputStreamWithFileAtPath:fPath];
	NSMutableURLRequest * request = nil;
	if ( theStream ) {
		request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[theDict objectForKey:DLTrackURLKey]] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:600.0];
		[request setHTTPMethod:@"PUT"];
		// get file length
		
		NSDictionary * attrDict = [[NSFileManager defaultManager] attributesOfItemAtPath:fPath error:nil];
		[request setValue:[NSString stringWithFormat:@"%qu", [attrDict fileSize]] forHTTPHeaderField:@"Content-Length"];
		// open up the file
		[request setHTTPBodyStream:theStream];
		[request setValue:self.appToken	forHTTPHeaderField:@"X-NB-AuthToken"];
		DLLog(@"[Delight] uploading recording to delight server");
	}
	return request;
}

- (void)processResponse {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"uploaded video file: %@", str);
//	[str release];
	// create Post Video task
	DLPostVideoTask * postTask = [[DLPostVideoTask alloc] initWithTrack:_trackName appToken:self.appToken];
	UIBackgroundTaskIdentifier bgIdf = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		// task expires. clean it up if it has not finished yet
		[postTask cancel];
		[self.taskController saveUnfinishedRecordingContext:self.recordingContext];
		[[UIApplication sharedApplication] endBackgroundTask:postTask.backgroundTaskIdentifier];
	}];
	postTask.taskController = self.taskController;
	postTask.backgroundTaskIdentifier = bgIdf;
	postTask.recordingContext = self.recordingContext;
	[self.taskController.queue addOperation:postTask];
	[postTask release];
	
	if ( [_trackName isEqualToString:@"screen_track"] ) {
		[self.recordingContext setTaskFinished:DLFinishedUploadVideoFile];
	} else if ( [_trackName isEqualToString:@"touch_track"] ) {
		[self.recordingContext setTaskFinished:DLFinishedUploadTouchesFile];
	} else if ( [_trackName isEqualToString:@"orientation_track"] ) {
		[self.recordingContext setTaskFinished:DLFinishedUploadOrientationFile];
	} else if ( [_trackName isEqualToString:@"front_track"] ) {
		[self.recordingContext setTaskFinished:DLFinishedUploadFrontCameraFile];
	}
	DLDebugLog(@"uploaded %@ to server", _trackName);
	// delete video file
	NSError * err = nil;
	NSString * fPath = [self.recordingContext.sourceFilePaths objectForKey:_trackName];
	if ( ![[NSFileManager defaultManager] removeItemAtPath:fPath error:&err] ) {
		// can't remove the file successfully
		DLLog(@"[Delight] can't delete uploaded video file: %@", fPath);
	}
	if ( [self.recordingContext allTasksFinished] ) {
		DLLog(@"[Delight] recording uploaded, session: %@", self.recordingContext.sessionID);
		// all tasks are done.
		// remove the task from incomplete array
		[self.taskController removeRecordingContext:self.recordingContext];
	}
	// end the background task
	[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
	self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
}

@end
