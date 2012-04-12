//
//  DLScreenshotController.h
//  Delight
//
//  Created by Chris Haugli on 4/9/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "UIWindow+InterceptEvents.h"

/*
   DLScreenshotController takes and stores screenshots of a UIView.
 */
@interface DLScreenshotController : NSObject <DLWindowDelegate> {
    NSMutableArray *pendingTouches;  
    NSMutableSet *privateViews;
    UIImage *openGLImage;
    UIView *openGLView;
    UIWindow *keyboardWindow;
    
    void *bitmapData;
    CGRect keyboardFrame;
    NSUInteger pngCount;
}

@property (nonatomic, assign) CGFloat scaleFactor;
@property (nonatomic, assign) BOOL hidesKeyboard;
@property (nonatomic, assign) BOOL writesToPNG;
@property (nonatomic, retain) UIImage *previousScreenshot;

- (UIImage *)screenshot;
- (UIImage *)openGLScreenshotForView:(UIView *)view colorRenderBuffer:(GLuint)colorRenderBuffer;
- (UIImage *)drawPendingTouchMarksOnImage:(UIImage *)image;
- (void)registerPrivateView:(UIView *)view description:(NSString *)description;
- (void)unregisterPrivateView:(UIView *)view;

@end
