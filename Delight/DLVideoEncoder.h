//
//  DLVideoEncoder.h
//  Delight
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol DLVideoEncoderDelegate;

/* 
   DLVideoEncoder encodes video to a file.
 */
@interface DLVideoEncoder : NSObject {
    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;    
    NSLock *lock;
}

@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, assign) BOOL savesToPhotoAlbum;
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) double averageBitRate;
@property (nonatomic, assign) NSUInteger maximumKeyFrameInterval;
@property (nonatomic, readonly) long outputFileSize;
@property (nonatomic, readonly) int pixelFormatType;
@property (nonatomic, assign) NSTimeInterval recordingStartTime;  // System uptime at recording start    
@property (nonatomic, assign) id<DLVideoEncoderDelegate> delegate;

- (void)startNewRecording;
- (void)stopRecording;
- (void)setup;
- (void)setupWriter;
- (void)cleanup;
- (void)encodeImage:(UIImage *)frameImage atPresentationTime:(CMTime)time byteShift:(NSInteger)byteShift scale:(CGFloat)scale;
- (NSURL *)tempFileURL;
- (CMTime)currentFrameTime;
- (NSTimeInterval)currentFrameTimeInterval;
- (UIImage *)resizedImageForPixelData:(void *)pixelData width:(int)backingWidth height:(int)backingHeight;

@end

@protocol DLVideoEncoderDelegate <NSObject>
@optional
- (void)videoEncoder:(DLVideoEncoder *)videoEncoder didBeginRecordingAtTime:(NSTimeInterval)startTime;
- (void)videoEncoderWillRender:(DLVideoEncoder *)videoEncoder;
- (void)videoEncoder:(DLVideoEncoder *)videoEncoder willEncodePixelBuffer:(CVPixelBufferRef)pixelBuffer scale:(CGFloat)scale;
- (void)videoEncoderDidFinishRecording:(DLVideoEncoder *)videoEncoder;
- (void)videoEncoder:(DLVideoEncoder *)videoEncoder didFailRecordingWithError:(NSError *)error;
@end
