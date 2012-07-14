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

+ (id)eventWithName:(NSString *)name properties:(NSDictionary *)properties
{
    return [[[DLEvent alloc] initWithName:name properties:properties] autorelease];
}

- (id)initWithName:(NSString *)name properties:(NSDictionary *)properties
{
    self = [super init];
    if (self) {
        self.name = name;
        self.properties = properties;
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
                                       _properties, @"properties", nil];    
    return dictionary;
}

@end
