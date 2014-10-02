//
//  Square.m
//  JavaScript Bridge
//
//  Created by John Sterling on 10/2/14.
//  Copyright (c) 2014 Volar Video. All rights reserved.
//

#import "Square.h"

@implementation Square

- (void)setColorRed:(NSNumber *)red green:(NSNumber *)green blue:(NSNumber *)blue
{
	self.backgroundColor = [UIColor colorWithRed:red.floatValue green:green.floatValue blue:blue.floatValue alpha:1.0f];
}

@end
