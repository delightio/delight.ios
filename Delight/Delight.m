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
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "DLTaskController.h"
#import "DLScreenshotController.h"
#import "DLVideoEncoder.h"
#import "DLGestureTracker.h"
#import "UIWindow+DLInterceptEvents.h"
#import "DLCamCaptureManager.h"
#import </usr/include/objc/objc-class.h>

#define kDLDefaultScaleFactor_iPad2x   0.25f
#define kDLDefaultScaleFactor_iPad     0.5f
#define kDLDefaultScaleFactor_iPhone2x 0.5f
#define kDLDefaultScaleFactor_iPhone   0.5f

#define kDLDefaultMaximumFrameRate 30.0f
#define kDLDefaultMaximumRecordingDuration 60.0f*10
#define kDLMaximumSessionInactiveTime 60.0f*5

#define kDLAlertViewTagStartUsabilityTest 1
#define kDLAlertViewTagStopUsabilityTest 2
#define kDLAlertViewDescriptionFieldTag 101

static Delight *sharedInstance = nil;
BOOL __DL_ENABLE_DEBUG_LOG = NO;

static void Swizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

@interface Delight () <DLGestureTrackerDelegate, DLCamCaptureManagerDelegate, UIAlertViewDelegate>
// OpenGL ES beta methods
+ (void)startOpenGLWithAppToken:(NSString *)appToken encodeRawBytes:(BOOL)encodeRawBytes;
+ (void)startOpenGLUsabilityTestWithAppToken:(NSString *)appToken encodeRawBytes:(BOOL)encodeRawBytes;
+ (void)takeOpenGLScreenshot:(UIView *)glView colorRenderBuffer:(GLuint)colorRenderBuffer;
+ (void)takeOpenGLScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight;

+ (Delight *)sharedInstance;
- (void)startRecording;
- (void)stopRecording;
- (void)pause;
- (void)resume;
- (void)takeScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight;
- (void)scheduleScreenshot;
- (void)tryCreateNewSession; // check with Delight server to see if we need to start a new recording session
@end

@implementation Delight

@synthesize appToken;
@synthesize appUserID;
@synthesize debugLogEnabled;
@synthesize scaleFactor;
@synthesize maximumFrameRate;
@synthesize maximumRecordingDuration;
@synthesize usabilityTestEnabled;
@synthesize paused;
@synthesize autoCaptureEnabled;
@synthesize recordsCamera;
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

+ (void)startUsabilityTestWithAppToken:(NSString *)appToken
{
    Delight *delight = [self sharedInstance];
    delight.usabilityTestEnabled = YES;
    delight.recordsCamera = YES;
    [self startWithAppToken:appToken];
}

+ (void)startOpenGLWithAppToken:(NSString *)appToken encodeRawBytes:(BOOL)encodeRawBytes
{
    Delight *delight = [self sharedInstance];
    delight.appToken = appToken;
    delight.autoCaptureEnabled = NO;
    delight.videoEncoder.encodesRawGLBytes = encodeRawBytes;
	[delight tryCreateNewSession];
}

+ (void)startOpenGLUsabilityTestWithAppToken:(NSString *)appToken encodeRawBytes:(BOOL)encodeRawBytes
{
    Delight *delight = [self sharedInstance];
    delight.usabilityTestEnabled = YES;
    delight.recordsCamera = YES;
    [self startOpenGLWithAppToken:appToken encodeRawBytes:encodeRawBytes];
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

+ (BOOL)savesToPhotoAlbum
{
    return [self sharedInstance].videoEncoder.savesToPhotoAlbum;
}

+ (void)setSavesToPhotoAlbum:(BOOL)savesToPhotoAlbum
{
    [self sharedInstance].videoEncoder.savesToPhotoAlbum = savesToPhotoAlbum;
}

+ (NSString *)appUserID
{
    return [self sharedInstance].appUserID;
}

+ (void)setAppUserID:(NSString *)appUserID
{
    [self sharedInstance].appUserID = appUserID;
}

+ (BOOL)debugLogEnabled
{
    return [self sharedInstance].debugLogEnabled;
}

+ (void)setDebugLogEnabled:(BOOL)debugLogEnabled
{
    [self sharedInstance].debugLogEnabled = debugLogEnabled;
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
        
        screenshotQueue = [[NSOperationQueue alloc] init];
        screenshotQueue.maxConcurrentOperationCount = 1;

        lock = [[NSLock alloc] init];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            if ([UIScreen mainScreen].scale == 1.0) {
                self.scaleFactor = kDLDefaultScaleFactor_iPad;
            } else {
                self.scaleFactor = kDLDefaultScaleFactor_iPad2x;                
            }
        } else {
            if ([UIScreen mainScreen].scale == 1.0) {
                self.scaleFactor = kDLDefaultScaleFactor_iPhone;
            } else {
                self.scaleFactor = kDLDefaultScaleFactor_iPhone2x;                
            }
        }
        
        self.maximumFrameRate = kDLDefaultMaximumFrameRate;
        self.maximumRecordingDuration = kDLDefaultMaximumRecordingDuration;
        self.autoCaptureEnabled = YES;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];

		// create task controller
		taskController = [[DLTaskController alloc] init];
		taskController.sessionDelegate = self;
		taskController.baseDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"com.pipely.delight"];
        
        // Method swizzling to intercept touch/shake events
        Swizzle([UIWindow class], @selector(sendEvent:), @selector(DLsendEvent:));
        Swizzle([UIWindow class], @selector(motionEnded:withEvent:), @selector(DLmotionEnded:withEvent:));
        Swizzle([UIApplication class], @selector(motionEnded:withEvent:), @selector(DLmotionEnded:withEvent:));
        
        // Method swizzling to rewrite UIWebView layer rendering code to avoid crash
        Swizzle(NSClassFromString(@"TileHostLayer"), @selector(renderInContext:), @selector(DLrenderInContext:));
    }
    return self;
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [appToken release];
    [appUserID release];
    [screenshotController release];
    [videoEncoder release];
    [gestureTracker release];
    [cameraManager release];
	[screenshotQueue release];	
	[taskController release];
    [lock release];
    
    [super dealloc];
}

- (BOOL)debugLogEnabled {
	return __DL_ENABLE_DEBUG_LOG;
}

- (void)setDebugLogEnabled:(BOOL)aflag {
	__DL_ENABLE_DEBUG_LOG = aflag;
}

- (void)startRecording
{    
    if (!videoEncoder.recording) {
        // Identify and create the cache directory if it doesn't already exist
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"com.pipely.delight"];
        cachePath = [cachePath stringByAppendingPathComponent:@"Videos"];
        BOOL isDir = NO;
        NSError *error;
        if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && !isDir) {
            [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:&error];
        }
        
        videoEncoder.outputPath = [NSString stringWithFormat:@"%@/%@.mp4", cachePath, (recordingContext ? recordingContext.sessionID : @"output")];
        [videoEncoder startNewRecording];
        
        if (recordsCamera) {
            cameraManager.outputPath = [NSString stringWithFormat:@"%@/%@_camera.mp4", cachePath, (recordingContext ? recordingContext.sessionID : @"output")];
            [cameraManager startRecording];
            recordingContext.cameraFilePath = cameraManager.outputPath;
        }
        
        recordingContext.startTime = [NSDate date];
        recordingContext.screenFilePath = videoEncoder.outputPath;
        
        if (autoCaptureEnabled) {
            [self scheduleScreenshot];
        }
    }
}

- (void)stopRecording 
{
    if (cameraManager.recording) {
        [cameraManager stopRecording];
    }
    
    if (videoEncoder.recording) {
        [lock lock];
        [videoEncoder stopRecording];
        [lock unlock];
    }
}

- (void)pause
{
    if (!paused) {
        paused = YES;
        [videoEncoder pause];
        [screenshotQueue setSuspended:YES];
    }
}

- (void)resume
{
    if (paused) {
        paused = NO;
        [videoEncoder resume];
        [screenshotQueue setSuspended:NO];
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
    if (autoCaptureEnabled != isAutoCaptureEnabled) {
        autoCaptureEnabled = isAutoCaptureEnabled;
        
        if (autoCaptureEnabled && videoEncoder.recording && screenshotQueue.operationCount == 0) {
            [self scheduleScreenshot];
        }
    }
}

- (void)setRecordsCamera:(BOOL)aRecordsCamera
{
    if (recordsCamera != aRecordsCamera) {
        recordsCamera = aRecordsCamera;
        
        if (recordsCamera) {
            cameraManager = [[DLCamCaptureManager alloc] init];
            cameraManager.delegate = self;
            if ([videoEncoder isRecording]) {
                [cameraManager startRecording];
            }
        } else {
            if ([cameraManager isRecording]) {
                [cameraManager stopRecording];
            }
            [cameraManager release];
            cameraManager = nil;
        }
    }
}

- (void)takeScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{    
    if (!videoEncoder.recording) return;
    
    // Need to set up an autorelease pool since this method gets called from a background thread
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Frame rate limiting
    float targetFrameInterval = 1.0f / maximumFrameRate;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - lastScreenshotTime < targetFrameInterval) {
        if (glView) {
            // We'll try again on a subsequent render loop iteration
            [pool drain];
            return;
        } else {
            [NSThread sleepForTimeInterval:targetFrameInterval - (now - lastScreenshotTime)];
        }
    }
    
    NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
    lastScreenshotTime = start;
        
    if (videoEncoder.encodesRawGLBytes && glView) {
        // Encode GL bytes directly
        [videoEncoder encodeRawBytesForGLView:glView backingWidth:backingWidth backingHeight:backingHeight];
    } else {
        UIImage *previousScreenshot = [screenshotController.previousScreenshot retain];

        // Take new screenshot
        if (glView) {
            [screenshotController openGLScreenshotForView:glView backingWidth:backingWidth backingHeight:backingHeight];
        } else {
            [screenshotController screenshot];
        }

        // Draw gestures onto the previous screenshot and send to encoder
        if (previousScreenshot) {
            UIImage *touchedUpScreenshot = [gestureTracker drawPendingTouchMarksOnImage:previousScreenshot];
            [lock lock];
            if (videoEncoder.recording) {
                [videoEncoder writeFrameImage:touchedUpScreenshot];
            }
            [lock unlock];
            [previousScreenshot release];
        }
    }
        
    if (recordingContext.startTime && [[NSDate date] timeIntervalSinceDate:recordingContext.startTime] >= maximumRecordingDuration) {
        // We've exceeded the maximum recording duration
        [self stopRecording];
    } else if (autoCaptureEnabled) {
        [self scheduleScreenshot];
    }
    
#ifdef DEBUG
    NSTimeInterval end = [[NSDate date] timeIntervalSince1970];
    elapsedTime += (end - start);
    if (++frameCount % 20 == 0) {
        DLDebugLog(@"[Frame #%i] Current %.0f ms, average %.0f ms, %.0f fps", frameCount, (end - start) * 1000, (elapsedTime / frameCount) * 1000, 1.0f / (end - now));
    }
#endif
    
    [pool drain];
}

- (void)scheduleScreenshot
{
    [screenshotQueue addOperationWithBlock:^{
        [self takeScreenshot:nil backingWidth:0 backingHeight:0];                                        
    }];
}

#pragma mark - Session

- (void)tryCreateNewSession {
#ifdef DL_OFFLINE_RECORDING
    [self startRecording];
#else
	[taskController requestSessionIDWithAppToken:self.appToken];
#endif
}

- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx {
    [recordingContext release];
	recordingContext = [ctx retain];
	if (recordingContext.shouldRecordVideo && !usabilityTestEnabled) {
		// start recording
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
	}
    recordingContext.endTime = [NSDate date];
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
            }
            recordingContext.endTime = [NSDate dateWithTimeIntervalSince1970:resignActiveTime];
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

- (void)handleWillTerminate:(NSNotification *)notification
{
	[taskController saveRecordingContext];
}

#pragma mark - DLCamCaptureManagerDelegate

- (void)captureManagerRecordingBegan:(DLCamCaptureManager *)captureManager
{
    DLDebugLog(@"Began camera recording");
}

- (void)captureManagerRecordingFinished:(DLCamCaptureManager *)captureManager
{
    DLDebugLog(@"Completed camera recording, file is stored at: %@", captureManager.outputPath);
}

- (void)captureManager:(DLCamCaptureManager *)captureManager didFailWithError:(NSError *)error
{
    DLDebugLog(@"Camera recording failed: %@", error);
}

#pragma mark - DLGestureTrackerDelegate

- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location privateViewFrame:(CGRect *)frame
{
    return [screenshotController locationIsInPrivateView:location privateViewFrame:frame];
}

- (void)gestureTrackerDidShake:(DLGestureTracker *)gestureTracker
{
    if (usabilityTestEnabled && recordingContext.shouldRecordVideo && !alertViewVisible) {
        if (![videoEncoder isRecording]) {
            // Start usability test mode
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"delight.io"
                                                                message:@"Start usability test?\n\n\n"
                                                               delegate:self
                                                      cancelButtonTitle:@"Cancel"
                                                      otherButtonTitles:@"Start", nil];
            
            UITextField *descriptionField = [[UITextField alloc] init];
            descriptionField.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
            descriptionField.backgroundColor = [UIColor whiteColor];
            descriptionField.placeholder = @"Description (Optional)";
            descriptionField.tag = kDLAlertViewDescriptionFieldTag;
            [alertView addSubview:descriptionField];
            [descriptionField release];

            alertView.tag = kDLAlertViewTagStartUsabilityTest;        
            [alertView show];
            [alertView release];
            alertViewVisible = YES;
        } else {
            // Stop usability test mode
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"delight.io"
                                                                message:@"Stop usability test?"
                                                               delegate:self
                                                      cancelButtonTitle:@"Cancel"
                                                      otherButtonTitles:@"Stop", nil];
            alertView.tag = kDLAlertViewTagStopUsabilityTest;
            [alertView show];
            [alertView release];   
            alertViewVisible = YES;
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)willPresentAlertView:(UIAlertView *)alertView
{
    if (alertView.tag == kDLAlertViewTagStartUsabilityTest) {
        // Need to know the alert view size to position the text field properly
        UITextField *descriptionField = (UITextField *)[alertView viewWithTag:kDLAlertViewDescriptionFieldTag];
        descriptionField.frame = CGRectMake(20.0, alertView.frame.size.height - 97, 245.0, 25.0);
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    alertViewVisible = NO;
    
    switch (alertView.tag) {
        case kDLAlertViewTagStartUsabilityTest:
            if (buttonIndex == 1 && recordingContext.shouldRecordVideo) {
                UITextField *descriptionField = (UITextField *)[alertView viewWithTag:kDLAlertViewDescriptionFieldTag];
                recordingContext.usabilityTestDescription = descriptionField.text;
                [self startRecording];
            }
            break;
        case kDLAlertViewTagStopUsabilityTest:
            if (buttonIndex == 1) {
                [self stopRecording];
            }
            break;
        default:
            break;
    }
}

@end
