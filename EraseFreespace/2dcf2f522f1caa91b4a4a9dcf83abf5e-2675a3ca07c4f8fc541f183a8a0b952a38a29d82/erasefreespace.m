/*
 *	erasefreespace.m
 *	Description: Parse a string for the percentage of freespace erased
 * 	Author: Chad Armstrong
 *	Date: 3 October 2017
 *	To compile: gcc -framework Foundation erasefreespace.m -o erasefreespace
 */

#import <Foundation/Foundation.h>

/*
Creating a temporary file
Securely erasing a file
[ / 0%................................................... ] 


Creating a temporary file
Securely erasing a file
[ / 0%..10%.............................................. ] 

Creating a temporary file
Securely erasing a file
[ | 0%..10%..20%..30%.................................... ] 

Creating a temporary file
Securely erasing a file
[ - 0%..10%..20%..30%..40%..50%.......................... ] 59% 0:00:11 


Creating a temporary file
Securely erasing a file
[ / 0%..10%..20%.

Creating a temporary file
Securely erasing a file
Creating a secondary temporary file
[ | 0%..10%..20%..30%..40%..50%..60%..70%..80%........... ] 83% 0:00:08 



[ - 0%..10%..20%..30%..40%..50%..60%..70%..80%..90%...... ] 98% 0:00:06 


*/

NSTask *task;
NSPipe *outputPipe;

/*
- (IBAction)startStopPing:(id)sender {
	// Is the task running?
	if (task) {
		[task interrupt];
	} else {
		task = [[NSTask alloc] init];
		[task setLaunchPath: @"/sbin/ping"];
		NSArray *args = [NSArray arrayWithObjects: @"-c10", [hostField stringValue], nil];
		[task setArguments: args];
		
		// Release the old pipe
		[pipe release];
		// Create a new pipe
		pipe = [[NSPipe alloc] init];
		[task setStandardOutput: pipe];
		
		NSFileHandle *fh = [ppipe fileHandleForReading];
		
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		
		[nc removeObserver: self];
		
		[nc addObserver: self selector:@selector(dataReady:) name: NSFileHandleReadCompletionNotification object:fh];
		[nc addObserver: self selector:@selector(taskTerminated:) name:NSTaskDidTerminateNotification object:task];
		[task launch];
		[fh readInBackgroundAndNotify];
	}
}
*/

- (void)appendData: (NSData*)d {
	// do stuff
	NSString *s = [[NSString alloc] initWithData:d encoding: NSUTF8StringEncoding];
	NSLog(@"appendData:: %@", s);
	// ...
}

- (void)dataReady:(NSNotification *)n {
	NSData *d;
	d = [[n userInfo] valueForKey: NSFileHandleNotificationDataItem];
	
	NSLog(@"dataReady: %d bytes", [d length]);
	
	if ([d length]) {
		[self appendData: d];
	}
	
	// If the task is running, start reading again
	if (task) {
		[[outputPipe fileHandlForReading] readInBackgroundAndNotify];
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


int main (int argc, const char * argv[]) 
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	task = [[NSTask alloc] init];
	
	NSString *erasingLevel = @"1";
	NSString *diskPath = @"/Volumes/Kingston";
	NSArray *args = [NSArray arrayWithObjects:@"secureErase", @"freespace", erasingLevel, diskPath, nil]; 
	
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

	
	[pool drain];
	return 0;
}

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