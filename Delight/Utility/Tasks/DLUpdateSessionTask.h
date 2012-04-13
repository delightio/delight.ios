//
//  DLUpdateSessionTask.h
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTask.h"
#import "DLRecordingContext.h"

@interface DLUpdateSessionTask : DLTask

@property (nonatomic, retain) DLRecordingContext * fileStatus;

@end
