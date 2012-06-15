//
//  DLOpenGLVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLOpenGLVideoEncoder.h"

@implementation DLOpenGLVideoEncoder

- (void)setupWriter
{
    [super setupWriter];
    
    // Flip video to its correct orientation
    videoWriterInput.transform = CGAffineTransformMakeScale(1, -1);
}

- (void)setupPixelBuffer
{
    [super setupPixelBuffer];
    
    // Create our own pixel buffer, since when encoding raw bytes we need the buffer to be at least 1 byte larger
    // than the avAdaptor's pixel buffer to account for RGBA->ARGB offset shift.
    pixelBufferPool = NULL;
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, 
                                [NSNumber numberWithUnsignedInt:self.videoSize.width], kCVPixelBufferWidthKey,
                                [NSNumber numberWithUnsignedInt:self.videoSize.height + 1], kCVPixelBufferHeightKey, nil];        
    CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL,
                            (CFDictionaryRef)attributes, &pixelBufferPool);
}

- (void)cleanup
{
    [super cleanup];
    
    if (pixelBufferPool) {
        CVPixelBufferPoolRelease(pixelBufferPool); pixelBufferPool = NULL;
    }
}

- (void)encodeGLPixelsWithBackingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{
    if (!videoWriter) {
        if (self.outputPath) {
            self.videoSize = CGSizeMake(backingWidth, backingHeight);
            [self setup];
        } else {
            // We don't have a session yet
            return;
        }
    }
    
    if (![videoWriterInput isReadyForMoreMediaData] || !self.recording) {
        return;
    }
    
    CVPixelBufferRef pixel_buffer = NULL;
    
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &pixel_buffer);
    if ((pixel_buffer == NULL) || (status != kCVReturnSuccess)) {
        return;
    } else {
        CVPixelBufferLockBaseAddress(pixel_buffer, 0);
        GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
        glReadPixels(0, 0, self.videoSize.width, self.videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData + 1);  // + 1 to convert RGBA->ARGB
    }
    
    CMTime time = [self currentFrameTime];
    if (![avAdaptor appendPixelBuffer:pixel_buffer withPresentationTime:time]){
        DLLog(@"[Delight] Problem appending pixel buffer at time: %lld", time.value);
    } 
    
    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
    CVPixelBufferRelease(pixel_buffer);    
}

@end
