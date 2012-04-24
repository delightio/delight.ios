//
//  DLRecordingContext.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	DLFinishedUpdateSession = 1,
	DLFinishedUploadVideoFile,
	DLFinishedPostVideo
} DLFinishedTaskIdentifier;

/*!
 Store file upload status variables. A video file will probably need some time to get fully uploaded. All upload related status variables should be persistent so that the library can resume upload when the app is launched next time.
 */

@interface DLRecordingContext : NSObject <NSCoding>

@property (nonatomic, retain) NSString * sessionID;
@property (nonatomic, retain) NSString * uploadURLString;
@property (nonatomic, retain) NSDate * uploadURLExpiryDate;
@property (nonatomic) BOOL shouldRecordVideo;
@property (nonatomic) BOOL wifiUploadOnly;
@property (nonatomic, retain) NSDate * startTime;
@property (nonatomic, retain) NSDate * endTime;
@property (nonatomic) NSInteger chunkSize;
@property (nonatomic) NSInteger chunkOffset;
@property (nonatomic, retain) NSString * filePath;
@property (nonatomic, retain) NSMutableIndexSet * finishedTaskIndex;
@property (nonatomic) BOOL saved;
@property (nonatomic, readonly) BOOL loadedFromArchive;

- (BOOL)shouldCompleteTask:(DLFinishedTaskIdentifier)idfr;
- (BOOL)allTasksFinished;
- (void)setTaskFinished:(DLFinishedTaskIdentifier)idfr;

@end