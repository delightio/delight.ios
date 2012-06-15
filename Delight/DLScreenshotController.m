//
//  DLScreenshotController.m
//  Delight
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLScreenshotController.h"
#import <QuartzCore/QuartzCore.h>
#import </usr/include/objc/objc-runtime.h>

#define kDLDescriptionKey "DLDescription"

@interface DLScreenshotController ()
- (UIWindow *)keyboardWindow;
- (CGContextRef)newBitmapContextOfSize:(CGSize)size;
- (void)drawLabelCenteredAt:(CGPoint)point inWindow:(UIWindow *)window inContext:(CGContextRef)context 
                       text:(NSString *)text textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor 
                   fontSize:(CGFloat)fontSize transform:(CGAffineTransform)transform;
- (void)hidePrivateFrames:(NSSet *)privateViews forWindow:(UIWindow *)window inContext:(CGContextRef)context;
- (void)hideKeyboardWindow:(UIWindow *)window inContext:(CGContextRef)context;
- (void)writeImageToPNG:(UIImage *)image;
@end

@implementation DLScreenshotController

@synthesize scaleFactor;
@synthesize hidesKeyboard;
@synthesize writesToPNG;
@synthesize imageSize;
@synthesize privateViews;

- (id)init
{
    self = [super init];
    if (self) {
        bitmapData = NULL;
        privateViews = [[NSMutableSet alloc] init];
        self.scaleFactor = 1.0f;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardDidShowNotification:) name:UIKeyboardDidShowNotification object:nil];    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardDidHideNotification:) name:UIKeyboardDidHideNotification object:nil];    
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
    
    [privateViews release];
    [keyboardWindow release];
    
    [super dealloc];
}

#pragma mark - Public methods

- (void)setScaleFactor:(CGFloat)aScaleFactor
{
    scaleFactor = aScaleFactor;
    
    UIScreen *mainScreen = [UIScreen mainScreen];
    imageSize = CGSizeMake(mainScreen.bounds.size.width * scaleFactor * mainScreen.scale, mainScreen.bounds.size.height * scaleFactor * mainScreen.scale);
}

- (UIImage *)screenshot
{
    CGSize windowSize = [[UIScreen mainScreen] bounds].size;
    CGContextRef context = [self newBitmapContextOfSize:imageSize];
    
    // Flip the y-axis since Core Graphics starts with 0 at the bottom
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -imageSize.height);
    
    // Clear the status bar since we don't draw over it
    CGContextClearRect(context, [[UIApplication sharedApplication] statusBarFrame]);
    
    // Store the private view frames at the time that rendering begins.
    // We don't use the views directly because the frames may have changed after rendering finishes.
    // We want to black out their original positions.
    NSMutableSet *privateFramesAtRenderTime = [[NSMutableSet alloc] initWithCapacity:[privateViews count]];
    for (UIView *view in privateViews) {
        NSString *description = objc_getAssociatedObject(view, kDLDescriptionKey);
        CGRect frameInWindow = [view convertRect:view.bounds toView:view.window];

        NSDictionary *viewDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithCGRect:frameInWindow], @"frame",
                                  view.window, @"window",
                                  description, @"description", nil];
        [privateFramesAtRenderTime addObject:viewDict];
    }
    
    // Iterate over every window from back to front
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen]) {
            CGContextSaveGState(context);
            
            // Center the context around the window's anchor point
            CGContextTranslateCTM(context, [window center].x, [window center].y);
            
            // Apply the window's transform about the anchor point
            CGContextTranslateCTM(context, (imageSize.width - windowSize.width) / 2, (imageSize.height - windowSize.height) / 2);
            CGContextConcatCTM(context, [window transform]);   
            CGContextScaleCTM(context, scaleFactor * [UIScreen mainScreen].scale, scaleFactor * [UIScreen mainScreen].scale);
            
            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context,
                                  -[window bounds].size.width * [[window layer] anchorPoint].x,
                                  -[window bounds].size.height * [[window layer] anchorPoint].y);
            
            if (!hidesKeyboard || window != keyboardWindow) {
                // Draw the view hierarchy onto our context
                [[window layer] renderInContext:context];
            }
            
            [self hidePrivateFrames:privateFramesAtRenderTime forWindow:window inContext:context];
            
            CGContextRestoreGState(context);
            
            if (hidesKeyboard && window == keyboardWindow) {
                [self hideKeyboardWindow:keyboardWindow inContext:context];
            }
        }
    }
    
    [privateFramesAtRenderTime release];
    
    // Retrieve the screenshot image
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(context);
    
    if (writesToPNG) {
        [self writeImageToPNG:image];
    }
    
    return image;
}

- (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    if (![privateViews containsObject:view]) {
        objc_setAssociatedObject(view, kDLDescriptionKey, description, OBJC_ASSOCIATION_RETAIN);
        [privateViews addObject:view];
        DLLog(@"[Delight] Registered private view: %@", [view class]);
    }
}

- (void)unregisterPrivateView:(UIView *)view
{
    if ([privateViews containsObject:view]) {
        objc_setAssociatedObject(view, kDLDescriptionKey, nil, OBJC_ASSOCIATION_RETAIN);
        [privateViews removeObject:view];
        DLLog(@"[Delight] Unregistered private view: %@", [view class]);
    }
}

#pragma mark - Private methods

- (UIWindow *)keyboardWindow
{
	NSArray *windows = [[UIApplication sharedApplication] windows];
	for (UIWindow *window in [windows reverseObjectEnumerator]) {
		for (UIView *view in [window subviews]) {
			if ([[[view class] description] isEqualToString:@"UIKeyboard"] || [[[view class] description] isEqualToString:@"UIPeripheralHostView"]) {
				return window;
			}
		}
	}
	
	return nil;
}

- (CGContextRef)newBitmapContextOfSize:(CGSize)size 
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * size.height);
    if (bitmapData != NULL) {
        free(bitmapData);
    }
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }

    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (bitmapData,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaNoneSkipFirst);
    
    CGContextSetAllowsAntialiasing(context, NO);
    CGContextSetAllowsFontSmoothing(context, NO);
    CGContextSetAllowsFontSubpixelPositioning(context, NO);
    CGContextSetAllowsFontSubpixelQuantization(context, NO);
    CGContextSetShouldAntialias(context, NO);
    CGContextSetShouldSmoothFonts(context, NO);
    CGContextSetShouldSubpixelPositionFonts(context, NO);
    CGContextSetShouldSubpixelQuantizeFonts(context, NO);
    CGColorSpaceRelease( colorSpace );

    if (context == NULL) {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    
    return context;
}

- (void)drawLabelCenteredAt:(CGPoint)point inWindow:(UIWindow *)window inContext:(CGContextRef)context text:(NSString *)text textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor fontSize:(CGFloat)fontSize transform:(CGAffineTransform)transform
{
    UIView *labelSuperview = [[UIView alloc] initWithFrame:window.frame];
    UILabel *label = [[UILabel alloc] initWithFrame:window.bounds];
    label.backgroundColor = backgroundColor;
    label.textColor = textColor;
    label.text = text;
    label.textAlignment = UITextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:fontSize];
    label.transform = transform;
    [label sizeToFit];
    label.center = point;
    [labelSuperview addSubview:label];
    [labelSuperview.layer renderInContext:context];
    [label removeFromSuperview];
    [label release];
    [labelSuperview release];    
}

- (void)hidePrivateFrames:(NSSet *)frames forWindow:(UIWindow *)window inContext:(CGContextRef)context
{
    // Black out private views
    for (NSDictionary *frameDict in frames) {
        CGRect frame = [[frameDict objectForKey:@"frame"] CGRectValue];
        UIWindow *viewWindow = [frameDict objectForKey:@"window"];
        NSString *description = [frameDict objectForKey:@"description"];
        
        if (viewWindow == window) {
            CGContextSetGrayFillColor(context, 0.1, 1.0);
            CGContextFillRect(context, frame);
            UIView *windowRootView = ([window.subviews count] > 0 ? [window.subviews objectAtIndex:0] : nil);
            
            if ((NSNull *)description != [NSNull null]) {
                [self drawLabelCenteredAt:CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame))
                                 inWindow:window
                                inContext:context 
                                     text:description 
                                textColor:[UIColor whiteColor] 
                          backgroundColor:[UIColor colorWithWhite:0.1 alpha:1.0]
                                 fontSize:18.0
                                transform:(windowRootView ? windowRootView.transform : CGAffineTransformIdentity)];
            }
        }
    }
}

- (BOOL)locationIsInPrivateView:(CGPoint)location inView:(UIView *)locationView privateViewFrame:(CGRect *)frame
{    
    for (UIView *view in privateViews) {
        CGRect frameInWindow = [view convertRect:view.bounds toView:locationView];
            
        if (CGRectContainsPoint(frameInWindow, location) && view.window && !view.hidden) {
            if (frame) {
                *frame = frameInWindow;
            }
            return YES;
        }
    }

    if (keyboardWindow && hidesKeyboard) {
        if (CGRectContainsPoint(keyboardFrame, location)) {
            if (frame) {
                *frame = keyboardFrame;
            }
            return YES;
        }
    }

    if (frame) {
        *frame = CGRectZero;
    }
    return NO;
}

- (void)hideKeyboardWindow:(UIWindow *)window inContext:(CGContextRef)context
{
    if (!window) return;
    
    CGContextSaveGState(context);
    
    CGFloat contentScale = [[UIScreen mainScreen] scale];
    CGRect scaledKeyboardFrame = CGRectMake(keyboardFrame.origin.x * scaleFactor * contentScale,
                                            keyboardFrame.origin.y * scaleFactor * contentScale,
                                            keyboardFrame.size.width * scaleFactor * contentScale,
                                            keyboardFrame.size.height * scaleFactor * contentScale);

    UIColor *fillColor = [UIColor colorWithRed:128/255.0 green:137/255.0 blue:149/255.0 alpha:1.0];
    CGContextSetFillColorWithColor(context, [fillColor CGColor]);
    CGContextFillRect(context, scaledKeyboardFrame);
    
    [self drawLabelCenteredAt:CGPointMake(CGRectGetMidX(scaledKeyboardFrame), CGRectGetMidY(scaledKeyboardFrame))
                     inWindow:window
                    inContext:context 
                         text:@"Keyboard Hidden"
                    textColor:[UIColor whiteColor]
              backgroundColor:fillColor
                     fontSize:24.0*scaleFactor*contentScale
                    transform:CGAffineTransformMake(window.transform.a, window.transform.b, window.transform.c, window.transform.d, 0, 0)]; // Only take into account scale/rotation
    
    CGContextRestoreGState(context);
}

- (void)writeImageToPNG:(UIImage *)image
{
    NSString *filename = [NSString stringWithFormat:@"Documents/frame_%i.png", pngCount++];
    NSString *pngPath = [NSHomeDirectory() stringByAppendingPathComponent:filename];
    [UIImagePNGRepresentation(image) writeToFile:pngPath atomically:YES];
}

#pragma mark - Notifications

- (void)handleKeyboardDidShowNotification:(NSNotification *)notification
{
    keyboardWindow = [[self keyboardWindow] retain];
    keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
}

- (void)handleKeyboardDidHideNotification:(NSNotification *)notification
{
    [keyboardWindow release];
    keyboardWindow = nil;
}

@end
