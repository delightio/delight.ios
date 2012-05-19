//
//  DLMetrics.m
//  Delight
//
//  Created by Chris Haugli on 5/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLMetrics.h"

@implementation DLMetrics

@synthesize privateViewCount;
@synthesize keyboardHiddenCount;
@synthesize stopReason;

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
    if (self) {
        self.privateViewCount = [aDecoder decodeIntegerForKey:@"privateViewCount"];
        self.keyboardHiddenCount = [aDecoder decodeIntegerForKey:@"keyboardHiddenCount"];
        self.stopReason = [aDecoder decodeIntegerForKey:@"stopReason"];
    }	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:privateViewCount forKey:@"privateViewCount"];
    [aCoder encodeInteger:keyboardHiddenCount forKey:@"keyboardHiddenCount"];
    [aCoder encodeInteger:stopReason forKey:@"stopReason"];
}

- (void)reset
{
    privateViewCount = 0;
    keyboardHiddenCount = 0;
    stopReason = DLMetricsStopReasonBackground;
}

@end
