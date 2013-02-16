//
//  Delight.m
//  Delight
//
//  Created by Chris Haugli on 1/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "Delight_Internal.h"
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import "DLUIKitVideoEncoder.h"
#import "DLMetrics.h"
#import "UIWindow+DLInterceptEvents.h"
#import "UITextField+DLPrivateView.h"
#import "UIViewController+DLViewInfo.h"
#import </usr/include/objc/objc-class.h>

#if PRIVATE_FRAMEWORK
#import "DLMobileFrameBufferVideoEncoder.h"
#endif

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

@implementation Delight {
    NSUInteger frameCount;
    NSTimeInterval elapsedTime;
    NSTimeInterval lastScreenshotTime;
    NSTimeInterval resignActiveTime;
    BOOL appInBackground;
    BOOL alertViewVisible;
    NSOperationQueue *screenshotQueue;
    
    // Configuration
	BOOL delaySessionUploadForCamera;
	BOOL cameraDidStop;
    double maximumFrameRate;
    NSTimeInterval maximumRecordingDuration;
}

@synthesize taskController = _taskController;
@synthesize recordingContext = _recordingContext;
@synthesize screenshotController = _screenshotController;
@synthesize videoEncoder = _videoEncoder;
@synthesize gestureTracker = _gestureTracker;
@synthesize cameraManager = _cameraManager;
@synthesize metrics = _metrics;
@synthesize analytics = _analytics;
@synthesize appToken = _appToken;
@synthesize annotation = _annotation;
@synthesize scaleFactor = _scaleFactor;
@synthesize autoCaptureEnabled = _autoCaptureEnabled;
@synthesize userProperties = _userProperties;
@synthesize screenshotThread = _screenshotThread;

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
    [self _setAppSessionType:@"app_session"];
    [self _startWithAppToken:appToken annotation:DLAnnotationNone];
}

+ (void)startWithAppToken:(NSString *)appToken annotation:(DLAnnotation)annotation
{
    [self _setAppSessionType:@"usability_app_session"];
    [self _startWithAppToken:appToken annotation:annotation];
}

+ (void)startWithPartnerAppToken:(NSString *)appToken
                     callbackURL:(NSString *)callbackURL
                  callbackPayload:(NSDictionary *)callbackPayload
{
    NSDictionary *callbackContext = [NSDictionary dictionaryWithObjectsAndKeys:
                                     callbackURL, @"callbackURL",
                                     callbackPayload, @"callbackPayload", nil];
    [self _setAppSessionType:@"partner_app_session"
             callbackContext:callbackContext];
    [self _startWithAppToken:appToken annotation:DLAnnotationNone];
}

+ (void)_startWithAppToken:(NSString *)appToken annotation:(DLAnnotation)annotation
{
	Delight *delight = [self sharedInstance];
    [delight setAnnotation:annotation];
    [delight setAppToken:appToken];
	[delight tryCreateNewSession];
}

+ (void)stopAndDiscard
{
    Delight * delight = [self sharedInstance];
    [delight stopRecording];
    [delight.recordingContext discardAllTracks];
    DLDebugLog(@"[Delight] recording is stopped and discarded");
}

+ (void)stopAndUpload
{
    Delight * delight = [self sharedInstance];
    [delight stopAndUpload];
    DLDebugLog(@"[Delight] recording is stopped and queued for uploading.");
}

+ (void)_setAppSessionType:(NSString *)sessionType
{
    Delight *delight = [self sharedInstance];
    delight.taskController.sessionObjectName = sessionType;
}

+ (void)_setAppSessionType:(NSString *)sessionType
           callbackContext:(NSDictionary *) callbackContext
{
    Delight *delight = [self sharedInstance];
    delight.taskController.callbackContext = callbackContext;
    
    [self _setAppSessionType:sessionType];
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
    return [self sharedInstance].screenshotController.hidesKeyboard;
}

+ (void)setHidesKeyboardInRecording:(BOOL)hidesKeyboardInRecording
{
    [self sharedInstance].screenshotController.hidesKeyboard = hidesKeyboardInRecording;
    if (hidesKeyboardInRecording) {
        [self sharedInstance].metrics.keyboardHiddenCount++;
    }
}

+ (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    [[self sharedInstance].screenshotController registerPrivateView:view description:description];
    
    [self sharedInstance].metrics.privateViewCount++;
}

+ (void)unregisterPrivateView:(UIView *)view
{
    [[self sharedInstance].screenshotController unregisterPrivateView:view];
}

+ (NSSet *)privateViews
{
    return [self sharedInstance].screenshotController.privateViews;
}

+ (void)setPropertyValue:(id)value forKey:(NSString *)key
{
    if (![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNumber class]]) {
        DLLog(@"[Delight] Ignoring property for key %@ - value must be an NSString or an NSNumber.", key);
    } else {
        [[self sharedInstance].userProperties setObject:value forKey:key];
    }
}

+ (void)markCurrentView:(NSString *)viewName
{
    Delight *delight = [Delight sharedInstance];
    NSTimeInterval startTime = [delight.videoEncoder currentFrameTimeInterval];
    DLViewInfo *lastViewInfo = [delight.analytics lastViewInfoForType:DLViewInfoTypeUser];
    DLViewInfo *sectionChange = [DLViewInfo viewInfoWithName:viewName type:DLViewInfoTypeUser startTime:startTime];

    [delight.analytics addViewInfo:sectionChange];
    
    // Set the end time for the last user-marked view
    if (lastViewInfo) {
        lastViewInfo.endTime = startTime;
    }
    
    DLLog(@"[Delight] Marked view: %@", viewName);
}

+ (void)trackEvent:(NSString *)eventName info:(NSDictionary *)eventInfo
{
    Delight *delight = [Delight sharedInstance];
    NSTimeInterval time = [delight.videoEncoder currentFrameTimeInterval];
    DLEvent *event = [DLEvent eventWithName:eventName properties:eventInfo at:time];
    [[Delight sharedInstance].analytics addEvent:event];
}

#pragma mark -

- (id)init
{
    self = [super init];
    if (self) {        
        self.screenshotController = [[[DLScreenshotController alloc] init] autorelease];
                
#if PRIVATE_FRAMEWORK
        self.videoEncoder = [[[DLMobileFrameBufferVideoEncoder alloc] init] autorelease];
#else
        self.videoEncoder = [[[DLUIKitVideoEncoder alloc] init] autorelease];
#endif
        self.videoEncoder.delegate = self;

        self.gestureTracker = [[[DLGestureTracker alloc] init] autorelease];
        self.gestureTracker.drawsGestures = NO;
        self.gestureTracker.delegate = self;
        
        screenshotQueue = [[NSOperationQueue alloc] init];
        screenshotQueue.maxConcurrentOperationCount = 1;
        
        self.userProperties = [NSMutableDictionary dictionary];
        self.metrics = [[[DLMetrics alloc] init] autorelease];        
        self.scaleFactor = kDLDefaultScaleFactor;
        self.autoCaptureEnabled = YES;

        maximumFrameRate = kDLDefaultMaximumFrameRate;
        maximumRecordingDuration = kDLDefaultMaximumRecordingDuration;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];

		// create task controller
		self.taskController = [[[DLTaskController alloc] init] autorelease];
		self.taskController.sessionDelegate = self;
		self.taskController.baseDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"com.pipely.delight"];
        
        // Method swizzling to intercept touch events
        Swizzle([UIWindow class], @selector(sendEvent:), @selector(DLsendEvent:));
        
        // Method swizzling to rewrite UIWebView layer rendering code to avoid crash
        Swizzle(NSClassFromString(@"TileHostLayer"), @selector(renderInContext:), @selector(DLthreadSafeRenderInContext:));
        Swizzle(NSClassFromString(@"WebLayer"), @selector(drawInContext:), @selector(DLthreadSafeDrawInContext:));
        //        Swizzle(NSClassFromString(@"WebTiledLayer"), @selector(drawInContext:), @selector(DLthreadSafeDrawInContext2:));
        
#ifndef PRIVATE_FRAMEWORK
        // Method swizzling to hide private views
        Swizzle([CALayer class], @selector(renderInContext:), @selector(DLrenderInContext:));
#endif
        
        // Method swizzling to automatically make secure UITextFields private views
        Swizzle([UITextField class], @selector(didMoveToSuperview), @selector(DLdidMoveToSuperview));
        Swizzle([UITextField class], @selector(setSecureTextEntry:), @selector(DLsetSecureTextEntry:));
        Swizzle([UITextField class], @selector(becomeFirstResponder), @selector(DLbecomeFirstResponder));
        Swizzle([UITextField class], @selector(resignFirstResponder), @selector(DLresignFirstResponder));
        
        // Method swizzling to automatically mark UIViewController changes in the view track
        Swizzle([UIViewController class], @selector(viewDidAppear:), @selector(DLviewDidAppear:));
        Swizzle([UIViewController class], @selector(viewWillDisappear:), @selector(DLviewWillDisappear:));
    }
    return self;
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_appToken release];
    [_screenshotController release];
    [_videoEncoder release];
    [_gestureTracker release];
    [_cameraManager release];
	[_taskController release];
    [_metrics release];
    [_userProperties release];
    [_analytics release];
	[screenshotQueue release];
    
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
    if (!self.videoEncoder.recording) {
        // Identify and create the cache directory if it doesn't already exist
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"com.pipely.delight"];
        cachePath = [cachePath stringByAppendingPathComponent:@"Videos"];
        BOOL isDir = NO;
        NSError *error;
        if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && !isDir) {
            [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:&error];
        }
        
        if (self.recordingContext) {
            // Set recording properties from server
            if (self.recordingContext.maximumFrameRate > 0) {
                maximumFrameRate = self.recordingContext.maximumFrameRate;
                DLDebugLog(@"Maximum frame rate: %.2f", self.recordingContext.maximumFrameRate);                
            }
            if (self.recordingContext.scaleFactor > 0) {
                [self setScaleFactor:self.recordingContext.scaleFactor];
                DLDebugLog(@"Scale factor: %.3f", self.recordingContext.scaleFactor);
            }
            if (self.recordingContext.averageBitRate > 0) {
                self.videoEncoder.averageBitRate = self.recordingContext.averageBitRate;
                DLDebugLog(@"Average bit rate: %.2f", self.recordingContext.averageBitRate);
            }
            if (self.recordingContext.maximumKeyFrameInterval > 0) {
                self.videoEncoder.maximumKeyFrameInterval = self.recordingContext.maximumKeyFrameInterval;
                DLDebugLog(@"Maximum keyframe interval: %i", self.recordingContext.maximumKeyFrameInterval);
            }
            if (self.recordingContext.maximumRecordingDuration > 0) {
                maximumRecordingDuration = self.recordingContext.maximumRecordingDuration;
                DLDebugLog(@"Maximum recording duration: %.1f", self.recordingContext.maximumRecordingDuration);
            }
        }
        
        self.videoEncoder.outputPath = [NSString stringWithFormat:@"%@/%@.mp4", cachePath, (self.recordingContext ? self.recordingContext.sessionID : @"output")];
        [self.videoEncoder startNewRecording];
        
        if (self.annotation != DLAnnotationNone) {    
            if (!self.cameraManager) {
                self.cameraManager = [[[DLCamCaptureManager alloc] init] autorelease];
                self.cameraManager.audioOnly = (self.annotation == DLAnnotationAudioOnly);
                self.cameraManager.delegate = self;
            }

            self.cameraManager.outputPath = [NSString stringWithFormat:@"%@/%@_camera.mp4", cachePath, (self.recordingContext ? self.recordingContext.sessionID : @"output")];
            [self.cameraManager startRecording];
            self.recordingContext.cameraFilePath = self.cameraManager.outputPath;
        }
        
        self.recordingContext.startTime = [NSDate date];
        self.recordingContext.screenFilePath = self.videoEncoder.outputPath;
        self.analytics = [[[DLAnalytics alloc] init] autorelease];

        if (self.autoCaptureEnabled) {
            [self scheduleScreenshot];
        }
    }
}

- (void)stopRecording 
{    
    if (self.cameraManager.recording) {
        [self.cameraManager stopRecording];
    }
    
    if (self.videoEncoder.recording) {
        [self.videoEncoder stopRecording];

		self.recordingContext.touches = self.gestureTracker.touches;
        self.recordingContext.touchBounds = [self.gestureTracker touchBounds];
        self.recordingContext.orientationChanges = self.gestureTracker.orientationChanges;
        self.recordingContext.viewInfos = self.analytics.viewInfos;
        self.recordingContext.events = self.analytics.events;
        self.analytics = nil;       // Stop tracking analytics data
    }
}

- (void)setScaleFactor:(CGFloat)aScaleFactor
{    
    if (self.videoEncoder.recording) {
        [NSException raise:@"Screen capture exception" format:@"Cannot change scale factor while recording is in progress."];
    }
    
    _scaleFactor = aScaleFactor;
    self.screenshotController.scaleFactor = aScaleFactor;
    self.videoEncoder.videoSize = self.screenshotController.imageSize;
    self.gestureTracker.scaleFactor = aScaleFactor;
}

- (void)stopAndUpload:(NSDate *)endTime
{
    if (self.recordingContext.shouldRecordVideo) {
        [self stopRecording];
    }
    self.recordingContext.endTime = endTime;
    self.recordingContext.userProperties = self.userProperties;
    self.recordingContext.metrics = self.metrics;
    if (!delaySessionUploadForCamera || (delaySessionUploadForCamera && cameraDidStop)) {
        delaySessionUploadForCamera = NO;
        [self.taskController prepareSessionUpload:self.recordingContext];
    }
}

- (void)stopAndUpload
{
    [self stopAndUpload:[NSDate date]];
}


- (void)setAutoCaptureEnabled:(BOOL)isAutoCaptureEnabled
{
    if (_autoCaptureEnabled != isAutoCaptureEnabled) {
        _autoCaptureEnabled = isAutoCaptureEnabled;
        
        if (isAutoCaptureEnabled && self.videoEncoder.recording && screenshotQueue.operationCount == 0) {
            [self scheduleScreenshot];
        }
    }
}

- (void)takeScreenshot
{    
    if (!self.videoEncoder.recording) return;
    
    // Need to set up an autorelease pool since this method gets called from a background thread
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Frame rate limiting
    float targetFrameInterval = 1.0f / maximumFrameRate;
    NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];
    if (now - lastScreenshotTime < targetFrameInterval) {
        [NSThread sleepForTimeInterval:targetFrameInterval - (now - lastScreenshotTime)];
    }
    
    NSTimeInterval start = [[NSProcessInfo processInfo] systemUptime];
    lastScreenshotTime = start;
    self.screenshotThread = [NSThread currentThread];
    
#if PRIVATE_FRAMEWORK
    DLMobileFrameBufferVideoEncoder *surfaceEncoder = (DLMobileFrameBufferVideoEncoder *)self.videoEncoder;
    [surfaceEncoder encode];
#else
    UIImage *screenshot = [self.screenshotController screenshot];
    DLUIKitVideoEncoder *imageEncoder = (DLUIKitVideoEncoder *)self.videoEncoder;
    [imageEncoder encodeImage:screenshot];
#endif
        
    if (self.recordingContext.startTime && [[NSDate date] timeIntervalSinceDate:self.recordingContext.startTime] >= maximumRecordingDuration) {
        // We've exceeded the maximum recording duration
        [self stopRecording];
        self.metrics.stopReason = DLMetricsStopReasonTimeLimit;
    } else if (self.autoCaptureEnabled) {
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
        [self takeScreenshot];
    }];
}

#pragma mark - Session

- (void)tryCreateNewSession {
    if (!self.videoEncoder.recording) {
        [self.taskController requestSessionIDWithAppToken:self.appToken];
    }
    
    [self.metrics reset];
}

- (void)taskController:(DLTaskController *)ctrl didGetNewSessionContext:(DLRecordingContext *)ctx {
    self.recordingContext = ctx;
    
	if (self.recordingContext.shouldRecordVideo) {
        if (self.annotation == DLAnnotationNone) {
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
            alertViewVisible = YES;
        }
	} else {
		// there's no need to record the session. Clean up video encoder?
		self.recordingContext.startTime = [NSDate date];
	}
}

#pragma mark - Notifications

- (void)handleDidEnterBackground:(NSNotification *)notification
{
    if (!alertViewVisible) {
        [self stopAndUpload];
    }
    
    appInBackground = YES;
}

- (void)handleWillEnterForeground:(NSNotification *)notification
{
    if (!alertViewVisible) {
        [self tryCreateNewSession];
    }
}

- (void)handleDidBecomeActive:(NSNotification *)notification
{
    // In iOS 4, locking the screen does not trigger didEnterBackground: notification. Check if we've been inactive for a long time.
    if (resignActiveTime > 0 && !appInBackground &&
        [[[UIDevice currentDevice] systemVersion] floatValue] < 5.0) {
        NSTimeInterval inactiveTime = [[NSDate date] timeIntervalSince1970] - resignActiveTime;
        if (inactiveTime > kDLMaximumSessionInactiveTime) {
            // We've been inactive for a long time, stop the previous recording and create a new session
            NSDate * previousEndTime = [NSDate dateWithTimeIntervalSince1970:resignActiveTime];
            [self stopAndUpload:previousEndTime];
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
	[self.taskController saveUnfinishedRecordingContext:self.recordingContext];
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
	if (!delaySessionUploadForCamera) {
        [self.taskController performSelectorOnMainThread:@selector(prepareSessionUpload:) withObject:self.recordingContext waitUntilDone:NO];
	}
    DLDebugLog(@"Completed camera recording, file is stored at: %@", captureManager.outputPath);
}

- (void)captureManager:(DLCamCaptureManager *)captureManager didFailWithError:(NSError *)error
{
    DLLog(@"[Delight] Camera recording failed: %@", error);
}

#pragma mark - DLGestureTrackerDelegate

- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location inView:(UIView *)view privateViewFrame:(CGRect *)frame
{
    return [self.screenshotController locationIsInPrivateView:location inView:view privateViewFrame:frame];
}

#pragma mark - UIAlertViewDelegate

- (void)willPresentAlertView:(UIAlertView *)alertView
{
    if (alertView.tag == kDLAlertViewTagStartUsabilityTest) {
        // Need to know the alert view size to position the text field properly
        UITextField *descriptionField = (UITextField *)[alertView viewWithTag:kDLAlertViewDescriptionFieldTag];
        descriptionField.frame = CGRectMake(20.0, alertView.frame.size.height - 97, 245.0, 25.0);
        [descriptionField becomeFirstResponder];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{    
    switch (alertView.tag) {
        case kDLAlertViewTagStartUsabilityTest:
            if (buttonIndex == 1 && self.recordingContext.shouldRecordVideo) {
                UITextField *descriptionField = (UITextField *)[alertView viewWithTag:kDLAlertViewDescriptionFieldTag];
                self.recordingContext.usabilityTestDescription = descriptionField.text;
                if ([descriptionField.text length]) {
                    [self.userProperties setObject:descriptionField.text forKey:@"description"];
                }
                [self startRecording];
            }
            break;
        default:
            break;
    }
    
    alertViewVisible = NO;
}

#pragma mark - DLVideoEncoderDelegate

- (void)videoEncoder:(DLVideoEncoder *)videoEncoder didBeginRecordingAtTime:(NSTimeInterval)startTime
{    
    if (videoEncoder.videoSize.width > videoEncoder.videoSize.height && self.gestureTracker.touchView.bounds.size.height > self.gestureTracker.touchView.bounds.size.width) {
        // Landscape video, portrait screen. Our surface is rotated.
        [self.gestureTracker setShouldRotateTouches:YES];
    }
    
    [self.gestureTracker startRecordingGesturesWithStartUptime:startTime];
}

- (void)videoEncoderWillRender:(DLVideoEncoder *)videoEncoder
{
    [self.screenshotController lockPrivateViewFrames];
}

- (void)videoEncoder:(DLVideoEncoder *)videoEncoder willEncodePixelBuffer:(CVPixelBufferRef)pixelBuffer scale:(CGFloat)scale
{
    if (![videoEncoder isKindOfClass:[DLUIKitVideoEncoder class]]) {
        // Black out private views before encoding
        CGAffineTransform transform = CGAffineTransformScale(self.gestureTracker.transform, scale, scale);
        [self.screenshotController blackOutPrivateViewsInPixelBuffer:pixelBuffer transform:transform];
    }
}

- (void)videoEncoderDidFinishRecording:(DLVideoEncoder *)videoEncoder
{
    [self.gestureTracker stopRecordingGestures];
}

@end
