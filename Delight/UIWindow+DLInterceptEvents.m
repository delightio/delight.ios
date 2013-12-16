//
//  UIWindow+DLInterceptEvents.m
//  Delight
//
//  Created by Chris Haugli on 1/23/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UIWindow+DLInterceptEvents.h"
#import <objc/runtime.h>

DL_MAKE_CATEGORIES_LOADABLE(UIWindow_DLInterceptEvents);

@implementation UIWindow (DLInterceptEvents)

- (void)DLsetDelegate:(id<DLWindowDelegate>)delegate
{
    // Can't use ivar since we need this class to have the same memory offsets as UIWindow
    objc_setAssociatedObject(self, "DLDelegate", delegate, OBJC_ASSOCIATION_ASSIGN);    
}

- (void)DLsendEvent:(UIEvent *)event
{
    id<DLWindowDelegate> delegate = objc_getAssociatedObject(self, "DLDelegate");
    [delegate window:self sendEvent:event]; 
    
    [self DLsendEvent:event];
}

@end
