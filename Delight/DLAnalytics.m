//
//  DLAnalytics.m
//  Delight
//
//  Created by Chris Haugli on 7/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLAnalytics.h"
#import "DLViewInfo.h"

@interface DLAnalytics ()
- (void)updateDictionariesForViewInfo:(DLViewInfo *)viewInfo;
@end

@implementation DLAnalytics {
    NSMutableArray *viewInfos;
    NSMutableDictionary *lastViewInfoForNameDict;
    NSMutableDictionary *lastViewInfoForTypeDict;
    
    NSMutableArray *events;
}

- (id)init
{
    self = [super init];
    if (self) {
        viewInfos = [[NSMutableArray alloc] init];
        lastViewInfoForNameDict = [[NSMutableDictionary alloc] init];
        lastViewInfoForTypeDict = [[NSMutableDictionary alloc] init];
        events = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [viewInfos release];
    [lastViewInfoForNameDict release];
    [lastViewInfoForTypeDict release];
    [events release];
    
    [super dealloc];
}

- (NSArray *)viewInfos
{
    return viewInfos;
}

- (NSArray *)events
{
    return events;
}

- (void)addViewInfo:(DLViewInfo *)viewInfo
{
    [viewInfos addObject:viewInfo];
    [self updateDictionariesForViewInfo:viewInfo];
}

- (void)insertViewInfo:(DLViewInfo *)viewInfo atIndex:(NSUInteger)index
{
    [viewInfos insertObject:viewInfo atIndex:index];
    [self updateDictionariesForViewInfo:viewInfo];
}

- (DLViewInfo *)lastViewInfoForName:(NSString *)name
{
    return [lastViewInfoForNameDict objectForKey:name];
}

- (DLViewInfo *)lastViewInfoForType:(DLViewInfoType)type
{
    return [lastViewInfoForTypeDict objectForKey:[NSNumber numberWithInt:type]];
}

- (void)addEvent:(DLEvent *)event
{
    [events addObject:event];
}

#pragma mark - Private methods

- (void)updateDictionariesForViewInfo:(DLViewInfo *)viewInfo
{
    [lastViewInfoForNameDict setObject:viewInfo forKey:viewInfo.name];
    [lastViewInfoForTypeDict setObject:viewInfo forKey:[NSNumber numberWithInt:viewInfo.type]];
}

@end
