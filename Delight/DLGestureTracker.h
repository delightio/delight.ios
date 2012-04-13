//
//  DLGestureTracker.h
//  Delight
//
//  Created by Chris Haugli on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIWindow+InterceptEvents.h"

@protocol DLWindowDelegate;
@protocol DLGestureTrackerDelegate;

@interface DLGestureTracker : NSObject <DLWindowDelegate> {
    void *bitmapData;
    NSMutableArray *pendingTouches;
}

@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, assign) id<DLGestureTrackerDelegate> delegate;

- (UIImage *)drawPendingTouchMarksOnImage:(UIImage *)image;

@end

@protocol DLGestureTrackerDelegate
- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location;
@end