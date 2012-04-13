//
//  DLTask.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DL_REQUEST_TIMEOUT	30.0
NSString * const DL_BASE_URL = @"delightweb.herokuapp.com";
extern NSString * const DL_ACCESS_TOKEN;
extern NSString * const DL_APP_LOCALE;
extern NSString * const DL_APP_VERSION;

@interface DLTask : NSObject

@property (nonatomic, retain) NSMutableData * receivedData;
@property (nonatomic, retain) NSHTTPURLResponse * httpResponse;

- (NSURLRequest *)URLRequest;
- (void)processResponse;
- (BOOL)responseContainsError;

@end
