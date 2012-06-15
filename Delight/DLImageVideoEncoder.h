//
//  DLImageVideoEncoder.h
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "DLVideoEncoder.h"

@interface DLImageVideoEncoder : DLVideoEncoder

- (void)encodeImage:(UIImage *)frameImage;

@end
