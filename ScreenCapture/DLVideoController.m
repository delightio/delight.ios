//
//  DLVideoController.m
//  ScreenCapture
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLVideoController.h"

#define kDefaultBitRate 500.0*1024.0

@interface DLVideoController ()
- (BOOL)setupWriter;
- (void)cleanupWriter;
- (NSURL *)tempFileURL;
@end

@implementation DLVideoController

@synthesize recording;
@synthesize outputPath;
@synthesize videoSize;
@synthesize averageBitRate;

- (id)init
{
    self = [super init];
    if (self) {
        videoWriter = nil;
        videoWriterInput = nil;
        avAdaptor = nil;
        
        pauseTime = 0;
        averageBitRate = kDefaultBitRate;
    }
    return self;
}

- (void)dealloc
{
    [self cleanupWriter];

    [outputPath release];
    
    [super dealloc];
}

- (void)startNewRecording
{
    [self cleanupWriter];
    [self setupWriter];
    
    recording = YES;
}

- (void)stopRecording
{
    if (recording) {
        recording = NO;
        [self completeRecordingSession];
        
        UISaveVideoAtPathToSavedPhotosAlbum([self outputPath], nil, nil, nil);
    }
}

- (void)writeFrameImage:(UIImage *)frameImage
{
    if (![videoWriterInput isReadyForMoreMediaData] || !recording) {
        NSLog(@"Not ready for video data");
    } else {
        float millisElapsed = ([[NSDate date] timeIntervalSinceDate:startedAt] - pauseTime) * 1000.0;
        CMTime time = CMTimeMake((int)millisElapsed, 1000);
        
        @synchronized (self) {
            CVPixelBufferRef pixelBuffer = NULL;
            CGImageRef cgImage = CGImageCreateCopy([frameImage CGImage]);
            CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
            
            int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, avAdaptor.pixelBufferPool, &pixelBuffer);
            if(status != 0){
                //could not get a buffer from the pool
                NSLog(@"Error creating pixel buffer:  status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
            } else {
                // set image data into pixel buffer
                CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
                uint8_t* destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
                CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);  //XXX:  will work if the pixel buffer is contiguous and has the same bytesPerRow as the input data
                
                if(status == 0){
                    BOOL success = [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                    if (!success)
                        NSLog(@"Warning:  Unable to write buffer to video: %@", videoWriter.error);
                }
                
                CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
                CVPixelBufferRelease( pixelBuffer );
            }
            
            CFRelease(image);
            CGImageRelease(cgImage);
        }
    }
}

- (void)addPauseTime:(NSTimeInterval)aPauseTime
{
    pauseTime += aPauseTime;
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
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];                                      
    
    avAdaptor = [[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes] retain];
    
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    startedAt = [[NSDate date] retain];

    return YES;
}

- (void)completeRecordingSession 
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [videoWriterInput markAsFinished];
    
    // Wait for the video
    int status = videoWriter.status;
    while (status == AVAssetWriterStatusUnknown) {
        NSLog(@"Waiting...");
        [NSThread sleepForTimeInterval:0.5f];
        status = videoWriter.status;
    }
    
    @synchronized(self) {
        BOOL success = [videoWriter finishWriting];
        if (!success) {
            NSLog(@"finishWriting returned NO: %@", [[videoWriter error] localizedDescription]);
        }
        
        [self cleanupWriter];
        
        NSLog(@"Completed recording, file is stored at:  %@", outputPath);
    }
    
    [pool drain];
}

- (void)cleanupWriter 
{
    [avAdaptor release]; avAdaptor = nil;
    [videoWriterInput release]; videoWriterInput = nil;
    [videoWriter release]; videoWriter = nil;
    [startedAt release]; startedAt = nil;
}

- (NSURL *)tempFileURL 
{
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            NSLog(@"Could not delete old recording file at path:  %@", outputPath);
        }
    }
    
    return [outputURL autorelease];
}

@end
