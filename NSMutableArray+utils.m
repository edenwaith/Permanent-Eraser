//
//  NSMutableArray+utils.m
//  PermanentEraser
//
//  Created by Chad Armstrong on 7/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NSMutableArray+utils.h"


@implementation NSMutableArray(utils)

- (NSString *) pathAtIndex: (int) i
{
	return ([[self objectAtIndex: i] objectForKey: @"path"]);
}

@end
