//
//  DLViewInfo.h
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    DLViewInfoTypeViewController = 1,
    DLViewInfoTypeUser
} DLViewInfoType;

@interface DLViewInfo : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) DLViewInfoType type;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval endTime;

+ (id)viewInfoWithName:(NSString *)name type:(DLViewInfoType)type startTime:(NSTimeInterval)startTime;
+ (NSString *)stringForType:(DLViewInfoType)type;
- (id)initWithName:(NSString *)name type:(DLViewInfoType)type startTime:(NSTimeInterval)startTime;
- (NSDictionary *)dictionaryRepresentation;

@end
