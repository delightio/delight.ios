//
//  DLVideoEncoder.h
//  ScreenCapture
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

/* 
   DLVideoEncoder encodes video to a file.
 */
@interface DLVideoEncoder : NSObject {
    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;

    NSTimeInterval recordingStartTime;
    NSTimeInterval pauseStartTime;
    NSTimeInterval totalPauseDuration;
}

@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, readonly, getter=isPaused) BOOL paused;
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) double averageBitRate;

- (void)startNewRecording;
- (void)stopRecording;
- (void)writeFrameImage:(UIImage *)frameImage;
- (void)pause;
- (void)resume;

@end
