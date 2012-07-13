//
//  DLAnalytics.m
//  Delight
//
//  Created by Chris Haugli on 7/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLAnalytics.h"
#import "DLViewSection.h"

@interface DLAnalytics ()
- (void)updateDictionariesForViewSection:(DLViewSection *)viewSection;
@end

@implementation DLAnalytics {
    NSMutableArray *viewSections;
    NSMutableDictionary *lastViewSectionForNameDict;
    NSMutableDictionary *lastViewSectionForTypeDict;
}

- (id)init
{
    self = [super init];
    if (self) {
        viewSections = [[NSMutableArray alloc] init];
        lastViewSectionForNameDict = [[NSMutableDictionary alloc] init];
        lastViewSectionForTypeDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [viewSections release];
    [lastViewSectionForNameDict release];
    [lastViewSectionForTypeDict release];
    
    [super dealloc];
}

- (NSArray *)viewSections
{
    return viewSections;
}

- (void)addViewSection:(DLViewSection *)viewSection
{
    [viewSections addObject:viewSection];
    [self updateDictionariesForViewSection:viewSection];
}

- (void)insertViewSection:(DLViewSection *)viewSection atIndex:(NSUInteger)index
{
    [viewSections insertObject:viewSection atIndex:index];
    [self updateDictionariesForViewSection:viewSection];
}

- (DLViewSection *)lastViewSectionForName:(NSString *)name
{
    return [lastViewSectionForNameDict objectForKey:name];
}

- (DLViewSection *)lastViewSectionForType:(DLViewSectionType)type
{
    return [lastViewSectionForTypeDict objectForKey:[NSNumber numberWithInt:type]];
}

#pragma mark - Private methods

- (void)updateDictionariesForViewSection:(DLViewSection *)viewSection
{
    [lastViewSectionForNameDict setObject:viewSection forKey:viewSection.name];
    [lastViewSectionForTypeDict setObject:viewSection forKey:[NSNumber numberWithInt:viewSection.type]];
}

@end
