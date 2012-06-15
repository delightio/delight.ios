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
#import "DLImageVideoEncoder.h"
#import "DLOpenGLVideoEncoder.h"
#import "DLGestureTracker.h"
#import "DLMetrics.h"
#import "UIWindow+DLInterceptEvents.h"
#import "UITextField+DLPrivateView.h"
#import "DLCamCaptureManager.h"
#import </usr/include/objc/objc-class.h>

#define kDLDefaultScaleFactor 0.5f
#define kDLDefaultMaximumFrameRate 15.0f
#define kDLDefaultMaximumRecordingDuration 60.0f*10
#define kDLMaximumSessionInactiveTime 60.0f*5

#define kDLAlertViewTagStartUsabilityTest 1
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

typedef enum {
    DLAnnotationNone,
    DLAnnotationFrontVideoAndAudio,
    DLAnnotationAudioOnly
} DLAnnotation;

@interface Delight () <DLRecordingSessionDelegate, DLGestureTrackerDelegate, DLVideoEncoderDelegate, DLCamCaptureManagerDelegate, UIAlertViewDelegate>
// Methods not yet ready for the public
+ (void)startWithAppToken:(NSString *)appToken annotation:(DLAnnotation)annotation;
+ (void)startOpenGLWithAppToken:(NSString *)appToken annotation:(DLAnnotation)annotation;

+ (Delight *)sharedInstance;
- (void)setAppToken:(NSString *)anAppToken;
- (void)setAnnotation:(DLAnnotation)annotation;
- (void)setOpenGL:(BOOL)openGL;
- (void)startRecording;
- (void)stopRecording;
- (void)takeScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight;
- (void)scheduleScreenshot;
- (void)tryCreateNewSession; // check with Delight server to see if we need to start a new recording session
@end

@implementation Delight {
    NSUInteger frameCount;
    NSTimeInterval elapsedTime;
    NSTimeInterval lastScreenshotTime;
    NSTimeInterval resignActiveTime;
    BOOL appInBackground;
    NSOperationQueue *screenshotQueue;

    // Helper classes
	DLTaskController *taskController;
	DLRecordingContext *recordingContext;
    DLScreenshotController *screenshotController;
    DLVideoEncoder *videoEncoder;
    DLGestureTracker *gestureTracker;
	DLCamCaptureManager *cameraManager;
    DLMetrics *metrics;
    
    // Configuration
    NSString *appToken;
    DLAnnotation annotation;
    BOOL openGL;
    BOOL autoCaptureEnabled;
	BOOL delaySessionUploadForCamera;
	BOOL cameraDidStop;
    CGFloat scaleFactor;
    double maximumFrameRate;
    NSTimeInterval maximumRecordingDuration;
    NSMutableDictionary *userProperties;
}

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
    [self startWithAppToken:appToken annotation:DLAnnotationNone];
}

+ (void)startWithAppToken:(NSString *)appToken annotation:(DLAnnotation)annotation
{
    Delight *delight = [self sharedInstance];
	if ( annotation == DLAnnotationFrontVideoAndAudio ) {
		delight->taskController.sessionObjectName = @"usability_app_session";
	} else {
		delight->taskController.sessionObjectName = @"app_session";
	}
	
    [delight setAnnotation:annotation];
    [delight setAppToken:appToken];
    [delight setOpenGL:NO];
	[delight tryCreateNewSession];   
}

+ (void)startOpenGLWithAppToken:(NSString *)appToken
{
    [self startOpenGLWithAppToken:appToken annotation:DLAnnotationNone];
}

+ (void)startOpenGLWithAppToken:(NSString *)appToken annotation:(DLAnnotation)annotation
{
    Delight *delight = [self sharedInstance];
    [delight setAutoCaptureEnabled:NO];
	if ( annotation == DLAnnotationFrontVideoAndAudio ) {
		delight->taskController.sessionObjectName = @"opengl_usability_app_session";
	} else {
		delight->taskController.sessionObjectName = @"opengl_app_session";
	}
    [delight setAnnotation:annotation];
    [delight setAppToken:appToken];
    [delight setOpenGL:YES];
	[delight tryCreateNewSession];
}

+ (void)stop
{
    [[self sharedInstance] stopRecording];
    [self sharedInstance]->metrics.stopReason = DLMetricsStopReasonManual;
}

+ (void)takeOpenGLScreenshot:(UIView *)glView colorRenderbuffer:(GLuint)colorRenderbuffer
{
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    [self takeOpenGLScreenshot:glView];
}

+ (void)takeOpenGLScreenshot:(UIView *)glView
{
    GLint backingWidth, backingHeight;
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    [[self sharedInstance] takeScreenshot:glView backingWidth:backingWidth backingHeight:backingHeight];
}

+ (BOOL)savesToPhotoAlbum
{
    return [self sharedInstance]->videoEncoder.savesToPhotoAlbum;
}

+ (void)setSavesToPhotoAlbum:(BOOL)savesToPhotoAlbum
{
    [self sharedInstance]->videoEncoder.savesToPhotoAlbum = savesToPhotoAlbum;
}

+ (BOOL)debugLogEnabled
{
    return [[self sharedInstance] debugLogEnabled];
}

+ (void)setDebugLogEnabled:(BOOL)debugLogEnabled
{
    [[self sharedInstance] setDebugLogEnabled:debugLogEnabled];
}

+ (BOOL)hidesKeyboardInRecording
{
    return [self sharedInstance]->screenshotController.hidesKeyboard;
}

+ (void)setHidesKeyboardInRecording:(BOOL)hidesKeyboardInRecording
{
    [self sharedInstance]->screenshotController.hidesKeyboard = hidesKeyboardInRecording;
    if (hidesKeyboardInRecording) {
        [self sharedInstance]->metrics.keyboardHiddenCount++;
    }
}

+ (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    [[self sharedInstance]->screenshotController registerPrivateView:view description:description];
    
    [self sharedInstance]->metrics.privateViewCount++;
}

+ (void)unregisterPrivateView:(UIView *)view
{
    [[self sharedInstance]->screenshotController unregisterPrivateView:view];
}

+ (NSSet *)privateViews
{
    return [self sharedInstance]->screenshotController.privateViews;
}

+ (void)setPropertyValue:(id)value forKey:(NSString *)key
{
    if (![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNumber class]]) {
        DLLog(@"[Delight] Ignoring property for key %@ - value must be an NSString or an NSNumber.", key);
    } else {
        [[self sharedInstance]->userProperties setObject:value forKey:key];
    }
}

#pragma mark -

- (id)init
{
    self = [super init];
    if (self) {        
        screenshotController = [[DLScreenshotController alloc] init];        
                
        gestureTracker = [[DLGestureTracker alloc] init];
        gestureTracker.drawsGestures = NO;
        gestureTracker.delegate = self;
        
        screenshotQueue = [[NSOperationQueue alloc] init];
        screenshotQueue.maxConcurrentOperationCount = 1;

        userProperties = [[NSMutableDictionary alloc] init];
        metrics = [[DLMetrics alloc] init];
        
        [self setScaleFactor:kDLDefaultScaleFactor];
        [self setAutoCaptureEnabled:YES];
        maximumFrameRate = kDLDefaultMaximumFrameRate;
        maximumRecordingDuration = kDLDefaultMaximumRecordingDuration;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];

		// create task controller
		taskController = [[DLTaskController alloc] init];
		taskController.sessionDelegate = self;
		taskController.baseDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"com.pipely.delight"];
        
        // Method swizzling to intercept touch events
        Swizzle([UIWindow class], @selector(sendEvent:), @selector(DLsendEvent:));
        
        // Method swizzling to rewrite UIWebView layer rendering code to avoid crash
        Swizzle(NSClassFromString(@"TileHostLayer"), @selector(renderInContext:), @selector(DLrenderInContext:));
        Swizzle(NSClassFromString(@"WebLayer"), @selector(drawInContext:), @selector(DLdrawInContext:));
        
        // Method swizzling to automatically make secure UITextFields private views
        Swizzle([UITextField class], @selector(didMoveToSuperview), @selector(DLdidMoveToSuperview));
        Swizzle([UITextField class], @selector(setSecureTextEntry:), @selector(DLsetSecureTextEntry:));
        Swizzle([UITextField class], @selector(becomeFirstResponder), @selector(DLbecomeFirstResponder));
        Swizzle([UITextField class], @selector(resignFirstResponder), @selector(DLresignFirstResponder));
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
    [cameraManager release];
	[screenshotQueue release];	
	[taskController release];
    [userProperties release];
    [metrics release];
    
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
        
        if (recordingContext) {
            // Set recording properties from server
            if (recordingContext.maximumFrameRate > 0) {
                maximumFrameRate = recordingContext.maximumFrameRate;
                DLDebugLog(@"Maximum frame rate: %.2f", recordingContext.maximumFrameRate);                
            }
            if (recordingContext.scaleFactor > 0) {
                [self setScaleFactor:recordingContext.scaleFactor];
                DLDebugLog(@"Scale factor: %.3f", recordingContext.scaleFactor);
            }
            if (recordingContext.averageBitRate > 0) {
                videoEncoder.averageBitRate = recordingContext.averageBitRate;
                DLDebugLog(@"Average bit rate: %.2f", recordingContext.averageBitRate);
            }
            if (recordingContext.maximumKeyFrameInterval > 0) {
                videoEncoder.maximumKeyFrameInterval = recordingContext.maximumKeyFrameInterval;
                DLDebugLog(@"Maximum keyframe interval: %i", recordingContext.maximumKeyFrameInterval);
            }
            if (recordingContext.maximumRecordingDuration > 0) {
                maximumRecordingDuration = recordingContext.maximumRecordingDuration;
                DLDebugLog(@"Maximum recording duration: %.1f", recordingContext.maximumRecordingDuration);
            }
        }
        
        videoEncoder.outputPath = [NSString stringWithFormat:@"%@/%@.mp4", cachePath, (recordingContext ? recordingContext.sessionID : @"output")];
        [videoEncoder startNewRecording];
        
        if (annotation != DLAnnotationNone) {    
            if (!cameraManager) {
                cameraManager = [[DLCamCaptureManager alloc] init];
                cameraManager.audioOnly = (annotation == DLAnnotationAudioOnly);
                cameraManager.savesToPhotoAlbum = videoEncoder.savesToPhotoAlbum;
                cameraManager.delegate = self;
            }

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
        [videoEncoder stopRecording];

		recordingContext.touches = gestureTracker.touches;
        recordingContext.touchBounds = gestureTracker.touchView.bounds;
        recordingContext.orientationChanges = gestureTracker.orientationChanges;
    }
}

- (void)setAppToken:(NSString *)anAppToken
{
    if (appToken != anAppToken) {
        [appToken release];
        appToken = [anAppToken retain];
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

- (void)setAnnotation:(DLAnnotation)anAnnotation
{
    annotation = anAnnotation;
}

- (void)setOpenGL:(BOOL)anOpenGL
{
    openGL = anOpenGL;

    [videoEncoder release];
    if (openGL) {
        videoEncoder = [[DLOpenGLVideoEncoder alloc] init];
    } else {
        videoEncoder = [[DLImageVideoEncoder alloc] init];
    }
    videoEncoder.delegate = self;
}

- (void)takeScreenshot:(UIView *)glView backingWidth:(GLint)backingWidth backingHeight:(GLint)backingHeight
{    
    if (!videoEncoder.recording) return;
    
    // Need to set up an autorelease pool since this method gets called from a background thread
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Frame rate limiting
    float targetFrameInterval = 1.0f / maximumFrameRate;
    NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];
    if (now - lastScreenshotTime < targetFrameInterval) {
        if (glView) {
            // We'll try again on a subsequent render loop iteration
            [pool drain];
            return;
        } else {
            [NSThread sleepForTimeInterval:targetFrameInterval - (now - lastScreenshotTime)];
        }
    }
    
    NSTimeInterval start = [[NSProcessInfo processInfo] systemUptime];
    lastScreenshotTime = start;
        
    if (openGL) {
        gestureTracker.touchView = glView;
        DLOpenGLVideoEncoder *openGLEncoder = (DLOpenGLVideoEncoder *)videoEncoder;
        [openGLEncoder encodeGLPixelsWithBackingWidth:backingWidth backingHeight:backingHeight];
    } else {
        UIImage *screenshot = [screenshotController screenshot];
        DLImageVideoEncoder *imageEncoder = (DLImageVideoEncoder *)videoEncoder;
        [imageEncoder encodeImage:screenshot];
    }
        
    if (recordingContext.startTime && [[NSDate date] timeIntervalSinceDate:recordingContext.startTime] >= maximumRecordingDuration) {
        // We've exceeded the maximum recording duration
        [self stopRecording];
        metrics.stopReason = DLMetricsStopReasonTimeLimit;
    } else if (autoCaptureEnabled) {
        [self scheduleScreenshot];
    }
    
#ifdef DEBUG
    NSTimeInterval end = [[NSProcessInfo processInfo] systemUptime];
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
    if (!videoEncoder.recording) {
        [taskController requestSessionIDWithAppToken:appToken];
    }
#endif
    
    [metrics reset];
}

- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx {
    [recordingContext release];
	recordingContext = [ctx retain];
    
	if (recordingContext.shouldRecordVideo) {
        if (annotation == DLAnnotationNone) {
            // Start recording immediately
            [self startRecording];
        } else {
            // Show warning that user will be recorded
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                                message:@"Start usability test? Your face and voice may be recorded.\n\n\n"
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
        }
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
	recordingContext.userProperties = userProperties;
    recordingContext.metrics = metrics;
	if ( !delaySessionUploadForCamera || (delaySessionUploadForCamera && cameraDidStop) ) {
		delaySessionUploadForCamera = NO;
		[taskController prepareSessionUpload:recordingContext];
	}
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
			recordingContext.userProperties = userProperties;
            recordingContext.metrics = metrics;
			if ( !delaySessionUploadForCamera || (delaySessionUploadForCamera && cameraDidStop) ) {
				delaySessionUploadForCamera = NO;
				[taskController prepareSessionUpload:recordingContext];
			}
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
	[taskController saveUnfinishedRecordingContext:recordingContext];
}

#pragma mark - DLCamCaptureManagerDelegate

- (void)captureManagerRecordingBegan:(DLCamCaptureManager *)captureManager
{
	delaySessionUploadForCamera = YES;
	cameraDidStop = NO;
    if (captureManager.audioOnly) {
        DLDebugLog(@"Began microphone recording");
    } else {
        DLDebugLog(@"Began camera recording");
    }
}

- (void)captureManagerRecordingFinished:(DLCamCaptureManager *)captureManager
{
	cameraDidStop = YES;
	if ( !delaySessionUploadForCamera ) {
		[taskController performSelectorOnMainThread:@selector(prepareSessionUpload:) withObject:recordingContext waitUntilDone:NO];
	}
    DLDebugLog(@"Completed camera recording, file is stored at: %@", captureManager.outputPath);
}

- (void)captureManager:(DLCamCaptureManager *)captureManager didFailWithError:(NSError *)error
{
    DLDebugLog(@"Camera recording failed: %@", error);
}

#pragma mark - DLGestureTrackerDelegate

- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location inView:(UIView *)view privateViewFrame:(CGRect *)frame
{
    return [screenshotController locationIsInPrivateView:location inView:view privateViewFrame:frame];
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
    switch (alertView.tag) {
        case kDLAlertViewTagStartUsabilityTest:
            if (buttonIndex == 1 && recordingContext.shouldRecordVideo) {
                UITextField *descriptionField = (UITextField *)[alertView viewWithTag:kDLAlertViewDescriptionFieldTag];
                recordingContext.usabilityTestDescription = descriptionField.text;
                if ([descriptionField.text length]) {
                    [userProperties setObject:descriptionField.text forKey:@"description"];
                }
                [self startRecording];
            }
            break;
        default:
            break;
    }
}

#pragma mark - DLVideoEncoderDelegate

- (void)videoEncoder:(DLVideoEncoder *)videoEncoder didBeginRecordingAtTime:(NSTimeInterval)startTime
{
    [gestureTracker startRecordingGesturesWithStartUptime:startTime];
}

- (void)videoEncoderDidFinishRecording:(DLVideoEncoder *)videoEncoder
{
    [gestureTracker stopRecordingGestures];
}

@end
