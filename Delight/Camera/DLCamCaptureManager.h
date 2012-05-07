//
//  DLCamCaptureManager.h
//  Delight
//
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class DLCamRecorder;
@protocol DLCamCaptureManagerDelegate;

@interface DLCamCaptureManager : NSObject {
}

@property (nonatomic,retain) AVCaptureSession *session;
@property (nonatomic,assign) AVCaptureVideoOrientation orientation;
@property (nonatomic,retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic,retain) AVCaptureDeviceInput *audioInput;
@property (nonatomic,retain) DLCamRecorder *recorder;
@property (nonatomic,assign) id deviceConnectedObserver;
@property (nonatomic,assign) id deviceDisconnectedObserver;
@property (nonatomic,assign) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic,assign,getter=isRecording) BOOL recording;
@property (nonatomic,retain) NSString *outputPath;
@property (nonatomic,assign) id <DLCamCaptureManagerDelegate> delegate;

- (void) startRecording;
- (void) stopRecording;
- (NSUInteger) cameraCount;
- (NSUInteger) micCount;

@end

// These delegate methods can be called on any arbitrary thread. If the delegate does something with the UI when called, make sure to send it to the main thread.
@protocol DLCamCaptureManagerDelegate <NSObject>
@optional
- (void) captureManager:(DLCamCaptureManager *)captureManager didFailWithError:(NSError *)error;
- (void) captureManagerRecordingBegan:(DLCamCaptureManager *)captureManager;
- (void) captureManagerRecordingFinished:(DLCamCaptureManager *)captureManager;
- (void) captureManagerStillImageCaptured:(DLCamCaptureManager *)captureManager;
- (void) captureManagerDeviceConfigurationChanged:(DLCamCaptureManager *)captureManager;
@end
