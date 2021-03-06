//
//  DLGestureTracker.m
//  Delight
//
//  Created by Chris Haugli on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLGestureTracker.h"
#import "DLGesture.h"
#import "DLOrientationChange.h"
#import "DLTouch.h"

@interface DLGestureTracker ()
- (void)drawPendingTouchMarksInContext:(CGContextRef)context;
- (CGContextRef)newBitmapContextOfSize:(CGSize)size;
- (void)updateGesturesForEvent:(UIEvent *)event;
- (void)handleDeviceOrientationDidChangeNotification:(NSNotification *)notification;
@end

#if PRIVATE_FRAMEWORK
@interface UIScreen (Private)
- (float)_rotation;
@end
#endif

@implementation DLGestureTracker

@synthesize scaleFactor;
@synthesize touchView;
@synthesize shouldRotateTouches;
@synthesize transform;
@synthesize drawsGestures;
@synthesize touches;
@synthesize orientationChanges;
@synthesize delegate;

- (id)init
{
    self = [super init];
    if (self) {
        gesturesInProgress = [[NSMutableSet alloc] init];
        gesturesCompleted = [[NSMutableSet alloc] init];
        touches = [[NSMutableArray alloc] init];
        orientationChanges = [[NSMutableArray alloc] init];
        lock = [[NSLock alloc] init];

        scaleFactor = 1.0f;
        transform = CGAffineTransformIdentity;
        bitmapData = NULL;
        startTime = -1;
        drawsGestures = YES;
        arrowheadPath = NULL;
        
        NSArray *windows = [[UIApplication sharedApplication] windows];
        if ([windows count]) {
            for (UIWindow *window in windows) {
                if (![window respondsToSelector:@selector(DLsetDelegate:)]) {
                    NSLog(@"[Delight] Error: categories not loaded. Have you included -ObjC in the 'Other Linker Flags' setting of your target?");
                    [NSException raise:@"Categories not loaded" format:@"UIWindow additions missing"];
                }
                [window DLsetDelegate:self];
            }
            
            // Assume rearmost window is the main app window
            self.touchView = [windows objectAtIndex:0];
        }
        
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(handleWindowDidBecomeVisibleNotification:) name:UIWindowDidBecomeVisibleNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(handleWindowDidBecomeHiddenNotification:) name:UIWindowDidBecomeHiddenNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(handleDeviceOrientationDidChangeNotification:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

    [gesturesInProgress release];
    [gesturesCompleted release];
    [touches release];
    [orientationChanges release];
    [lock release];
    [touchView release];
    
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
    
    if (arrowheadPath != NULL) {
        CGPathRelease(arrowheadPath);
    }
    
    [super dealloc];
}

- (UIImage *)drawPendingTouchMarksOnImage:(UIImage *)image
{
    if (!drawsGestures || (![gesturesInProgress count] && ![gesturesCompleted count])) {
        // If no gestures to draw, just return the original image
        return image;
    }
    
    CGContextRef context = [self newBitmapContextOfSize:image.size];
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), [image CGImage]);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -image.size.height);
    
    [self drawPendingTouchMarksInContext:context];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *touchMarkImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(context);
    
    return touchMarkImage;
}

- (void)startRecordingGesturesWithStartUptime:(NSTimeInterval)aStartTime
{
    startTime = aStartTime;
    [touches removeAllObjects];
    [orientationChanges removeAllObjects];
        
    // Set the initial orientation
    [self handleDeviceOrientationDidChangeNotification:nil];
}

- (void)stopRecordingGestures
{
    startTime = -1;
}

- (void)setShouldRotateTouches:(BOOL)aShouldRotateTouches
{
    shouldRotateTouches = aShouldRotateTouches;
    
    if (shouldRotateTouches) {
#if PRIVATE_FRAMEWORK
        CGFloat rotation = ([[UIScreen mainScreen] respondsToSelector:@selector(_rotation)] ? -[[UIScreen mainScreen] _rotation] : M_PI_2);
#else
        CGFloat rotation = M_PI_2;
#endif
        CGRect transformedBounds = CGRectApplyAffineTransform(self.touchView.bounds, CGAffineTransformMakeRotation(rotation));
        transform = CGAffineTransformMakeTranslation(-transformedBounds.origin.x, -transformedBounds.origin.y);
        transform = CGAffineTransformRotate(transform, rotation);
    } else {
        transform = CGAffineTransformIdentity;
    }
}

#pragma mark - Private methods

- (void)drawPendingTouchMarksInContext:(CGContextRef)context
{    
    // Draw touch points
    CGFloat scale = [UIScreen mainScreen].scale;
    CGContextSetRGBStrokeColor(context, 0, 0, 1, 0.7);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetLineWidth(context, 5 * scaleFactor * scale);
    CGFloat tapCircleRadius = 7 * scaleFactor * scale;
    
    NSMutableSet *allGestures = [[NSMutableSet alloc] init];
    [lock lock];
    [allGestures unionSet:gesturesInProgress];
    [allGestures unionSet:gesturesCompleted];
    [lock unlock];
    
    for (DLGesture *gesture in allGestures) {
        CGRect privateViewFrame;
        BOOL startLocationIsInPrivateView = [delegate gestureTracker:self locationIsPrivate:[[gesture.locations objectAtIndex:0] CGPointValue] inView:touchView privateViewFrame:&privateViewFrame];

        if (startLocationIsInPrivateView) {
            // Gesture is in a private view. Don't draw it, that could leak private information. Just flash the view it's in.
            CGRect scaledPrivateViewFrame = CGRectApplyAffineTransform(privateViewFrame, CGAffineTransformMakeScale(scaleFactor * scale, scaleFactor * scale));
            CGContextSetRGBFillColor(context, 0, 0, 1, 0.5);             
            CGContextFillRect(context, scaledPrivateViewFrame);
        
        } else {
            if (gesture.type == DLGestureTypeTap) {
                // Tap: draw a circle at the start point
                CGPoint location = [[gesture.locations objectAtIndex:0] CGPointValue];
                CGPoint scaledLocation = CGPointMake(location.x * scaleFactor * scale, location.y * scaleFactor * scale);
                
                CGContextSetRGBFillColor(context, 0, 0, 1, 0.7);                                 
                CGContextFillEllipseInRect(context, CGRectMake(scaledLocation.x - tapCircleRadius, scaledLocation.y - tapCircleRadius, 2 * tapCircleRadius + 1, 2 * tapCircleRadius + 1));
            } else {
                // Swipe: draw a line from start to finish with an arrowhead
                NSInteger strokeCount = 0;
                CGPoint lastLocations[4];

                for (NSUInteger i = 0; i < [gesture.locations count]; i++) {
                    CGPoint location = [[gesture.locations objectAtIndex:i] CGPointValue];
                    CGPoint scaledLocation = CGPointMake(location.x * scaleFactor * scale, location.y * scaleFactor * scale);

                    if (i == 0) {
                        CGContextMoveToPoint(context, scaledLocation.x, scaledLocation.y);
                    } else if (i < [gesture.locations count] - 1) {
                        for (NSInteger i = 0; i < 3; i++) {
                            lastLocations[i] = lastLocations[i+1];
                        }
                        lastLocations[3] = scaledLocation;
                        strokeCount++;
                        
                        CGContextAddLineToPoint(context, scaledLocation.x, scaledLocation.y);
                    } else if (strokeCount > 0) {
                        CGContextStrokePath(context);
                        
                        if (arrowheadPath == NULL) {
                            // Create the arrowhead path and cache it for future use
                            CGFloat arrowSize = 50 * scaleFactor * scale;

                            arrowheadPath = CGPathCreateMutable();
                            CGPathMoveToPoint(arrowheadPath, NULL, 0, 0);
                            CGPathAddLineToPoint(arrowheadPath, NULL, arrowSize*cos(M_PI + M_PI/8), arrowSize*sin(M_PI + M_PI/8));
                            CGPathAddLineToPoint(arrowheadPath, NULL, arrowSize*cos(M_PI - M_PI/8), arrowSize*sin(M_PI - M_PI/8));
                            CGPathAddLineToPoint(arrowheadPath, NULL, 0, 0);
                            CGPathCloseSubpath(arrowheadPath);
                        }
                        
                        // Draw the arrowhead
                        CGPoint lastLocation = (strokeCount < 4 ? lastLocations[4 - strokeCount] : lastLocations[0]);
                        double angle = atan2(scaledLocation.y - lastLocation.y, scaledLocation.x - lastLocation.x);
                        
                        CGContextSetRGBFillColor(context, 0, 0, 1, 1.0); 
                        CGContextSaveGState(context);
                        CGContextTranslateCTM(context, scaledLocation.x, scaledLocation.y);
                        CGContextRotateCTM(context, angle);
                        CGContextAddPath(context, arrowheadPath);
                        CGContextFillPath(context);
                        CGContextRestoreGState(context);
                    }
                }                
            }
        }
    }
    
    [allGestures release];
    
    [lock lock];
    [gesturesCompleted removeAllObjects];
    [lock unlock];
}

- (CGContextRef)newBitmapContextOfSize:(CGSize)size
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * size.height);
    if (bitmapData != NULL) {
        free(bitmapData);
    }
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }

    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (bitmapData,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaNoneSkipFirst);
    CGColorSpaceRelease( colorSpace );
    
    if (context == NULL) {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    
    return context;
}

- (void)updateGesturesForEvent:(UIEvent *)event
{
    NSMutableSet *gesturesJustCompleted = [[NSMutableSet alloc] initWithSet:gesturesInProgress];
    
    for (UITouch *touch in [event allTouches]) {
        if (touch.timestamp > 0) {
            CGPoint location = [touch locationInView:touchView];
            
            BOOL existing = NO;
            if (touch.phase != UITouchPhaseBegan) {
                // Check if this touch is part of an existing gesture
                [lock lock];
                for (DLGesture *gesture in gesturesInProgress) {
                    if ([gesture locationBelongsToGesture:location]) {
                        [gesture addLocation:location];
                        
                        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
                            // Still in progress
                            [gesturesJustCompleted removeObject:gesture];
                        }
                        existing = YES;
                        break;
                    }
                }
                [lock unlock];
            }
            
            if (!existing) {
                // This is part of a new gesture
                DLGesture *gesture = [[DLGesture alloc] initWithLocation:location];
                [lock lock];
                [gesturesInProgress addObject:gesture];
                [lock unlock];
                [gesture release];
            }
        }
    }
    
    // Any gestures that were not updated are now completed
    [gesturesCompleted unionSet:gesturesJustCompleted];
    [gesturesInProgress minusSet:gesturesJustCompleted];
    
    [gesturesJustCompleted release];
}

- (CGRect)touchBounds
{
    CGRect touchBounds = CGRectApplyAffineTransform(self.touchView.bounds, transform);
    touchBounds.origin = CGPointMake(0, 0);
    return touchBounds;
}

#pragma mark - Notifications

- (void)handleWindowDidBecomeVisibleNotification:(NSNotification *)notification
{
    UIWindow *window = [notification object];
    if (![window respondsToSelector:@selector(DLsetDelegate:)]) {
        NSLog(@"[Delight] Error: categories not loaded. Have you included -ObjC in the 'Other Linker Flags' setting of your target?");
        [NSException raise:@"Categories not loaded" format:@"UIWindow additions missing"];
    }
    [window DLsetDelegate:self];
    
    if (!touchView) {
        self.touchView = window;
    }
}

- (void)handleWindowDidBecomeHiddenNotification:(NSNotification *)notification
{
    UIWindow *window = [notification object];
    [window DLsetDelegate:nil];    
}

- (void)handleDeviceOrientationDidChangeNotification:(NSNotification *)notification
{
    if (startTime < 0) return;
    
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    NSTimeInterval timeInSession = (notification ? [[NSProcessInfo processInfo] systemUptime] - startTime : 0.0f);
    
    DLOrientationChange *orientationChange = [[DLOrientationChange alloc] initWithDeviceOrientation:deviceOrientation
                                                                               interfaceOrientation:interfaceOrientation
                                                                                      timeInSession:timeInSession];
    [orientationChanges addObject:orientationChange];
    [orientationChange release];
}

#pragma mark - DLWindowDelegate

- (void)window:(UIWindow *)window sendEvent:(UIEvent *)event
{
    if (startTime < 0) return;
    
    if (drawsGestures) {
        [self updateGesturesForEvent:event];
    } else {
		++eventSequenceLog;
        for (UITouch *touch in [event allTouches]) {
			CGRect privateViewFrame;
			CGPoint location = [touch locationInView:touchView];
            CGPoint previousLocation = [touch previousLocationInView:touchView];
            BOOL touchIsInPrivateView = [delegate gestureTracker:self locationIsPrivate:location inView:touchView privateViewFrame:&privateViewFrame];

            // If there's a transform property set, apply it
            if (!CGAffineTransformEqualToTransform(transform, CGAffineTransformIdentity)) {
                location = CGPointApplyAffineTransform(location, transform);
                previousLocation = CGPointApplyAffineTransform(previousLocation, transform);
                if (touchIsInPrivateView) {
                    privateViewFrame = CGRectApplyAffineTransform(privateViewFrame, transform);
                }
            }
            
            DLTouch *ourTouch = [[DLTouch alloc] initWithSequence:eventSequenceLog location:location previousLocation:previousLocation phase:touch.phase tapCount:touch.tapCount timeInSession:touch.timestamp - startTime inPrivateView:touchIsInPrivateView privateViewFrame:privateViewFrame];
            [touches addObject:ourTouch];
            [ourTouch release];            
        }
    }
}

@end
