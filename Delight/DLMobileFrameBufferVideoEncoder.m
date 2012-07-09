//
//  DLMobileFrameBufferVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/20/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLMobileFrameBufferVideoEncoder.h"
#import "IOMobileFramebuffer/IOMobileFramebuffer.h"
#include <dlfcn.h>

void CARenderServerRenderDisplay(int, NSString *, IOSurfaceRef, int, int);

// Dynamically-loaded functions
static IOSurfaceRef (*DLIOSurfaceCreate)(CFDictionaryRef);
static void * (*DLIOSurfaceGetBaseAddress)(IOSurfaceRef);
static size_t (*DLIOSurfaceGetAllocSize)(IOSurfaceRef);
static size_t (*DLIOSurfaceGetWidth)(IOSurfaceRef);
static size_t (*DLIOSurfaceGetHeight)(IOSurfaceRef);
static io_service_t (*DLIOServiceGetMatchingService)(mach_port_t, CFDictionaryRef);
static CFMutableDictionaryRef (*DLIOServiceMatching)(const char *);
static IOMobileFramebufferReturn (*DLIOMobileFramebufferOpen)(IOMobileFramebufferService, task_port_t, unsigned int, IOMobileFramebufferConnection *);
static IOMobileFramebufferReturn (*DLIOMobileFramebufferGetLayerDefaultSurface)(IOMobileFramebufferConnection, int, IOSurfaceRef *);

@implementation DLMobileFrameBufferVideoEncoder

- (id)init
{
    self = [super init];
    if (self) {
        // Load the dynamic functions we need
        void *ioSurfaceHandle = dlopen("/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface", RTLD_LAZY);
        DLIOSurfaceCreate = dlsym(ioSurfaceHandle, "IOSurfaceCreate");
        DLIOSurfaceGetBaseAddress = dlsym(ioSurfaceHandle, "IOSurfaceGetBaseAddress");
        DLIOSurfaceGetAllocSize = dlsym(ioSurfaceHandle, "IOSurfaceGetAllocSize");
        DLIOSurfaceGetWidth = dlsym(ioSurfaceHandle, "IOSurfaceGetWidth");
        DLIOSurfaceGetHeight = dlsym(ioSurfaceHandle, "IOSurfaceGetHeight");
        dlclose(ioSurfaceHandle);
        
        void *ioKitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        DLIOServiceGetMatchingService = dlsym(ioKitHandle, "IOServiceGetMatchingService");
        DLIOServiceMatching = dlsym(ioKitHandle, "IOServiceMatching");
        dlclose(ioKitHandle);

        void *ioMobileFramebufferHandle = dlopen("/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer", RTLD_LAZY);
        DLIOMobileFramebufferOpen = dlsym(ioMobileFramebufferHandle, "IOMobileFramebufferOpen");
        DLIOMobileFramebufferGetLayerDefaultSurface = dlsym(ioMobileFramebufferHandle, "IOMobileFramebufferGetLayerDefaultSurface");
        dlclose(ioMobileFramebufferHandle);
    }
    return self;
}

- (void)startNewRecording
{
    [super startNewRecording];
    
    // We can set up our asset writer already, since we know the video size (from the surface size)
    [self setup];
}

- (void)cleanup
{
    [super cleanup];
    
    if (bgraSurface) {
        CFRelease(bgraSurface);
        bgraSurface = NULL;
    }
}

- (void)setup
{
    CGSize defaultSurfaceSize = [self defaultSurfaceSize];
    if (defaultSurfaceSize.height > 1024.0) {
        // Encoder has a dimension limit, need to scale down our video
        videoScale = 0.5;
    } else {
        videoScale = 1.0;
    }
    self.videoSize = CGSizeMake(defaultSurfaceSize.width * videoScale, defaultSurfaceSize.height * videoScale);
    
    uint32_t width = (uint32_t) defaultSurfaceSize.width;
    uint32_t height = (uint32_t) defaultSurfaceSize.height;

    // Create a BGRA surface that we will render the display to
    int pitch = width * 4, allocSize = 4 * width * height;
    int bPE = 4;
    char pixelFormat[4] = {'A', 'R', 'G', 'B'};
    CFMutableDictionaryRef dict;
    dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                     &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(dict, @"IOSurfaceIsGlobal", kCFBooleanTrue);
    CFDictionarySetValue(dict, @"IOSurfaceBytesPerRow", CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pitch));
    CFDictionarySetValue(dict, @"IOSurfaceBytesPerElement", CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bPE));
    CFDictionarySetValue(dict, @"IOSurfaceWidth", CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width));
    CFDictionarySetValue(dict, @"IOSurfaceHeight", CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height));
    CFDictionarySetValue(dict, @"IOSurfacePixelFormat", CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, pixelFormat));
    CFDictionarySetValue(dict, @"IOSurfaceAllocSize", CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &allocSize));
    bgraSurface = DLIOSurfaceCreate(dict);
    
    [super setup];
}

- (void)encode
{
    if (![videoWriterInput isReadyForMoreMediaData] || !self.recording) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(videoEncoderWillRender:)]) {
        [self.delegate videoEncoderWillRender:self];
    }
    
    CMTime time = [self currentFrameTime];
    
    // Render the display to our BGRA surface
    CARenderServerRenderDisplay(0, @"LCD", bgraSurface, 0, 2);
    void *frameBuffer = DLIOSurfaceGetBaseAddress(bgraSurface);
    
    if (videoScale == 1.0) {
        // We can encode the surface data directly
        CVPixelBufferRef pixelBuffer = NULL;
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, avAdaptor.pixelBufferPool, &pixelBuffer);
        if ((pixelBuffer == NULL) || (status != kCVReturnSuccess)) {
            DLLog(@"[Delight] Error creating pixel buffer: status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
            return;
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *pixelBufferData = (void *) CVPixelBufferGetBaseAddress(pixelBuffer);
        memcpy(pixelBufferData, frameBuffer, DLIOSurfaceGetAllocSize(bgraSurface));
        
        if ([self.delegate respondsToSelector:@selector(videoEncoder:willEncodePixelBuffer:)]) {
            [self.delegate videoEncoder:self willEncodePixelBuffer:pixelBuffer];
        }
        
        if (self.recording && ![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
            DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
    } else {
        // Need to scale down before encoding
        UIImage *image = [self resizedImageForPixelData:frameBuffer width:DLIOSurfaceGetWidth(bgraSurface) height:DLIOSurfaceGetHeight(bgraSurface)];
        [self encodeImage:image atPresentationTime:time byteShift:0];
    }
}

#pragma mark - Private methods

- (CGSize)defaultSurfaceSize
{
    IOMobileFramebufferConnection connect;
    IOSurfaceRef defaultSurface = NULL;
    
    io_service_t framebufferService = DLIOServiceGetMatchingService(0, DLIOServiceMatching("AppleCLCD"));
    if (framebufferService) {
        DLDebugLog(@"Using AppleCLCD");
    } else {
        framebufferService = DLIOServiceGetMatchingService(0, DLIOServiceMatching("AppleH1CLCD"));
        if (framebufferService) {
            DLDebugLog(@"Using AppleH1CLCD");
        } else {
            framebufferService = DLIOServiceGetMatchingService(0, DLIOServiceMatching("AppleM2CLCD"));
            if (framebufferService) {
                DLDebugLog(@"Using AppleM2CLCD");
            } else {
                framebufferService = DLIOServiceGetMatchingService(0, DLIOServiceMatching("IOMobileFramebuffer"));
                if (framebufferService) {
                    DLDebugLog(@"Using IOMobileFramebuffer");
                } 
            }
        }
    }
    
    if (framebufferService) {
        DLIOMobileFramebufferOpen(framebufferService, mach_task_self(), 0, &connect);
        DLIOMobileFramebufferGetLayerDefaultSurface(connect, 0, &defaultSurface);
    }
    
    if (!defaultSurface) {
        DLLog(@"[Delight] Couldn't detect surface size, defaulting to screen size");
        CGFloat scale = [[UIScreen mainScreen] scale];
        return CGSizeMake([UIScreen mainScreen].bounds.size.width * scale, [UIScreen mainScreen].bounds.size.height * scale);
    }
    
    size_t width = DLIOSurfaceGetWidth(defaultSurface);
    size_t height = DLIOSurfaceGetHeight(defaultSurface);
    return CGSizeMake(width, height);
}

@end
