//
//  DLRecordingContext.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLRecordingContext.h"

@implementation DLRecordingContext
@synthesize sessionID = _sessionID;
@synthesize uploadURLString = _uploadURLString;
@synthesize shouldRecordVideo = _shouldRecordVideo;
@synthesize wifiUploadOnly = _wifiUploadOnly;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;
@synthesize chunkSize;
@synthesize chunkOffset;
@synthesize filePath = _filePath;
@synthesize finishedTaskIndex = _finishedTaskIndex;

- (void)dealloc {
	[_sessionID release];
	[_uploadURLString release];
	[_startTime release];
	[_endTime release];
	[_filePath release];
	[_finishedTaskIndex release];
	[super dealloc];
}

- (NSMutableIndexSet *)finishedTaskIndex {
	if ( _finishedTaskIndex == nil ) {
		// create the index set object
		_finishedTaskIndex = [[NSMutableIndexSet alloc] init];
	}
	return _finishedTaskIndex;
}

@end
