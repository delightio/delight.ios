//
//  DLScreenCapture.m
//  ipad
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLScreenCapture.h"
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import </usr/include/objc/objc-class.h>

#define kDefaultScaleFactor 1.0f
#define kDefaultMaxFrameRate 100.0f
#define kStartingFrameRate 5.0f

static DLScreenCapture *sharedInstance = nil;

static void Swizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

@interface DLScreenCapture ()
- (void)screenshotTimerFired;
- (void)takeScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;
@end

@implementation DLScreenCapture

@synthesize scaleFactor;
@synthesize frameRate;
@synthesize maximumFrameRate;
@synthesize paused;
@synthesize autoCaptureEnabled;
@synthesize screenshotController;
@synthesize videoController;

#pragma mark - Class methods

+ (DLScreenCapture *)sharedInstance
{
    if (!sharedInstance) {
        sharedInstance = [[DLScreenCapture alloc] init];
    }
    return sharedInstance;
}

+ (void)start
{
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

+ (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    [[self sharedInstance].screenshotController registerPrivateView:view description:description];
}

+ (void)unregisterPrivateView:(UIView *)view
{
    [[self sharedInstance].screenshotController unregisterPrivateView:view];
}

+ (BOOL)hidesKeyboard
{
    return [self sharedInstance].screenshotController.hidesKeyboard;
}

+ (void)setHidesKeyboard:(BOOL)hidesKeyboard
{
    [self sharedInstance].screenshotController.hidesKeyboard = hidesKeyboard;
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

+ (BOOL)autoCaptureEnabled
{
    return [self sharedInstance].autoCaptureEnabled;
}

+ (void)setAutoCaptureEnabled:(BOOL)autoCaptureEnabled
{
    [self sharedInstance].autoCaptureEnabled = autoCaptureEnabled;
}

#pragma mark -

- (id)init 
{
    self = [super init];
    if (self) {        
        screenshotController = [[DLScreenshotController alloc] init];
        videoController = [[DLVideoController alloc] init];
        videoController.outputPath = [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
        
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
    [videoController release];
    
    [super dealloc];
}

- (void)startRecording
{
    if (!videoController.recording) {
        [videoController startNewRecording];
        
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
    [videoController stopRecording];
}

- (void)pause
{
    if (!paused) {
        paused = YES;
        pauseStartedAt = [[NSDate date] timeIntervalSince1970];
    }
}

- (void)resume
{
    if (paused) {
        paused = NO;
        NSTimeInterval thisPauseTime = [[NSDate date] timeIntervalSince1970] - pauseStartedAt;
        [videoController addPauseTime:thisPauseTime];
        
        NSLog(@"Resume recording, was paused for %.1f seconds", thisPauseTime);
    }
}

- (void)setScaleFactor:(CGFloat)aScaleFactor
{
    if (videoController.recording) {
        [NSException raise:@"Screen capture exception" format:@"Cannot change scale factor while recording is in progress."];
    }
    
    scaleFactor = aScaleFactor;
    screenshotController.scaleFactor = scaleFactor;
    videoController.videoSize = CGSizeMake([[UIScreen mainScreen] bounds].size.width * scaleFactor, [[UIScreen mainScreen] bounds].size.height * scaleFactor);
}

- (void)setAutoCaptureEnabled:(BOOL)isAutoCaptureEnabled
{
    autoCaptureEnabled = isAutoCaptureEnabled;
    
    if (autoCaptureEnabled && videoController.recording) {
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
        // NSLog(@"%i frames, current %.3f, average %.3f", frameCount, (end - start), elapsedTime / frameCount);        
        
        if (previousScreenshot) {
            UIImage *touchedUpScreenshot = [screenshotController drawPendingTouchMarksOnImage:previousScreenshot];
            [videoController writeFrameImage:touchedUpScreenshot];
            [previousScreenshot release];
        }
        
        [pool drain];
    } 
    
    processing = NO;
}

- (void)takeScreenshot
{    
    [self takeScreenshot:nil colorRenderBuffer:0];
}

- (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer
{
    [self takeScreenshot:glView colorRenderBuffer:colorRenderBuffer];
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