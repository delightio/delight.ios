//
//  DLAnalytics.h
//  Delight
//
//  Created by Chris Haugli on 7/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLViewInfo.h"
#import "DLEvent.h"

@interface DLAnalytics : NSObject

@property (nonatomic, readonly) NSArray *viewInfos;
@property (nonatomic, readonly) NSArray *events;

- (void)addViewInfo:(DLViewInfo *)viewInfo;
- (void)insertViewInfo:(DLViewInfo *)viewInfo atIndex:(NSUInteger)index;
- (DLViewInfo *)lastViewInfoForName:(NSString *)name;
- (DLViewInfo *)lastViewInfoForType:(DLViewInfoType)type;
- (void)addEvent:(DLEvent *)event;

@end
