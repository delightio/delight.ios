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
    NSTimeInterval startTime;
    
    NSMutableSet *gesturesInProgress;
    NSMutableSet *gesturesCompleted;
    CGMutablePathRef arrowheadPath;
    NSLock *lock;
}

@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, retain) UIWindow *mainWindow;
@property (nonatomic, assign) BOOL drawsGestures;
@property (nonatomic, retain) NSMutableArray *touches;
@property (nonatomic, retain) NSMutableArray *orientationChanges;
@property (nonatomic, assign) id<DLGestureTrackerDelegate> delegate;

- (void)startRecordingGesturesWithStartUptime:(NSTimeInterval)aStartTime;
- (void)stopRecordingGestures;
- (UIImage *)drawPendingTouchMarksOnImage:(UIImage *)image;

@end

@protocol DLGestureTrackerDelegate <NSObject>
- (BOOL)gestureTracker:(DLGestureTracker *)gestureTracker locationIsPrivate:(CGPoint)location privateViewFrame:(CGRect *)frame;
@optional
- (void)gestureTrackerDidShake:(DLGestureTracker *)gestureTracker;
@end
