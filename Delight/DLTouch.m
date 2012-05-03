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

- (NSString *)description
{
    return [NSString stringWithFormat:@"Location: %@, phase: %i, time: %.3f", NSStringFromCGPoint(location), phase, timeInSession];
}

@end
