//
//  CALayer+DLThreadSafe.h
//  Delight
//
//  Created by Chris Haugli on 5/7/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CALayer (DLThreadSafe)
- (void)DLrenderInContext:(CGContextRef)context;
- (CALayer *)copyWithPlainLayer;
@end