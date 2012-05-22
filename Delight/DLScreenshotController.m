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
- (void)hidePrivateViewsForWindow:(UIWindow *)window inContext:(CGContextRef)context;
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
    [openGLImage release];
    [openGLView release];
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
                        
            // Draw the OpenGL view, if there is one
            if (openGLImage && openGLView.window == window) {
                CGContextDrawImage(context, openGLView.frame, [openGLImage CGImage]);
                [openGLImage release]; openGLImage = nil;
                [openGLView release]; openGLView = nil;
            }
            
            [self hidePrivateViewsForWindow:window inContext:context];
            
            CGContextRestoreGState(context);
        }
    }
    
    if (hidesKeyboard) {
        [self hideKeyboardWindow:[self keyboardWindow] inContext:context];
    }
    
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

- (UIImage *)openGLScreenshotForView:(UIView *)view backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{
    NSInteger x = 0;
    NSInteger y = 0; 
    NSInteger width = backingWidth;
    NSInteger height = backingHeight;
    NSInteger dataLength = width * height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    // Create a CGImage with the pixel data
    // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
    // otherwise, use kCGImageAlphaPremultipliedLast
    CGDataProviderRef ref           = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace      = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref                 = CGImageCreate(width, 
                                                    height, 
                                                    8, 
                                                    32, 
                                                    width * 4, 
                                                    colorspace, 
                                                    kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                                    ref, NULL, true, kCGRenderingIntentDefault);
    
    // Rotate the image if necessary (we want everything in "UIWindow orientation", i.e. portrait)
    CGFloat angle;
    switch ([[UIApplication sharedApplication] statusBarOrientation]) {
        case UIInterfaceOrientationLandscapeLeft:  angle = -M_PI_2; break;
        case UIInterfaceOrientationLandscapeRight: angle = M_PI_2;  break;
        default:                                   angle = 0;       break;
    }
	CGRect rotatedRect = CGRectApplyAffineTransform(CGRectMake(0, 0, width, height), 
                                                    CGAffineTransformMakeRotation(angle));
    
    // OpenGL ES measures data in PIXELS
    // Create a graphics context with the target size measured in POINTS
    NSInteger widthInPoints; 
    NSInteger heightInPoints;
    CGRect scaledRotatedRect;
    if (NULL != UIGraphicsBeginImageContextWithOptions) {
        // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
        // Set the scale parameter to your OpenGL ES view's contentScaleFactor
        // so that you get a high-resolution snapshot when its value is greater than 1.0
        CGFloat scale       = scaleFactor / view.contentScaleFactor;
        widthInPoints       = width * scale;
        heightInPoints      = height * scale;
        scaledRotatedRect   = CGRectMake(0, 0, rotatedRect.size.width * scale, rotatedRect.size.height * scale);
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(scaledRotatedRect.size.width, scaledRotatedRect.size.height), NO, view.contentScaleFactor);
    } else {
        // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
        CGFloat scale       = scaleFactor;
        widthInPoints       = width * scale;
        heightInPoints      = height * scale;
        scaledRotatedRect   = CGRectMake(0, 0, rotatedRect.size.width * scale, rotatedRect.size.height * scale);
        UIGraphicsBeginImageContext(CGSizeMake(scaledRotatedRect.size.width, scaledRotatedRect.size.height));
    }
    
    CGContextRef cgcontext  = UIGraphicsGetCurrentContext();
    
    // UIKit coordinate system is upside down to GL/Quartz coordinate system
    // Flip the CGImage by rendering it to the flipped bitmap context
    // Flip the y-axis since Core Graphics starts with 0 at the bottom
    CGContextScaleCTM(cgcontext, 1.0, -1.0);
    CGContextTranslateCTM(cgcontext, 0, -scaledRotatedRect.size.height);

    // The size of the destination area is measured in POINTS
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextSetAllowsAntialiasing(cgcontext, NO);
	CGContextSetInterpolationQuality(cgcontext, kCGInterpolationNone);

    CGContextTranslateCTM(cgcontext, (scaledRotatedRect.size.width / 2), (scaledRotatedRect.size.height / 2));
	CGContextRotateCTM(cgcontext, angle);
	CGContextDrawImage(cgcontext, CGRectMake(-widthInPoints / 2.0f, -heightInPoints / 2.0f, widthInPoints, heightInPoints), iref);
    
    // Retrieve the UIImage from the current context
    UIImage *glImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    // Clean up
    free(data);
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);
        
    [openGLImage release];
    [openGLView release];
    openGLImage = [glImage retain];
    openGLView = [view retain];

    return [self screenshot];
}

- (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    if (![privateViews containsObject:view]) {
        objc_setAssociatedObject(view, kDLDescriptionKey, description, OBJC_ASSOCIATION_RETAIN);
        [privateViews addObject:view];
        DLDebugLog(@"Registered private view: %@", [view class]);
    }
}

- (void)unregisterPrivateView:(UIView *)view
{
    if ([privateViews containsObject:view]) {
        objc_setAssociatedObject(view, kDLDescriptionKey, nil, OBJC_ASSOCIATION_RETAIN);
        [privateViews removeObject:view];
        DLDebugLog(@"Unregistered private view: %@", [view class]);
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

- (void)hidePrivateViewsForWindow:(UIWindow *)window inContext:(CGContextRef)context
{
    // Black out private views
    for (UIView *view in privateViews) {
        NSString *description = objc_getAssociatedObject(view, kDLDescriptionKey);

        if ([view window] == window) {
            CGRect frameInWindow = [view convertRect:view.bounds toView:window];
            CGContextSetGrayFillColor(context, 0.1, 1.0);
            CGContextFillRect(context, frameInWindow);
            UIView *windowRootView = ([window.subviews count] > 0 ? [window.subviews objectAtIndex:0] : nil);
            
            if ((NSNull *)description != [NSNull null]) {
                [self drawLabelCenteredAt:CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow))
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

- (BOOL)locationIsInPrivateView:(CGPoint)location privateViewFrame:(CGRect *)frame
{
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    
    for (UIView *view in privateViews) {
        CGRect frameInWindow = [view convertRect:view.bounds toView:keyWindow];
            
        if (CGRectContainsPoint(frameInWindow, location)) {
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
