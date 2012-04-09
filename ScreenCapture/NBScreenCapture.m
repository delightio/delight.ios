//
//  NBScreenCapture.m
//  ipad
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "NBScreenCapture.h"
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import </usr/include/objc/objc-class.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#define kDefaultScaleFactor 1.0f
#define kDefaultMaxFrameRate 100.0f
#define kStartingFrameRate 5.0f
#define kBitRate 500.0*1024.0

//#define DEBUG_PNG

static NBScreenCapture *sharedInstance = nil;

static void Swizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

@interface NBScreenCapture(Private)
- (BOOL)startRecordingWithScaleFactor:(CGFloat)scaleFactor maximumFrameRate:(NSUInteger)maximumFrameRate;
- (void)pause;
- (void)resume;
- (void)stopRecording;
- (void)openGLScreenCapture:(UIView *)eaglview colorRenderBuffer:(GLuint)colorRenderBuffer;
- (void)drawTouchMarksInContext:(CGContextRef)context;
- (void)hidePrivateViewsForWindow:(UIWindow *)window inContext:(CGContextRef)context;
- (void)hideKeyboardWindow:(UIWindow *)window inContext:(CGContextRef)context;
- (void)writeVideoFrameAtTime:(CMTime)time;
- (UIWindow *)keyboardWindow;
@end

@implementation NBScreenCapture

@synthesize currentScreen;
@synthesize frameRate;
@synthesize privateViews;
@synthesize hidesKeyboard;
@synthesize openGLImage;
@synthesize openGLFrame;
@synthesize captureDelegate;

#pragma mark - Class methods

+ (NBScreenCapture *)sharedInstance
{
    if (!sharedInstance) {
        sharedInstance = [[NBScreenCapture alloc] init];
    }
    return sharedInstance;
}

+ (void)start
{
    [[self sharedInstance] startRecordingWithScaleFactor:kDefaultScaleFactor maximumFrameRate:kDefaultMaxFrameRate];    
}

+ (void)startWithScaleFactor:(CGFloat)scaleFactor maximumFrameRate:(NSUInteger)maximumFrameRate
{
    [[self sharedInstance] startRecordingWithScaleFactor:scaleFactor maximumFrameRate:maximumFrameRate];
}

+ (void)stop
{
    [sharedInstance stopRecording];
    [sharedInstance release]; sharedInstance = nil;
}

+ (void)pause
{
    [sharedInstance pause];
}

+ (void)resume
{
    [sharedInstance resume];
}

+ (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    [[self sharedInstance].privateViews addObject:[NSDictionary dictionaryWithObjectsAndKeys:view, @"view", 
                                            description, @"description", nil]];
}

+ (void)unregisterPrivateView:(UIView *)view
{
    NSDictionary *dictionaryToRemove = nil;
    for (NSDictionary *dictionary in sharedInstance.privateViews) {
        if ([dictionary objectForKey:@"view"] == view) {
            dictionaryToRemove = dictionary;
            break;
        }
    }
    
    if (dictionaryToRemove) {
        [sharedInstance.privateViews removeObject:dictionaryToRemove];
    }
}

+ (void)setHidesKeyboard:(BOOL)hidesKeyboard
{
    [[self sharedInstance] setHidesKeyboard:hidesKeyboard];
}

+ (void)openGLScreenCapture:(UIView *)eaglview colorRenderBuffer:(GLuint)colorRenderBuffer
{
    [[self sharedInstance] openGLScreenCapture:eaglview colorRenderBuffer:colorRenderBuffer];
}

#pragma mark -

- (void)initialize 
{
    self.currentScreen = nil;
    self.frameRate = kStartingFrameRate;     // frames per seconds
    _recording = false;
    videoWriter = nil;
    videoWriterInput = nil;
    avAdaptor = nil;
    startedAt = nil;
    bitmapData = NULL;
    pendingTouches = [[NSMutableArray alloc] init];
    privateViews = [[NSMutableSet alloc] init];
    
    // ISA swizzling
//    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
//        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen]) {
//            object_setClass(window, [NBScreenCapturingWindow class]);
//            [(NBScreenCapturingWindow *)window setDelegate:self];
//        }
//    }

    // Method swizzling
    Swizzle([UIWindow class], @selector(sendEvent:), @selector(NBsendEvent:));
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        [window NBsetDelegate:self];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWillResignActive:) 
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDidBecomeActive:) 
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleKeyboardFrameChanged:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];    
    
    // iOS 5+ only
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 5.0) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardFrameChanged:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
    }
}

- (id)init 
{
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)cleanupWriter 
{
    [avAdaptor release];
    avAdaptor = nil;
    
    [videoWriterInput release];
    videoWriterInput = nil;
    
    [videoWriter release];
    videoWriter = nil;
    
    [startedAt release];
    startedAt = nil;
    
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cleanupWriter];
    
    [pendingTouches release];
    [privateViews release];
    [openGLImage release];
    
    [super dealloc];
}

#pragma mark -

- (NSString *)outputPath 
{
    return [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
}

- (CGContextRef)createBitmapContextOfSize:(CGSize) size 
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

- (UIImage *)screenshot 
{
    CGSize windowSize = [[UIScreen mainScreen] bounds].size;
    CGSize imageSize = CGSizeMake(windowSize.width * scaleFactor, windowSize.height * scaleFactor);
    CGContextRef context = [self createBitmapContextOfSize:imageSize];

    // Iterate over every window from back to front
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen]) {
            CGContextSaveGState(context);

            // Flip the y-axis since Core Graphics starts with 0 at the bottom
            CGContextScaleCTM(context, 1.0, -1.0);
            CGContextTranslateCTM(context, 0, -imageSize.height);

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
            
            if (!hidesKeyboard || window != [self keyboardWindow]) {
                // Draw the view hierarchy onto our context
                [[window layer] renderInContext:context];
            } else {
//                [self hideKeyboardWindow:[self keyboardWindow] inContext:context];
            }

            // Draw any OpenGL views
            if (openGLImage) {
                CGContextDrawImage(context, openGLFrame, [openGLImage CGImage]);
            }
            
            [self drawTouchMarksInContext:context];
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
        
    return image;
}

- (void)openGLScreenCapture:(UIView *)eaglview colorRenderBuffer:(GLuint)colorRenderBuffer
{
    @synchronized(self) {
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
            
        // OpenGL ES measures data in PIXELS
        // Create a graphics context with the target size measured in POINTS
        NSInteger widthInPoints; 
        NSInteger heightInPoints;
        if (NULL != UIGraphicsBeginImageContextWithOptions) {
            // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
            // Set the scale parameter to your OpenGL ES view's contentScaleFactor
            // so that you get a high-resolution snapshot when its value is greater than 1.0
            CGFloat scale       = eaglview.contentScaleFactor;
            widthInPoints       = width / scale;
            heightInPoints      = height / scale;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthInPoints, heightInPoints), NO, scale);
        } else {
            // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
            widthInPoints       = width;
            heightInPoints      = height;
            UIGraphicsBeginImageContext(CGSizeMake(widthInPoints, heightInPoints));
        }
        
        CGContextRef cgcontext  = UIGraphicsGetCurrentContext();

        // UIKit coordinate system is upside down to GL/Quartz coordinate system
        // Flip the CGImage by rendering it to the flipped bitmap context
        // The size of the destination area is measured in POINTS
        CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
        CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, widthInPoints, heightInPoints), iref);
        // Retrieve the UIImage from the current context
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        self.openGLFrame = [eaglview convertRect:eaglview.frame toView:eaglview.window];
        self.openGLImage = image;
        
        UIGraphicsEndImageContext();
        
        // Clean up
        free(data);
        CFRelease(ref);
        CFRelease(colorspace);
        CGImageRelease(iref);
    }
}

- (void)drawTouchMarksInContext:(CGContextRef)context
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
            NSInteger decayCount = [[touch objectForKey:@"decayCount"] integerValue];
            UITouchPhase phase = [[touch objectForKey:@"phase"] intValue];
            
            // Increase the decay count
            [touch setObject:[NSNumber numberWithInteger:decayCount+1] forKey:@"decayCount"];
            if (decayCount >= frameRate) {
                [objectsToRemove addObject:touch];
            }
            
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
                        CGContextFillEllipseInRect(context, CGRectMake(location.x - 15, location.y - 15, 15, 15));    
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

- (void)takeScreenshot
{
    if (!processing) {
        [self performSelectorInBackground:@selector(takeScreenshotInCurrentThread) withObject:nil];
        if (frameRate < maximumFrameRate) {
            frameRate++;
        }
    } else {
        // Frame rate too high to keep up
        if (frameRate > 1.0) {
            frameRate--;
        }
    }
    
    if (frameCount % 30 == 0) {
        NSLog(@"Frame rate: %.0f fps", frameRate);
    }
    
    [self performSelector:@selector(takeScreenshot) withObject:nil afterDelay:1.0/frameRate];
}

- (void)takeScreenshotInCurrentThread
{
    if (!_recording) return;
    
    processing = YES;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if (!_paused) {
        @synchronized(self) {
            NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
            self.currentScreen = [self screenshot];
            NSTimeInterval end = [[NSDate date] timeIntervalSince1970];
            frameCount++;
            elapsedTime += (end - start);
//            NSLog(@"%i frames, current %.3f, average %.3f", frameCount, (end - start), elapsedTime / frameCount);
        }
        
        self.openGLImage = nil;
        
#ifdef DEBUG_PNG
        if (frameCount < 600) {
            NSString* filename = [NSString stringWithFormat:@"Documents/frame_%d.png", frameCount];
            NSString* pngPath = [NSHomeDirectory() stringByAppendingPathComponent:filename];
            [UIImagePNGRepresentation(self.currentScreen) writeToFile: pngPath atomically: YES];
        }
#endif
        
        if (_recording) {
            float millisElapsed = ([[NSDate date] timeIntervalSinceDate:startedAt] - pauseTime) * 1000.0;
            @synchronized(self) {
                [self writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000)];
            } 
        }
    }
    
    [pool drain];
    
    processing = NO;
}
                                        
- (NSURL *)tempFileURL 
{
    NSString *outputPath = [self outputPath];
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            NSLog(@"Could not delete old recording file at path:  %@", outputPath);
        }
    }
    
    return [outputURL autorelease];
}

- (BOOL)setUpWriter 
{
    NSError* error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[self tempFileURL] fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    
    //Configure video
    NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:kBitRate], AVVideoAverageBitRateKey,
                                           nil ];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:[[UIScreen mainScreen] bounds].size.width * scaleFactor], AVVideoWidthKey,
                                   [NSNumber numberWithInt:[[UIScreen mainScreen] bounds].size.height * scaleFactor], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    videoWriterInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings] retain];
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];                                      
    
    avAdaptor = [[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes] retain];
    
    //add input
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    return YES;
}

- (void)completeRecordingSession 
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    [videoWriterInput markAsFinished];
    
    // Wait for the video
    int status = videoWriter.status;
    while (status == AVAssetWriterStatusUnknown) {
        NSLog(@"Waiting...");
        [NSThread sleepForTimeInterval:0.5f];
        status = videoWriter.status;
    }
    
    @synchronized(self) {
        BOOL success = [videoWriter finishWriting];
        if (!success) {
            NSLog(@"finishWriting returned NO: %@", [[videoWriter error] localizedDescription]);
        }
        
        [self cleanupWriter];
        
        id delegateObj = self.captureDelegate;
        NSString *outputPath = [self outputPath];
        NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
        
        NSLog(@"Completed recording, file is stored at:  %@", outputURL);
        if ([delegateObj respondsToSelector:@selector(recordingFinished:)]) {
            [delegateObj performSelectorOnMainThread:@selector(recordingFinished:) withObject:(success ? outputURL : nil) waitUntilDone:YES];
        }
        
        [outputURL release];
    }
    
    [pool drain];
}

- (BOOL)startRecordingWithScaleFactor:(CGFloat)aScaleFactor maximumFrameRate:(NSUInteger)aMaximumFrameRate
{
    bool result = NO;
    scaleFactor = aScaleFactor;
    maximumFrameRate = aMaximumFrameRate;
    @synchronized(self) {
        if (! _recording) {
            result = [self setUpWriter];
            startedAt = [[NSDate date] retain];
            _recording = true;
            
            [self performSelector:@selector(takeScreenshot) withObject:nil afterDelay:1.0/frameRate];
//            screenshotTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f/frameRate target:self selector:@selector(takeScreenshot) userInfo:nil repeats:YES];
        }
    }
    
    return result;
}

- (void)stopRecording 
{
    @synchronized(self) {
        if (_recording) {
            _recording = false;
            [screenshotTimer invalidate]; screenshotTimer = nil;            
            [self completeRecordingSession];
        }
    }
}

- (void)pause
{
    if (!_paused) {
        _paused = YES;
        pauseStartedAt = [[NSDate date] timeIntervalSince1970];
    }
}

- (void)resume
{
    if (_paused) {
        _paused = NO;
        NSTimeInterval thisPauseTime = [[NSDate date] timeIntervalSince1970] - pauseStartedAt;
        pauseTime += thisPauseTime;
        
        NSLog(@"Resume recording, was paused for %.1f seconds", thisPauseTime);
    }
}

- (void)writeVideoFrameAtTime:(CMTime)time {
    if (![videoWriterInput isReadyForMoreMediaData] || !currentScreen) {
        NSLog(@"Not ready for video data");
    } else {
        @synchronized (self) {
            UIImage* newFrame = [self.currentScreen retain];
            CVPixelBufferRef pixelBuffer = NULL;
            CGImageRef cgImage = CGImageCreateCopy([newFrame CGImage]);
            CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
            
            int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, avAdaptor.pixelBufferPool, &pixelBuffer);
            if(status != 0){
                //could not get a buffer from the pool
                NSLog(@"Error creating pixel buffer:  status=%d, pixelBufferPool=%p", status, avAdaptor.pixelBufferPool);
            } else {
                // set image data into pixel buffer
                CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
                uint8_t* destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
                CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);  //XXX:  will work if the pixel buffer is contiguous and has the same bytesPerRow as the input data
                
                if(status == 0){
                    BOOL success = [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                    if (!success)
                        NSLog(@"Warning:  Unable to write buffer to video: %@", videoWriter.error);
                }
                
                CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
                CVPixelBufferRelease( pixelBuffer );
            }
            
            //clean up
            [newFrame release];
            CFRelease(image);
            CGImageRelease(cgImage);
        }
    }
}

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

#pragma mark - Notifications

- (void)handleWillResignActive:(NSNotification *)notification
{
    [self stopRecording];
    UISaveVideoAtPathToSavedPhotosAlbum([self outputPath], nil, nil, nil);
}

- (void)handleDidBecomeActive:(NSNotification *)notification
{
    [self startRecordingWithScaleFactor:scaleFactor maximumFrameRate:maximumFrameRate];
}

- (void)handleKeyboardFrameChanged:(NSNotification *)notification
{
    keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
}

#pragma mark - NBScreenCapturingWindowDelegate

- (void)screenCapturingWindow:(UIWindow *)window sendEvent:(UIEvent *)event
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