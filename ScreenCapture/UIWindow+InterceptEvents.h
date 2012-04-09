//
//  UIWindow+InterceptEvents.h
//  ipad
//
//  Created by Chris Haugli on 1/23/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol NBScreenCapturingWindowDelegate;

@interface UIWindow (InterceptEvents)

- (void)NBsetDelegate:(id<NBScreenCapturingWindowDelegate>)delegate;
- (void)NBsendEvent:(UIEvent *)event;

@end

@protocol NBScreenCapturingWindowDelegate <NSObject>
- (void)screenCapturingWindow:(UIWindow *)window sendEvent:(UIEvent *)event;
@end
