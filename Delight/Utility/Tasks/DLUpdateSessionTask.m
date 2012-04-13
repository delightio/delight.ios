//
//  DLUpdateSessionTask.m
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLUpdateSessionTask.h"

@implementation DLUpdateSessionTask
@synthesize fileStatus = _fileStatus;

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"http://%@/app_sessions.xml?duration=%d&app_user_id=%@", DL_BASE_URL, (NSInteger)[_fileStatus.endTime timeIntervalSinceDate:_fileStatus.startTime]];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
	[request setHTTPMethod:@"PUT"];
	return request;
}

- (void)processResponse {
	
}

@end
