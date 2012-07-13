//
//  DLViewSection.h
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    DLViewSectionTypeViewController = 1,
    DLViewSectionTypeUser
} DLViewSectionType;

@interface DLViewSection : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) DLViewSectionType type;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval endTime;

+ (id)viewSectionWithName:(NSString *)name type:(DLViewSectionType)type startTime:(NSTimeInterval)startTime;
+ (NSString *)stringForType:(DLViewSectionType)type;
- (id)initWithName:(NSString *)name type:(DLViewSectionType)type startTime:(NSTimeInterval)startTime;
- (NSDictionary *)dictionaryRepresentation;

@end
