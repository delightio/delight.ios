//
//  UITextField+DLPrivateView.m
//  Delight
//
//  Created by Chris Haugli on 5/15/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UITextField+DLPrivateView.h"
#import "Delight.h"

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

@end
