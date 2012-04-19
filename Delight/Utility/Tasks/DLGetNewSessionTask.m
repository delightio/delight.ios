//
//  DLGetSessionTask.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLGetNewSessionTask.h"
#import "DLTaskController.h"

NSString * const DLAppSessionElementName = @"app_session";
NSString * const DLUploadURIElementName = @"upload_uris";
NSString * const DLWifiOnlyElementName = @"uploading_on_wifi_only";
NSString * const DLIDElementName = @"id";
NSString * const DLRecordElementName = @"recording";

@implementation DLGetNewSessionTask
@synthesize appToken = _appToken;
@synthesize contentOfCurrentProperty = _contentOfCurrentProperty;

- (void)dealloc {
	[_appToken release];
	[_contentOfCurrentProperty release];
	[super dealloc];
}

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"http://%@/app_sessions.xml", DL_BASE_URL];
	NSDictionary * dict = [[NSBundle mainBundle] infoDictionary];
	NSString * buildVer = [dict objectForKey:(NSString *)kCFBundleVersionKey];
	if ( buildVer == nil ) buildVer = @"";
	else buildVer = [self stringByAddingPercentEscapes:buildVer];
	NSString * dotVer = [dict objectForKey:@"CFBundleShortVersionString"];
	if ( dotVer == nil ) dotVer = @"";
	else dotVer = [self stringByAddingPercentEscapes:dotVer];
	NSString * paramStr = [NSString stringWithFormat:@"app_session[app_token]=%@&app_session[app_version]=%@&app_session[app_build]=%@&app_session[locale]=%@&app_session[delight_version]=1", _appToken, dotVer, buildVer, [[NSLocale currentLocale] localeIdentifier]];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
//	[request setHTTPBody:[[self stringByAddingPercentEscapes:paramStr] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:[paramStr dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPMethod:@"POST"];
	return request;
}

- (void)processResponse {
	// parse the object into Cocoa objects
	NSXMLParser * parser = [[NSXMLParser alloc] initWithData:self.receivedData];
	[parser setDelegate:self];
	if ( ![parser parse] ) {
		NSLog(@"error parsing xml: %@", [parser parserError]);
	}
}

#pragma mark XML parsing delegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if ( [elementName isEqualToString:DLAppSessionElementName] ) {
		// create a new session object
		self.recordingContext = [[[DLRecordingContext alloc] init] autorelease];
	} else if ( [elementName isEqualToString:DLUploadURIElementName] ) {
		// we can get the URI directly from the attribute
		self.recordingContext.uploadURLString = [attributeDict objectForKey:@"screen"];
	} else {
		// prepare the string buffer
		_contentOfCurrentProperty = [[NSMutableString alloc] initWithCapacity:16];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	if ( [elementName isEqualToString:DLIDElementName] ) {
		self.recordingContext.sessionID = _contentOfCurrentProperty;
	} else if ( [elementName isEqualToString:DLRecordElementName] ) {
		self.recordingContext.shouldRecordVideo = [_contentOfCurrentProperty boolValue];
	} else if ( [elementName isEqualToString:DLWifiOnlyElementName] ) {
		self.recordingContext.wifiUploadOnly = [_contentOfCurrentProperty boolValue];
	}
	self.contentOfCurrentProperty = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	if ( _contentOfCurrentProperty ) {
		[_contentOfCurrentProperty appendString:string];
	}
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
	// call the method in Delight in main thread
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.taskController handleSessionTaskCompletion:self];
	});
}

@end
