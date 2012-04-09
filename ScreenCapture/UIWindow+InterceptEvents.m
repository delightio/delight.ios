//
//  UIWindow+InterceptEvents.m
//  ipad
//
//  Created by Chris Haugli on 1/23/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UIWindow+InterceptEvents.h"
#import </usr/include/objc/objc-runtime.h>

MAKE_CATEGORIES_LOADABLE(UIWindow_InterceptEvents);

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