//
//  DLRecordingContext.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLRecordingContext.h"
#import "DLTask.h"

@implementation DLRecordingContext
@synthesize sessionID = _sessionID;
@synthesize tracks = _tracks;
@synthesize sourceFilePaths = _sourceFilePaths;
@synthesize shouldRecordVideo = _shouldRecordVideo;
@synthesize wifiUploadOnly = _wifiUploadOnly;
@synthesize scaleFactor = _scaleFactor;
@synthesize maximumFrameRate = _maximumFrameRate;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;
@synthesize chunkSize = _chunkSize;
@synthesize chunkOffset = _chunkOffset;
@synthesize usabilityTestDescription = _usabilityTestDescription;
@synthesize userProperties = _userProperties;
@synthesize finishedTaskIndex = _finishedTaskIndex;
@synthesize saved = _saved;
@synthesize loadedFromArchive = _loadedFromArchive;

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super init];
	self.sessionID = [aDecoder decodeObjectForKey:@"sessionID"];
	self.tracks = [aDecoder decodeObjectForKey:@"tracks"];
	self.sourceFilePaths = [aDecoder decodeObjectForKey:@"sourceFilePaths"];
	_shouldRecordVideo = [aDecoder decodeBoolForKey:@"shouldRecordVideo"];
	_wifiUploadOnly = [aDecoder decodeBoolForKey:@"wifiUploadOnly"];
    _scaleFactor = [aDecoder decodeFloatForKey:@"scaleFactor"];
    _maximumFrameRate = [aDecoder decodeIntegerForKey:@"maximumFrameRate"];
	self.startTime = [aDecoder decodeObjectForKey:@"startTime"];
	self.endTime = [aDecoder decodeObjectForKey:@"endTime"];
	_chunkSize = [aDecoder decodeIntegerForKey:@"chunkSize"];
	_chunkOffset = [aDecoder decodeIntegerForKey:@"chunkOffset"];
	self.screenFilePath = [aDecoder decodeObjectForKey:@"screenFilePath"];
    self.cameraFilePath = [aDecoder decodeObjectForKey:@"cameraFilePath"];
    self.usabilityTestDescription = [aDecoder decodeObjectForKey:@"usabilityTestDescription"];
    self.userProperties = [aDecoder decodeObjectForKey:@"userProperties"];
	self.finishedTaskIndex = [aDecoder decodeObjectForKey:@"finishedTaskIndex"];
	_loadedFromArchive = YES;
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:_sessionID forKey:@"sessionID"];
	[aCoder encodeObject:_tracks forKey:@"tracks"];
	[aCoder encodeObject:_sourceFilePaths forKey:@"sourceFilePaths"];
	[aCoder encodeBool:_shouldRecordVideo forKey:@"shouldRecordVideo"];
	[aCoder encodeBool:_wifiUploadOnly forKey:@"wifiUploadOnly"];
    [aCoder encodeFloat:_scaleFactor forKey:@"scaleFactor"];
    [aCoder encodeInteger:_maximumFrameRate forKey:@"maximumFrameRate"];
	[aCoder encodeObject:_startTime forKey:@"startTime"];
	[aCoder encodeObject:_endTime forKey:@"endTime"];
	[aCoder encodeInteger:_chunkSize forKey:@"chunkSize"];
	[aCoder encodeInteger:_chunkOffset forKey:@"chunkOffset"];
    [aCoder encodeObject:_usabilityTestDescription forKey:@"usabilityTestDescription"];
    [aCoder encodeObject:_userProperties forKey:@"userProperties"];
	[aCoder encodeObject:_finishedTaskIndex forKey:@"finishedTaskIndex"];
}

- (void)dealloc {
	[_sessionID release];
	[_tracks release];
	[_sourceFilePaths release];
	[_startTime release];
	[_endTime release];
    [_usabilityTestDescription release];
    [_userProperties release];
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

#pragma mark Getter-setter overrides
- (NSString *)screenFilePath {
	return [_sourceFilePaths objectForKey:DLScreenTrackKey];
}

- (void)setScreenFilePath:(NSString *)aPath {
	if ( _sourceFilePaths == nil ) {
		_sourceFilePaths = [[NSMutableDictionary alloc] initWithCapacity:4];
	}
	[_sourceFilePaths setObject:aPath forKey:DLScreenTrackKey];
}

- (NSString *)cameraFilePath {
	return [_sourceFilePaths objectForKey:DLFrontTrackKey];
}

- (void)setCameraFilePath:(NSString *)aPath {
	if ( _sourceFilePaths == nil ) {
		_sourceFilePaths = [[NSMutableDictionary alloc] initWithCapacity:4];
	}
	[_sourceFilePaths setObject:aPath forKey:DLFrontTrackKey];
}

- (NSString *)touchFilePath {
	return [_sourceFilePaths objectForKey:DLTouchTrackKey];
}

- (void)setTouchFilePath:(NSString *)aPath {
	if ( _sourceFilePaths == nil ) {
		_sourceFilePaths = [[NSMutableDictionary alloc] initWithCapacity:4];
	}
	[_sourceFilePaths setObject:aPath forKey:DLTouchTrackKey];
}

@end
