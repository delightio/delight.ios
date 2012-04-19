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
#import "UIWindow+DLInterceptEvents.h"
#import "DLTaskController.h"

#define kDLDefaultScaleFactor 1.0f
#define kDLDefaultMaximumFrameRate 30.0f
#define kDLDefaultMaximumRecordingDuration 60.0f*10
#define kDLStartingFrameRate 5.0f
#define kDLMaximumSessionInactiveTime 60.0f*5

static Delight *sharedInstance = nil;

@interface Delight ()
- (void)startRecording;
- (void)stopRecording;
- (void)pause;
- (void)resume;
- (void)takeScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight;
- (void)takeScreenshot;
- (void)screenshotTimerFired;
- (void)tryCreateNewSession; // check with Delight server to see if we need to start a new recording session
@end

@implementation Delight

@synthesize appToken;
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

+ (void)startWithAppToken:(NSString *)appToken
{
    Delight *delight = [self sharedInstance];
    delight.appToken = appToken;
	[delight tryCreateNewSession];
}

+ (void)startOpenGLWithAppToken:(NSString *)appToken encodeRawBytes:(BOOL)encodeRawBytes
{
    Delight *delight = [self sharedInstance];
    delight.appToken = appToken;
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
    [[self sharedInstance] takeScreenshot:nil backingWidth:0 backingHeight:0];
}

+ (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer
{
    GLint backingWidth, backingHeight;
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderBuffer);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);

    [[self sharedInstance] takeScreenshot:glView backingWidth:backingWidth backingHeight:backingHeight];
}

+ (void)takeOpenGLScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{
    [[self sharedInstance] takeScreenshot:glView backingWidth:backingWidth backingHeight:backingHeight];
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

+ (NSSet *)privateViews
{
    return [self sharedInstance].screenshotController.privateViews;
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
        
        self.scaleFactor = kDLDefaultScaleFactor;
        self.maximumFrameRate = kDLDefaultMaximumFrameRate;
        self.maximumRecordingDuration = kDLDefaultMaximumRecordingDuration;
        self.autoCaptureEnabled = YES;
        frameRate = kDLStartingFrameRate;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
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
    
    [appToken release];
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
    if (videoEncoder.recording) {
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

- (void)takeScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{
    if (paused || processing || (glView && [[NSDate date] timeIntervalSince1970] - lastScreenshotTime < 1.0f / maximumFrameRate)) return;
        
    processing = YES;
    
    @synchronized(self) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSTimeInterval start = [[NSDate date] timeIntervalSince1970];

        if (videoEncoder.encodesRawGLBytes && glView) {
            [videoEncoder encodeRawBytesForGLView:glView backingWidth:backingWidth backingHeight:backingHeight];
        } else {
            UIImage *previousScreenshot = [screenshotController.previousScreenshot retain];
            if (glView) {
                [screenshotController openGLScreenshotForView:glView backingWidth:backingWidth backingHeight:backingHeight];
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
        
#ifdef DEBUG
        if (frameCount % (int)(3 * ceil(frameRate)) == 0) {
            DLDebugLog(@"[Frame #%i] Current %.0f ms, average %.0f ms, %.0f fps", frameCount, (end - start) * 1000, (elapsedTime / frameCount) * 1000, frameRate);
        }
#endif
        
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
    [self takeScreenshot:nil backingWidth:0 backingHeight:0];
}

- (void)screenshotTimerFired
{
    if (!paused && videoEncoder.recording) {
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
    }
    
    if (autoCaptureEnabled) {
        [self performSelector:@selector(screenshotTimerFired) withObject:nil afterDelay:1.0f/frameRate];
    }
}

#pragma mark - Session

- (void)tryCreateNewSession {
#ifdef DL_OFFLINE_RECORDING
    videoEncoder.outputPath = [NSString stringWithFormat:@"%@/output.mp4", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    [self startRecording];
#else
	[taskController requestSessionIDWithAppToken:self.appToken];
#endif
}

- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx {
    [recordingContext release];
	recordingContext = [ctx retain];
	if ( recordingContext.shouldRecordVideo ) {
		// start recording
		videoEncoder.outputPath = [NSString stringWithFormat:@"%@/%@.mp4", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], ctx.sessionID];
		
		[self startRecording];
	} else {
		// there's no need to record the session. Clean up video encoder?
		recordingContext.startTime = [NSDate date];
	}
}

#pragma mark - Notifications

- (void)handleDidEnterBackground:(NSNotification *)notification
{
#ifdef DL_OFFLINE_RECORDING
    [self stopRecording];
#else
	if ( recordingContext.shouldRecordVideo ) {
		[self stopRecording];
	} else {
		recordingContext.endTime = [NSDate date];
	}
	[taskController uploadSession:recordingContext];
#endif
    
    appInBackground = YES;
}

- (void)handleWillEnterForeground:(NSNotification *)notification
{
    [self tryCreateNewSession];
}

- (void)handleDidBecomeActive:(NSNotification *)notification
{
    // In iOS 4, locking the screen does not trigger didEnterBackground: notification. Check if we've been inactive for a long time.
    if (resignActiveTime > 0 && !appInBackground && [[[UIDevice currentDevice] systemVersion] floatValue] < 5.0) {
        NSTimeInterval inactiveTime = [[NSDate date] timeIntervalSince1970] - resignActiveTime;
        if (inactiveTime > kDLMaximumSessionInactiveTime) {
            // We've been inactive for a long time, stop the previous recording and create a new session
            if (recordingContext.shouldRecordVideo) {
                [self stopRecording];
            } else {
				recordingContext.endTime = [NSDate date];
			}
            [taskController uploadSession:recordingContext];
            [self tryCreateNewSession];
        }
    }
    
    appInBackground = NO;
}

- (void)handleWillResignActive:(NSNotification *)notification
{
    resignActiveTime = [[NSDate date] timeIntervalSince1970];
}

#pragma mark - DLGestureTrackerDelegate

- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location
{
    return [screenshotController locationIsInPrivateView:location];
}

@end