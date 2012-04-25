//
//  DLOrientationChange.h
//  Delight
//
//  Created by Chris Haugli on 4/24/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

/* 
  Represents a device orientation change.
 */
@interface DLOrientationChange : NSObject

@property (nonatomic, assign) UIDeviceOrientation deviceOrientation;
@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, assign) NSTimeInterval timeInSession;

- (id)initWithDeviceOrientation:(UIDeviceOrientation)aDeviceOrientation interfaceOrientation:(UIInterfaceOrientation)anInterfaceOrientation timeInSession:(NSTimeInterval)aTimeInSession;

@end