//
//  DLCamRecorder.m
//  Delight
//
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLCamRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface DLCamRecorder () <AVCaptureFileOutputRecordingDelegate>
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;
@end

@implementation DLCamRecorder

@synthesize session;
@synthesize movieFileOutput;
@synthesize outputFileURL;
@synthesize delegate;

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
	return nil;
}

- (id) initWithSession:(AVCaptureSession *)aSession outputFileURL:(NSURL *)anOutputFileURL
{
    self = [super init];
    if (self != nil) {
        AVCaptureMovieFileOutput *aMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        if ([aSession canAddOutput:aMovieFileOutput])
            [aSession addOutput:aMovieFileOutput];
        [self setMovieFileOutput:aMovieFileOutput];
        [aMovieFileOutput release];
		
		[self setSession:aSession];
		[self setOutputFileURL:anOutputFileURL];
    }

	return self;
}

- (void)dealloc
{
    [[self session] removeOutput:[self movieFileOutput]];
	[session release];
	[outputFileURL release];
	[movieFileOutput release];
    [super dealloc];
}

- (BOOL)recordsVideo
{
	AVCaptureConnection *videoConnection = [DLCamRecorder connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]];
	return [videoConnection isActive];
}

- (BOOL)recordsAudio
{
	AVCaptureConnection *audioConnection = [DLCamRecorder connectionWithMediaType:AVMediaTypeAudio fromConnections:[[self movieFileOutput] connections]];
	return [audioConnection isActive];
}

- (BOOL)isRecording
{
    return [[self movieFileOutput] isRecording];
}

- (void)startRecordingWithOrientation:(AVCaptureVideoOrientation)videoOrientation;
{
    AVCaptureConnection *videoConnection = [DLCamRecorder connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]];
    if ([videoConnection isVideoOrientationSupported])
        [videoConnection setVideoOrientation:videoOrientation];
    
    [[self movieFileOutput] startRecordingToOutputFileURL:[self outputFileURL] recordingDelegate:self];
}

-(void)stopRecording
{
    [[self movieFileOutput] stopRecording];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)             captureOutput:(AVCaptureFileOutput *)captureOutput
didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                   fromConnections:(NSArray *)connections
{
    if ([[self delegate] respondsToSelector:@selector(recorderRecordingDidBegin:)]) {
        [[self delegate] recorderRecordingDidBegin:self];
    }
}

- (void)              captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)anOutputFileURL
                    fromConnections:(NSArray *)connections
                              error:(NSError *)error
{
    if ([[self delegate] respondsToSelector:@selector(recorder:recordingDidFinishToOutputFileURL:error:)]) {
        [[self delegate] recorder:self recordingDidFinishToOutputFileURL:anOutputFileURL error:error];
    }
}

@end
