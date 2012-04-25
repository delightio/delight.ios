//
//  DLTouch.h
//  Delight
//
//  Created by Chris Haugli on 4/24/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

/*
  Represents a single touch event.
 */
@interface DLTouch : NSObject

@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign) NSTimeInterval timeInSession;

- (id)initWithLocation:(CGPoint)location timeInSession:(NSTimeInterval)timeInSession;

@end
