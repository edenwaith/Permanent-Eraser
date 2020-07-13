//
//  Erase.m
//  Erase
//
//  Created by Chad Armstrong on 5/11/07.
//  Copyright 2007 Edenwaith. All rights reserved.
//

#import "Erase.h"


@implementation Erase

- (id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo
{
	// NSEnumerator *enumerate = [input objectEnumerator];

	NSTask		*peTask		= [[NSTask alloc] init];
	NSString	*appPath	= nil;

	// Add your code here, returning the data to be passed to the next action.
	
	if ([[NSFileManager defaultManager] fileExistsAtPath: @"/Applications/Permanent Eraser.app"] == YES)
	{
		appPath = @"/Applications/Permanent Eraser.app/Contents/MacOS/Permanent Eraser";
	}
	else
	{
		appPath = [[[NSWorkspace sharedWorkspace] fullPathForApplication:@"Permanent Eraser"] stringByAppendingString:@"/Contents/MacOS/Permanent Eraser"];
	}
	
	[peTask setLaunchPath: appPath];
	[peTask setArguments:[NSArray arrayWithArray:input]];

	[peTask launch];
	
	// Should I release the peTask?
	
	return input;
}

@end
