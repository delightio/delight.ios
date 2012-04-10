//
//  DLVideoController.h
//  ScreenCapture
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

/* 
   DLVideoController encodes video to a file.
 */
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

// If the encoding should be temporarily paused, the pause duration should be passed to here.
// Any frames added after this method call will have their timestamp reduced by the total pause time.
- (void)addPauseTime:(NSTimeInterval)pauseTime;

@end
