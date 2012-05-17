//
//  DLUploadVideoFileTask.h
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTask.h"

@interface DLUploadVideoFileTask : DLTask

@property (nonatomic, retain) NSString * trackName;

- (id)initWithTrack:(NSString *)trcName appToken:(NSString *)aToken;

@end
