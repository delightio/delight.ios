//
//  DLTaskController.h
//  Delight
//
//  Created by Bill So on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DLTaskController : NSObject <NSURLConnectionDataDelegate>

@property (nonatomic, retain) NSURLConnection * controlConnection;

- (void)requestSessionID;
- (void)uploadVideoAtPath:(NSString *)aPath;

@end
