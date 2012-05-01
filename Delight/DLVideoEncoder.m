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
- (BOOL)setupWriter;
- (void)cleanupWriter;
- (NSURL *)tempFileURL;
- (CMTime)currentFrameTime;
@end

@implementation DLVideoEncoder

@synthesize recording;
@synthesize paused;
@synthesize encodesRawGLBytes;
@synthesize savesToPhotoAlbum;
@synthesize outputPath;
@synthesize videoSize;
@synthesize averageBitRate;
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
    [self cleanupWriter];

    [outputPath release];
    [lock release];
    
    [super dealloc];
}

- (void)startNewRecording
{
    [self cleanupWriter];
    
    // Delay setting up the writer if encoding raw bytes - we need the exact size of the view first
    if (!encodesRawGLBytes) {
        [self setupWriter];
    }
    
    recording = YES;
}

- (void)stopRecording
{
    if (recording) {
        recording = NO;
        [self completeRecordingSession];
        
        if (savesToPhotoAlbum) {
            UISaveVideoAtPathToSavedPhotosAlbum([self outputPath], nil, nil, nil);
        }
    }
}

- (void)writeFrameImage:(UIImage *)frameImage
{
    if (![videoWriterInput isReadyForMoreMediaData] || !recording || paused) {
        DLDebugLog(@"Not ready for video data");
    } else {
        CMTime time = [self currentFrameTime];
        
        [lock lock];
        
        CVPixelBufferRef pixelBuffer = NULL;
        CGImageRef cgImage = CGImageCreateCopy([frameImage CGImage]);
        CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
        
        int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, avAdaptor.pixelBufferPool, &pixelBuffer);
        if(status != 0){
            //could not get a buffer from the pool
            DLDebugLog(@"Error creating pixel buffer:  status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
        } else {
            // set image data into pixel buffer
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            uint8_t* destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
            CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);  //XXX:  will work if the pixel buffer is contiguous and has the same bytesPerRow as the input data
            
            if(status == 0){
                BOOL success = [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                if (!success)
                    DLDebugLog(@"Warning:  Unable to write buffer to video: %@", videoWriter.error);
            }
            
            CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
            CVPixelBufferRelease( pixelBuffer );
        }
        
        CFRelease(image);
        CGImageRelease(cgImage);
        
        [lock unlock];
    }
}
    
- (void)encodeRawBytesForGLView:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{
    if (!videoWriter) {
        if (outputPath) {
            self.videoSize = CGSizeMake(backingWidth, backingHeight);
            [self setupWriter];
        } else {
            // We don't have a session yet
            return;
        }
    }
    
    CVPixelBufferRef pixel_buffer = NULL;
    
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &pixel_buffer);
    if ((pixel_buffer == NULL) || (status != kCVReturnSuccess)) {
        return;
    } else {
        CVPixelBufferLockBaseAddress(pixel_buffer, 0);
        GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
        glReadPixels(0, 0, videoSize.width, videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData + 1);  // + 1 to convert RGBA->ARGB
    }
    
    CMTime time = [self currentFrameTime];
    if (![avAdaptor appendPixelBuffer:pixel_buffer withPresentationTime:time]){
        NSLog(@"Problem appending pixel buffer at time: %lld", time.value);
    } 
    
    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
    CVPixelBufferRelease(pixel_buffer);    
}

- (void)pause
{
    if (!paused) {
        paused = YES;
        pauseStartTime = [[NSProcessInfo processInfo] systemUptime];
    }
}

- (void)resume
{
    if (paused) {
        paused = NO;
        totalPauseDuration += [[NSProcessInfo processInfo] systemUptime] - pauseStartTime;
    }
}

#pragma mark - Private methods

- (BOOL)setupWriter 
{
    NSError *error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[self tempFileURL] fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:averageBitRate], AVVideoAverageBitRateKey,
                                           nil];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:videoSize.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:videoSize.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    videoWriterInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings] retain];
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];                                      
    avAdaptor = [[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes] retain];
    
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    recordingStartTime = -1;
    totalPauseDuration = 0.0f;
    
    // Create our own pixel buffer, since when encoding raw bytes we need the buffer to be at least 1 byte larger
    // than the avAdaptor's pixel buffer to account for RGBA->ARGB offset shift.
    if (encodesRawGLBytes) {
        pixelBufferPool = NULL;
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, 
                                    [NSNumber numberWithUnsignedInt:videoSize.width], kCVPixelBufferWidthKey,
                                    [NSNumber numberWithUnsignedInt:videoSize.height + 1], kCVPixelBufferHeightKey, nil];        
        CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL,
                                (CFDictionaryRef)attributes, &pixelBufferPool);
    }
    
    return YES;
}

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
    
    [lock lock];
    BOOL success = [videoWriter finishWriting];
    if (success) {
        DLDebugLog(@"Completed recording, file is stored at:  %@", outputPath);
        if ([delegate respondsToSelector:@selector(videoEncoderDidFinishRecording:)]) {
            [delegate videoEncoderDidFinishRecording:self];
        }
    } else {
        DLDebugLog(@"finishWriting returned NO: %@", [[videoWriter error] localizedDescription]);
        if ([delegate respondsToSelector:@selector(videoEncoder:didFailRecordingWithError:)]) {
            [delegate videoEncoder:self didFailRecordingWithError:[videoWriter error]];
        }
    }
        
    [self cleanupWriter];        
    [lock unlock];
    
    [pool drain];
}

- (void)cleanupWriter 
{
    [avAdaptor release]; avAdaptor = nil;
    [videoWriterInput release]; videoWriterInput = nil;
    [videoWriter release]; videoWriter = nil;
    
    if (pixelBufferPool) {
        CVPixelBufferPoolRelease(pixelBufferPool); pixelBufferPool = NULL;
    }
}

- (NSURL *)tempFileURL 
{
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            DLDebugLog(@"Could not delete old recording file at path:  %@", outputPath);
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
    
    float millisElapsed = (now - recordingStartTime - totalPauseDuration) * 1000.0;
    CMTime time = CMTimeMake((int)millisElapsed, 1000);
    
    return time;
}

@end
