//
//  EraseFreespace.m
//  EraseFreespace
//
//  Created by Chad Armstrong on 9/27/17.
//  Copyright (c) 2017 Edenwaith, All Rights Reserved.
//

#import <OSAKit/OSAKit.h>
#import "EraseFreespace.h"

#ifndef NSAppKitVersionNumber10_6
	#define NSAppKitVersionNumber10_6 1038
#endif


@implementation EraseFreespace

- (id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo
{
	// Accept items of type public.volume or com.apple.cocoa.path
	NSString *erasingLevel = nil;
	NSString *diskPath = nil;
	
	if (input != nil && [input isKindOfClass:[NSArray class]] && [input count] > 0) 
	{
		diskPath = [input objectAtIndex: 0];
		
		if (diskPath == nil) 
		{
			NSString *errorMessage = @"Error: No disk path could be found.";
			*errorInfo = [self errorInfoWithMessage: errorMessage];
			
			return input;
		} 
		else if ([self isVolume: diskPath] == NO) 
		{
			NSString *errorMessage = [NSString stringWithFormat: @"Error: %@ is not an available volume.", diskPath];
			*errorInfo = [self errorInfoWithMessage: errorMessage];
			
			return input;
		}
	} 
	else 
	{
		NSString *errorMessage = @"Error: No valid input is available.";
		*errorInfo = [self errorInfoWithMessage: errorMessage];
		
		return input;
	}
	
	// Get the selected erasing level using key bindings
	NSNumber *fileErasingLevel = [[self parameters] objectForKey:@"fileErasingLevel"];
	
	if (fileErasingLevel != nil) 
	{
		erasingLevel = [fileErasingLevel stringValue];
		
		if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_6) {
			// If Leopard, the option cannot be 0 or 4, so change to 1 or 3
			if ([fileErasingLevel intValue] < 1)
			{	// Single-pass random-fill erase
				erasingLevel = @"1";
			}
			else if ([fileErasingLevel intValue] > 3)
			{	//  Gutmann algorithm 35-pass secure erase
				erasingLevel = @"3";
			}
		}
	}
	else 
	{
		NSString *errorMessage = @"Error: No file erasing level available.";
		*errorInfo = [self errorInfoWithMessage: errorMessage];
		
		return input;
	}
	
	task = [[NSTask alloc] init];
	NSArray *args = [NSArray arrayWithObjects:@"secureErase", @"freespace", erasingLevel, diskPath, nil];
	
	[task setLaunchPath:@"/usr/sbin/diskutil"];
	[task setArguments: args];
	
	// Create a new pipe
	outputPipe = [[NSPipe alloc] init];
	[task setStandardOutput: outputPipe];
	[task setStandardError: outputPipe];
	
	NSFileHandle *fileHandle = [outputPipe fileHandleForReading];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc removeObserver: self];
	
	// The following commented line is another method to detect and read the output from the running task
	// [nc addObserver: self selector:@selector(dataReady:) name: NSFileHandleReadCompletionNotification object:fileHandle];
	[nc addObserver: self selector:@selector(taskTerminated:) name:NSTaskDidTerminateNotification object:task];
	
	// Example: /usr/sbin/diskutil secureErase freespace 1 /Volumes/Kingston
	[task launch];
	// [fileHandle readInBackgroundAndNotify];

	[NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: fileHandle];
	
	return input;
}


- (void) outputData: (NSFileHandle *) fileHandle
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSData *data;
	
	while ([data=[fileHandle availableData] length])
	{
		NSString *dataString = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
		// If any output is ever provided for this Automator Action, this might be useful to display
		NSLog(@"dataString:: %@", [dataString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]);
		[dataString release];
	}
	
	[pool release];
	
	[NSThread exit];
	
}


- (void)taskTerminated:(NSNotification *)note {
	
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
 https://lists.apple.com/archives/automator-dev/2009/Sep/msg00000.html
 https://github.com/junecloud/Automator-Actions/blob/master/Download%20URL%20Pattern/Download%20URL%20Pattern/Download_URL_Pattern.m
 https://searchcode.com/codesearch/view/12386529/
 
 NSArray *objsArray = [NSArray arrayWithObjects:
 
 [NSNumber numberWithInt:errOSASystemError],
 
 [NSString stringWithFormat:@”ERROR:
 
 Could not make document from file: %@\n", xmlFile], nil];
 
 NSArray *keysArray = [NSArray arrayWithObjects:OSAScriptErrorNumber, OSAScriptErrorMessage, nil];
 
 *errorInfo = [NSDictionary dictionaryWithObjects:objsArray forKeys:keysArray];
 
 
 NSArray *objsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:errOSASystemError], @"Error: nothing passed to Folder Filter", nil];
 NSArray *keysArray = [NSArray arrayWithObjects:OSAScriptErrorNumber, OSAScriptErrorMessage, nil];
 *errorInfo = [NSDictionary dictionaryWithObjects:objsArray forKeys:keysArray];
 
 
 *errorInfo = @{
 OSAScriptErrorNumber: @(errOSASystemError),
 OSAScriptErrorMessage: errorString
 };
 */
- (NSDictionary *)errorInfoWithMessage: (NSString *)errorMessage {
	
	NSArray *objsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:errOSASystemError], errorMessage, nil];
	NSArray *keysArray = [NSArray arrayWithObjects:OSAScriptErrorNumber, OSAScriptErrorMessage, nil];
	
	return [NSDictionary dictionaryWithObjects:objsArray forKeys:keysArray];
}

#pragma mark - Unused Alternative Methods

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


/*
// This was example code used to parse the output when running diskutil
// If any output is provided for this Automator Action, this might be useful.
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
