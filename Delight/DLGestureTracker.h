//
//  DLGestureTracker.h
//  Delight
//
//  Created by Chris Haugli on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIWindow+DLInterceptEvents.h"

@protocol DLWindowDelegate;
@protocol DLGestureTrackerDelegate;

@interface DLGestureTracker : NSObject <DLWindowDelegate> {
    void *bitmapData;
    
    NSMutableSet *gesturesInProgress;
    NSMutableSet *gesturesCompleted;
}

@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, assign) BOOL drawsGestures;
@property (nonatomic, retain) NSMutableArray *touches;
@property (nonatomic, retain) NSMutableArray *orientationChanges;
@property (nonatomic, assign) NSTimeInterval startTime; // t=0 as system uptime
@property (nonatomic, assign) id<DLGestureTrackerDelegate> delegate;

- (UIImage *)drawPendingTouchMarksOnImage:(UIImage *)image;

@end

@protocol DLGestureTrackerDelegate
- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location;
@end