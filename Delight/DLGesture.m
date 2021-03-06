//
//  DLGesture.m
//  Delight
//
//  Created by Chris Haugli on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLGesture.h"

// The maximum difference in distance between two touches that can be considered to be part of the same gesture
#define kDLGestureDistanceThreshold 50

// The distance required before a tap becomes a swipe
#define kDLMinimumSwipeDistance 40

static CGFloat DistanceBetweenTwoPoints(CGPoint point1, CGPoint point2)
{
    CGFloat dx = point2.x - point1.x;
    CGFloat dy = point2.y - point1.y;
    return sqrt(dx*dx + dy*dy);
};

@implementation DLGesture

@synthesize locations;
@synthesize type;

- (id)init
{
    self = [super init];
    if (self) {
        locations = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithLocation:(CGPoint)location
{
    self = [self init];
    if (self) {
        [self addLocation:location];
    }
    return self;
}

- (void)dealloc
{
    [locations release];
    [super dealloc];
}

- (void)addLocation:(CGPoint)location
{
    [locations addObject:[NSValue valueWithCGPoint:location]];
    
    if (DistanceBetweenTwoPoints(location, [[locations objectAtIndex:0] CGPointValue]) >= kDLMinimumSwipeDistance) {
        type = DLGestureTypeSwipe;
    }
}

- (BOOL)locationBelongsToGesture:(CGPoint)location
{
    if (![locations count]) return NO;
    
    CGPoint lastLocation = [[locations lastObject] CGPointValue];
    return (DistanceBetweenTwoPoints(location, lastLocation) <= kDLGestureDistanceThreshold);
}

@end
