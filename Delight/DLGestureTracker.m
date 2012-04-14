//
//  DLGestureTracker.m
//  Delight
//
//  Created by Chris Haugli on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLGestureTracker.h"
#import "DLGesture.h"
#import </usr/include/objc/objc-class.h>

static void Swizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

@interface DLGestureTracker ()
- (void)drawPendingTouchMarksInContext:(CGContextRef)context;
- (CGContextRef)createBitmapContextOfSize:(CGSize)size;
@end

@implementation DLGestureTracker

@synthesize scaleFactor;
@synthesize delegate;

- (id)init
{
    self = [super init];
    if (self) {
        gesturesInProgress = [[NSMutableSet alloc] init];
        gesturesCompleted = [[NSMutableSet alloc] init];
        
        scaleFactor = 1.0f;
        bitmapData = NULL;
        
        // Method swizzling to intercept events
        Swizzle([UIWindow class], @selector(sendEvent:), @selector(DLsendEvent:));
        for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
            [window DLsetDelegate:self];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWindowDidBecomeVisibleNotification:) name:UIWindowDidBecomeVisibleNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWindowDidBecomeHiddenNotification:) name:UIWindowDidBecomeHiddenNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [gesturesInProgress release];
    [gesturesCompleted release];
    
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
    
    [super dealloc];
}

- (UIImage *)drawPendingTouchMarksOnImage:(UIImage *)image
{
    CGContextRef context = [self createBitmapContextOfSize:image.size];
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

#pragma mark - Private methods

- (void)drawPendingTouchMarksInContext:(CGContextRef)context
{    
    // Draw touch points
    CGContextSetRGBStrokeColor(context, 0, 0, 1, 0.7);
    CGContextSetLineWidth(context, 5.0);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat tapCircleRadius = 7 * scaleFactor * scale;
    
    NSMutableSet *allGestures = [[NSMutableSet alloc] init];
    @synchronized(self) {
        [allGestures unionSet:gesturesInProgress];
        [allGestures unionSet:gesturesCompleted];
    }
    
    for (DLGesture *gesture in allGestures) {
        BOOL startLocationIsInPrivateView = [delegate gestureTracker:self locationIsPrivate:[[gesture.locations objectAtIndex:0] CGPointValue]];

        if (!startLocationIsInPrivateView) {
            if (gesture.type == DLGestureTypeTap) {
                // Tap: draw a circle at the start point
                CGPoint location = [[gesture.locations objectAtIndex:0] CGPointValue];
                CGPoint scaledLocation = CGPointMake(location.x * scaleFactor * scale, location.y * scaleFactor * scale);
                
                CGContextSetRGBFillColor(context, 0, 0, 1, 0.7);                                 
                CGContextFillEllipseInRect(context, CGRectMake(scaledLocation.x - tapCircleRadius, scaledLocation.y - tapCircleRadius, 2 * tapCircleRadius + 1, 2 * tapCircleRadius + 1));
            } else {
                // Swipe: draw a line from start to finish with an arrowhead
                CGPoint startLocation;
                NSInteger strokeCount = 0;
                CGPoint lastLocations[4];

                for (NSUInteger i = 0; i < [gesture.locations count]; i++) {
                    CGPoint location = [[gesture.locations objectAtIndex:i] CGPointValue];
                    CGPoint scaledLocation = CGPointMake(location.x * scaleFactor * scale, location.y * scaleFactor * scale);

                    if (i == 0) {
                        startLocation = scaledLocation;
                        CGContextMoveToPoint(context, scaledLocation.x, scaledLocation.y);
                    } else if (i < [gesture.locations count] - 1) {
                        for (NSInteger i = 0; i < 3; i++) {
                            lastLocations[i] = lastLocations[i+1];
                        }
                        lastLocations[3] = scaledLocation;
                        strokeCount++;
                        
                        CGContextAddLineToPoint(context, scaledLocation.x, scaledLocation.y);
                    } else {
                        CGContextStrokePath(context);
                        
                        CGPoint lastLocation = (strokeCount < 4 ? lastLocations[4 - strokeCount] : lastLocations[0]);
                        double angle = atan2(scaledLocation.y - lastLocation.y, scaledLocation.x - lastLocation.x);
                        
                        CGContextSetRGBFillColor(context, 0, 0, 1, 1.0); 
                        CGContextMoveToPoint(context, scaledLocation.x, scaledLocation.y);
                        CGContextAddLineToPoint(context, scaledLocation.x + 50*cos(angle + M_PI + M_PI/8), scaledLocation.y + 50*sin(angle + M_PI + M_PI/8));
                        CGContextAddLineToPoint(context, scaledLocation.x + 50*cos(angle + M_PI - M_PI/8), scaledLocation.y + 50*sin(angle + M_PI - M_PI/8));
                        CGContextAddLineToPoint(context, scaledLocation.x, scaledLocation.y);
                        CGContextFillPath(context);
                    }
                }                
            }
        }
    }
    
    [allGestures release];
    
    @synchronized(self) {
        [gesturesCompleted removeAllObjects];
    }
}

- (CGContextRef)createBitmapContextOfSize:(CGSize)size
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * size.height);
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (bitmapData != NULL) {
        free(bitmapData);
    }
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }
    
    context = CGBitmapContextCreate (bitmapData,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaNoneSkipFirst);
    
    if (context == NULL) {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    CGColorSpaceRelease( colorSpace );
    
    return context;
}

#pragma mark - Notifications

- (void)handleWindowDidBecomeVisibleNotification:(NSNotification *)notification
{
    UIWindow *window = [notification object];
    [window DLsetDelegate:self];
}

- (void)handleWindowDidBecomeHiddenNotification:(NSNotification *)notification
{
    UIWindow *window = [notification object];
    [window DLsetDelegate:nil];    
}

#pragma mark - DLWindowDelegate

- (void)window:(UIWindow *)window sendEvent:(UIEvent *)event
{
    NSMutableSet *gesturesJustCompleted = [[NSMutableSet alloc] initWithSet:gesturesInProgress];
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    
    for (UITouch *touch in [event allTouches]) {
        if (touch.timestamp > 0) {
            CGPoint location = [touch locationInView:keyWindow];
            
            BOOL existing = NO;
            if (touch.phase != UITouchPhaseBegan) {
                // Check if this touch is part of an existing gesture
                @synchronized(self) {
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
                }
            }
            
            if (!existing) {
                // This is part of a new gesture
                DLGesture *gesture = [[DLGesture alloc] initWithLocation:location];
                @synchronized(self) {
                    [gesturesInProgress addObject:gesture];
                }
                [gesture release];
            }
        }
    }
    
    // Any gestures that were not updated are now completed
    [gesturesCompleted unionSet:gesturesJustCompleted];
    [gesturesInProgress minusSet:gesturesJustCompleted];
    
    [gesturesJustCompleted release];
}

@end
