//
//  Delight.m
//  Delight
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "Delight.h"
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import </usr/include/objc/objc-class.h>

#define kDefaultScaleFactor 1.0f
#define kDefaultMaxFrameRate 100.0f
#define kStartingFrameRate 5.0f

static Delight *sharedInstance = nil;

static void Swizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

@interface Delight ()
- (void)startRecording;
- (void)stopRecording;
- (void)pause;
- (void)resume;
- (void)takeScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;
- (void)takeScreenshot;
- (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;
- (void)screenshotTimerFired;
@end

@implementation Delight

@synthesize scaleFactor;
@synthesize frameRate;
@synthesize maximumFrameRate;
@synthesize paused;
@synthesize autoCaptureEnabled;
@synthesize screenshotController;
@synthesize videoEncoder;

#pragma mark - Class methods

+ (Delight *)sharedInstance
{
    if (!sharedInstance) {
        sharedInstance = [[Delight alloc] init];
    }
    return sharedInstance;
}

+ (void)start
{
    [[self sharedInstance] startRecording];
}

+ (void)startOpenGL
{
    [self sharedInstance].autoCaptureEnabled = NO;
    [[self sharedInstance] startRecording];
}

+ (void)stop
{
    [[self sharedInstance] stopRecording];
    [sharedInstance release]; sharedInstance = nil;
}

+ (void)pause
{
    [[self sharedInstance] pause];
}

+ (void)resume
{
    [[self sharedInstance] resume];
}

+ (void)takeScreenshot
{
    [[self sharedInstance] takeScreenshot];
}

+ (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer
{
    [[self sharedInstance] takeOpenGLScreenshot:glView colorRenderBuffer:colorRenderBuffer];
}

+ (CGFloat)scaleFactor
{
    return [self sharedInstance].scaleFactor;
}

+ (void)setScaleFactor:(CGFloat)scaleFactor
{

    [self sharedInstance].scaleFactor = scaleFactor;
}

+ (NSUInteger)maximumFrameRate
{
    return [self sharedInstance].maximumFrameRate;
}

+ (void)setMaximumFrameRate:(NSUInteger)maximumFrameRate
{
    [self sharedInstance].maximumFrameRate = maximumFrameRate;
}

+ (BOOL)hidesKeyboardInRecording
{
    return [self sharedInstance].screenshotController.hidesKeyboard;
}

+ (void)setHidesKeyboardInRecording:(BOOL)hidesKeyboardInRecording
{
    [self sharedInstance].screenshotController.hidesKeyboard = hidesKeyboardInRecording;
}

+ (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    [[self sharedInstance].screenshotController registerPrivateView:view description:description];
}

+ (void)unregisterPrivateView:(UIView *)view
{
    [[self sharedInstance].screenshotController unregisterPrivateView:view];
}

#pragma mark -

- (id)init 
{
    self = [super init];
    if (self) {        
        screenshotController = [[DLScreenshotController alloc] init];
        videoEncoder = [[DLVideoEncoder alloc] init];
        videoEncoder.outputPath = [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
        
        self.scaleFactor = kDefaultScaleFactor;
        self.maximumFrameRate = kDefaultMaxFrameRate;
        self.autoCaptureEnabled = YES;
        frameRate = kStartingFrameRate;

        // Method swizzling to intercept events
        Swizzle([UIWindow class], @selector(sendEvent:), @selector(DLsendEvent:));
        for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
            [window DLsetDelegate:screenshotController];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [screenshotController release];
    [videoEncoder release];
    
    [super dealloc];
}

- (void)startRecording
{
    if (!videoEncoder.recording) {
        [videoEncoder startNewRecording];
        
        if (autoCaptureEnabled) {
            if (frameRate > maximumFrameRate) {
                frameRate = maximumFrameRate;
            }
            
            [self performSelector:@selector(screenshotTimerFired) withObject:nil afterDelay:1.0f/frameRate];
        }
    }
}

- (void)stopRecording 
{
    [videoEncoder stopRecording];
}

- (void)pause
{
    if (!paused) {
        paused = YES;
        [videoEncoder pause];
    }
}

- (void)resume
{
    if (paused) {
        paused = NO;
        [videoEncoder resume];
    }
}

- (void)setScaleFactor:(CGFloat)aScaleFactor
{
    if (videoEncoder.recording) {
        [NSException raise:@"Screen capture exception" format:@"Cannot change scale factor while recording is in progress."];
    }
    
    scaleFactor = aScaleFactor;
    screenshotController.scaleFactor = scaleFactor;
    videoEncoder.videoSize = CGSizeMake([[UIScreen mainScreen] bounds].size.width * scaleFactor, [[UIScreen mainScreen] bounds].size.height * scaleFactor);
}

- (void)setAutoCaptureEnabled:(BOOL)isAutoCaptureEnabled
{
    autoCaptureEnabled = isAutoCaptureEnabled;
    
    if (autoCaptureEnabled && videoEncoder.recording) {
        [self performSelector:@selector(screenshotTimerFired) withObject:nil afterDelay:1.0f/frameRate];
    }
}

- (void)takeScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer
{
    processing = YES;
    
    @synchronized(self) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
        UIImage *previousScreenshot = [screenshotController.previousScreenshot retain];
        if (glView) {
            [screenshotController openGLScreenshotForView:glView colorRenderBuffer:colorRenderBuffer];
        } else {
            [screenshotController screenshot];
        }
        NSTimeInterval end = [[NSDate date] timeIntervalSince1970];
        
        frameCount++;
        elapsedTime += (end - start);
        lastScreenshotTime = end;
        // NSLog(@"%i frames, current %.3f, average %.3f", frameCount, (end - start), elapsedTime / frameCount);        
        
        if (previousScreenshot) {
            UIImage *touchedUpScreenshot = [screenshotController drawPendingTouchMarksOnImage:previousScreenshot];
            [videoEncoder writeFrameImage:touchedUpScreenshot];
            [previousScreenshot release];
        }
        
        [pool drain];
    } 
    
    processing = NO;
}

- (void)takeScreenshot
{   
    if (!paused && !processing) {
        [self takeScreenshot:nil colorRenderBuffer:0];
    }
}

- (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer
{
    if (!paused && !processing && [[NSDate date] timeIntervalSince1970] - lastScreenshotTime >= 1.0f / maximumFrameRate) {
        [self takeScreenshot:glView colorRenderBuffer:colorRenderBuffer];
    }
}

- (void)screenshotTimerFired
{
    if (!paused) {
        if (!processing) {
            [self performSelectorInBackground:@selector(takeScreenshot) withObject:nil];
            if (frameRate + 1 <= maximumFrameRate) {
                frameRate++;
            }
        } else {
            // Frame rate too high to keep up
            if (frameRate - 1 > 0) {
                frameRate--;
            }
        }
        
        if (frameCount % 30 == 0) {
            NSLog(@"Frame rate: %.0f fps", frameRate);
        }
    }
    
    if (autoCaptureEnabled) {
        [self performSelector:@selector(screenshotTimerFired) withObject:nil afterDelay:1.0f/frameRate];
    }
}

#pragma mark - Notifications

- (void)handleDidBecomeActive:(NSNotification *)notification
{
    [self startRecording];
}

- (void)handleWillResignActive:(NSNotification *)notification
{
    [self stopRecording];
}

@end