//
//  CALayer+DLThreadSafe.m
//  Delight
//
//  Created by Chris Haugli on 5/7/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "CALayer+DLThreadSafe.h"
#import "Delight_Internal.h"
#import </usr/include/objc/objc-runtime.h>

DL_MAKE_CATEGORIES_LOADABLE(CALayer_DLThreadSafe);

@implementation CALayer (DLThreadSafe)

- (void)DLthreadSafeRenderInContext:(CGContextRef)context
{
    if ([self isRendingInBackground]) {
        // If calling from background thread, trying to render a UIWebView tile host layer will result in a crash.
        // Copy the layer to a plain CALayer and render that instead.
        CALayer *layerCopy = [self copyWithPlainLayer];
        [layerCopy renderInContext:context];
        [layerCopy release];
    } else {
        // No thread safety problems if calling from main or web thread, proceed as normal
        [self DLthreadSafeRenderInContext:context];
    }
}

- (void)DLthreadSafeDrawInContext:(CGContextRef)context
{
    if ([self isRendingInBackground]) {
        // If calling from background thread, trying to draw a UIWebView WebLayer/WebTiledLayer will result in a crash.
        // Copy the layer to a plain CALayer and draw that instead.
        CALayer *layerCopy = [self copyWithPlainLayer];
        [layerCopy drawInContext:context];
        [layerCopy release];
    } else {
        // No thread safety problems if calling from main or web thread, proceed as normal
        [self DLthreadSafeDrawInContext:context];
    }
}

// Need a different implementation for WebTiledLayer since it's a subclass of WebLayer, and otherwise we end up calling the super method by accident
- (void)DLthreadSafeDrawInContext2:(CGContextRef)context
{    
    if ([self isRendingInBackground]) {
        // If calling from background thread, trying to draw a UIWebView WebLayer/WebTiledLayer will result in a crash.
        // Copy the layer to a plain CALayer and draw that instead.
        CALayer *layerCopy = [self copyWithPlainLayer];
        [layerCopy drawInContext:context];
        [layerCopy release];
    } else {
        // No thread safety problems if calling from main or web thread, proceed as normal
        [self DLthreadSafeDrawInContext2:context];
    }
}

- (BOOL)isRendingInBackground
{
    return [NSThread currentThread] == [Delight sharedInstance].screenshotThread;
}

- (BOOL)isInBackground
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    return (state == UIApplicationStateBackground ||
            state == UIApplicationStateInactive);
}

- (BOOL)isPrivateView
{
    return [[Delight privateViews] containsObject:self.delegate];
}

- (BOOL)isMKMapView
{
    return [[[[self delegate] class] description] isEqualToString:@"MKMapView"];
}

- (BOOL)isVKMapView
{
    return [[[[self delegate] class] description] isEqualToString:@"VKMapView"];
}

- (BOOL)isMapView
{
    return ([self isMKMapView] || [self isVKMapView]);
}

- (void)blackout:(NSString *)description inContext:(CGContextRef)context
{
    CGContextSetGrayFillColor(context, 0.1, 1.0);
    CGContextFillRect(context, self.bounds);
    
    if ([description length]) {
        UILabel *label = [[UILabel alloc] initWithFrame:self.bounds];
        label.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        label.textColor = [UIColor whiteColor];
        label.text = description;
        label.textAlignment = UITextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:18.0];
        label.minimumFontSize = 12.0;
        [label.layer renderInContext:context];
        [label release];
    }
}

- (void)DLrenderInContext:(CGContextRef)context
{
    // Black out private views.
    if ([self isRendingInBackground] && [self isPrivateView]) {
        [self blackout:objc_getAssociatedObject(self.delegate, "DLDescription")
             inContext:context];
        return;
    }
    
    // Black out map views as we could not figure out which
    // layer to swizzle with DLthreadSafeRenderInContext.
    //
    // TODO: We still crash when the app goes into background and tries to
    //       take a snapshot for app transitioin animation. So, as a work
    //       around, we will black out all map views when recording is on.
    if ( [self isMapView] &&
        ([self isRendingInBackground] || [self isInBackground])) {
        [self blackout:@"MKMapView" inContext:context];
        return;
    }
    
    // Due to swizzling, calling DLrenderInContext will actually call the original renderInContext
    [self DLrenderInContext:context];
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
