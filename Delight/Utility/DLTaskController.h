//
//  DLTaskController.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLTaskHeader.h"

@class DLTaskController;

@protocol DLRecordingSessionDelegate;
//@protocol DLRecordingSessionDelegate <NSObject>
//
//@required
//- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx;
//@optional
//- (void)sessionRequestDeniedForTaskController:(DLTaskController *)ctrl;
//
//@end

@interface DLTaskController : NSObject <NSURLConnectionDataDelegate>

@property (nonatomic, retain) NSOperationQueue * queue;
@property (nonatomic, retain) NSURLConnection * controlConnection;
@property (nonatomic, retain) DLTask * task;
@property (nonatomic, assign) id<DLRecordingSessionDelegate> sessionDelegate;

- (void)requestSessionID;
- (void)uploadSession:(DLRecordingContext *)aSession;

// task management
- (void)handleSessionTaskCompletion:(DLGetNewSessionTask *)aTask;

@end
