//
//  NBScreenCapturingWindow.m
//  ipad
//
//  Created by Chris Haugli on 1/23/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "NBScreenCapturingWindow.h"
#import </usr/include/objc/objc-runtime.h>

@implementation NBScreenCapturingWindow

- (void)sendEvent:(UIEvent *)event
{
    id<NBScreenCapturingWindowDelegate> delegate = objc_getAssociatedObject(self, "delegate");
    [delegate screenCapturingWindow:self sendEvent:event];
    [super sendEvent:event];
}

- (void)setDelegate:(id<NBScreenCapturingWindowDelegate>)delegate
{
    // Can't use ivar since we need this class to be have the same memory offsets as UIWindow
    objc_setAssociatedObject(self, "delegate", delegate, OBJC_ASSOCIATION_ASSIGN);    
}

@end


@implementation UIWindow (InterceptEvents)

- (void)NBsetDelegate:(id<NBScreenCapturingWindowDelegate>)delegate
{
    // Can't use ivar since we need this class to be have the same memory offsets as UIWindow
    objc_setAssociatedObject(self, "delegate", delegate, OBJC_ASSOCIATION_ASSIGN);    
}

- (void)NBsendEvent:(UIEvent *)event
{
    id<NBScreenCapturingWindowDelegate> delegate = objc_getAssociatedObject(self, "delegate");
    [delegate screenCapturingWindow:self sendEvent:event]; 
    
    [self NBsendEvent:event];
}

@end