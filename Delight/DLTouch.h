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
@property (nonatomic, assign) UITouchPhase phase;
@property (nonatomic, assign) NSTimeInterval timeInSession;
@property (nonatomic, assign) NSUInteger touchID;
@property (nonatomic, assign) UIEvent * event;

- (id)initWithUITouch:(UITouch *)atouch;

- (id)initWithLocation:(CGPoint)aLocation phase:(UITouchPhase)aPhase timeInSession:(NSTimeInterval)aTimeInSession;
- (NSDictionary *)dictionaryRepresentation;

@end
