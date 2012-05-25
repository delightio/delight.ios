//
//  DLRecordingContext.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLRecordingContext.h"
#import "DLTask.h"
#import "DLMetrics.h"

@implementation DLRecordingContext
@synthesize sessionID = _sessionID;
@synthesize tracks = _tracks;
@synthesize sourceFilePaths = _sourceFilePaths;
@synthesize touches = _touches;
@synthesize touchBounds = _touchBounds;
@synthesize orientationChanges = _orientationChanges;
@synthesize shouldRecordVideo = _shouldRecordVideo;
@synthesize wifiUploadOnly = _wifiUploadOnly;
@synthesize scaleFactor = _scaleFactor;
@synthesize maximumFrameRate = _maximumFrameRate;
@synthesize averageBitRate = _averageBitRate;
@synthesize maximumKeyFrameInterval = _maximumKeyFrameInterval;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;
@synthesize chunkSize = _chunkSize;
@synthesize chunkOffset = _chunkOffset;
@synthesize usabilityTestDescription = _usabilityTestDescription;
@synthesize userProperties = _userProperties;
@synthesize finishedTaskIndex = _finishedTaskIndex;
@synthesize saved = _saved;
@synthesize loadedFromArchive = _loadedFromArchive;
@synthesize metrics = _metrics;

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super init];
	self.sessionID = [aDecoder decodeObjectForKey:@"sessionID"];
	self.tracks = [aDecoder decodeObjectForKey:@"tracks"];
	self.sourceFilePaths = [aDecoder decodeObjectForKey:@"sourceFilePaths"];
	_shouldRecordVideo = [aDecoder decodeBoolForKey:@"shouldRecordVideo"];
	_wifiUploadOnly = [aDecoder decodeBoolForKey:@"wifiUploadOnly"];
    _scaleFactor = [aDecoder decodeFloatForKey:@"scaleFactor"];
    _maximumFrameRate = [aDecoder decodeIntegerForKey:@"maximumFrameRate"];
    _averageBitRate = [aDecoder decodeDoubleForKey:@"averageBitRate"];
    _maximumKeyFrameInterval = [aDecoder decodeIntegerForKey:@"maximumKeyFrameInterval"];
	self.startTime = [aDecoder decodeObjectForKey:@"startTime"];
	self.endTime = [aDecoder decodeObjectForKey:@"endTime"];
	_chunkSize = [aDecoder decodeIntegerForKey:@"chunkSize"];
	_chunkOffset = [aDecoder decodeIntegerForKey:@"chunkOffset"];
	self.screenFilePath = [aDecoder decodeObjectForKey:@"screenFilePath"];
    self.cameraFilePath = [aDecoder decodeObjectForKey:@"cameraFilePath"];
    self.usabilityTestDescription = [aDecoder decodeObjectForKey:@"usabilityTestDescription"];
    self.userProperties = [aDecoder decodeObjectForKey:@"userProperties"];
	self.finishedTaskIndex = [aDecoder decodeObjectForKey:@"finishedTaskIndex"];
    self.metrics = [aDecoder decodeObjectForKey:@"metrics"];
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
    [aCoder encodeDouble:_averageBitRate forKey:@"averageBitRate"];
    [aCoder encodeInt:_maximumKeyFrameInterval forKey:@"maximumKeyFrameInterval"];
	[aCoder encodeObject:_startTime forKey:@"startTime"];
	[aCoder encodeObject:_endTime forKey:@"endTime"];
	[aCoder encodeInteger:_chunkSize forKey:@"chunkSize"];
	[aCoder encodeInteger:_chunkOffset forKey:@"chunkOffset"];
    [aCoder encodeObject:_usabilityTestDescription forKey:@"usabilityTestDescription"];
    [aCoder encodeObject:_userProperties forKey:@"userProperties"];
	[aCoder encodeObject:_finishedTaskIndex forKey:@"finishedTaskIndex"];
    [aCoder encodeObject:_metrics forKey:@"metrics"];
}

- (void)dealloc {
	[_sessionID release];
	[_tracks release];
	[_sourceFilePaths release];
	[_touches release];
    [_orientationChanges release];
	[_startTime release];
	[_endTime release];
    [_usabilityTestDescription release];
    [_userProperties release];
	[_finishedTaskIndex release];
    [_metrics release];
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
			[_finishedTaskIndex addIndex:DLFinishedUploadTouchesFile];
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
	[_finishedTaskIndex addIndex:DLFinishedUploadCameraFile];
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

- (NSString *)orientationFilePath {
	return [_sourceFilePaths objectForKey:DLOrientationTrackKey];
}

- (void)setOrientationFilePath:(NSString *)aPath {
	if ( _sourceFilePaths == nil ) {
		_sourceFilePaths = [[NSMutableDictionary alloc] initWithCapacity:4];
	}
	[_sourceFilePaths setObject:aPath forKey:DLOrientationTrackKey];
}

@end
