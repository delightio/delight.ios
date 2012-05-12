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
@class DLReachability;

@protocol DLRecordingSessionDelegate;
//@protocol DLRecordingSessionDelegate <NSObject>
//
//@required
//- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx;
//@optional
//- (void)sessionRequestDeniedForTaskController:(DLTaskController *)ctrl;
//
//@end

@interface DLTaskController : NSObject <NSURLConnectionDataDelegate> {
	BOOL firstReachabilityNotificationReceived;
	BOOL pendingRequestSessionForFirstReachabilityNotification;
}

@property (nonatomic, retain) NSString * appToken;
@property (nonatomic, retain) NSOperationQueue * queue;
@property (nonatomic, retain) DLTask * task;
@property (nonatomic, assign) id<DLRecordingSessionDelegate> sessionDelegate;
@property (nonatomic, retain) NSMutableArray * unfinishedContexts;
@property (nonatomic, retain) NSString * baseDirectory;
@property (nonatomic, retain) DLReachability * wifiReachability;
@property (nonatomic) BOOL containsIncompleteSessions;
@property (nonatomic) BOOL wifiConnected;
@property (nonatomic, readonly) NSString * networkStatusString;

- (void)requestSessionIDWithAppToken:(NSString *)aToken;
- (void)uploadSession:(DLRecordingContext *)aSession;
- (void)updateSession:(DLRecordingContext *)aSession;

// session management
- (NSString *)unfinishedRecordingContextsArchiveFilePath;
- (void)removeRecordingContext:(DLRecordingContext *)ctx;
// task management
- (void)handleSessionTaskCompletion:(DLTask *)aTask;
//- (void)saveUnfinishedRecordingContext:(DLRecordingContext *)ctx;
- (void)saveRecordingContext;

@end
