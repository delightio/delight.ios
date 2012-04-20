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
@property (nonatomic, retain) DLTask * task;
@property (nonatomic, assign) id<DLRecordingSessionDelegate> sessionDelegate;
@property (nonatomic, retain) NSMutableArray * incompleteSessions;
@property (nonatomic, retain) NSString * baseDirectory;
@property (nonatomic) BOOL containsIncompleteSessions;

- (void)requestSessionIDWithAppToken:(NSString *)aToken;
- (void)uploadSession:(DLRecordingContext *)aSession;

- (NSString *)incompleteSessionsArchiveFilePath;
// task management
- (void)handleSessionTaskCompletion:(DLGetNewSessionTask *)aTask;
- (void)saveIncompleteSession:(DLRecordingContext *)ctx;

@end
