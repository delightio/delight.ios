//
//  DLMobileFrameBufferVideoEncoder.h
//  Delight
//
//  Created by Chris Haugli on 6/20/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLVideoEncoder.h"
#include "IOSurface/IOSurface.h"

int calculateHash(IOSurfaceID surfaceID);

@interface DLMobileFrameBufferVideoEncoder : DLVideoEncoder {
    BOOL surfaceFound;
    NSInteger searchIterations;
    
    IOSurfaceID foundSurfaceID;
    IOSurfaceAcceleratorRef accelerator;
    IOSurfaceRef bgraSurface;
}

@property (nonatomic, retain) NSMutableSet *potentialSurfaces;

- (void)encode;

@end
