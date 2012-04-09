//
//  NBScreenCapture.h
//  ipad
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "NBScreenCapturingWindow.h"

/**
 * Delegate protocol.  Implement this if you want to receive a notification when the
 * view completes a recording.
 *
 * When a recording is completed, the NBScreenCapture object will notify the delegate, passing
 * it the path to the created recording file if the recording was successful, or a value
 * of nil if the recording failed/could not be saved.
 */
@protocol ScreenCaptureViewDelegate <NSObject>
- (void) recordingFinished:(NSString*)outputPathOrNil;
@end

@interface NBScreenCapture : NSObject <NBScreenCapturingWindowDelegate> {
    //video writing
    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
    
    //recording state
    BOOL _recording;
    BOOL _paused;
    NSDate *startedAt;
    NSTimeInterval pauseStartedAt;
    NSTimeInterval pauseTime;
    void *bitmapData;
    BOOL processing;
    NSInteger frameCount;
    NSTimeInterval elapsedTime;
    
    NSTimer *screenshotTimer;
    NSMutableArray *pendingTouches;  
    CGRect keyboardFrame;
    
    CGFloat scaleFactor;
    NSUInteger maximumFrameRate;
}

+ (void)start;
+ (void)startWithScaleFactor:(CGFloat)scaleFactor maximumFrameRate:(NSUInteger)maximumFrameRate;
+ (void)stop;
+ (void)pause;
+ (void)resume;
+ (void)registerPrivateView:(UIView *)view description:(NSString *)description;
+ (void)unregisterPrivateView:(UIView *)view;
+ (void)setHidesKeyboard:(BOOL)hidesKeyboard;
+ (void)openGLScreenCapture:(UIView *)view colorRenderBuffer:(GLuint)colorRenderBuffer;

@property(nonatomic, retain) UIImage *currentScreen;
@property(nonatomic, retain) NSMutableSet *privateViews;
@property(nonatomic, assign) BOOL hidesKeyboard;
@property(retain) UIImage *openGLImage;
@property(nonatomic, assign) CGRect openGLFrame;
@property(nonatomic, assign) float frameRate;
@property(nonatomic, assign) id<ScreenCaptureViewDelegate> captureDelegate;

@end