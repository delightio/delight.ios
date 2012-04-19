//
//  DLTask.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "DLRecordingContext.h"

#define DL_REQUEST_TIMEOUT	30.0

@class DLTaskController;

extern NSString * const DL_BASE_URL;
extern NSString * const DL_ACCESS_TOKEN;
extern NSString * const DL_APP_LOCALE;
extern NSString * const DL_APP_VERSION;

@interface DLTask : NSOperation

@property (nonatomic, assign) DLTaskController * taskController;
@property (nonatomic, retain) DLRecordingContext * recordingContext;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, retain) NSMutableData * receivedData;
@property (nonatomic, retain) NSHTTPURLResponse * httpResponse;
@property (nonatomic, retain) NSURLConnection * connection;

- (NSString *)stringByAddingPercentEscapes:(NSString *)str;
- (NSURLRequest *)URLRequest;
- (void)processResponse;
- (BOOL)responseContainsError;

@end
