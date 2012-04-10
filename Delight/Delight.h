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

// Recording control
+ (void)start;
+ (void)startWithScaleFactor:(CGFloat)scaleFactor;
+ (void)startWithScaleFactor:(CGFloat)scaleFactor bitRate:(double)bitRate;
+ (void)stop;
+ (void)pause;
+ (void)resume;

// Manually trigger a screenshot call
+ (void)takeScreenshot;
+ (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;

// Set views that should be censored
+ (void)registerPrivateView:(UIView *)view description:(NSString *)description;
+ (void)unregisterPrivateView:(UIView *)view;

// Set whether the keyboard window is rendered
+ (void)setHidesKeyboard:(BOOL)hidesKeyboard;
+ (BOOL)hidesKeyboard;

// Set the maximum frame rate
+ (void)setMaximumFrameRate:(NSUInteger)maximumFrameRate;
+ (NSUInteger)maximumFrameRate;

// Set whether screenshots should be taken automatically. For OpenGL ES apps, autocapture should be disabled
// and takeOpenGLScreenshot:colorRenderBuffer: should be called just before presentRenderbuffer: in the
// rendering loop.
+ (void)setAutoCaptureEnabled:(BOOL)autoCaptureEnabled;
+ (BOOL)autoCaptureEnabled;

@end