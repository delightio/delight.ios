//
//  DLTask.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTask.h"
#import "DLTaskController.h"

NSString * const DL_BASE_URL = @"0.0.0.0:5000";
NSString * const DL_BASE_SCHEME = @"http";
NSString * const DL_APP_LOCALE = @"";
NSString * const DLTrackURLKey = @"url";
NSString * const DLTrackExpiryDateKey = @"expiry_date";
NSString * const DLScreenTrackKey = @"screen_track";
NSString * const DLTouchTrackKey = @"touch_track";
NSString * const DLFrontTrackKey = @"front_track";
NSString * const DLOrientationTrackKey = @"orientation_track";
NSString * const DLViewTrackKey = @"view_track";
NSString * const DLEventTrackKey = @"event_track";

@implementation DLTask
@synthesize recordingContext = _recordingContext;
@synthesize backgroundTaskIdentifier = _backgroundTaskIdentifier;
@synthesize taskController = _taskController;
@synthesize receivedData = _receivedData;
@synthesize httpResponse = _httpResponse;
@synthesize connection = _connection;
@synthesize appToken = _appToken;

- (id)initWithAppToken:(NSString *)aToken {
	self = [super init];
	_backgroundTaskIdentifier = UIBackgroundTaskInvalid;
	_appToken = [aToken retain];
	return self;
}

- (void)dealloc {
	[_recordingContext release];
	[_receivedData release];
	[_httpResponse release];
	[_appToken release];
	[super dealloc];
}

- (NSString *)stringByAddingPercentEscapes:(NSString *)str {
	CFStringRef percentWord = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)str, NULL, CFSTR(":/?#[]@!$&’()*+,;="), kCFStringEncodingUTF8);
	str = (NSString *)percentWord;
	return [str autorelease];
}

- (NSURLRequest *)URLRequest {
	return nil;
}

- (void)processResponse {

}

- (BOOL)responseContainsError {
	NSInteger theCode = [_httpResponse statusCode];
	return !(theCode < 300 && theCode > 199);
}

#pragma mark NSOperation
- (void)start {
	NSURLConnection * theConn = [[NSURLConnection alloc] initWithRequest:[self URLRequest] delegate:self startImmediately:NO];
	NSRunLoop * runloop = [NSRunLoop mainRunLoop];
	[theConn scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
	[theConn start];
	self.connection = theConn;
	[theConn release];
}

- (void)cancel {
	@synchronized (self) {
		BOOL flag = [self isCancelled];
		if ( flag ) {
			[super cancel];
			[self.connection cancel];
			self.connection = nil;
		}
	}
}

//- (BOOL)isConcurrent {
//    // any thread
//    return YES;
//}
//
- (BOOL)isExecuting {
    // any thread
    return _connection != nil;
}

- (BOOL)isFinished {
    // any thread
    return _connection == nil;
}

#pragma mark URL Connection
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	self.httpResponse = (NSHTTPURLResponse *)response;
	_receivedData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"%@", str);
//	[str release];
	// check if there's error
	if ( ![self responseContainsError] ) {
		DLDebugLog(@"[Delight] Received data from server successfully");
		// process the data
		[self.taskController.queue addOperationWithBlock:^{
			[self processResponse];
		}];
	} else {
		NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
		NSLog(@"[Delight] Server returns error: %@\nStatus code: %d", str, _httpResponse.statusCode);
		[str release];
	}
	self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	DLLog(@"[Delight] error connecting to delight server: %@", error);
	self.connection = nil;
	self.receivedData = nil;
}

@end
