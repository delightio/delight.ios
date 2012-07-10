//
//  DLUIKitVideoEncoder.m
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLUIKitVideoEncoder.h"

@implementation DLUIKitVideoEncoder

- (void)startNewRecording
{
    [super startNewRecording];
    
    // We can set up our asset writer already, since we know the video size (from the UIWindow size)
    [self setup];
}

- (void)encodeImage:(UIImage *)frameImage
{
    [self encodeImage:frameImage atPresentationTime:[self currentFrameTime] byteShift:0 scale:1.0f];
}

@end
