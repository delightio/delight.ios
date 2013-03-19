//
//  Account.m
//  UIKitSample
//
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "Account.h"

@implementation Account

@synthesize name;
@synthesize email;
@synthesize password;

+ (id)accountWithName:(NSString *)name email:(NSString *)email password:(NSString *)password
{
    return [[[Account alloc] initWithName:name email:email password:password] autorelease];
}

- (id)initWithName:(NSString *)aName email:(NSString *)anEmail password:(NSString *)aPassword
{
    self = [super init];
    if (self) {
        self.name = aName;
        self.email = anEmail;
        self.password = aPassword;
    }
    return self;
}

- (NSDictionary *)dictionary
{
    return [NSDictionary dictionaryWithObjectsAndKeys:self.name, @"name", self.email,@"email", nil];
}

- (void)dealloc
{
    [name release];
    [email release];
    [password release];
    
    [super dealloc];
}

@end
