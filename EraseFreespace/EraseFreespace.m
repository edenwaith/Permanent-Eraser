//
//  EraseFreespace.m
//  EraseFreespace
//
//  Created by Chad Armstrong on 9/27/17.
//  Copyright (c) 2017 Edenwaith, All Rights Reserved.
//

#import "EraseFreespace.h"


@implementation EraseFreespace

- (id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo
{
	// Accept items of type public.volume or com.apple.cocoa.path
	
	// TODO: Check if the item is a mounted volume
	// NSString *firstPath = [input objectAtIndex: 0]; // Need to verify there is a first object
	
	// Get the selected erasing level using key bindings
	
	// Add your code here, returning the data to be passed to the next action.
	
	task = [[NSTask alloc] init];
	
	NSString *erasingLevel = @"1";
	NSString *diskPath = @"/Volumes/Kingston";
	NSArray *args = [NSArray arrayWithObjects:@"secureErase", @"freespace", erasingLevel, diskPath, nil]; 
	
	
	id obj = [[self parameters] objectForKey:@"fileErasingLevel"];
	
	NSLog(@"parameters: %@", [self parameters]);
	
	if (obj != nil) {
		NSLog(@"obj: %@", NSStringFromClass([obj class]));
	}
	
	
	if ([self isVolume: diskPath] == NO) {
		NSLog(@"%@ is not an available volume.", diskPath);
		// TODO: Set up errorInfo dictionary
		return input;
	}
	
	
	[task setLaunchPath:@"/usr/sbin/diskutil"];
	[task setArguments: args];
	
	// Create a new pipe
	outputPipe = [[NSPipe alloc] init];
	[task setStandardOutput: outputPipe];
	
	NSFileHandle *fileHandle = [outputPipe fileHandleForReading];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc removeObserver: self];
	
	[nc addObserver: self selector:@selector(dataReady:) name: NSFileHandleReadCompletionNotification object:fileHandle];
	[nc addObserver: self selector:@selector(taskTerminated:) name:NSTaskDidTerminateNotification object:task];
	
	[task launch];
	[fileHandle readInBackgroundAndNotify];
	
	return input;
}

- (void)appendData: (NSData*)data {
	// do stuff
	NSString *s = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
	NSLog(@"appendData:: %@", s);
	// ...
}

- (void)dataReady:(NSNotification *)notification {
	
	NSData *data = [[notification userInfo] valueForKey: NSFileHandleNotificationDataItem];
	
	NSLog(@"dataReady: %d bytes", [data length]);
	
	if ([data length]) {
		[self appendData: data];
	}
	
	// If the task is running, start reading again
	if ([task isRunning]) {
		[[outputPipe fileHandleForReading] readInBackgroundAndNotify];
	}
}

- (void)taskTerminated:(NSNotification *)note {
	NSLog(@"taskTerminated:");
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[outputPipe release];
	outputPipe = nil;
	
	[task release];
	task = nil;
}

- (BOOL)isVolume: (NSString *) volumePath
{
	BOOL isPathVolume = NO;
	NSArray * volumesList = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	
	if ([volumesList containsObject:volumePath] == YES)
	{
		isPathVolume = YES;
	}
	else
	{
		isPathVolume = NO;
	}
	
	return (isPathVolume);
}

/*
- (void)parseData:(NSNotification *)notification {
	NSCharacterSet* nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
	// NSString *percentageString = @"[ | 0%..10%..20%..30%.................................... ]";
	NSArray *percentageArray = [NSArray arrayWithObjects: 
								@"Creating a temporary file", 
								@"[ / 0%................................................... ] ",
								@"[ / 0%..10%.............................................. ] ",
								@"[ | 0%..10%..20%..30%.................................... ] ",
								@"[ - 0%..10%..20%..30%..40%..50%.......................... ] 59% 0:00:11 ",
								@"Creating a secondary temporary file", 
								@"[ | 0%..10%..20%..30%..40%..50%..60%..70%..80%........... ] 83% 0:00:08 ",
								@"[ - 0%..10%..20%..30%..40%..50%..60%..70%..80%..90%...... ] 98% 0:00:06 ", nil];
	
	
	for (NSString *percentageString in percentageArray) {
		
		NSArray *percentageComponents = [percentageString componentsSeparatedByString: @"%"];
		// NSLog(@"percentageComponents: %@", percentageComponents);
		
		int percentageComponentsCount = [percentageComponents count];
		
		if (percentageComponentsCount >= 2) {
			
			NSString *component = [percentageComponents objectAtIndex: percentageComponentsCount-2];
			NSString *strippedComponent = [component  stringByTrimmingCharactersInSet:nonDigits];
			// NSLog(@"Length of strippedComponent: %lu", [strippedComponent length]);
			if ([strippedComponent length] > 0) {
				int num = [[component  stringByTrimmingCharactersInSet:nonDigits] intValue];
				NSLog(@"Num: %d", num);
			}
		} else {
			NSLog(@"percentageComponentsCount: %d | %@", percentageComponentsCount, percentageComponents);
			if ([percentageComponents count] > 0) {
				NSString *component = [percentageComponents objectAtIndex: 0];
				if ([component rangeOfString:@"%"].location == NSNotFound) {
					NSLog(@"No percent sign found in %@", component);
				}
			}
		}
	}
}
*/

@end
