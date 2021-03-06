//
//  DLMobileFrameBufferVideoEncoder.h
//  Delight
//
//  Created by Chris Haugli on 6/20/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLVideoEncoder.h"
#include "IOSurface/IOSurface.h"

@interface DLMobileFrameBufferVideoEncoder : DLVideoEncoder {
    IOSurfaceRef bgraSurface;
    CGFloat videoScale;
    CIContext *imageContext;
    CGColorSpaceRef colorSpace;
}

- (void)encode;

@end
