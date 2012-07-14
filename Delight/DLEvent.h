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

+ (id)eventWithName:(NSString *)name properties:(NSDictionary *)properties;
- (id)initWithName:(NSString *)name properties:(NSDictionary *)properties;
- (NSDictionary *)dictionaryRepresentation;

@end
