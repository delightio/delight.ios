//
//  Delight_Private.h
//  Delight
//
//  Created by Chris Haugli on 7/2/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "Delight.h"
#import "DLTaskController.h"
#import "DLScreenshotController.h"
#import "DLVideoEncoder.h"
#import "DLGestureTracker.h"
#import "DLCamCaptureManager.h"
#import "DLViewChange.h"

typedef enum {
    DLAnnotationNone,
    DLAnnotationFrontVideoAndAudio,
    DLAnnotationAudioOnly
} DLAnnotation;

@interface Delight () <DLRecordingSessionDelegate, DLGestureTrackerDelegate, DLVideoEncoderDelegate, DLCamCaptureManagerDelegate, UIAlertViewDelegate>

@property (nonatomic, retain) DLTaskController *taskController;
@property (nonatomic, retain) DLRecordingContext *recordingContext;
@property (nonatomic, retain) DLScreenshotController *screenshotController;
@property (nonatomic, retain) DLVideoEncoder *videoEncoder;
@property (nonatomic, retain) DLGestureTracker *gestureTracker;
@property (nonatomic, retain) DLCamCaptureManager *cameraManager;
@property (nonatomic, retain) DLMetrics *metrics;
@property (nonatomic, retain) NSString *appToken;
@property (nonatomic, assign) DLAnnotation annotation;
@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, assign) BOOL autoCaptureEnabled;
@property (nonatomic, assign) BOOL userStopped;
@property (nonatomic, retain) NSMutableDictionary *userProperties;
@property (nonatomic, retain) NSMutableArray *viewChanges;
@property (nonatomic, assign) NSThread *screenshotThread;

+ (Delight *)sharedInstance;
+ (void)startWithAppToken:(NSString *)appToken annotation:(DLAnnotation)annotation;
+ (void)markViewChange:(NSString *)viewName type:(DLViewChangeType)type;

- (void)startRecording;
- (void)stopRecording;
- (void)takeScreenshot;
- (void)scheduleScreenshot;
- (void)tryCreateNewSession; // check with Delight server to see if we need to start a new recording session

@end
