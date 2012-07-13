//
//  DLViewSection.m
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLViewSection.h"

@implementation DLViewSection

@synthesize name = _name;
@synthesize type = _type;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;

+ (id)viewSectionWithName:(NSString *)name type:(DLViewSectionType)type startTime:(NSTimeInterval)startTime
{
    return [[[self alloc] initWithName:name type:type startTime:startTime] autorelease];
}

+ (NSString *)stringForType:(DLViewSectionType)type
{
    switch (type) {
        case DLViewSectionTypeViewController:   return @"vc";
        case DLViewSectionTypeUser:             return @"user";
    }
    
    return nil;
}

- (id)initWithName:(NSString *)name type:(DLViewSectionType)type startTime:(NSTimeInterval)startTime
{
    self = [super init];
    if (self) {
        self.name = name;
        self.type = type;
        self.startTime = startTime;
        self.endTime = -1;
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [super dealloc];
}

- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        _name, @"name",
                                        [DLViewSection stringForType:_type], @"type",
                                        [NSNumber numberWithDouble:_startTime], @"startTime", nil];
    if (_endTime >= 0) {
        [dictionary setObject:[NSNumber numberWithDouble:_endTime] forKey:@"endTime"];
    }
    
    return dictionary;
}

@end
