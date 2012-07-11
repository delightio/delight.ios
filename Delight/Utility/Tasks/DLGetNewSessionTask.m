//
//  DLGetSessionTask.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLGetNewSessionTask.h"
#import "DLTaskController.h"
#import <sys/utsname.h>
#import "Delight.h"
#import "Delight_Private.h"
#import "DLConstants.h"

NSString * const DLUploadURIElementName = @"upload_uris";
NSString * const DLWifiOnlyElementName = @"uploading_on_wifi_only";
NSString * const DLIDElementName = @"id";
NSString * const DLRecordElementName = @"recording";
NSString * const DLScaleFactorElementName = @"scale_factor";
NSString * const DLMaximumFrameRateElementName = @"maximum_frame_rate";
NSString * const DLAverageBitRateElementName = @"average_bit_rate";
NSString * const DLMaximumKeyFrameIntervalElementName = @"maximum_key_frame_interval";
NSString * const DLMaximumRecordingDurationElementName = @"maximum_duration";

@interface DLGetNewSessionTask ()
- (NSString *)parameterStringForProperties:(NSDictionary *)properties;
@end

@implementation DLGetNewSessionTask
@synthesize contentOfCurrentProperty = _contentOfCurrentProperty;

- (void)dealloc {
	[_contentOfCurrentProperty release];
	[super dealloc];
}

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"https://%@/%@s.xml", DL_BASE_URL, self.taskController.sessionObjectName];
	// check build and version number
	NSDictionary * dict = [[NSBundle mainBundle] infoDictionary];
	NSString * buildVer = [dict objectForKey:(NSString *)kCFBundleVersionKey];
	if ( buildVer == nil ) buildVer = @"";
	else buildVer = [self stringByAddingPercentEscapes:buildVer];
	NSString * dotVer = [dict objectForKey:@"CFBundleShortVersionString"];
	if ( dotVer == nil ) dotVer = buildVer;
	else dotVer = [self stringByAddingPercentEscapes:dotVer];
	UIDevice * theDevice = [UIDevice currentDevice];
	// get the exact hardward name
	struct utsname systemInfo;
	uname(&systemInfo);
	
	NSString * machineName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
	NSString * systemPropertyParamStr = [self parameterStringForProperties:[NSDictionary dictionaryWithObjectsAndKeys:dotVer, @"app_version", 
                                                                            buildVer, @"app_build",
                                                                            [[NSLocale currentLocale] localeIdentifier], @"app_locale",
                                                                            self.taskController.networkStatusString, @"app_connectivity",
                                                                            DELIGHT_VERSION, @"delight_version",
                                                                            machineName, @"device_hw_version", 
                                                                            theDevice.systemVersion, @"device_os_version",
                                                                            nil]];

    NSMutableString *userPropertyParamStr = [NSMutableString string];
    NSDictionary *userProperties = [Delight sharedInstance].userProperties;
    for (NSString * key in [userProperties allKeys]) {
        id value = [userProperties objectForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            value = [self stringByAddingPercentEscapes:value];
        }
        [userPropertyParamStr appendFormat:@"&%@[properties][%@]=%@", self.taskController.sessionObjectName, [self stringByAddingPercentEscapes:key], value];
    }
    
    NSString *paramStr = [NSString stringWithFormat:@"%@%@", systemPropertyParamStr, userPropertyParamStr];
    
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
//	[request setHTTPBody:[[self stringByAddingPercentEscapes:paramStr] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:[paramStr dataUsingEncoding:NSUTF8StringEncoding]];
	[request setValue:self.appToken	forHTTPHeaderField:@"X-NB-AuthToken"];
	[request setHTTPMethod:@"POST"];
	
	DLLog(@"[Delight] connecting to Delight server");
	return request;
}

- (void)processResponse {
	// parse the object into Cocoa objects
	NSXMLParser * parser = [[NSXMLParser alloc] initWithData:self.receivedData];
	[parser setDelegate:self];
	if ( ![parser parse] ) {
		NSLog(@"error parsing xml: %@", [parser parserError]);
	}
	[parser release];
}

#pragma mark XML parsing delegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if ( [elementName isEqualToString:self.taskController.sessionObjectName] ) {
		// create a new session object
		self.recordingContext = [[[DLRecordingContext alloc] init] autorelease];
	} else if ( [elementName isEqualToString:DLUploadURIElementName] ) {
		NSMutableDictionary * trackDict = [NSMutableDictionary dictionaryWithCapacity:4];
		for (NSString * theKey in attributeDict) {
			if ( [theKey rangeOfString:@"_track"].location != NSNotFound ) {
				// this is a track URL
				// we can get the URI directly from the attribute
				NSString * strURL = [attributeDict objectForKey:theKey];
				// get expiry timestamp
				NSRange firstRange = [strURL rangeOfString:@"Expires="];
				NSRange nextRange = [strURL rangeOfString:@"&" options:0 range:NSMakeRange(firstRange.length + firstRange.location, [strURL length] - firstRange.length - firstRange.location)];
				NSString * dateStr = [strURL substringWithRange:NSMakeRange(firstRange.length + firstRange.location, nextRange.location - firstRange.length - firstRange.location)];
				NSDate * expDate = nil;
				if ( dateStr ) {
					expDate = [NSDate dateWithTimeIntervalSince1970:[dateStr doubleValue]];
				}
				// save the track
				[trackDict setObject:[NSDictionary dictionaryWithObjectsAndKeys:strURL, DLTrackURLKey, expDate == nil ? [NSNull null] : expDate, DLTrackExpiryDateKey, nil] forKey:theKey];
			}
		}
		self.recordingContext.tracks = trackDict;
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
	} else if ( [elementName isEqualToString:DLScaleFactorElementName] ) {
        self.recordingContext.scaleFactor = [_contentOfCurrentProperty floatValue];
    } else if ( [elementName isEqualToString:DLMaximumFrameRateElementName] ) {
        self.recordingContext.maximumFrameRate = [_contentOfCurrentProperty doubleValue];
    } else if ( [elementName isEqualToString:DLAverageBitRateElementName] ) {
        self.recordingContext.averageBitRate = [_contentOfCurrentProperty doubleValue];
    } else if ( [elementName isEqualToString:DLMaximumKeyFrameIntervalElementName] ) {
        self.recordingContext.maximumKeyFrameInterval = [_contentOfCurrentProperty integerValue];
    } else if ( [elementName isEqualToString:DLMaximumRecordingDurationElementName] ) {
        self.recordingContext.maximumRecordingDuration = [_contentOfCurrentProperty doubleValue];
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

- (NSString *)parameterStringForProperties:(NSDictionary *)properties
{
    NSMutableString *paramStr = [NSMutableString string];
    for (NSString *propertyName in [properties allKeys]) {
        [paramStr appendFormat:@"%@[%@]=%@&", self.taskController.sessionObjectName, propertyName, [properties objectForKey:propertyName]];
    }
    return [paramStr substringToIndex:[paramStr length] - 1];
}

@end
