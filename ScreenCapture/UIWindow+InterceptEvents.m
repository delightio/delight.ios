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

- (void)DLsetDelegate:(id<DLWindowDelegate>)delegate
{
    // Can't use ivar since we need this class to have the same memory offsets as UIWindow
    objc_setAssociatedObject(self, "delegate", delegate, OBJC_ASSOCIATION_ASSIGN);    
}

- (void)DLsendEvent:(UIEvent *)event
{
    id<DLWindowDelegate> delegate = objc_getAssociatedObject(self, "delegate");
    [delegate window:self sendEvent:event]; 
    
    [self DLsendEvent:event];
}

@end