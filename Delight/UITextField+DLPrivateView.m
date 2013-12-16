//
//  UITextField+DLPrivateView.m
//  Delight
//
//  Created by Chris Haugli on 5/15/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UITextField+DLPrivateView.h"
#import "Delight.h"
#import <objc/runtime.h>

DL_MAKE_CATEGORIES_LOADABLE(UITextField_DLPrivateView);

@implementation UITextField (DLPrivateView)

- (void)DLdidMoveToSuperview
{
    [self DLdidMoveToSuperview];
    
    // Automatically register secure UITextFields as private views
    if (self.secureTextEntry) {
        if (self.superview) {
            [Delight registerPrivateView:self description:nil];
        } else {
            [Delight unregisterPrivateView:self];
        }
    }
}

- (void)DLsetSecureTextEntry:(BOOL)secureTextEntry
{
    [self DLsetSecureTextEntry:secureTextEntry];

    // Automatically register secure UITextFields as private views
    if (self.superview) {
        if (secureTextEntry) {
            [Delight registerPrivateView:self description:@""];
        } else {
            [Delight unregisterPrivateView:self];
        }
    }
}

- (void)DLbecomeFirstResponder
{
    if (self.secureTextEntry && ![Delight hidesKeyboardInRecording]) {
        // Remember whether the keyboard was hidden
        objc_setAssociatedObject(self, "DLHidKeyboardInRecording", [NSNumber numberWithBool:[Delight hidesKeyboardInRecording]], OBJC_ASSOCIATION_RETAIN);
        [Delight setHidesKeyboardInRecording:YES];        
    }    
    
    [self DLbecomeFirstResponder];
}

- (void)DLresignFirstResponder
{
    if (self.secureTextEntry) {
        // Restore previous hide-keyboard state
        NSNumber *hidKeyboardInRecording = objc_getAssociatedObject(self, "DLHidKeyboardInRecording");
        if (hidKeyboardInRecording) {
            [Delight setHidesKeyboardInRecording:[hidKeyboardInRecording boolValue]];
            objc_setAssociatedObject(self, "DLHidKeyboardInRecording", nil, OBJC_ASSOCIATION_RETAIN);
        }
    }    
    
    [self DLresignFirstResponder];
}

@end
