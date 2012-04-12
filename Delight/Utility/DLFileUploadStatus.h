//
//  DLFileUploadStatus.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
 Store file upload status variables. A video file will probably need some time to get fully uploaded. All upload related status variables should be persistent so that the library can resume upload when the app is launched next time.
 */

@interface DLFileUploadStatus : NSObject

@property (nonatomic, retain) NSDate * startTime;
@property (nonatomic, retain) NSDate * endTime;
@property (nonatomic) NSInteger chunkSize;
@property (nonatomic) NSInteger chunkOffset;
@property (nonatomic, retain) NSString * filePath;

@end
