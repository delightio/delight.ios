//
//  DLEvent.h
//  Delight
//
//  Created by Chris Haugli on 7/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DLEvent : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSDictionary *properties;
@property (nonatomic) NSTimeInterval time;

+ (id)eventWithName:(NSString *)name properties:(NSDictionary *)properties at:(NSTimeInterval)time;
- (id)initWithName:(NSString *)name properties:(NSDictionary *)properties at:(NSTimeInterval)time;
- (NSDictionary *)dictionaryRepresentation;

@end
