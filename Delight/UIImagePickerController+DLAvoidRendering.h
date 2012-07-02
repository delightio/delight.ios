//
//  UIImagePickerController+DLAvoidRendering.h
//  Delight
//
//  Created by Chris Haugli on 7/2/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImagePickerController (DLAvoidRendering)

- (void)DLviewWillAppear:(BOOL)animated;
- (void)DLviewDidDisappear:(BOOL)animated;

@end
