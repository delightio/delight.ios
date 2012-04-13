//
//  DLPostVideoInfoTask.h
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTask.h"
#import "DLFileUploadStatus.h"

@interface DLPostVideoInfoTask : DLTask

@property (nonatomic, retain) NSString * videoURLString;
@property (nonatomic, retain) DLFileUploadStatus * fileStatus;

@end
