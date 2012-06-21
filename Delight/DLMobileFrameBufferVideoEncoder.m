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

- (void)encode
{
    if (!videoWriter) {
        self.videoSize = CGSizeMake(640, 960);
        [self setup];
    }
    
    if (![videoWriterInput isReadyForMoreMediaData] || !self.recording || encoding) {
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

    dispatch_async(dispatch_get_main_queue(), ^{
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
                
        CoreSurfaceBufferLock(surfaceBuffer);
        frameBuffer = CoreSurfaceBufferGetBaseAddress(surfaceBuffer);
        NSLog(@"Screen height: %i, width: %i, bytes per row: %i, size: %zu", screenHeight, screenWidth, bytesPerRow, CoreSurfaceBufferGetAllocSize(surfaceBuffer));
        NSLog(@"Buffer address: %p", frameBuffer);
        /*NSLog(@"Lines:");
        for (int j = 527; j < 535; j++) {
            for (int i = 195; i < 205; i++) {
                printf("%3d ", frameBuffer[i*4 + j*screenWidth]);
                printf("%3d ", frameBuffer[i*4 + 1 + j*screenWidth]);
                printf("%3d ", frameBuffer[i*4 + 2 + j*screenWidth]);
                printf("%3d ", frameBuffer[i*4 + 3 + j*screenWidth]);
            }
            printf("\n");
        }*/

//        // Write to file
//        static int i = 0;
//        if (i++ == 40) {
//            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); 
//            NSString *documentsDirectory = [paths objectAtIndex:0];
//            NSString *file = [documentsDirectory stringByAppendingPathComponent:@"frame.bin"];
//            [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
//            NSMutableData *data = [NSMutableData data];
//            [data appendBytes:frameBuffer length:CoreSurfaceBufferGetAllocSize(surfaceBuffer)];
//            [data writeToFile:file atomically:YES];
//        }        
        
        CoreSurfaceBufferFlushProcessorCaches(surfaceBuffer);
        memcpy(pixelBufferData, frameBuffer, screenHeight * bytesPerRow);
        CoreSurfaceBufferUnlock(surfaceBuffer);
        
        if (self.recording && ![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
            DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
        
        encoding = NO;
    });
}

@end
