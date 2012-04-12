//
//  DLScreenshotController.m
//  Delight
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLScreenshotController.h"
#import <QuartzCore/QuartzCore.h>

@interface DLScreenshotController ()
- (UIWindow *)keyboardWindow;
- (CGContextRef)createBitmapContextOfSize:(CGSize)size;
- (void)drawLabelCenteredAt:(CGPoint)point inWindow:(UIWindow *)window inContext:(CGContextRef)context 
                       text:(NSString *)text textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor 
                   fontSize:(CGFloat)fontSize transform:(CGAffineTransform)transform;
- (void)hidePrivateViewsForWindow:(UIWindow *)window inContext:(CGContextRef)context;
- (BOOL)locationIsInPrivateView:(CGPoint)location;
- (void)hideKeyboardWindow:(UIWindow *)window inContext:(CGContextRef)context;
- (void)drawPendingTouchMarksInContext:(CGContextRef)context;
- (void)writeImageToPNG:(UIImage *)image;
@end

@implementation DLScreenshotController

@synthesize scaleFactor;
@synthesize hidesKeyboard;
@synthesize writesToPNG;
@synthesize previousScreenshot;

- (id)init
{
    self = [super init];
    if (self) {
        bitmapData = NULL;
        pendingTouches = [[NSMutableArray alloc] init];
        privateViews = [[NSMutableSet alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillShowNotification:) name:UIKeyboardWillShowNotification object:nil];    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillHideNotification:) name:UIKeyboardWillHideNotification object:nil];    
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
    
    [pendingTouches release];
    [privateViews release];
    [openGLImage release];
    [openGLView release];
    [keyboardWindow release];
    [previousScreenshot release];
    
    [super dealloc];
}

#pragma mark - Public methods

- (UIImage *)screenshot
{
    CGSize windowSize = [[UIScreen mainScreen] bounds].size;
    CGSize imageSize = CGSizeMake(windowSize.width * scaleFactor, windowSize.height * scaleFactor);
    CGContextRef context = [self createBitmapContextOfSize:imageSize];
    
    // Flip the y-axis since Core Graphics starts with 0 at the bottom
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -imageSize.height);
    
    // Iterate over every window from back to front
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen]) {
            CGContextSaveGState(context);
            
            // Center the context around the window's anchor point
            CGContextTranslateCTM(context, [window center].x, [window center].y);
            
            // Apply the window's transform about the anchor point
            CGContextTranslateCTM(context, (imageSize.width - windowSize.width) / 2, (imageSize.height - windowSize.height) / 2);
            CGContextConcatCTM(context, [window transform]);   
            CGContextScaleCTM(context, scaleFactor, scaleFactor);
            
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
    
    self.previousScreenshot = image;
    
    return image;
}

- (UIImage *)openGLScreenshotForView:(UIView *)view colorRenderBuffer:(GLuint)colorRenderBuffer
{
    // Get the size of the backing CAEAGLLayer
    GLint backingWidth, backingHeight;
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderBuffer);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
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

- (UIImage *)drawPendingTouchMarksOnImage:(UIImage *)image
{
    CGContextRef context = [self createBitmapContextOfSize:image.size];
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), [image CGImage]);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -image.size.height);

    [self drawPendingTouchMarksInContext:context];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *touchMarkImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(context);
    
    return touchMarkImage;
}

- (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    [privateViews addObject:[NSDictionary dictionaryWithObjectsAndKeys:view, @"view", 
                             description, @"description", nil]];
}

- (void)unregisterPrivateView:(UIView *)view
{
    NSDictionary *dictionaryToRemove = nil;
    for (NSDictionary *dictionary in privateViews) {
        if ([dictionary objectForKey:@"view"] == view) {
            dictionaryToRemove = dictionary;
            break;
        }
    }
    
    if (dictionaryToRemove) {
        [privateViews removeObject:dictionaryToRemove];
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

- (CGContextRef)createBitmapContextOfSize:(CGSize)size 
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * size.height);
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (bitmapData != NULL) {
        free(bitmapData);
    }
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }
    
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
    
    if (context== NULL) {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    CGColorSpaceRelease( colorSpace );
    
    return context;
}

- (void)drawPendingTouchMarksInContext:(CGContextRef)context
{
    // Draw touch points
    NSMutableArray *objectsToRemove = [NSMutableArray array];
    CGContextSetRGBStrokeColor(context, 0, 0, 1, 0.7);
    CGContextSetLineWidth(context, 5.0);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGPoint lastLocations[4];
    CGPoint startLocation = CGPointZero;
    NSInteger strokeCount = 0;
    
    @synchronized(self) {
        BOOL lineBegun = NO;
        for (NSMutableDictionary *touch in pendingTouches) {
            CGPoint location = [[touch objectForKey:@"location"] CGPointValue];
            BOOL locationIsInPrivateView = [self locationIsInPrivateView:location];
            location.x *= scaleFactor;
            location.y *= scaleFactor;
            NSInteger decayCount = [[touch objectForKey:@"decayCount"] integerValue];
            UITouchPhase phase = [[touch objectForKey:@"phase"] intValue];
            
            // Increase the decay count
            [touch setObject:[NSNumber numberWithInteger:decayCount+1] forKey:@"decayCount"];
            [objectsToRemove addObject:touch];
            
            if (!locationIsInPrivateView) {
                switch (phase) {
                    case UITouchPhaseBegan:
                        startLocation = location;
                        CGContextMoveToPoint(context, location.x, location.y);
                        lineBegun = YES;
                        break;
                    case UITouchPhaseEnded:
                    case UITouchPhaseCancelled:
                        CGContextStrokePath(context);
                        double distance = sqrt((location.y - startLocation.y)*(location.y - startLocation.y) + (location.x - startLocation.x)*(location.x-startLocation.x));
                        
                        if (distance > 10 && strokeCount > 0) {
                            CGPoint lastLocation = (strokeCount < 4 ? lastLocations[4 - strokeCount] : lastLocations[0]);
                            double angle = atan2(location.y - lastLocation.y, location.x - lastLocation.x);
                            
                            CGContextSetRGBFillColor(context, 0, 0, 1, 1.0); 
                            CGContextMoveToPoint(context, location.x, location.y);
                            CGContextAddLineToPoint(context, location.x + 50*cos(angle + M_PI + M_PI/8), location.y + 50*sin(angle + M_PI + M_PI/8));
                            CGContextAddLineToPoint(context, location.x + 50*cos(angle + M_PI - M_PI/8), location.y + 50*sin(angle + M_PI - M_PI/8));
                            CGContextAddLineToPoint(context, location.x, location.y);
                            CGContextFillPath(context);
                        } else {
                            CGContextSetRGBFillColor(context, 0, 0, 1, 0.7);                                 
                            CGContextFillEllipseInRect(context, CGRectMake(location.x - 8, location.y - 8, 16, 16));    
                        }
                        break;
                    case UITouchPhaseMoved:
                    case UITouchPhaseStationary:
                        if (lineBegun) {
                            CGContextAddLineToPoint(context, location.x, location.y);
                        } else {
                            CGContextMoveToPoint(context, location.x, location.y);
                        }
                        if (CGPointEqualToPoint(startLocation, CGPointZero)) {
                            startLocation = location;
                        }
                        for (NSInteger i = 0; i <= 2; i++) {
                            lastLocations[i] = lastLocations[i+1];
                        }
                        lastLocations[3] = location;
                        strokeCount++;
                        break;
                }
            }
        }
        [pendingTouches removeObjectsInArray:objectsToRemove];
    }         
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
    for (NSDictionary *dictionary in privateViews) {
        UIView *view = [dictionary objectForKey:@"view"];
        NSString *description = [dictionary objectForKey:@"description"];
        
        if ([view window] == window) {
            CGRect frameInWindow = [view convertRect:view.frame toView:window];
            CGContextSetGrayFillColor(context, 0.1, 1.0);
            CGContextFillRect(context, frameInWindow);
            UIView *windowRootView = ([window.subviews count] > 0 ? [window.subviews objectAtIndex:0] : nil);
            
            [self drawLabelCenteredAt:CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow))
                             inWindow:window
                            inContext:context 
                                 text:description 
                            textColor:[UIColor whiteColor] 
                      backgroundColor:[UIColor colorWithWhite:0.1 alpha:1.0]
                             fontSize:24.0
                            transform:(windowRootView ? windowRootView.transform : CGAffineTransformIdentity)];
        }
    }
}

- (BOOL)locationIsInPrivateView:(CGPoint)location
{
    for (NSDictionary *dictionary in privateViews) {
        UIView *view = [dictionary objectForKey:@"view"];
        CGRect frameInWindow = [view convertRect:view.frame toView:view.window];
            
        if (CGRectContainsPoint(frameInWindow, location)) {
            return YES;
        }
    }
    
    return NO;
}

- (void)hideKeyboardWindow:(UIWindow *)window inContext:(CGContextRef)context
{
    CGContextSaveGState(context);
    
    // Flip the y-axis since Core Graphics starts with 0 at the bottom
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -window.frame.size.height * scaleFactor);
    
    CGRect scaledKeyboardFrame = CGRectMake(keyboardFrame.origin.x * scaleFactor,
                                            keyboardFrame.origin.y * scaleFactor,
                                            keyboardFrame.size.width * scaleFactor,
                                            keyboardFrame.size.height * scaleFactor);
    
    CGContextSetGrayFillColor(context, 0.7, 1.0);
    CGContextFillRect(context, scaledKeyboardFrame);
    
    [self drawLabelCenteredAt:CGPointMake(CGRectGetMidX(scaledKeyboardFrame), CGRectGetMidY(scaledKeyboardFrame))
                     inWindow:window
                    inContext:context 
                         text:@"Keyboard is hidden"
                    textColor:[UIColor blackColor]
              backgroundColor:[UIColor colorWithWhite:0.7 alpha:1.0]
                     fontSize:24.0*scaleFactor
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

- (void)handleKeyboardWillShowNotification:(NSNotification *)notification
{
    keyboardWindow = [[self keyboardWindow] retain];
    keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification
{
    [keyboardWindow release];
    keyboardWindow = nil;
}

#pragma mark - DLWindowDelegate

- (void)window:(UIWindow *)window sendEvent:(UIEvent *)event
{
    @synchronized(self) {
        for (UITouch *touch in [event allTouches]) {
            if (touch.timestamp > 0) {
                CGPoint location = [touch locationInView:touch.window];
                
                // UITouch objects seem to get reused. We can't copy or clone them, so create a poor man's touch object using a dictionary.
                NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithCGPoint:location], @"location",
                                                   [NSNumber numberWithInteger:0], @"decayCount", 
                                                   [NSNumber numberWithInt:touch.phase], @"phase",
                                                   nil];
                [pendingTouches addObject:dictionary];
            }
        }
    }
}

@end
