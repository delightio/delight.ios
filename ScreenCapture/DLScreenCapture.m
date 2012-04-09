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

@interface DLScreenCapture(Private)
- (void)startRecordingWithScaleFactor:(CGFloat)scaleFactor maximumFrameRate:(NSUInteger)maximumFrameRate;
- (void)stopRecording;
- (void)pause;
- (void)resume;
@end

@implementation DLScreenCapture

@synthesize frameRate;
@synthesize paused;
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
    [[self sharedInstance] startRecordingWithScaleFactor:kDefaultScaleFactor maximumFrameRate:kDefaultMaxFrameRate];    
}

+ (void)startWithScaleFactor:(CGFloat)scaleFactor maximumFrameRate:(NSUInteger)maximumFrameRate
{
    [[self sharedInstance] startRecordingWithScaleFactor:scaleFactor maximumFrameRate:maximumFrameRate];
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

+ (void)registerPrivateView:(UIView *)view description:(NSString *)description
{
    [[self sharedInstance].screenshotController registerPrivateView:view description:description];
}

+ (void)unregisterPrivateView:(UIView *)view
{
    [[self sharedInstance].screenshotController unregisterPrivateView:view];
}

+ (void)setHidesKeyboard:(BOOL)hidesKeyboard
{
    [[self sharedInstance].screenshotController setHidesKeyboard:hidesKeyboard];
}

#pragma mark -

- (id)init 
{
    self = [super init];
    if (self) {
        self.frameRate = kStartingFrameRate;
        
        screenshotController = [[DLScreenshotController alloc] init];

        videoController = [[DLVideoController alloc] init];
        videoController.outputPath = [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
        
        // Method swizzling to intercept events
        Swizzle([UIWindow class], @selector(sendEvent:), @selector(NBsendEvent:));
        for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
            [window NBsetDelegate:screenshotController];
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
    if (paused || !videoController.recording) return;
    
    processing = YES;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    UIImage *screenshot = nil;
    
    @synchronized(self) {
        // Take screenshot
        NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
        screenshot = [screenshotController screenshot];
        NSTimeInterval end = [[NSDate date] timeIntervalSince1970];
        
        frameCount++;
        elapsedTime += (end - start);
        // NSLog(@"%i frames, current %.3f, average %.3f", frameCount, (end - start), elapsedTime / frameCount);
    }
    
    if (videoController.recording) {
        @synchronized(self) {
            [videoController writeFrameImage:screenshot];
        } 
    }
    
    [pool drain];
    processing = NO;
}

- (void)startRecordingWithScaleFactor:(CGFloat)aScaleFactor maximumFrameRate:(NSUInteger)aMaximumFrameRate
{
    scaleFactor = aScaleFactor;
    screenshotController.scaleFactor = aScaleFactor;
    maximumFrameRate = aMaximumFrameRate;

    if (!videoController.recording) {
        videoController.videoSize = CGSizeMake([[UIScreen mainScreen] bounds].size.width * scaleFactor, [[UIScreen mainScreen] bounds].size.height * scaleFactor);
        [videoController startNewRecording];
        
        [self performSelector:@selector(takeScreenshot) withObject:nil afterDelay:1.0/frameRate];
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

#pragma mark - Notifications

- (void)handleWillResignActive:(NSNotification *)notification
{
    [self stopRecording];
}

- (void)handleDidBecomeActive:(NSNotification *)notification
{
    [self startRecordingWithScaleFactor:scaleFactor maximumFrameRate:maximumFrameRate];
}

@end