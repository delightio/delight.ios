//
//  UIViewController+DLViewInfo.h
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (DLViewInfo)

- (void)DLviewDidAppear:(BOOL)animated;
- (void)DLviewWillDisappear:(BOOL)animated;

@end
