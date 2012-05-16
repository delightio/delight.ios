//
//  UITextField+DLPrivateView.h
//  Delight
//
//  Created by Chris Haugli on 5/15/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UITextField (DLPrivateView)

- (void)DLdidMoveToSuperview;
- (void)DLsetSecureTextEntry:(BOOL)secureTextEntry;
- (void)DLbecomeFirstResponder;
- (void)DLresignFirstResponder;

@end
