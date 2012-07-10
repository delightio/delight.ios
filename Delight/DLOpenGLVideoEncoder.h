//
//  DLOpenGLVideoEncoder.h
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLVideoEncoder.h"

@interface DLOpenGLVideoEncoder : DLVideoEncoder {
    CVPixelBufferPoolRef pixelBufferPool;
    BOOL encoding;
    GLint pixelFormat;
    GLint pixelType;
}

@property (nonatomic, assign) BOOL usesImplementationPixelFormat;

- (void)encodeGLPixelsWithBackingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight;

@end
