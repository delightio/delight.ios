//
//  DLVideoEncoder.h
//  Delight
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@protocol DLVideoEncoderDelegate;

/* 
   DLVideoEncoder encodes video to a file.
 */
@interface DLVideoEncoder : NSObject {
    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
    
    NSTimeInterval recordingStartTime;  // System uptime at recording start    
    NSLock *lock;
}

@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, assign) BOOL savesToPhotoAlbum;
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) double averageBitRate;
@property (nonatomic, assign) NSUInteger maximumKeyFrameInterval;
@property (nonatomic, readonly) long outputFileSize;
@property (nonatomic, assign) id<DLVideoEncoderDelegate> delegate;

- (void)startNewRecording;
- (void)stopRecording;
- (void)setup;
- (void)setupWriter;
- (void)cleanup;
- (void)encodeImage:(UIImage *)frameImage atPresentationTime:(CMTime)time byteShift:(NSInteger)byteShift;
- (NSURL *)tempFileURL;
- (CMTime)currentFrameTime;

@end

@protocol DLVideoEncoderDelegate <NSObject>
@optional
- (void)videoEncoder:(DLVideoEncoder *)videoEncoder didBeginRecordingAtTime:(NSTimeInterval)startTime;
- (void)videoEncoderWillRender:(DLVideoEncoder *)videoEncoder;
- (void)videoEncoder:(DLVideoEncoder *)videoEncoder willEncodePixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)videoEncoderDidFinishRecording:(DLVideoEncoder *)videoEncoder;
- (void)videoEncoder:(DLVideoEncoder *)videoEncoder didFailRecordingWithError:(NSError *)error;
@end
