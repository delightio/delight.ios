//
//  DLViewChange.m
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLViewChange.h"

@implementation DLViewChange

@synthesize name = _name;
@synthesize type = _type;
@synthesize timeInSession = _timeInSession;

+ (id)viewChangeWithName:(NSString *)name type:(DLViewChangeType)type timeInSession:(NSTimeInterval)timeInSession
{
    return [[[self alloc] initWithName:name type:type timeInSession:timeInSession] autorelease];
}

+ (NSString *)stringForType:(DLViewChangeType)type
{
    switch (type) {
        case DLViewChangeTypeViewController:   return @"view";
        case DLViewChangeTypeUser:             return @"user";
    }
    
    return nil;
}

- (id)initWithName:(NSString *)name type:(DLViewChangeType)type timeInSession:(NSTimeInterval)timeInSession
{
    self = [super init];
    if (self) {
        self.name = name;
        self.type = type;
        self.timeInSession = timeInSession;
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
	return [NSDictionary dictionaryWithObjectsAndKeys:
            _name, @"name",
            [DLViewChange stringForType:_type], @"type",
            [NSNumber numberWithDouble:_timeInSession], @"time", nil];
}

@end
