//
//  DLGesture.h
//  Delight
//
//  Created by Chris Haugli on 4/13/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    DLGestureTypeTap,
    DLGestureTypeSwipe
} DLGestureType;

@interface DLGesture : NSObject

@property (nonatomic, retain) NSMutableArray *locations;
@property (nonatomic, assign) DLGestureType type;

- (id)initWithLocation:(CGPoint)location;
- (void)addLocation:(CGPoint)location;
- (BOOL)locationBelongsToGesture:(CGPoint)location;

@end
