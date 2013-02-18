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

@interface DLScreenshotController ()
- (UIWindow *)keyboardWindow;
- (CGContextRef)newBitmapContextOfSize:(CGSize)size;
- (void)drawLabelCenteredAt:(CGPoint)point inWindow:(UIWindow *)window inContext:(CGContextRef)context 
                       text:(NSString *)text textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor 
                   fontSize:(CGFloat)fontSize transform:(CGAffineTransform)transform;
- (void)blackOutPrivateFrame:(CGRect)frame inPixelBuffer:(CVPixelBufferRef)pixelBuffer transform:(CGAffineTransform)transform;
- (void)hideKeyboardWindow:(UIWindow *)window inContext:(CGContextRef)context;
- (void)writeImageToPNG:(UIImage *)image;
@end

@implementation DLScreenshotController

@synthesize scaleFactor;
@synthesize hidesKeyboard;
@synthesize writesToPNG;
@synthesize imageSize;
@synthesize privateViews;
@synthesize lockedPrivateViewFrames;

- (id)init
{
    self = [super init];
    if (self) {
        bitmapData = NULL;
        privateViews = [[NSMutableSet alloc] init];
        lockedPrivateViewFrames = [[NSMutableSet alloc] init];
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
    [lockedPrivateViewFrames release];
    
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
    
    // https://github.com/delightio/delight.ios/issues/12
    // Chris suggested us to retain the windows before we go into the loop.
    NSArray * retainedWindows = [NSArray arrayWithArray:
                                 [[UIApplication sharedApplication] windows]];

    // Iterate over every window from back to front
    for (UIWindow *window in retainedWindows) {
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
                        
            CGContextRestoreGState(context);
            
            if (hidesKeyboard && window == keyboardWindow) {
                [self hideKeyboardWindow:keyboardWindow inContext:context];
            }
        }
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

- (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    if (![privateViews containsObject:view]) {
        objc_setAssociatedObject(view, "DLDescription", description, OBJC_ASSOCIATION_RETAIN);
        [privateViews addObject:view];
        DLLog(@"[Delight] Registered private view: %@", [view class]);
    }
}

- (void)unregisterPrivateView:(UIView *)view
{
    if ([privateViews containsObject:view]) {
        NSString *className = [[view class] description];
        objc_setAssociatedObject(view, "DLDescription", nil, OBJC_ASSOCIATION_RETAIN);
        [privateViews removeObject:view];
        DLLog(@"[Delight] Unregistered private view: %@", className);
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

- (void)lockPrivateViewFrames
{
    // Keep track of the positions of the private views at the current time
    [lockedPrivateViewFrames removeAllObjects];
    
    for (UIView *privateView in privateViews) {
        if (privateView.window && !privateView.hidden) {
            CGRect frameInWindow = [privateView convertRect:privateView.bounds toView:privateView.window];
            NSDictionary *viewDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithCGRect:frameInWindow], @"frame", nil];
            [lockedPrivateViewFrames addObject:viewDict];
        }
    }
    
    if (keyboardWindow && hidesKeyboard) {
        // Hide the keyboard, but also include the area just above the keyboard where the scaled keys show up on iPhone
        CGRect extendedKeyboardFrame;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            extendedKeyboardFrame = CGRectMake(keyboardFrame.origin.x - 65, keyboardFrame.origin.y - 55, keyboardFrame.size.width + 65, keyboardFrame.size.height + 110);
        } else {
            extendedKeyboardFrame = keyboardFrame;
        }
        NSDictionary *viewDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithCGRect:extendedKeyboardFrame], @"frame", nil];
        [lockedPrivateViewFrames addObject:viewDict];
    }
}

- (void)blackOutPrivateViewsInPixelBuffer:(CVPixelBufferRef)pixelBuffer transform:(CGAffineTransform)transform
{
    // Black out private views directly in the pixel buffer
    for (NSDictionary *frameDict in lockedPrivateViewFrames) {
        CGRect frame = [[frameDict objectForKey:@"frame"] CGRectValue];
        [self blackOutPrivateFrame:frame inPixelBuffer:pixelBuffer transform:transform];
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

- (void)blackOutPrivateFrame:(CGRect)frame inPixelBuffer:(CVPixelBufferRef)pixelBuffer transform:(CGAffineTransform)transform
{
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGRect frameInBuffer = CGRectApplyAffineTransform(frame, transform);
    frameInBuffer.origin.x *= scale;
    frameInBuffer.origin.y *= scale;
    frameInBuffer.size.width *= scale;
    frameInBuffer.size.height *= scale;
            
    void *buffer = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerPixel = CVPixelBufferGetBytesPerRow(pixelBuffer) / width;
    
    for (int row = MAX(0, CGRectGetMinY(frameInBuffer)); row < CGRectGetMaxY(frameInBuffer) && row < height; row++) {
        unsigned long startColumn = CGRectGetMinX(frameInBuffer);
        unsigned long length = CGRectGetWidth(frameInBuffer) * bytesPerPixel;
        
        memset(buffer + ((row * width + startColumn) * bytesPerPixel), 0, length);
    }
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
