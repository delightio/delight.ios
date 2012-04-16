//
//  DLTask.m
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTask.h"

NSString * const DL_BASE_URL = @"delightweb.herokuapp.com";

@implementation DLTask
@synthesize receivedData = _receivedData;
@synthesize httpResponse = _httpResponse;

- (void)dealloc {
	[_receivedData release];
	[_httpResponse release];
	[super dealloc];
}

- (NSMutableData *)receivedData {
	if ( _receivedData == nil ) {
		_receivedData = [[NSMutableData alloc] init];
	}
	return _receivedData;
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

@end
