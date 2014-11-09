//
//  EraseTrash.m
//  EraseTrash
//
//  Created by Chad Armstrong on 5/14/07.
//  Copyright 2007 Edenwaith. All rights reserved.
//

#import "EraseTrash.h"


@implementation EraseTrash

- (id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo
{
	// Add your code here, returning the data to be passed to the next action.
	
	[[NSWorkspace sharedWorkspace] launchApplication:@"Permanent Eraser"];
	
	return input;
}

@end
