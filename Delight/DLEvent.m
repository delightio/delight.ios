//
//  DLEvent.m
//  Delight
//
//  Created by Chris Haugli on 7/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLEvent.h"

@implementation DLEvent

@synthesize name = _name;
@synthesize properties = _properties;
@synthesize time = _time;

+ (id)eventWithName:(NSString *)name properties:(NSDictionary *)properties at:(NSTimeInterval)time
{
    return [[[DLEvent alloc] initWithName:name properties:properties at:time] autorelease];
}

- (id)initWithName:(NSString *)name properties:(NSDictionary *)properties at:(NSTimeInterval)time
{
    self = [super init];
    if (self) {
        self.name = name;
        self.properties = properties;
        self.time = time;
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [_properties release];
    
    [super dealloc];
}

- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       _name, @"name",
                                       [NSNumber numberWithDouble:_time], @"time",
                                       _properties, @"properties", nil];    
    return dictionary;
}

@end
