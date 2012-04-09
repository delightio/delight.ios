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
    NSUInteger maximumFrameRate;
    CGFloat scaleFactor;
}

+ (void)start;
+ (void)startWithScaleFactor:(CGFloat)scaleFactor maximumFrameRate:(NSUInteger)maximumFrameRate;
+ (void)stop;
+ (void)pause;
+ (void)resume;
+ (void)registerPrivateView:(UIView *)view description:(NSString *)description;
+ (void)unregisterPrivateView:(UIView *)view;
+ (void)setHidesKeyboard:(BOOL)hidesKeyboard;

@property (nonatomic, assign) CGFloat frameRate;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic, readonly) DLScreenshotController *screenshotController;
@property (nonatomic, readonly) DLVideoController *videoController;

@end