//
//  DLMetrics.h
//  Delight
//
//  Created by Chris Haugli on 5/18/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    DLMetricsStopReasonBackground,
    DLMetricsStopReasonTimeLimit,
    DLMetricsStopReasonManual
} DLMetricsStopReason;

@interface DLMetrics : NSObject <NSCoding>

@property (nonatomic, assign) NSUInteger privateViewCount;
@property (nonatomic, assign) NSUInteger keyboardHiddenCount;
@property (nonatomic, assign) DLMetricsStopReason stopReason;

- (void)reset;

@end
