//
//  DLAnalytics.h
//  Delight
//
//  Created by Chris Haugli on 7/12/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLViewSection.h"

@interface DLAnalytics : NSObject

@property (nonatomic, readonly) NSArray *viewSections;

- (void)addViewSection:(DLViewSection *)viewSection;
- (void)insertViewSection:(DLViewSection *)viewSection atIndex:(NSUInteger)index;
- (DLViewSection *)lastViewSectionForName:(NSString *)name;
- (DLViewSection *)lastViewSectionForType:(DLViewSectionType)type;

@end
