//
//  Delight.h
//  Delight
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLScreenshotController.h"
#import "DLVideoEncoder.h"

@interface Delight : NSObject {
    BOOL processing;
    NSUInteger frameCount;
    NSTimeInterval elapsedTime;
}

@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, readonly) float frameRate;
@property (nonatomic, assign) NSUInteger maximumFrameRate;
@property (nonatomic, assign, getter=isAutoCaptureEnabled) BOOL autoCaptureEnabled;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic, readonly) DLScreenshotController *screenshotController;
@property (nonatomic, readonly) DLVideoEncoder *videoEncoder;

/**************
 * UIKit apps *
 **************/

// Start recording
+ (void)start;

// Manually trigger a screen capture. Doesn't need to be called, but can be used if you want to ensure
// that a screenshot is taken at a particular time.
+ (void)takeScreenshot;

/******************
 * OpenGL ES apps *
 ******************/

// Start recording
+ (void)startOpenGL;

// This must be called in your render loop before presentRenderbuffer:
+ (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;

/*********************
 * Recording control *
 *********************/

+ (void)stop;
+ (void)pause;
+ (void)resume;

/*****************
 * Configuration *
 *****************/

// Set the amount the recording should be scaled by, e.g. 0.5 = 50% scale
+ (void)setScaleFactor:(CGFloat)scaleFactor;
+ (CGFloat)scaleFactor;

// Set the maximum frame rate
+ (void)setMaximumFrameRate:(NSUInteger)maximumFrameRate;
+ (NSUInteger)maximumFrameRate;

// Set whether the keyboard is covered up in the recording
+ (void)setHidesKeyboardInRecording:(BOOL)hidesKeyboardInRecording;
+ (BOOL)hidesKeyboardInRecording;

// Register/unregister views that should be censored
+ (void)registerPrivateView:(UIView *)view description:(NSString *)description;
+ (void)unregisterPrivateView:(UIView *)view;

@end