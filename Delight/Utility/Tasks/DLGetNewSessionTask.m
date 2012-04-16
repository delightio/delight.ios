//
//  DLGetSessionTask.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLGetNewSessionTask.h"

@implementation DLGetNewSessionTask
@synthesize statusObject = _statusObject;

- (void)dealloc {
	[_statusObject release];
	[super dealloc];
}

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"http://%@/app_sessions.xml", DL_BASE_URL];
	NSString * paramStr = [NSString stringWithFormat:@"{\"app_session\":{\"app_token\":\"%@\",\"app_version\":\"%@\",\"locale\":\"%@\",\"delight_version\":\"0.1\"}}", DL_ACCESS_TOKEN, DL_APP_VERSION, DL_APP_LOCALE];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
	[request setHTTPBody:[[self stringByAddingPercentEscapes:paramStr] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPMethod:@"POST"];
	return request;
}

- (void)processResponse {
	// parse the object into Cocoa objects
	NSXMLParser * parser = [[NSXMLParser alloc] initWithData:self.receivedData];
	[parser setDelegate:self];
	[parser parse];
}

#pragma mark XML parsing delegate
- (void)parserDidStartDocument:(NSXMLParser *)parser {
	// create the session object
	_statusObject = [[DLRecordingContext alloc] init];
}

@end
