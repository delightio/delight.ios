//
//  DLImageVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLImageVideoEncoder.h"

@implementation DLImageVideoEncoder

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
        if (status != 0) {
            //could not get a buffer from the pool
            DLLog(@"Error creating pixel buffer: status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
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

@end
