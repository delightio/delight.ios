//
//  UIViewController+DLViewChange.m
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UIViewController+DLViewChange.h"
#import "Delight_Private.h"

DL_MAKE_CATEGORIES_LOADABLE(UIViewController_DLViewChange);

@implementation UIViewController (DLViewChange)

- (void)DLviewDidAppear:(BOOL)animated
{
    [self DLviewDidAppear:animated];    
    [Delight markCurrentViewName:NSStringFromClass([self class]) type:DLViewChangeTypeViewController];
}

@end
