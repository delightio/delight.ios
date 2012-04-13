//
//  DLPostVideoInfoTask.m
//  Delight
//
//  Created by Bill So on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLPostVideoInfoTask.h"

@implementation DLPostVideoInfoTask
@synthesize videoURLString = _videoURLString;
@synthesize fileStatus = _fileStatus;

- (NSURLRequest *)URLRequest {
	NSString * urlStr = [NSString stringWithFormat:@"http://%@/videos.xml?uri=%@&app_session_id=%@", _videoURLString, _fileStatus.sessionID];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:DL_REQUEST_TIMEOUT];
	[request setHTTPMethod:@"POST"];
	return request;
}

- (void)processResponse {
	
}

@end
