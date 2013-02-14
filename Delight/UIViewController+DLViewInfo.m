//
//  UIViewController+DLViewInfo.m
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UIViewController+DLViewInfo.h"
#import "Delight_Internal.h"

DL_MAKE_CATEGORIES_LOADABLE(UIViewController_DLViewInfo);

@implementation UIViewController (DLViewInfo)

- (void)DLviewDidAppear:(BOOL)animated
{
    [self DLviewDidAppear:animated];
    
    Delight *delight = [Delight sharedInstance];
    NSTimeInterval startTime = [delight.videoEncoder currentFrameTimeInterval];
    DLViewInfo *sectionChange = [DLViewInfo viewInfoWithName:NSStringFromClass([self class])
                                                              type:DLViewInfoTypeViewController
                                                         startTime:startTime];
    [delight.analytics addViewInfo:sectionChange];
}

- (void)DLviewWillDisappear:(BOOL)animated
{
    [self DLviewWillDisappear:animated];
    
    // Set the end time for the view section
    Delight *delight = [Delight sharedInstance];
    DLViewInfo *lastViewInfo = [delight.analytics lastViewInfoForName:NSStringFromClass([self class])];
    if (lastViewInfo) {
        lastViewInfo.endTime = [delight.videoEncoder currentFrameTimeInterval];
    } else {
        // This view was initially displayed before analytics tracking began
        // Create the view change object now
        DLViewInfo *viewInfo = [DLViewInfo viewInfoWithName:NSStringFromClass([self class])
                                                               type:DLViewInfoTypeViewController
                                                          startTime:0];
        viewInfo.endTime = [delight.videoEncoder currentFrameTimeInterval];
        [delight.analytics insertViewInfo:viewInfo atIndex:0];
    }
}

@end
