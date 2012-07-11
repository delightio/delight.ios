//
//  DLViewChange.h
//  Delight
//
//  Created by Chris Haugli on 7/10/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    DLViewChangeTypeViewController = 1,
    DLViewChangeTypeUser
} DLViewChangeType;

@interface DLViewChange : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) DLViewChangeType type;
@property (nonatomic, assign) NSTimeInterval timeInSession;

+ (id)viewChangeWithName:(NSString *)name type:(DLViewChangeType)type timeInSession:(NSTimeInterval)timeInSession;
+ (NSString *)stringForType:(DLViewChangeType)type;
- (id)initWithName:(NSString *)name type:(DLViewChangeType)type timeInSession:(NSTimeInterval)timeInSession;
- (NSDictionary *)dictionaryRepresentation;

@end
