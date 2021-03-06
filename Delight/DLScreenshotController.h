//
//  DLScreenshotController.h
//  Delight
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

/*
   DLScreenshotController takes and stores screenshots of a UIView.
 */
@interface DLScreenshotController : NSObject {
    UIWindow *keyboardWindow;
    
    void *bitmapData;
    CGRect keyboardFrame;
    NSUInteger pngCount;
}

@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, assign) BOOL hidesKeyboard;
@property (nonatomic, assign) BOOL writesToPNG;
@property (nonatomic, readonly) CGSize imageSize;
@property (nonatomic, readonly) NSMutableSet *privateViews;
@property (nonatomic, retain) NSMutableSet *lockedPrivateViewFrames;

- (UIImage *)screenshot;
- (void)registerPrivateView:(UIView *)view description:(NSString *)description;
- (void)unregisterPrivateView:(UIView *)view;
- (BOOL)locationIsInPrivateView:(CGPoint)location inView:(UIView *)view privateViewFrame:(CGRect *)frame;
- (void)lockPrivateViewFrames;
- (void)blackOutPrivateViewsInPixelBuffer:(CVPixelBufferRef)pixelBuffer transform:(CGAffineTransform)transform;

@end
