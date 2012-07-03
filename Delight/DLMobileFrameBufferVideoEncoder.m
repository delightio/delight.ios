//
//  DLMobileFrameBufferVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/20/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLMobileFrameBufferVideoEncoder.h"
#include "IOKit/IOKitLib.h"
#include "IOMobileFramebuffer/IOMobileFramebuffer.h"

#define kDLMaxSurfaceID 200
#define kDLMinSurfaceScale 0.5
#define kDLMaxSearchIterations 8

int calculateHash(IOSurfaceID surfaceID)
{
    IOSurfaceRef surface = IOSurfaceLookup(surfaceID);
    size_t size = IOSurfaceGetAllocSize(surface) / sizeof(uint32_t);
    uint32_t *baseAddress = IOSurfaceGetBaseAddress(surface);
    uint32_t hash = IOSurfaceGetSeed(surface);
    
    for (size_t i = 0; i < size; i += 37) {
        uint32_t pixelValue = baseAddress[i];
        hash += pixelValue;
    }
    
    return hash;
}

@interface DLMobileFrameBufferVideoEncoder ()
- (void)findPotentialSurfaces;
- (void)updatePotentialSurfaces;
@end

@implementation DLMobileFrameBufferVideoEncoder

@synthesize potentialSurfaces = _potentialSurfaces;

- (id)init
{
    self = [super init];
    if (self) {
        foundSurfaceID = -1;
    }
    return self;
}

- (void)dealloc
{
    CFRelease(accelerator);
    CFRelease(bgraSurface);
    [_potentialSurfaces release];
    
    [super dealloc];
}

- (void)setup
{
    IOSurfaceRef surface = IOSurfaceLookup(foundSurfaceID);
    size_t width = IOSurfaceGetWidth(surface);
    size_t height = IOSurfaceGetHeight(surface);
    self.videoSize = CGSizeMake(width, height);
    
    IOSurfaceAcceleratorCreate(NULL, 0, &accelerator);
    if (accelerator == NULL) {
        DLLog(@"[Delight] Error: Accelerator was not created");
    }
    
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
    bgraSurface = IOSurfaceCreate(dict);

    [super setup];
}

- (void)encode
{
    if (!surfaceFound) {
        if (self.potentialSurfaces) {
            [self updatePotentialSurfaces];
        } else {
            [self findPotentialSurfaces];
        }
        
        if (surfaceFound) {
            [self setup];
        } else {
            return;
        }
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
    
    IOSurfaceRef surface = IOSurfaceLookup(foundSurfaceID);
    IOSurfaceLock(surface, kIOSurfaceLockReadOnly, &aseed);
    IOSurfaceAcceleratorTransferSurface(accelerator, surface, bgraSurface, ed, NULL);
    IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, &aseed);

    void *frameBuffer = IOSurfaceGetBaseAddress(bgraSurface);
    memcpy(pixelBufferData, frameBuffer, self.videoSize.height * self.videoSize.width * 4);

    if (self.recording && ![avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time]) {
        DLLog(@"[Delight] Unable to write buffer to video: %@", videoWriter.error);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);
}

#pragma mark - Private methods

- (void)findPotentialSurfaces
{    
    NSMutableSet *potentialSurfaceSet = [NSMutableSet set];
    CGFloat screenScale = [UIScreen mainScreen].scale;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width * screenScale;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height * screenScale;
    
    // Loop through all surface IDs finding surfaces that are potentially big enough
    for (int i = 0; i < kDLMaxSurfaceID; i++) {
        IOSurfaceRef surface = IOSurfaceLookup(i);
        if (surface) {
            size_t width = IOSurfaceGetWidth(surface);
            size_t height = IOSurfaceGetHeight(surface);
            
            if ((width >= screenWidth * kDLMinSurfaceScale && height >= screenHeight * kDLMinSurfaceScale) ||
                 (height >= screenWidth * kDLMinSurfaceScale && width >= screenHeight * kDLMinSurfaceScale)) {                    
                    NSMutableDictionary *surfaceDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithInt:i], @"surfaceID",
                                                        [NSNumber numberWithInt:calculateHash(i)], @"lastHash", nil];
                    [potentialSurfaceSet addObject:surfaceDict];
                }
        }
    }
    
    self.potentialSurfaces = potentialSurfaceSet;
    surfaceFound = NO;
    searchIterations = 0;
}

- (void)updatePotentialSurfaces
{
    NSMutableSet *surfacesToRemove = [NSMutableSet set];
    
    for (NSMutableDictionary *surfaceDict in self.potentialSurfaces) {
        IOSurfaceID surfaceID = [[surfaceDict objectForKey:@"surfaceID"] intValue];
        int lastHash = [[surfaceDict objectForKey:@"lastHash"] intValue];
        int newHash = calculateHash(surfaceID);
        [surfaceDict setObject:[NSNumber numberWithInt:newHash] forKey:@"lastHash"];
        
        if (lastHash == newHash) {
            // Surface is out of the running
            [surfacesToRemove addObject:surfaceDict];
        }
    }
    
    [self.potentialSurfaces minusSet:surfacesToRemove];
    
    if ([self.potentialSurfaces count] == 0) {
        [self findPotentialSurfaces];
        DLLog(@"[Delight] No surfaces found, retrying");
    } else if ([self.potentialSurfaces count] == 1 || ++searchIterations > kDLMaxSearchIterations) {
        foundSurfaceID = [[[self.potentialSurfaces anyObject] objectForKey:@"surfaceID"] intValue];
        surfaceFound = YES;        
        DLLog(@"[Delight] Using surface #%i", foundSurfaceID);
    }    
}

@end
