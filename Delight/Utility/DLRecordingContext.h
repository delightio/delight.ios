//
//  DLRecordingContext.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DLMetrics;

typedef enum {
	DLFinishedUpdateSession = 1,
	DLFinishedUploadVideoFile,
	DLFinishedUploadFrontCameraFile,
	DLFinishedUploadTouchesFile,
	DLFinishedUploadOrientationFile,
	DLFinishedPostVideo,
	DLFinishedPostTouches,
	DLFinishedPostOrientation,
	DLFinishedPostFrontCamera,
} DLFinishedTaskIdentifier;

/*!
 Store file upload status variables. A video file will probably need some time to get fully uploaded. All upload related status variables should be persistent so that the library can resume upload when the app is launched next time.
 */

@interface DLRecordingContext : NSObject <NSCoding>

@property (nonatomic, retain) NSString * sessionID;
@property (nonatomic, retain) NSDictionary * tracks;
@property (nonatomic, retain) NSMutableDictionary * sourceFilePaths;
@property (nonatomic, retain) NSArray * touches;
@property (nonatomic, assign) CGRect touchBounds;
@property (nonatomic, retain) NSArray * orientationChanges;
@property (nonatomic) BOOL shouldRecordVideo;
@property (nonatomic) BOOL wifiUploadOnly;
@property (nonatomic) float scaleFactor;
@property (nonatomic) NSUInteger maximumFrameRate;
@property (nonatomic) double averageBitRate;
@property (nonatomic) NSUInteger maximumKeyFrameInterval;
@property (nonatomic, retain) NSDate * startTime;
@property (nonatomic, retain) NSDate * endTime;
@property (nonatomic) NSInteger chunkSize;
@property (nonatomic) NSInteger chunkOffset;
@property (nonatomic, retain) NSString * screenFilePath;
@property (nonatomic, retain) NSString * cameraFilePath;
@property (nonatomic, retain) NSString * touchFilePath;
@property (nonatomic, retain) NSString * orientationFilePath;
@property (nonatomic, retain) NSString * usabilityTestDescription;
@property (nonatomic, retain) NSMutableDictionary * userProperties;
@property (nonatomic, retain) NSMutableIndexSet * finishedTaskIndex;
@property (nonatomic) BOOL saved;
@property (nonatomic, readonly) BOOL loadedFromArchive;
@property (nonatomic, retain) DLMetrics *metrics;

- (BOOL)shouldCompleteTask:(DLFinishedTaskIdentifier)idfr;
- (BOOL)allTasksFinished;
- (void)setTaskFinished:(DLFinishedTaskIdentifier)idfr;

@end
