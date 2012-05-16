//
//  Delight.h
//  Delight
//
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DLTaskController;
@class DLRecordingContext;
@class DLScreenshotController;
@class DLVideoEncoder;
@class DLGestureTracker;
@class DLCamCaptureManager;

@protocol DLRecordingSessionDelegate <NSObject>

@required
- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx;

@end

@interface Delight : NSObject <DLRecordingSessionDelegate> {
    NSUInteger frameCount;
    NSTimeInterval elapsedTime;
    NSTimeInterval lastScreenshotTime;
    NSTimeInterval resignActiveTime;
    BOOL appInBackground;
    BOOL alertViewVisible;
    
	DLTaskController * taskController;
	DLRecordingContext * recordingContext;
    NSOperationQueue * screenshotQueue;
    NSLock * lock;
	DLCamCaptureManager * cameraManager;
}

@property (nonatomic, retain) NSString *appToken;
@property (nonatomic) BOOL debugLogEnabled;
@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, assign) NSUInteger maximumFrameRate;
@property (nonatomic, assign) NSTimeInterval maximumRecordingDuration;
@property (nonatomic, assign, getter=isAutoCaptureEnabled) BOOL autoCaptureEnabled;
@property (nonatomic, assign) BOOL recordsCamera;
@property (nonatomic, assign, getter=isUsabilityTestEnabled) BOOL usabilityTestEnabled;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic, readonly) DLScreenshotController *screenshotController;
@property (nonatomic, readonly) DLVideoEncoder *videoEncoder;
@property (nonatomic, readonly) DLGestureTracker *gestureTracker;
@property (nonatomic, readonly) NSMutableDictionary *userProperties;

/*********************
 * Recording control *
 *********************/

// Start/stop/pause/resume recording
+ (void)startWithAppToken:(NSString *)appToken;
+ (void)stop;
+ (void)pause;
+ (void)resume;

// Manually trigger a screen capture. Doesn't need to be called, but can be used if you want to ensure
// that a screenshot is taken at a particular time.
+ (void)takeScreenshot;

/*****************
 * Configuration *
 *****************/

// Set the amount the recording should be scaled by, e.g. 0.5 = 50% scale
+ (void)setScaleFactor:(CGFloat)scaleFactor;
+ (CGFloat)scaleFactor;

// Set the maximum frame rate
+ (void)setMaximumFrameRate:(NSUInteger)maximumFrameRate;
+ (NSUInteger)maximumFrameRate;

// Set whether recordings are copied to the user's photo album
+ (void)setSavesToPhotoAlbum:(BOOL)savesToPhotoAlbum;
+ (BOOL)savesToPhotoAlbum;

// Set whether the debug log should be printed to the console
+ (void)setDebugLogEnabled:(BOOL)debugLogEnabled;
+ (BOOL)debugLogEnabled;

// Set whether the keyboard is covered up in the recording
+ (void)setHidesKeyboardInRecording:(BOOL)hidesKeyboardInRecording;
+ (BOOL)hidesKeyboardInRecording;

// Register/unregister views that should be censored
+ (void)registerPrivateView:(UIView *)view description:(NSString *)description;
+ (void)unregisterPrivateView:(UIView *)view;
+ (NSSet *)privateViews;

// Attach arbitrary properties to the session. Value must be an NSString or NSNumber.
+ (void)setPropertyValue:(id)value forKey:(NSString *)key;

@end
