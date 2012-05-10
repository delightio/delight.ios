//
//  CALayer+DLThreadSafe.m
//  Delight
//
//  Created by Chris Haugli on 5/7/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "CALayer+DLThreadSafe.h"
#import "Delight.h"

@implementation CALayer (DLThreadSafe)

- (void)DLrenderInContext:(CGContextRef)context
{    
    NSThread *currentThread = [NSThread currentThread];

    if ([currentThread isMainThread] || [[currentThread name] isEqualToString:@"WebThread"]) {
        // No thread safety problems if calling from main or web thread, proceed as normal
        [self DLrenderInContext:context];
    } else {
        // If calling from background thread, trying to render a UIWebView tile host layer will result in a crash.
        // Copy the layer to a plain CALayer and render that instead.
        CALayer *layerCopy = [self copyWithPlainLayer];
        [layerCopy renderInContext:context];
        [layerCopy release];
    }
}

- (CALayer *)copyWithPlainLayer
{
    CALayer *newLayer = [[CALayer alloc] init];
    newLayer.contents = self.contents;
    newLayer.contentsCenter = self.contentsCenter;
    newLayer.contentsGravity = self.contentsGravity;
    newLayer.contentsRect = self.contentsRect;
    newLayer.contentsScale = self.contentsScale;
    newLayer.frame = self.frame;
        
    // Add the sublayers as plain CALayers as well
    // Old-style loop to avoid "mutated while being enumerated" exception
    for (NSInteger i = 0; i < [self.sublayers count]; i++) {
        CALayer *sublayer = [self.sublayers objectAtIndex:i];
        
        // Only need to add the sublayer if it's visible in the application window
        CALayer *windowLayer = [[[[UIApplication sharedApplication] windows] objectAtIndex:0] layer];
        CGRect frameInWindow = [sublayer convertRect:sublayer.bounds toLayer:windowLayer];
        if (CGRectIntersectsRect(frameInWindow, windowLayer.bounds)) {
            CALayer *sublayerCopy = [sublayer copyWithPlainLayer];
            [newLayer addSublayer:sublayerCopy];
            [sublayerCopy release];
        }
    }
        
    return newLayer;
}

@end
