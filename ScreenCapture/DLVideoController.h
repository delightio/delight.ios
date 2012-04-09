//
//  DLVideoController.h
//  ScreenCapture
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface DLVideoController : NSObject {
    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
    NSDate *startedAt;
    NSTimeInterval pauseTime;
}

@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) double averageBitRate;

- (void)startNewRecording;
- (void)stopRecording;
- (void)writeFrameImage:(UIImage *)frameImage;
- (void)addPauseTime:(NSTimeInterval)pauseTime;

@end
