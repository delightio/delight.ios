//
//  DLOpenGLVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLOpenGLVideoEncoder.h"
#import "DLConstants.h"

@interface DLOpenGLVideoEncoder ()
- (UIImage *)resizedImageForPixelData:(GLubyte *)pixelData backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight;
- (void)convertPixelsTo32ARGB:(GLubyte *)pixels width:(GLint)width height:(GLint)height;
@end

@implementation DLOpenGLVideoEncoder

@synthesize usesImplementationPixelFormat;

- (id)init
{
    self = [super init];
    if (self) {
        self.usesImplementationPixelFormat = YES;
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
            if (usesImplementationPixelFormat) {
                [self convertPixelsTo32ARGB:pixelBufferData width:backingWidth height:backingHeight];
            }
            
            UIImage *image = [self resizedImageForPixelData:pixelBufferData backingWidth:backingWidth backingHeight:backingHeight];
            [self encodeImage:image atPresentationTime:time byteShift:(usesImplementationPixelFormat ? 0 : 1)];
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
            encoding = NO;
        });
        
    } else {
        // Encode the raw GL bytes directly
        glReadPixels(0, 0, backingWidth, backingHeight, pixelFormat, pixelType, pixelBufferData + (usesImplementationPixelFormat ? 0 : 1));
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{  
            if (usesImplementationPixelFormat) {
                [self convertPixelsTo32ARGB:pixelBufferData width:backingWidth height:backingHeight];
            }
            
            if (![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
                DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
            encoding = NO;
        });
    }
}

#pragma mark - Private methods

- (UIImage *)resizedImageForPixelData:(GLubyte *)pixelData backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{
    // Create a CGImage with the original pixel data
    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, pixelData, backingWidth * backingHeight * 4, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(backingWidth, backingHeight, 8, 32, backingWidth * 4, colorspace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                                    ref, NULL, true, kCGRenderingIntentDefault);
    
    // Create a graphics context with the target size
    UIGraphicsBeginImageContextWithOptions(self.videoSize, NO, 1.0);

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -self.videoSize.height);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextSetAllowsAntialiasing(context, NO);
	CGContextSetInterpolationQuality(context, kCGInterpolationNone);

    CGContextDrawImage(context, CGRectMake(0.0, 0.0, self.videoSize.width, self.videoSize.height), iref);
    
    // Retrieve the UIImage from the current context
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    // Clean up
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);    
    
    return image;
}

- (void)convertPixelsTo32ARGB:(GLubyte *)pixels width:(GLint)width height:(GLint)height
{
    if (pixelFormat == GL_RGB && pixelType == GL_UNSIGNED_SHORT_5_6_5) {
/*        for (int i = width*height - 1; i >= 0; i--) {
            GLbyte red = pixels[i*2] >> 3 * ((2^8 - 1) / (2^5 - 1));
            GLbyte green = ((pixels[i*2] & 7) << 3 | pixels[i*2 + 1] >> 3) * 
            pixels[i*4 + 1] = 0;
        }*/
    }
}

@end
