//
//  DLOrientationChange.m
//  Delight
//
//  Created by Chris Haugli on 4/24/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLOrientationChange.h"

@implementation DLOrientationChange

@synthesize deviceOrientation;
@synthesize interfaceOrientation;
@synthesize timeInSession;

- (id)initWithDeviceOrientation:(UIDeviceOrientation)aDeviceOrientation interfaceOrientation:(UIInterfaceOrientation)anInterfaceOrientation timeInSession:(NSTimeInterval)aTimeInSession
{
    self = [super init];
    if (self) {
        self.deviceOrientation = aDeviceOrientation;
        self.interfaceOrientation = anInterfaceOrientation;
        self.timeInSession = aTimeInSession;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Device orientation: %i, interface orientation: %i, time: %.3f", deviceOrientation, interfaceOrientation, timeInSession];
}

@end
