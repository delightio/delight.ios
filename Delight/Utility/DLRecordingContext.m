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
@synthesize uploadURLExpiryDate = _uploadURLExpiryDate;
@synthesize shouldRecordVideo = _shouldRecordVideo;
@synthesize wifiUploadOnly = _wifiUploadOnly;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;
@synthesize chunkSize = _chunkSize;
@synthesize chunkOffset = _chunkOffset;
@synthesize filePath = _filePath;
@synthesize finishedTaskIndex = _finishedTaskIndex;
@synthesize saved = _saved;
@synthesize loadedFromArchive = _loadedFromArchive;

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super init];
	self.sessionID = [aDecoder decodeObjectForKey:@"sessionID"];
	self.uploadURLString = [aDecoder decodeObjectForKey:@"uploadURLString"];
	self.uploadURLExpiryDate = [aDecoder decodeObjectForKey:@"uploadURLExpiryDate"];
	_shouldRecordVideo = [aDecoder decodeBoolForKey:@"shouldRecordVideo"];
	_wifiUploadOnly = [aDecoder decodeBoolForKey:@"wifiUploadOnly"];
	self.startTime = [aDecoder decodeObjectForKey:@"startTime"];
	self.endTime = [aDecoder decodeObjectForKey:@"endTime"];
	_chunkSize = [aDecoder decodeIntegerForKey:@"chunkSize"];
	_chunkOffset = [aDecoder decodeIntegerForKey:@"chunkOffset"];
	self.filePath = [aDecoder decodeObjectForKey:@"filePath"];
	self.finishedTaskIndex = [aDecoder decodeObjectForKey:@"finishedTaskIndex"];
	_loadedFromArchive = YES;
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:_sessionID forKey:@"sessionID"];
	[aCoder encodeObject:_uploadURLString forKey:@"uploadURLString"];
	[aCoder encodeObject:_uploadURLExpiryDate forKey:@"uploadURLExpiryDate"];
	[aCoder encodeBool:_shouldRecordVideo forKey:@"shouldRecordVideo"];
	[aCoder encodeBool:_wifiUploadOnly forKey:@"wifiUploadOnly"];
	[aCoder encodeObject:_startTime forKey:@"startTime"];
	[aCoder encodeObject:_endTime forKey:@"endTime"];
	[aCoder encodeInteger:_chunkSize forKey:@"chunkSize"];
	[aCoder encodeInteger:_chunkOffset forKey:@"chunkOffset"];
	[aCoder encodeObject:_filePath forKey:@"filePath"];
	[aCoder encodeObject:_finishedTaskIndex forKey:@"finishedTaskIndex"];
}

- (void)dealloc {
	[_sessionID release];
	[_uploadURLString release];
	[_uploadURLExpiryDate release];
	[_startTime release];
	[_endTime release];
	[_filePath release];
	[_finishedTaskIndex release];
	[super dealloc];
}

- (BOOL)shouldCompleteTask:(DLFinishedTaskIdentifier)idfr {
	// no lock needed. It's only called in main thread
	BOOL flag;
	// if it doesn't not contain the index, the task is done
	flag = [self.finishedTaskIndex containsIndex:idfr];
	return flag;
}

- (BOOL)allTasksFinished {
	BOOL val;
	@synchronized (self) {
		val = [self.finishedTaskIndex count] == 0;
	}
	return val;
}

- (void)setTaskFinished:(DLFinishedTaskIdentifier)idfr {
	@synchronized (self) {
		[self.finishedTaskIndex removeIndex:idfr];
	}
}

- (NSMutableIndexSet *)finishedTaskIndex {
	if ( _finishedTaskIndex == nil ) {
		// create the index set object
		_finishedTaskIndex = [[NSMutableIndexSet alloc] init];
		if ( _shouldRecordVideo ) {
			// this is a recording session. need to fulfill 3 upload tasks
			[_finishedTaskIndex addIndex:DLFinishedPostVideo];
			[_finishedTaskIndex addIndex:DLFinishedUpdateSession];
			[_finishedTaskIndex addIndex:DLFinishedUploadVideoFile];
		} else {
			// only upload the info
			[_finishedTaskIndex addIndex:DLFinishedUpdateSession];
		}
	}
	return _finishedTaskIndex;
}

@end
