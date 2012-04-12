//
//  DLTaskController.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTaskController.h"
#import <UIKit/UIKit.h>

@implementation DLTaskController
@synthesize controlConnection = _controlConnection;

- (void)dealloc {
	if ( _controlConnection ) {
		[_controlConnection cancel];
		self.controlConnection = nil;
	}
	[super dealloc];
}

- (void)requestSessionID {
	if ( _controlConnection ) return;
	
	// begin connection
	NSString * urlStr = [NSString stringWithFormat:@""];
	NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
	_controlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)uploadVideoAtPath:(NSString *)aPath {
	// check if we can run background task
	UIDevice* device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)]) backgroundSupported = device.multitaskingSupported;
	
	if ( !backgroundSupported ) {
		// upload next time when the app is launched
		return;
	}
}

#pragma mark NSURLConnection delegate methods
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
}

@end
