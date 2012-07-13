//
//  UIViewController+DLViewSection.m
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UIViewController+DLViewSection.h"
#import "Delight_Private.h"

DL_MAKE_CATEGORIES_LOADABLE(UIViewController_DLViewSection);

@implementation UIViewController (DLViewSection)

- (void)DLviewDidAppear:(BOOL)animated
{
    [self DLviewDidAppear:animated];
    
    Delight *delight = [Delight sharedInstance];
    NSTimeInterval startTime = [delight.videoEncoder currentFrameTimeInterval];
    DLViewSection *sectionChange = [DLViewSection viewSectionWithName:NSStringFromClass([self class])
                                                              type:DLViewSectionTypeViewController
                                                         startTime:startTime];
    [delight.analytics addViewSection:sectionChange];
}

- (void)DLviewWillDisappear:(BOOL)animated
{
    [self DLviewWillDisappear:animated];
    
    // Set the end time for the view section
    Delight *delight = [Delight sharedInstance];
    DLViewSection *lastViewSection = [delight.analytics lastViewSectionForName:NSStringFromClass([self class])];
    if (lastViewSection) {
        lastViewSection.endTime = [delight.videoEncoder currentFrameTimeInterval];
    } else {
        // This view was initially displayed before analytics tracking began
        // Create the view change object now
        DLViewSection *viewSection = [DLViewSection viewSectionWithName:NSStringFromClass([self class])
                                                               type:DLViewSectionTypeViewController
                                                          startTime:0];
        viewSection.endTime = [delight.videoEncoder currentFrameTimeInterval];
        [delight.analytics insertViewSection:viewSection atIndex:0];
    }
}

@end
