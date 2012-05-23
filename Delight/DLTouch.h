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
@property (nonatomic, assign) CGPoint previousLocation;
@property (nonatomic, assign) UITouchPhase phase;
@property (nonatomic, assign) NSTimeInterval timeInSession;
@property (nonatomic, assign) NSUInteger sequenceNum;
@property (nonatomic, assign) NSUInteger tapCount;

- (id)initWithSequence:(NSUInteger)seqNum location:(CGPoint)aLocation previousLocation:(CGPoint)prevLoc phase:(UITouchPhase)aPhase tapCount:(NSUInteger)aCount timeInSession:(NSTimeInterval)aTimeInSession;
- (NSDictionary *)dictionaryRepresentation;

@end
