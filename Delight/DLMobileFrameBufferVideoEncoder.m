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
#include <dlfcn.h>

#define kDLMaxSurfaceID 200
#define kDLMinSurfaceScale 0.5
#define kDLMaxSearchIterations 8

// Dynamically-loaded functions
static IOSurfaceRef (*DLIOSurfaceCreate)(CFDictionaryRef);
static IOReturn (*DLIOSurfaceLock)(IOSurfaceRef, uint32_t, uint32_t *);
static IOReturn (*DLIOSurfaceUnlock)(IOSurfaceRef, uint32_t, uint32_t *);
static IOSurfaceAcceleratorReturn (*DLIOSurfaceAcceleratorCreate)(CFAllocatorRef, uint32_t, IOSurfaceAcceleratorRef *);
static IOSurfaceAcceleratorReturn (*DLIOSurfaceAcceleratorTransferSurface)(IOSurfaceAcceleratorRef, IOSurfaceRef, IOSurfaceRef, CFDictionaryRef, void *);
static IOSurfaceRef (*DLIOSurfaceLookup)(IOSurfaceID);
static void * (*DLIOSurfaceGetBaseAddress)(IOSurfaceRef);
static size_t (*DLIOSurfaceGetAllocSize)(IOSurfaceRef);
static size_t (*DLIOSurfaceGetWidth)(IOSurfaceRef);
static size_t (*DLIOSurfaceGetHeight)(IOSurfaceRef);
static uint32_t (*DLIOSurfaceGetSeed)(IOSurfaceRef);

int calculateHash(IOSurfaceID surfaceID)
{
    IOSurfaceRef surface = DLIOSurfaceLookup(surfaceID);
    size_t size = DLIOSurfaceGetAllocSize(surface) / sizeof(uint32_t);
    uint32_t *baseAddress = DLIOSurfaceGetBaseAddress(surface);
    uint32_t hash = DLIOSurfaceGetSeed(surface);
    
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
        
        // Load the dynamic functions we need
        void *handle = dlopen("/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface", RTLD_LAZY);
        DLIOSurfaceCreate = dlsym(handle, "IOSurfaceCreate");
        DLIOSurfaceLock = dlsym(handle, "IOSurfaceLock");
        DLIOSurfaceUnlock = dlsym(handle, "IOSurfaceUnlock");
        DLIOSurfaceAcceleratorCreate = dlsym(handle, "IOSurfaceAcceleratorCreate");
        DLIOSurfaceAcceleratorTransferSurface = dlsym(handle, "IOSurfaceAcceleratorTransferSurface");
        DLIOSurfaceLookup = dlsym(handle, "IOSurfaceLookup");
        DLIOSurfaceGetBaseAddress = dlsym(handle, "IOSurfaceGetBaseAddress");
        DLIOSurfaceGetAllocSize = dlsym(handle, "IOSurfaceGetAllocSize");
        DLIOSurfaceGetWidth = dlsym(handle, "IOSurfaceGetWidth");
        DLIOSurfaceGetHeight = dlsym(handle, "IOSurfaceGetHeight");
        DLIOSurfaceGetSeed = dlsym(handle, "IOSurfaceGetSeed");
        dlclose(handle);
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
    IOSurfaceRef surface = DLIOSurfaceLookup(foundSurfaceID);
    size_t width = DLIOSurfaceGetWidth(surface);
    size_t height = DLIOSurfaceGetHeight(surface);
    self.videoSize = CGSizeMake(width, height);
    
    // Create an accelerator to transfer surfaces quickly
    DLIOSurfaceAcceleratorCreate(NULL, 0, &accelerator);
    if (accelerator == NULL) {
        DLLog(@"[Delight] Error: Accelerator was not created");
    }
    
    // Create a BGRA surface that we will transfer the surface to
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
    
    IOSurfaceRef surface = DLIOSurfaceLookup(foundSurfaceID);
    DLIOSurfaceLock(surface, kIOSurfaceLockReadOnly, &aseed);
    DLIOSurfaceAcceleratorTransferSurface(accelerator, surface, bgraSurface, ed, NULL);
    DLIOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, &aseed);

    void *frameBuffer = DLIOSurfaceGetBaseAddress(bgraSurface);
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
        IOSurfaceRef surface = DLIOSurfaceLookup(i);
        if (surface) {
            size_t width = DLIOSurfaceGetWidth(surface);
            size_t height = DLIOSurfaceGetHeight(surface);
            
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
