//
//  DLMobileFrameBufferVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/20/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLMobileFrameBufferVideoEncoder.h"
#include "IOKit/IOKitLib.h"
#include "IOSurface/IOSurface.h"
#include "IOMobileFramebuffer/IOMobileFramebuffer.h"
#include "CoreSurface/CoreSurface.h"

@implementation DLMobileFrameBufferVideoEncoder

static CoreSurfaceAcceleratorRef accelerator_;
static CoreSurfaceBufferRef buffer_;
static const size_t BytesPerPixel = 4;
static CFDictionaryRef options_;

static IOSurfaceAcceleratorRef accel=nil;
static IOSurfaceRef surf;
static IOSurfaceRef ref;

- (void)setup
{
    [super setup];

//    CoreSurfaceAcceleratorCreate(NULL, NULL, &accelerator_);
//    options_ = (CFDictionaryRef) [[NSDictionary dictionaryWithObjectsAndKeys:
//                                   nil] retain];
//    
//    if (accelerator_ != NULL) {
//        buffer_ = CoreSurfaceBufferCreate((CFDictionaryRef) [NSDictionary dictionaryWithObjectsAndKeys:
////                                                             @"PurpleEDRAM", kCoreSurfaceBufferMemoryRegion,
//                                                             [NSNumber numberWithBool:YES], kCoreSurfaceBufferGlobal,
//                                                             [NSNumber numberWithInt:(self.videoSize.width * BytesPerPixel)], kCoreSurfaceBufferPitch,
//                                                             [NSNumber numberWithInt:self.videoSize.width], kCoreSurfaceBufferWidth,
//                                                             [NSNumber numberWithInt:self.videoSize.height], kCoreSurfaceBufferHeight,
//                                                             [NSNumber numberWithInt:'BGRA'], kCoreSurfaceBufferPixelFormat,
//                                                             [NSNumber numberWithInt:(self.videoSize.width * self.videoSize.height * BytesPerPixel)], kCoreSurfaceBufferAllocSize,
//                                                             nil]);
//    } else {
//        NSLog(@"Couldn't create accelerator!");
//    }
    
    IOSurfaceID searchId = 1;
    ref = IOSurfaceLookup(searchId);
    uint32_t aseed;
    IOSurfaceLock(ref, kIOSurfaceLockReadOnly, &aseed);
    uint32_t width = IOSurfaceGetWidth(ref);
    uint32_t height = IOSurfaceGetHeight(ref);
    OSType pixFormat = IOSurfaceGetPixelFormat(ref);
    char formatStr[5];
    for(int i=0; i<4; i++ ) {
        formatStr[i] = ((char*)&pixFormat)[3-i];
    }
    NSString *s = [NSString stringWithCString:formatStr encoding:NSUTF8StringEncoding];
    if (![s isEqualToString:@"BGRA"] && ![s isEqualToString:@"ARGB"]) {
        NSLog(@"Error: %@ surface. Only BGRA/ARGB surfaces supported for now\n", s);
    }
    
    IOSurfaceAcceleratorCreate(NULL,NULL,&accel);
    if (accel==nil) {
        NSLog(@"accelerator was not created");
    }
    
    int pitch = width * 4, allocSize = 4 * width * height;
    int bPE = 4;
    char pixelFormat[4] = {'A', 'R', 'G', 'B'};
    CFMutableDictionaryRef dict;
    dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                     &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(dict, kIOSurfaceIsGlobal, kCFBooleanTrue);
    //CFDictionarySetValue(dict, kIOSurfaceMemoryRegion, (CFStringRef)@"PurpleEDRAM");
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
    
    IOSurfaceUnlock(ref,kIOSurfaceLockReadOnly,&aseed);
}


- (void)encode
{
    if (!videoWriter) {
        self.videoSize = CGSizeMake(640, 960);
        [self setup];
    }
    
    if (![videoWriterInput isReadyForMoreMediaData] || !self.recording) {
        return;
    }

    [self encodeIOSurface];
}

- (void)encodeCoreSurface
{        
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, avAdaptor.pixelBufferPool, &pixelBuffer);
    if ((pixelBuffer == NULL) || (status != kCVReturnSuccess)) {
        DLLog(@"[Delight] Error creating pixel buffer: status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
        return;
    }
    
    CMTime time = [self currentFrameTime];
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pixelBufferData = (void *) CVPixelBufferGetBaseAddress(pixelBuffer);

    IOMobileFramebufferConnection conn;
    CoreSurfaceBufferRef surfaceBuffer;
    int screenHeight, screenWidth, bytesPerRow;
    void *frameBuffer;
    
    io_service_t fb_service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleCLCD"));
    if (!fb_service) {
        fb_service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleM2CLCD"));
        if (!fb_service) {
            fb_service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleH1CLCD"));
            if (!fb_service) {
                DLLog(@"[Delight] Couldn't find framebuffer");
            }
        }
    }
    
    IOMobileFramebufferOpen(fb_service, mach_task_self(), 0, &conn);
    IOMobileFramebufferGetLayerDefaultSurface(conn, 0, &surfaceBuffer);
    screenHeight = CoreSurfaceBufferGetHeight(surfaceBuffer);
    screenWidth = CoreSurfaceBufferGetWidth(surfaceBuffer);
    bytesPerRow = CoreSurfaceBufferGetBytesPerRow(surfaceBuffer);
    NSLog(@"Screen height: %i, width: %i, bytes per row: %i, size: %zu", screenHeight, screenWidth, bytesPerRow, CoreSurfaceBufferGetAllocSize(surfaceBuffer));

    CoreSurfaceAcceleratorTransferSurface(accelerator_, surfaceBuffer, buffer_, options_);
    frameBuffer = CoreSurfaceBufferGetBaseAddress(buffer_);
    memcpy(pixelBufferData, frameBuffer, screenHeight * bytesPerRow);
    
//        CoreSurfaceBufferLock(surfaceBuffer, 3);
//        frameBuffer = CoreSurfaceBufferGetBaseAddress(surfaceBuffer);
//        CoreSurfaceBufferFlushProcessorCaches(surfaceBuffer);
//        memcpy(pixelBufferData, frameBuffer, screenHeight * bytesPerRow);
//        CoreSurfaceBufferUnlock(surfaceBuffer);
    
    if (self.recording && ![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
        DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);        
}

- (void)writeBufferToFile:(CoreSurfaceBufferRef)surfaceBuffer
{
    // Write to file
    static int i = 0;
    if (i++ == 40) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); 
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *file = [documentsDirectory stringByAppendingPathComponent:@"frame.bin"];
        [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
        NSMutableData *data = [NSMutableData data];
        [data appendBytes:CoreSurfaceBufferGetBaseAddress(surfaceBuffer) length:CoreSurfaceBufferGetAllocSize(surfaceBuffer)];
        [data writeToFile:file atomically:YES];
    }        
}

- (void)encodeIOSurface
{
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
    IOSurfaceAcceleratorTransferSurface(accel,ref,surf,ed,NULL);
    IOSurfaceUnlock(ref,kIOSurfaceLockReadOnly,&aseed);

    void *frameBuffer = IOSurfaceGetBaseAddress(surf);
    memcpy(pixelBufferData, frameBuffer, self.videoSize.height * self.videoSize.width * 4);

    if (self.recording && ![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
        DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);  
}

@end
