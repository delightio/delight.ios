//
//  UIImage+DLAdditions.m
//  Delight
//
//  Created by Chris Haugli on 6/14/12.
//  Copyright (c) 2012 Pipely Inc. All rights reserved.
//

#import "UIImage+DLAdditions.h"

DL_MAKE_CATEGORIES_LOADABLE(UIImage_DLAdditions);

@implementation UIImage (DLAdditions)

- (UIImage *)scaledImageWithHeight:(CGFloat)newHeight
{
    if (self.size.height == 0.0) return self;
    
    CGFloat aspectRatio = self.size.width / self.size.height;
    CGSize newSize = CGSizeMake(aspectRatio * newHeight, newHeight);

    UIGraphicsBeginImageContext(newSize);
    [self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
