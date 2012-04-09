//
//  DLScreenshotController.h
//  ScreenCapture
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
@interface DLScreenshotController : NSObject <NBScreenCapturingWindowDelegate> {
    NSMutableArray *screenshotBuffer;
    NSMutableArray *pendingTouches;  
    NSMutableSet *privateViews;
    
    void *bitmapData;
    CGRect keyboardFrame;
    NSUInteger pngCount;
}

@property (nonatomic, assign) CGFloat scaleFactor;      // Note: does not currently apply to OpenGL screenshots
@property (nonatomic, assign) BOOL hidesKeyboard;
@property (nonatomic, assign) BOOL writesToPNG;

- (UIImage *)screenshot;
- (UIImage *)openGLScreenshotForView:(UIView *)view colorRenderBuffer:(GLuint)colorRenderBuffer;
- (void)registerPrivateView:(UIView *)view description:(NSString *)description;
- (void)unregisterPrivateView:(UIView *)view;

@end
