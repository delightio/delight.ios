//
//  DLOpenGLVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLOpenGLVideoEncoder.h"
#import "DLConstants.h"

// The maximum height that OpenGL recordings should have.
// If a OpenGL backing height is beyond this value, each frame will be scaled down (slow).
#define DL_OPENGL_MAX_VIDEO_HEIGHT 1080

@implementation DLOpenGLVideoEncoder

@synthesize usesImplementationPixelFormat;

- (id)init
{
    self = [super init];
    if (self) {
        self.usesImplementationPixelFormat = NO;
    }
    return self;
}

- (void)setupWriter
{
    [super setupWriter];
    
    // Flip video to its correct orientation
    videoWriterInput.transform = CGAffineTransformMakeScale(1, -1);
}

- (void)openGLSetupForBackingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{
    pixelBufferPool = NULL;
    BOOL rgbaShift;
    
    if (backingHeight > DL_OPENGL_MAX_VIDEO_HEIGHT) {
        // Backing size too big, we need to resize each frame before we encode it
        self.videoSize = CGSizeMake(((double) backingWidth / backingHeight) * DL_OPENGL_MAX_VIDEO_HEIGHT, DL_OPENGL_MAX_VIDEO_HEIGHT);
        rgbaShift = NO;
    } else {
        // Backing size not too big, we can encode the GL bytes directly
        self.videoSize = CGSizeMake(backingWidth, backingHeight);
        rgbaShift = YES;
    }
    
    if (usesImplementationPixelFormat) {
        glGetIntegerv(GL_IMPLEMENTATION_COLOR_READ_FORMAT, &pixelFormat);
        glGetIntegerv(GL_IMPLEMENTATION_COLOR_READ_TYPE, &pixelType);
        rgbaShift = NO;
    } else {
        pixelFormat = GL_RGBA;
        pixelType = GL_UNSIGNED_BYTE;
    }
    
    [self setup];
    
    // Create our own pixel buffer, since the avAdaptor one won't be the right size
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, 
                                [NSNumber numberWithUnsignedInt:backingWidth], kCVPixelBufferWidthKey,
                                [NSNumber numberWithUnsignedInt:backingHeight + (rgbaShift ? 1 : 0)], kCVPixelBufferHeightKey, nil];
    CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (CFDictionaryRef)attributes, &pixelBufferPool);
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
            [self openGLSetupForBackingWidth:backingWidth backingHeight:backingHeight];
        } else {
            // We don't have a session yet, try again in the next frame.
            return;
        }
    }
    
    if (![videoWriterInput isReadyForMoreMediaData] || !self.recording || encoding) {
        return;
    }
    
    encoding = YES;
    
    // Get a pixel buffer
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &pixelBuffer);
    if ((pixelBuffer == NULL) || (status != kCVReturnSuccess)) {
        DLLog(@"[Delight] Error creating pixel buffer: status=%d, pixelBufferPool=%p", status, pixelBufferPool);
        return;
    }
    
    CMTime time = [self currentFrameTime];
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    GLubyte *pixelBufferData = (GLubyte *) CVPixelBufferGetBaseAddress(pixelBuffer);

    if (backingHeight != self.videoSize.height) {
        // Encode a scaled image
        glReadPixels(0, 0, backingWidth, backingHeight, pixelFormat, pixelType, pixelBufferData);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *image = [self resizedImageForPixelData:pixelBufferData width:backingWidth height:backingHeight];
            [self encodeImage:image atPresentationTime:time byteShift:(usesImplementationPixelFormat ? 0 : 1) scale:(self.videoSize.width / backingWidth)];
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
            encoding = NO;
        });
        
    } else {
        // Encode the raw GL bytes directly
        glReadPixels(0, 0, backingWidth, backingHeight, pixelFormat, pixelType, pixelBufferData + (usesImplementationPixelFormat ? 0 : 1));
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{  
            if (![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
                DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
            encoding = NO;
        });
    }
}

@end
