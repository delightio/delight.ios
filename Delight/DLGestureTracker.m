//
//  DLGestureTracker.m
//  Delight
//
//  Created by Chris Haugli on 4/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLGestureTracker.h"

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
        pendingTouches = [[NSMutableArray alloc] init];
        scaleFactor = 1.0f;
        bitmapData = NULL;
    }
    return self;
}

- (void)dealloc
{
    [pendingTouches release];
    
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
    NSMutableArray *objectsToRemove = [NSMutableArray array];
    CGContextSetRGBStrokeColor(context, 0, 0, 1, 0.7);
    CGContextSetLineWidth(context, 5.0);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGPoint lastLocations[4];
    CGPoint startLocation = CGPointZero;
    NSInteger strokeCount = 0;
    CGFloat scale = [UIScreen mainScreen].scale;
    
    @synchronized(self) {
        BOOL lineBegun = NO;
        for (NSMutableDictionary *touch in pendingTouches) {
            CGPoint location = [[touch objectForKey:@"location"] CGPointValue];

            BOOL locationIsInPrivateView = [delegate gestureTracker:self locationIsPrivate:location];
            location.x *= scaleFactor * scale;
            location.y *= scaleFactor * scale;
            NSInteger decayCount = [[touch objectForKey:@"decayCount"] integerValue];
            UITouchPhase phase = [[touch objectForKey:@"phase"] intValue];
            
            // Increase the decay count
            [touch setObject:[NSNumber numberWithInteger:decayCount+1] forKey:@"decayCount"];
            [objectsToRemove addObject:touch];
            
            if (!locationIsInPrivateView) {
                switch (phase) {
                    case UITouchPhaseBegan:
                        startLocation = location;
                        CGContextMoveToPoint(context, location.x, location.y);
                        lineBegun = YES;
                        break;
                    case UITouchPhaseEnded:
                    case UITouchPhaseCancelled:
                        CGContextStrokePath(context);
                        double distance = sqrt((location.y - startLocation.y)*(location.y - startLocation.y) + (location.x - startLocation.x)*(location.x-startLocation.x));
                        
                        if (distance > 10 && strokeCount > 0) {
                            CGPoint lastLocation = (strokeCount < 4 ? lastLocations[4 - strokeCount] : lastLocations[0]);
                            double angle = atan2(location.y - lastLocation.y, location.x - lastLocation.x);
                            
                            CGContextSetRGBFillColor(context, 0, 0, 1, 1.0); 
                            CGContextMoveToPoint(context, location.x, location.y);
                            CGContextAddLineToPoint(context, location.x + 50*cos(angle + M_PI + M_PI/8), location.y + 50*sin(angle + M_PI + M_PI/8));
                            CGContextAddLineToPoint(context, location.x + 50*cos(angle + M_PI - M_PI/8), location.y + 50*sin(angle + M_PI - M_PI/8));
                            CGContextAddLineToPoint(context, location.x, location.y);
                            CGContextFillPath(context);
                        } else {
                            CGContextSetRGBFillColor(context, 0, 0, 1, 0.7);                                 
                            CGContextFillEllipseInRect(context, CGRectMake(location.x - 8, location.y - 8, 16, 16));    
                        }
                        break;
                    case UITouchPhaseMoved:
                    case UITouchPhaseStationary:
                        if (lineBegun) {
                            CGContextAddLineToPoint(context, location.x, location.y);
                        } else {
                            CGContextMoveToPoint(context, location.x, location.y);
                        }
                        if (CGPointEqualToPoint(startLocation, CGPointZero)) {
                            startLocation = location;
                        }
                        for (NSInteger i = 0; i <= 2; i++) {
                            lastLocations[i] = lastLocations[i+1];
                        }
                        lastLocations[3] = location;
                        strokeCount++;
                        break;
                }
            }
        }
        [pendingTouches removeObjectsInArray:objectsToRemove];
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

#pragma mark - DLWindowDelegate

- (void)window:(UIWindow *)window sendEvent:(UIEvent *)event
{
    @synchronized(self) {
        for (UITouch *touch in [event allTouches]) {
            if (touch.timestamp > 0) {
                CGPoint location = [touch locationInView:touch.window];
                
                // UITouch objects seem to get reused. We can't copy or clone them, so create a poor man's touch object using a dictionary.
                NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithCGPoint:location], @"location",
                                                   [NSNumber numberWithInteger:0], @"decayCount", 
                                                   [NSNumber numberWithInt:touch.phase], @"phase",
                                                   nil];
                [pendingTouches addObject:dictionary];
            }
        }
    }
}

@end
