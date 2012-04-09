//
//  DLScreenCapture.h
//  ipad
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLScreenshotController.h"
#import "DLVideoController.h"

@interface DLScreenCapture : NSObject {
    NSTimeInterval pauseStartedAt;
    BOOL processing;
    NSInteger frameCount;
    NSTimeInterval elapsedTime;
}

+ (void)start;
+ (void)stop;
+ (void)pause;
+ (void)resume;
+ (void)registerPrivateView:(UIView *)view description:(NSString *)description;
+ (void)unregisterPrivateView:(UIView *)view;
+ (BOOL)hidesKeyboard;
+ (void)setHidesKeyboard:(BOOL)hidesKeyboard;
+ (CGFloat)scaleFactor;
+ (void)setScaleFactor:(CGFloat)scaleFactor;
+ (BOOL)autoCaptureEnabled;
+ (void)setAutoCaptureEnabled:(BOOL)autoCaptureEnabled;

@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, readonly) float frameRate;
@property (nonatomic, assign) NSUInteger maximumFrameRate;
@property (nonatomic, assign, getter=isAutoCaptureEnabled) BOOL autoCaptureEnabled;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic, readonly) DLScreenshotController *screenshotController;
@property (nonatomic, readonly) DLVideoController *videoController;

@end