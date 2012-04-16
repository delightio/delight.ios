//
//  Delight.m
//  Delight
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "Delight.h"
#import "DLTaskController.h"
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIWindow+InterceptEvents.h"

#define kDefaultScaleFactor 1.0f
#define kDefaultMaxFrameRate 100.0f
#define kStartingFrameRate 5.0f

static Delight *sharedInstance = nil;

@interface Delight ()
- (void)startRecording;
- (void)stopRecording;
- (void)pause;
- (void)resume;
- (void)takeScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;
- (void)takeScreenshot;
- (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;
- (void)screenshotTimerFired;
- (void)tryCreateNewSession; // check with Delight server to see if we need to start a new recording session
@end

@implementation Delight

@synthesize appID;
@synthesize scaleFactor;
@synthesize frameRate;
@synthesize maximumFrameRate;
@synthesize paused;
@synthesize autoCaptureEnabled;
@synthesize screenshotController;
@synthesize videoEncoder;
@synthesize gestureTracker;

#pragma mark - Class methods

+ (Delight *)sharedInstance
{
    if (!sharedInstance) {
        sharedInstance = [[Delight alloc] init];
    }
    return sharedInstance;
}

+ (void)startWithAppID:(NSString *)appID
{
    Delight *delight = [self sharedInstance];
    delight.appID = appID;
	[delight tryCreateNewSession];
//    [delight startRecording];
}

+ (void)startOpenGLWithAppID:(NSString *)appID
{
    Delight *delight = [self sharedInstance];
    delight.appID = appID;
    delight.autoCaptureEnabled = NO;
    [delight startRecording];
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

        gestureTracker = [[DLGestureTracker alloc] init];
        gestureTracker.delegate = self;
        
        self.scaleFactor = kDefaultScaleFactor;
        self.maximumFrameRate = kDefaultMaxFrameRate;
        self.autoCaptureEnabled = YES;
        frameRate = kStartingFrameRate;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		
		// create task controller
		taskController = [[DLTaskController alloc] init];
    }
    return self;
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [appID release];
    [screenshotController release];
    [videoEncoder release];
    [gestureTracker release];
	
	[taskController release];
    
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
    videoEncoder.videoSize = screenshotController.imageSize;
    gestureTracker.scaleFactor = scaleFactor;
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
            UIImage *touchedUpScreenshot = [gestureTracker drawPendingTouchMarksOnImage:previousScreenshot];
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

- (void)tryCreateNewSession {
	[taskController requestSessionID];
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

#pragma mark - DLGestureTrackerDelegate

- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location
{
    return [screenshotController locationIsInPrivateView:location];
}

@end