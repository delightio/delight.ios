//
//  DLTouch.m
//  Delight
//
//  Created by Chris Haugli on 4/24/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLTouch.h"

@implementation DLTouch

@synthesize location = _location;
@synthesize phase = _phase;
@synthesize timeInSession = _timeInSession;
@synthesize touchID = _touchID;
@synthesize sequenceNum = _sequenceNum;

- (id)initWithID:(NSUInteger)anID sequence:(NSUInteger)seqNum location:(CGPoint)aLocation phase:(UITouchPhase)aPhase timeInSession:(NSTimeInterval)aTimeInSession
{
    self = [super init];
    if (self) {
        _location = aLocation;
        _phase = aPhase;
        _timeInSession = aTimeInSession;
		_touchID = anID;
		_sequenceNum = seqNum;
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:_location.x], @"x", [NSNumber numberWithFloat:_location.y], @"y", [NSNumber numberWithInteger:_phase], @"phase", [NSNumber numberWithDouble:_timeInSession], @"timeInSession", [NSNumber numberWithUnsignedInteger:_touchID], @"touchID", [NSNumber numberWithUnsignedInteger:_sequenceNum], @"sequenceNum", nil];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Location: %@, phase: %i, time: %.3f", NSStringFromCGPoint(_location), _phase, _timeInSession];
}

@end
