//
//  DLVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLVideoEncoder.h"
#include <sys/xattr.h>

#define kDLDefaultBitRate 500.0*1024.0

@interface DLVideoEncoder ()
- (void)completeRecordingSession;
@end

@implementation DLVideoEncoder

@synthesize recording;
@synthesize savesToPhotoAlbum;
@synthesize outputPath;
@synthesize videoSize;
@synthesize averageBitRate;
@synthesize maximumKeyFrameInterval;
@synthesize outputFileSize;
@synthesize delegate;

- (id)init
{
    self = [super init];
    if (self) {
        averageBitRate = kDLDefaultBitRate;
        lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];

    [outputPath release];
    [lock release];
    
    [super dealloc];
}

- (void)startNewRecording
{
    [self cleanup];
    recording = YES;
}

- (void)stopRecording
{
    [lock lock];
    if (recording) {
        recording = NO;
        [self completeRecordingSession];
        
        if (savesToPhotoAlbum) {
            UISaveVideoAtPathToSavedPhotosAlbum([self outputPath], nil, nil, nil);
        }
    }
    [lock unlock];
}

- (void)setup
{
    [self setupWriter];

    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    avAdaptor = [[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes] retain];
    
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
}

- (void)setupWriter
{
    NSError *error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[self tempFileURL] fileType:AVFileTypeMPEG4 error:&error];
    NSParameterAssert(videoWriter);
    
    NSMutableDictionary *videoCompressionProps = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithDouble:self.averageBitRate], AVVideoAverageBitRateKey,
                                                  nil];
    if (self.maximumKeyFrameInterval > 0) {
        [videoCompressionProps setObject:[NSNumber numberWithInteger:self.maximumKeyFrameInterval] forKey:AVVideoMaxKeyFrameIntervalKey];
    }
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:self.videoSize.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:self.videoSize.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    videoWriterInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings] retain];
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    recordingStartTime = -1;
}

- (void)cleanup 
{
    [avAdaptor release]; avAdaptor = nil;
    [videoWriterInput release]; videoWriterInput = nil;
    [videoWriter release]; videoWriter = nil;
}

- (void)encodeImage:(UIImage *)frameImage atPresentationTime:(CMTime)time byteShift:(NSInteger)byteShift
{
    if ([videoWriterInput isReadyForMoreMediaData] && self.recording) {        
        [lock lock];
        
        CVPixelBufferRef pixelBuffer = NULL;
        CGImageRef cgImage = CGImageCreateCopy([frameImage CGImage]);
        CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
        
        int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, avAdaptor.pixelBufferPool, &pixelBuffer);
        if (status != kCVReturnSuccess) {
            // Could not get a buffer from the pool
            DLLog(@"[Delight] Error creating pixel buffer: status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
        } else {
            // Put image data into pixel buffer
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            uint8_t *destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
            CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image) - byteShift), destPixels + byteShift);
            
            if (![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]){
                DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
        }
        
        CFRelease(image);
        CGImageRelease(cgImage);
        
        [lock unlock];
    }
}

- (long)outputFileSize
{
    NSError *error = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:&error];
    if (error) {
        return 0;
    }
    return [[fileAttributes objectForKey:NSFileSize] longValue];
}

- (NSURL *)tempFileURL 
{
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            DLDebugLog(@"Could not delete old recording file at path: %@", outputPath);
        }
    }
    
    return [outputURL autorelease];
}

- (CMTime)currentFrameTime
{
    NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];
    if (recordingStartTime < 0) {
        // This is the first frame
        recordingStartTime = now;
        
        if ([delegate respondsToSelector:@selector(videoEncoder:didBeginRecordingAtTime:)]) {
            [delegate videoEncoder:self didBeginRecordingAtTime:recordingStartTime];
        }
    }
    
    float millisElapsed = (now - recordingStartTime) * 1000.0;
    CMTime time = CMTimeMake((int)millisElapsed, 1000);
    
    return time;
}

#pragma mark - Private methods

- (void)completeRecordingSession 
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [videoWriterInput markAsFinished];
    
    // Wait for the video
    int status = videoWriter.status;
    while (status == AVAssetWriterStatusUnknown) {
        DLDebugLog(@"Waiting...");
        [NSThread sleepForTimeInterval:0.5f];
        status = videoWriter.status;
    }
    
    BOOL success = [videoWriter finishWriting];
    if (success) {
        DLDebugLog(@"Completed screen capture, file is stored at: %@", outputPath);
        if ([delegate respondsToSelector:@selector(videoEncoderDidFinishRecording:)]) {
            [delegate videoEncoderDidFinishRecording:self];
        }
    } else {
        DLDebugLog(@"Screen capture failed: %@", [[videoWriter error] localizedDescription]);
        if ([delegate respondsToSelector:@selector(videoEncoder:didFailRecordingWithError:)]) {
            [delegate videoEncoder:self didFailRecordingWithError:[videoWriter error]];
        }
    }
        
    [self cleanup];        
    
    [pool drain];
}

@end
