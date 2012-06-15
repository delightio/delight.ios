//
//  DLUIKitVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLUIKitVideoEncoder.h"

@implementation DLUIKitVideoEncoder

- (void)startNewRecording
{
    [super startNewRecording];
    
    // We can set up our asset writer already, since we know the video size (from the UIWindow size)
    [self setup];
}

- (void)encodeImage:(UIImage *)frameImage
{
    if ([videoWriterInput isReadyForMoreMediaData] && self.recording) {
        CMTime time = [self currentFrameTime];
        
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
            CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);  // Will work if the pixel buffer is contiguous and has the same bytesPerRow as the input data
            
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

@end
