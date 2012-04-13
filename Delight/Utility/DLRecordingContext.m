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
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;
@synthesize chunkSize;
@synthesize chunkOffset;
@synthesize filePath = _filePath;

- (void)dealloc {
	[_sessionID release];
	[_startTime release];
	[_endTime release];
	[_filePath release];
	[super dealloc];
}

@end
