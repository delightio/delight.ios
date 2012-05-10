//
//  AppDelegate.m
//  UIKitSample
//
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "AccountsViewController.h"
#import <Delight/Delight.h>

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;

- (void)dealloc
{
    [window release];
    [navigationController release];
    
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    
    AccountsViewController *accountsViewController = [[AccountsViewController alloc] initWithStyle:UITableViewStylePlain];
    navigationController = [[UINavigationController alloc] initWithRootViewController:accountsViewController];
    [accountsViewController release];
    
    window.rootViewController = navigationController;
    [window makeKeyAndVisible];

//    [Delight startWithAppToken:@"Get your token at http://delight.io"];
    
    [Delight setSavesToPhotoAlbum:YES];
    [Delight startWithAppToken:@"aad181ca9524c95082a231714"];

    return YES;
}

@end
