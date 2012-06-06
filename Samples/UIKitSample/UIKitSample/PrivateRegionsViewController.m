//
//  PrivateRegionsViewController.m
//  UIKitSample
//
//  Created by Bill So on 5/31/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "PrivateRegionsViewController.h"
#import <Delight/Delight.h>

@interface PrivateRegionsViewController ()

@end

@implementation PrivateRegionsViewController
@synthesize oneLabelPrivateView;
@synthesize twoLabelPrivateView;

//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
//{
//    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//    if (self) {
//        // Custom initialization
//    }
//    return self;
//}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	[Delight registerPrivateView:oneLabelPrivateView description:@"one"];
	[Delight registerPrivateView:twoLabelPrivateView description:@"two"];
	self.title = @"Private View Test";
}

- (void)viewDidUnload
{
    [self setOneLabelPrivateView:nil];
    [self setTwoLabelPrivateView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
    [oneLabelPrivateView release];
    [twoLabelPrivateView release];
    [super dealloc];
}

@end
