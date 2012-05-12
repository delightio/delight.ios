//
//  DLTouch.m
//  Delight
//
//  Created by Chris Haugli on 4/24/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTouch.h"

@implementation DLTouch

@synthesize location;
@synthesize phase;
@synthesize timeInSession;

- (id)initWithLocation:(CGPoint)aLocation phase:(UITouchPhase)aPhase timeInSession:(NSTimeInterval)aTimeInSession
{
    self = [super init];
    if (self) {
        self.location = aLocation;
        self.phase = aPhase;
        self.timeInSession = aTimeInSession;
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:self.location.x], @"x", [NSNumber numberWithFloat:self.location.y], @"y", nil], @"location", [NSNumber numberWithInteger:phase], @"phase", [NSNumber numberWithDouble:timeInSession], @"timeInSession", nil];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Location: %@, phase: %i, time: %.3f", NSStringFromCGPoint(location), phase, timeInSession];
}

@end
