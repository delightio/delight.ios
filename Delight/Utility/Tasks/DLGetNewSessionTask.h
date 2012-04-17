//
//  DLGetSessionTask.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTask.h"
#import "DLRecordingContext.h"

@interface DLGetNewSessionTask : DLTask <NSXMLParserDelegate>

@property (nonatomic, retain) DLRecordingContext * recordingContext;
@property (nonatomic, retain) NSMutableString * contentOfCurrentProperty;

@end
