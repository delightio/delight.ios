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
@synthesize previousLocation = _previousLocation;
@synthesize phase = _phase;
@synthesize timeInSession = _timeInSession;
@synthesize sequenceNum = _sequenceNum;
@synthesize tapCount = _tapCount;

- (id)initWithSequence:(NSUInteger)seqNum location:(CGPoint)aLocation previousLocation:(CGPoint)prevLoc phase:(UITouchPhase)aPhase tapCount:(NSUInteger)aCount timeInSession:(NSTimeInterval)aTimeInSession
{
    self = [super init];
    if (self) {
        _location = aLocation;
		_previousLocation = prevLoc;
        _phase = aPhase;
        _timeInSession = aTimeInSession;
		_sequenceNum = seqNum;
		_tapCount = aCount;
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromCGPoint(_location), @"curLoc", NSStringFromCGPoint(_previousLocation), @"prevLoc", [NSNumber numberWithInteger:_phase], @"phase", [NSNumber numberWithDouble:_timeInSession], @"time", [NSNumber numberWithUnsignedInteger:_sequenceNum], @"seq", [NSNumber numberWithUnsignedInteger:_tapCount], @"tapCount", nil];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Location: %@, phase: %i, time: %.3f", NSStringFromCGPoint(_location), _phase, _timeInSession];
}

@end
