//
//  DLUploadVideoFileTask.m
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLUploadVideoFileTask.h"

@implementation DLUploadVideoFileTask

- (NSURLRequest *)URLRequest {
	NSInputStream * theStream = [NSInputStream inputStreamWithFileAtPath:self.recordingContext.filePath];
	NSMutableURLRequest * request = nil;
	if ( theStream ) {
		request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.recordingContext.uploadURLString] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:600.0];
		[request setHTTPMethod:@"PUT"];
		// get file length
		NSDictionary * attrDict = [[NSFileManager defaultManager] attributesOfItemAtPath:self.recordingContext.filePath error:nil];
		[request setValue:[NSString stringWithFormat:@"%qu", [attrDict fileSize]] forHTTPHeaderField:@"Content-Length"];
		// open up the file
		[request setHTTPBodyStream:theStream];
	}
	return request;
}

- (void)processResponse {
//	NSString * str = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
//	NSLog(@"received data: %@", str);
//	[str release];
	// create Post Video task
	
	[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
	self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
}

@end
