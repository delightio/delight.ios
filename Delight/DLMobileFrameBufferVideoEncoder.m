//
//  DLMobileFrameBufferVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/20/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLMobileFrameBufferVideoEncoder.h"
#include "IOSurface/IOSurface.h"
#include "IOKit/IOKitLib.h"
#include "IOMobileFramebuffer/IOMobileFramebuffer.h"

@implementation DLMobileFrameBufferVideoEncoder

static IOSurfaceAcceleratorRef accel = NULL;
static IOSurfaceRef surf = NULL;
static IOSurfaceRef ref = NULL;

- (void)setup
{
    uint32_t aseed;    
    IOMobileFramebufferConnection connect;
    
    io_service_t framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleM2TVOut"));
    if (framebufferService) {
        DLDebugLog(@"Using AppleM2TVOut");
    } else {
        framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleCLCD"));
        if (framebufferService) {
            DLDebugLog(@"Using AppleCLCD");
        } else {
            framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleH1CLCD"));
            if (framebufferService) {
                DLDebugLog(@"Using AppleHC1CLCD");
            } else {
                framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleM2CLCD"));
                if (framebufferService) {
                    DLDebugLog(@"Using AppleM2CLCD");
                } else {
                    framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOMobileFramebuffer"));
                    if (framebufferService) {
                        DLDebugLog(@"Using IOMobileFramebuffer");
                    } else {
                        DLLog(@"[Delight] Error: Couldn't find a matching IOService");
                        return;
                    }
                }
            }
        }
    }
    
    IOMobileFramebufferOpen(framebufferService, mach_task_self(), 0, &connect);
    IOMobileFramebufferGetLayerDefaultSurface(connect, 0, &ref);    
    uint32_t width = IOSurfaceGetWidth(ref);
    uint32_t height = IOSurfaceGetHeight(ref);
    
    if (ref == NULL) {
        DLLog(@"[Delight] Error: Couldn't find a surface");
        return;
    }
    
    IOSurfaceAcceleratorCreate(NULL, 0, &accel);
    if (accel == NULL) {
        DLLog(@"[Delight] Error: Accelerator was not created");
        return;
    }
    
    IOSurfaceLock(ref, kIOSurfaceLockReadOnly, &aseed);

    int pitch = width * 4, allocSize = 4 * width * height;
    int bPE = 4;
    char pixelFormat[4] = {'A', 'R', 'G', 'B'};
    CFMutableDictionaryRef dict;
    dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                     &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(dict, kIOSurfaceIsGlobal, kCFBooleanTrue);
    CFDictionarySetValue(dict, kIOSurfaceBytesPerRow,
                         CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pitch));
    CFDictionarySetValue(dict, kIOSurfaceBytesPerElement,
                         CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bPE));
    CFDictionarySetValue(dict, kIOSurfaceWidth,
                         CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width));
    CFDictionarySetValue(dict, kIOSurfaceHeight,
                         CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height));
    CFDictionarySetValue(dict, kIOSurfacePixelFormat,
                         CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, pixelFormat));
    CFDictionarySetValue(dict, kIOSurfaceAllocSize,
                         CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &allocSize));
    surf = IOSurfaceCreate(dict);
    
    IOSurfaceUnlock(ref, kIOSurfaceLockReadOnly, &aseed);
    
    self.videoSize = CGSizeMake(width, height);
    [super setup];
}

- (void)encode
{
    if (!videoWriter) {
        [self setup];
    }
    
    if (![videoWriterInput isReadyForMoreMediaData] || !self.recording) {
        return;
    }

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, avAdaptor.pixelBufferPool, &pixelBuffer);
    if ((pixelBuffer == NULL) || (status != kCVReturnSuccess)) {
        DLLog(@"[Delight] Error creating pixel buffer: status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
        return;
    }
    
    CMTime time = [self currentFrameTime];
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pixelBufferData = (void *) CVPixelBufferGetBaseAddress(pixelBuffer);
    
    CFDictionaryRef ed = (CFDictionaryRef) [[NSDictionary dictionaryWithObjectsAndKeys:nil] retain];
    uint32_t aseed;
    IOSurfaceLock(ref, kIOSurfaceLockReadOnly, &aseed);
    IOSurfaceAcceleratorTransferSurface(accel, ref, surf, ed, NULL);
    IOSurfaceUnlock(ref, kIOSurfaceLockReadOnly, &aseed);
    
    void *frameBuffer = IOSurfaceGetBaseAddress(surf);
    memcpy(pixelBufferData, frameBuffer, self.videoSize.height * self.videoSize.width * 4);
    
    if (self.recording && ![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
        DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);
}

@end
