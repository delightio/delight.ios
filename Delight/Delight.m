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
#import "UIWindow+InterceptEvents.h"
#import "DLTaskController.h"

#define kDefaultScaleFactor 1.0f
#define kDefaultMaxFrameRate 100.0f
#define kDefaultMaximumRecordingDuration 60.0f*10
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
@synthesize maximumRecordingDuration;
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

+ (void)startOpenGLWithAppID:(NSString *)appID encodeRawBytes:(BOOL)encodeRawBytes
{
    Delight *delight = [self sharedInstance];
    delight.appID = appID;
    delight.autoCaptureEnabled = NO;
    delight.videoEncoder.encodesRawGLBytes = encodeRawBytes;
	[delight tryCreateNewSession];
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
        gestureTracker = [[DLGestureTracker alloc] init];
        gestureTracker.delegate = self;
        
        self.scaleFactor = kDefaultScaleFactor;
        self.maximumFrameRate = kDefaultMaxFrameRate;
        self.maximumRecordingDuration = kDefaultMaximumRecordingDuration;
        self.autoCaptureEnabled = YES;
        frameRate = kStartingFrameRate;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		
		// create task controller
		taskController = [[DLTaskController alloc] init];
		taskController.sessionDelegate = self;
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
        recordingContext.startTime = [NSDate date];
        recordingContext.filePath = videoEncoder.outputPath;
        
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
    if (recordingContext && videoEncoder.recording) {
        [videoEncoder stopRecording];
        recordingContext.endTime = [NSDate date];
    }
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

        if (videoEncoder.encodesRawGLBytes && glView) {
            [videoEncoder encodeRawBytesForGLView:glView colorRenderBuffer:colorRenderBuffer];
        } else {
            UIImage *previousScreenshot = [screenshotController.previousScreenshot retain];
            if (glView) {
                [screenshotController openGLScreenshotForView:glView colorRenderBuffer:colorRenderBuffer];
            } else {
                [screenshotController screenshot];
            }

            if (previousScreenshot) {
                UIImage *touchedUpScreenshot = [gestureTracker drawPendingTouchMarksOnImage:previousScreenshot];
                [videoEncoder writeFrameImage:touchedUpScreenshot];
                [previousScreenshot release];
            }
        }
        
        NSTimeInterval end = [[NSDate date] timeIntervalSince1970];
        
        frameCount++;
        elapsedTime += (end - start);
        lastScreenshotTime = end;
        // NSLog(@"%i frames, current %.3f, average %.3f", frameCount, (end - start), elapsedTime / frameCount);        
        
        [pool drain];
    } 
    
    processing = NO;
    
    if (recordingContext.startTime && [[NSDate date] timeIntervalSinceDate:recordingContext.startTime] >= maximumRecordingDuration) {
        // We've exceeded the maximum recording duration
        [self stopRecording];
    }
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

#pragma mark - Session

- (void)tryCreateNewSession {
	[taskController requestSessionID];
}

- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx {
	recordingContext = [ctx retain];
	if ( recordingContext.shouldRecordVideo ) {
		// start recording
		videoEncoder.outputPath = [NSString stringWithFormat:@"%@/%@.mp4", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], ctx.sessionID];
		
		[self startRecording];
	} else {
		// there's no need to record the session. Clean up delight?
	}
}

#pragma mark - Notifications

- (void)handleDidBecomeActive:(NSNotification *)notification
{
//    [self startRecording];
}

- (void)handleWillResignActive:(NSNotification *)notification
{
    [self stopRecording]; // update properties in recordingContext as well.
}

#pragma mark - DLGestureTrackerDelegate

- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location
{
    return [screenshotController locationIsInPrivateView:location];
}

@end