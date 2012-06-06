//
//  DLCamCaptureManager.m
//  Delight
//
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLCamCaptureManager.h"
#import "DLCamRecorder.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/CGImageProperties.h>

@interface DLCamCaptureManager (RecorderDelegate) <DLCamRecorderDelegate>
@end


#pragma mark -
@interface DLCamCaptureManager (InternalUtilityMethods)
- (BOOL) setupSession;
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *) frontFacingCamera;
- (AVCaptureDevice *) audioDevice;
- (NSURL *) tempFileURL;
- (void) removeFile:(NSURL *)outputFileURL;
@end


#pragma mark -
@implementation DLCamCaptureManager

@synthesize session;
@synthesize orientation;
@synthesize videoInput;
@synthesize audioInput;
@synthesize recorder;
@synthesize deviceConnectedObserver;
@synthesize deviceDisconnectedObserver;
@synthesize backgroundRecordingID;
@synthesize recording;
@synthesize audioOnly;
@synthesize savesToPhotoAlbum;
@synthesize outputPath;
@synthesize delegate;

- (id) init
{
    self = [super init];
    if (self != nil) {
		__block id weakSelf = self;
        void (^deviceConnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
			AVCaptureDevice *device = [notification object];
			
			BOOL sessionHasDeviceWithMatchingMediaType = NO;
			NSString *deviceMediaType = nil;
			if ([device hasMediaType:AVMediaTypeAudio])
                deviceMediaType = AVMediaTypeAudio;
			else if ([device hasMediaType:AVMediaTypeVideo])
                deviceMediaType = AVMediaTypeVideo;
			
			if (deviceMediaType != nil) {
				for (AVCaptureDeviceInput *input in [session inputs])
				{
					if ([[input device] hasMediaType:deviceMediaType]) {
						sessionHasDeviceWithMatchingMediaType = YES;
						break;
					}
				}
				
				if (!sessionHasDeviceWithMatchingMediaType) {
					NSError	*error;
					AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
					if ([session canAddInput:input])
						[session addInput:input];
				}				
			}
            
			if ([delegate respondsToSelector:@selector(captureManagerDeviceConfigurationChanged:)]) {
				[delegate captureManagerDeviceConfigurationChanged:self];
			}			
        };
        void (^deviceDisconnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
			AVCaptureDevice *device = [notification object];
			
			if ([device hasMediaType:AVMediaTypeAudio]) {
				[session removeInput:[weakSelf audioInput]];
				[weakSelf setAudioInput:nil];
			}
			else if ([device hasMediaType:AVMediaTypeVideo]) {
				[session removeInput:[weakSelf videoInput]];
				[weakSelf setVideoInput:nil];
			}
			
			if ([delegate respondsToSelector:@selector(captureManagerDeviceConfigurationChanged:)]) {
				[delegate captureManagerDeviceConfigurationChanged:self];
			}			
        };
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [self setDeviceConnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification object:nil queue:nil usingBlock:deviceConnectedBlock]];
        [self setDeviceDisconnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification object:nil queue:nil usingBlock:deviceDisconnectedBlock]];
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
		[notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
		orientation = AVCaptureVideoOrientationPortrait;        
    }
    
    return self;
}

- (void) dealloc
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:[self deviceConnectedObserver]];
    [notificationCenter removeObserver:[self deviceDisconnectedObserver]];
	[notificationCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    [[self session] stopRunning];
    [session release];
    [videoInput release];
    [audioInput release];
    [recorder release];
    
    [super dealloc];
}

- (void)startRecording
{    
    [self setupSession];    
}

- (void)stopRecording
{
    [[self recorder] stopRecording];
    [[self session] stopRunning];
    self.session = nil;
    recording = NO;
}

#pragma mark Device Counts

- (NSUInteger) cameraCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (NSUInteger) micCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] count];
}

@end

#pragma mark -

@implementation DLCamCaptureManager (InternalUtilityMethods)

- (BOOL)setupSession
{    
    AVCaptureDevice *cameraDevice = [self frontFacingCamera];
    AVCaptureDevice *audioDevice = [self audioDevice];
    
    if (audioDevice && !cameraDevice && !audioOnly) {
        DLLog(@"[Delight] No front-facing camera available. Only audio will be captured.");
    } if (!cameraDevice && !audioDevice) {
        DLLog(@"[Delight] No front-facing camera or microphone available.");
        return NO;
    }
    
    // Init the device inputs
    AVCaptureDeviceInput *newVideoInput = (audioOnly ? nil : [[AVCaptureDeviceInput alloc] initWithDevice:cameraDevice error:nil]);
    AVCaptureDeviceInput *newAudioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:nil];
    
    // Create session
    AVCaptureSession *newCaptureSession = [[AVCaptureSession alloc] init];
    newCaptureSession.sessionPreset = AVCaptureSessionPresetLow;
    
    // Add inputs and output to the capture session
    if (newVideoInput && [newCaptureSession canAddInput:newVideoInput]) {
        [newCaptureSession addInput:newVideoInput];
    }
    if ([newCaptureSession canAddInput:newAudioInput]) {
        [newCaptureSession addInput:newAudioInput];
    }
    
    [self setVideoInput:newVideoInput];
    [self setAudioInput:newAudioInput];
    [self setSession:newCaptureSession];
    
    [newVideoInput release];
    [newAudioInput release];
    [newCaptureSession release];
    
	// Set up the movie file output
    NSURL *outputFileURL = [self tempFileURL];
    DLCamRecorder *newRecorder = [[DLCamRecorder alloc] initWithSession:[self session] outputFileURL:outputFileURL];
    [newRecorder setDelegate:self];
	
	[self setRecorder:newRecorder];
    [newRecorder release];
	
    // Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [session startRunning];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[UIDevice currentDevice] isMultitaskingSupported]) {
                // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until DLCam returns
                // to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library
                // when DLCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error:
                // after the recorded file has been saved.
                [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}]];
            }
            
            // Remove old file and start recording
            [self removeFile:[[self recorder] outputFileURL]];
            [[self recorder] startRecordingWithOrientation:orientation];
            
            recording = YES;
        });                       
    });
    
    return YES;
}

// Keep track of current device orientation so it can be applied to movie recordings and still image captures
- (void)deviceOrientationDidChange
{	
	UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    
	if (deviceOrientation == UIDeviceOrientationPortrait)
		orientation = AVCaptureVideoOrientationPortrait;
	else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
		orientation = AVCaptureVideoOrientationPortraitUpsideDown;
	
	// AVCapture and UIDevice have opposite meanings for landscape left and right (AVCapture orientation is the same as UIInterfaceOrientation)
	else if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
		orientation = AVCaptureVideoOrientationLandscapeRight;
	else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
		orientation = AVCaptureVideoOrientationLandscapeLeft;
	
	// Ignore device orientations for which there is no corresponding still image orientation (e.g. UIDeviceOrientationFaceUp)
}

// Find a camera with the specificed AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

// Find a front facing camera, returning nil if one is not found
- (AVCaptureDevice *) frontFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

// Find and return an audio device, returning nil if one is not found
- (AVCaptureDevice *) audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0) {
        return [devices objectAtIndex:0];
    }
    return nil;
}

- (NSURL *) tempFileURL
{
    return [NSURL fileURLWithPath:outputPath];
}

- (void) removeFile:(NSURL *)fileURL
{
    NSString *filePath = [fileURL path];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:filePath error:&error] == NO) {
            if ([[self delegate] respondsToSelector:@selector(captureManager:didFailWithError:)]) {
                [[self delegate] captureManager:self didFailWithError:error];
            }            
        }
    }
}

@end


#pragma mark -
@implementation DLCamCaptureManager (RecorderDelegate)

- (void)recorderRecordingDidBegin:(DLCamRecorder *)recorder
{
    if ([[self delegate] respondsToSelector:@selector(captureManagerRecordingBegan:)]) {
        [[self delegate] captureManagerRecordingBegan:self];
    }
}

- (void)recorder:(DLCamRecorder *)recorder recordingDidFinishToOutputFileURL:(NSURL *)outputFileURL error:(NSError *)error
{
    if (error && [error code] != -11818) {
        // Not the regular "recording stopped" "error"
        if ([[self delegate] respondsToSelector:@selector(captureManager:didFailWithError:)]) {
            [[self delegate] captureManager:self didFailWithError:error];
        }
    }
    
    if (videoInput && savesToPhotoAlbum) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                    completionBlock:^(NSURL *assetURL, NSError *error) {
                                        if (error) {
                                            if ([[self delegate] respondsToSelector:@selector(captureManager:didFailWithError:)]) {
                                                [[self delegate] captureManager:self didFailWithError:error];
                                            }											
                                        }
                                        
                                        if ([[self delegate] respondsToSelector:@selector(captureManagerRecordingFinished:)]) {
                                            [[self delegate] captureManagerRecordingFinished:self];
                                        }
                                        
                                        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
                                            [[UIApplication sharedApplication] endBackgroundTask:[self backgroundRecordingID]];
                                        }
                                    }];
        [library release];
    } else {
        if ([[self delegate] respondsToSelector:@selector(captureManagerRecordingFinished:)]) {
            [[self delegate] captureManagerRecordingFinished:self];
        }
        
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            [[UIApplication sharedApplication] endBackgroundTask:[self backgroundRecordingID]];
        }
    }
}

@end
