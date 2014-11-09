//  PEController.m
//  PermanentEraser
//
//  Created by Chad Armstrong on Mon Jun 02 2003.
//  Copyright (c) 2003-2007 Edenwaith. All rights reserved.
//

// How to add a badge using Cocoa
// http://www.cocoabuilder.com/archive/message/cocoa/2004/2/3/95988

// How to add a Hot Key using Cocoa
// http://www.unsanity.org/archives/2002_10.php

// Description of the Mac OS X version of statfs
// http://developer.apple.com/documentation/Darwin/Reference/Manpages/man2/statfs.2.html

// Erasing free space examples

// EXAMPLE 1
// nice -n 20 dd bs=50m if=/dev/random of=/tmp/$UID/temp.$$ count=1
// nice -n 20 srm -z /tmp/$UID/temp.$$
//
//	EXAMPLE 2
//	#!/bin/sh
//
//	set +e +u
//	dd if=/dev/urandom of=/tmp/_shred_free_space
//	sync; sync
//	srm /tmp/_shred_free_space
//	sync; sync

// Time Machine Utility: http://fernlightning.com/doku.php?id=software:misc:tms

// Erase a CD-RW:  hdiutil burn (-erase|-fullerase) -device (something or another...check into this)
// Also check out: drutil erase (quick | full)
// Also: diskutil eraseOptical [quick] device
// diskutil eraseOptical /dev/disk3
// diskutil also has other options, such as zeroDisk, randomDisk, etc.
// diskutil secureErase [freespace] level device
// The diskutil tip taken from the Erase Selected Disc AppleScript
// diskutil list -- lists out available discs & partitions


#import "PEController.h"
#import "NSEvent+ModifierKeys.h"
#import "NSMutableArray+utils.h"


@implementation PEController


// =========================================================================
// (void) init
// -------------------------------------------------------------------------
// Initialize variables and set up notifications.
// -------------------------------------------------------------------------
// Created: 2. June 2003 14:20
// Version: 12 June 2008 22:25
// =========================================================================
- (id) init 
{
    self = [super init];

    fm					= [NSFileManager defaultManager];
    trash_files			= [[NSMutableArray alloc] init];
    pEraser				= nil; 		// initialize the NSTask
    files_were_dropped 	= NO;
    uid					= [[NSString alloc] initWithFormat:@"%d", getuid()];
 	originalIcon		= [NSImage imageNamed:@"PE"]; 
	end_angle			= 90.0;
	lastPercentageCD	= 0;
	totalFilesSize		= 0;
	
	firstTimeHere		= YES;
	wasCanceled			= NO;
	beepBeforeTerminating = YES;
	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	   
    [[NSNotificationCenter defaultCenter] addObserver:self 
            selector:@selector(doneErasing:) 
            name:NSTaskDidTerminateNotification 
            object:nil];

	// If the ALT/Option key is pressed when PE is launched, do not show
	// the warning dialog.  This is similar to holding down the Option
	// key when selecting the Empty Trash menu from Finder.
	if ([NSEvent isOptionKeyDown] == YES)
	{
		warnBeforeErasing = NO;
	}
	else
	{
		warnBeforeErasing = YES;
	}
 
    return self;
}


// =========================================================================
// (void) dealloc
// -------------------------------------------------------------------------
// Clean up after the program by deallocing space and unnotifying notifications
// -------------------------------------------------------------------------
// Created: 2. June 2003 14:20
// Version: 14. November 2004
// =========================================================================
- (void) dealloc 
{
    pEraser = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSTaskDidTerminateNotification object: nil];
        
	[pipe dealloc];
    [pEraser dealloc];
    [uid dealloc];
    [trash_files dealloc];
    [super dealloc];
}


// =========================================================================
// (void) appWillTerminateNotification: (NSNotification *)aNotification 
// -------------------------------------------------------------------------
// Call this when the application is quitting.  Clean up the app icon
// so the badge doesn't remain.
// -------------------------------------------------------------------------
// Created: 24 October 2005 20:57
// Version: 11 March 2007
// =========================================================================
- (void) appWillTerminateNotification: (NSNotification *)aNotification 
{
	NSImage *icon = [NSImage imageNamed:@"PE"];

	[NSApp setApplicationIconImage:icon];	
}


// =========================================================================
// (void) awakeFromNib
// -------------------------------------------------------------------------
// Brings focus to the window.  Otherwise, it is greyed out when running.
// -------------------------------------------------------------------------
// Created: 2. June 2003 14:20
// Version: 1 November 2008 21:55
// =========================================================================
- (void) awakeFromNib 
{
//    [theWindow makeKeyAndOrderFront:self];
	[theWindow setBackgroundColor:[NSColor colorWithCalibratedRed: 0.909 green: 0.909 blue: 0.909 alpha:1.0]];
//	[theWindow setBackgroundColor:[NSColor colorWithCalibratedRed: 0.22 green: 0.22 blue: 0.22 alpha:1.0]];
	[theWindow display];  // redraw the window to display the white background.
	[theWindow center];	// center the window on the screen
	[erasing_msg setStringValue:NSLocalizedString(@"PreparingMessage", nil)];
	
	// Use a spinning indeterminate progress meter when retrieving the list of files
	[indicator setIndeterminate: YES];
	[indicator setUsesThreadedAnimation:YES];
    [indicator startAnimation: self];

	// retrieve preference value for warnBeforeErasing
	// defaults write com.edenwaith.permanenteraser WarnBeforeErasing -bool NO
	// defaults write com.edenwaith.permanenteraser WarnBeforeErasing -bool YES
	if (warnBeforeErasing != NO)
	{
		if ([prefs objectForKey:@"WarnBeforeErasing"] != nil)
		{
			if ([prefs boolForKey:@"WarnBeforeErasing"] == YES)
			{
				warnBeforeErasing = YES;
			}
			else
			{
				warnBeforeErasing = NO;
			}
		}
		else
		{
			warnBeforeErasing = YES;
			// [prefs setBool:NO forKey: @"WarnBeforeErasing"];
		}
	}
	
	
	if ([prefs objectForKey:@"BeepBeforeTerminating"] != nil)
	{
		if ([prefs boolForKey:@"BeepBeforeTerminating"] == YES)
		{
			beepBeforeTerminating = YES;
		}
		else
		{
			beepBeforeTerminating = NO;
		}
	}
	else
	{
		beepBeforeTerminating = YES;
	}
	
	
	if ([prefs objectForKey: @"DiscErasingLevel"] != nil)
    {
		discErasingLevel = [[NSMutableString alloc] initWithString:[prefs objectForKey: @"DiscErasingLevel"]];
    }
	else
	{
		discErasingLevel = [[NSMutableString alloc] initWithString:@"Complete"];
	}
	
	if ([prefs objectForKey: @"FileErasingLevel"] != nil)
    {
		fileErasingLevel = [[NSMutableString alloc] initWithString:[prefs objectForKey: @"FileErasingLevel"]];
    }
	else
	{
		// Assign a default fileErasingLevel
	}
	
}


// =========================================================================
// (void) applicationDidFinishLaunching: (NSNotification *)
// -------------------------------------------------------------------------
// Need to make the PEController a delegate of the File Owner
// -------------------------------------------------------------------------
// Created: 2. June 2003
// Version: 20 August 2007 22:00
// =========================================================================
- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    if (files_were_dropped == YES)
    {
        [self erase];
    }
    else // Search for files in .Trash and .Trashes
    {
        BOOL isDir;
        id object = nil;
        int j = 0;
        NSMutableString *currentDirectory = [[NSMutableString alloc] init];
        NSDirectoryEnumerator *enumerator;
        
        NSArray *volumes = [[NSArray alloc] initWithArray: [fm directoryContentsAtPath: @"/Volumes"]];
        
        for (j = 0; j < [volumes count]; j++)
        {
            // Check to see if the .Trashes exist, and if so, get the contents
            // of the .Trashes and add them to trash_files (full path)
            [currentDirectory setString: [[[@"/Volumes/" stringByAppendingPathComponent: [volumes objectAtIndex: j]]  
                                        stringByAppendingPathComponent: @".Trashes"]
                                        stringByAppendingPathComponent: uid]];
                                        
            if ( [fm fileExistsAtPath: currentDirectory isDirectory:&isDir] && isDir )
            {
                enumerator = [fm enumeratorAtPath: currentDirectory];
                
                while (object = [enumerator nextObject])
                {
					
                    // check for bundled files, i.e. .app, .rtfd, etc.
                    if ( [fm fileExistsAtPath: [currentDirectory stringByAppendingPathComponent: object] isDirectory:&isDir] && isDir &&
                        [[NSWorkspace sharedWorkspace] isFilePackageAtPath: [currentDirectory stringByAppendingPathComponent: object]] )
                    {
						totalFilesSize += [self fileSize: [currentDirectory stringByAppendingPathComponent: object]];
                        [trash_files insertObject: [currentDirectory stringByAppendingPathComponent: object] atIndex:0]; 
                        [enumerator skipDescendents];
                    }
                    else
                    {
						totalFilesSize += [self fileSize: [currentDirectory stringByAppendingPathComponent: object]];
                        // this will reverse the array so a directory will be erased last after it is empty
                        [trash_files insertObject: [currentDirectory stringByAppendingPathComponent: object] atIndex:0];
                    }
                }
            }            
        }
        
        // Get the files in the home account's Trash
        enumerator = [fm enumeratorAtPath:[@"~/.Trash/" stringByExpandingTildeInPath]];
        
        while(object = [enumerator nextObject])
        {
            // check for bundled files, i.e. .app, .rtfd, etc.
            if ( [fm fileExistsAtPath: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object] isDirectory:&isDir] && isDir &&
                 [[NSWorkspace sharedWorkspace] isFilePackageAtPath: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object]] == YES )
            {
				// Generate a dictionary and insert that into the trash_files array
				totalFilesSize += [self fileSize: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object]];
                [trash_files insertObject: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object] atIndex:0]; 
                [enumerator skipDescendents];	
            }
            else
            {
				// Generate a dictionary and insert that into the trash_files array
				totalFilesSize += [self fileSize: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object]];
                // this will reverse the array so a directory will be erased last after it's empty
                [trash_files insertObject: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object] atIndex:0];
            }

        }
        
        [volumes dealloc];
        [currentDirectory dealloc];
		
        [self erase];
    }
}


// =========================================================================
// (void) application:(NSApplication*) openFile:
// -------------------------------------------------------------------------
// This method is only called when a file is dragged-n-dropped onto the
// PE icon.  The timer is called to add each of the new files.
// -------------------------------------------------------------------------
// Created: 21. April 2004 
// Version: 20 August 2007 21:25
// =========================================================================
- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    BOOL isDir;
	BOOL isDir2;
    id object = nil;
    files_were_dropped = YES;
	NSMutableDictionary *fileDict = [NSMutableDictionary dictionary];;

	// Set this up to identify only burnable discs
	if ([self isVolume: filename] == YES && [self isErasableDisc: filename])
	{
		[trash_files insertObject: filename atIndex: 0];
		totalFilesSize += [self fileSize: filename];
	}
	else if ( [fm fileExistsAtPath: filename isDirectory:&isDir] && isDir &&
         [[NSWorkspace sharedWorkspace] isFilePackageAtPath: filename] == NO )
    {
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: filename];
		
        [trash_files insertObject: filename atIndex: 0]; // add the directory name
        
        while (object = [enumerator nextObject])
        {
			if ( [fm fileExistsAtPath: [filename stringByAppendingPathComponent: object] isDirectory:&isDir2] && isDir2 &&
                 [[NSWorkspace sharedWorkspace] isFilePackageAtPath: [filename stringByAppendingPathComponent: object]] == YES )
            {
                // [trash_files insertObject: [filename stringByAppendingPathComponent: object] atIndex:0];
                [enumerator skipDescendents];
				totalFilesSize += [self fileSize: [filename stringByAppendingPathComponent: object]];
            }
            else
            {
				/*
				fileDict = [NSDictionary dictionaryWithObjectsAndKeys:
							filename, @"path",
							[self fileSize:filename], @"size",
							nil];
				 */
				[fileDict setObject: filename forKey: @"path"];
				[fileDict setObject: [NSNumber numberWithInt: [self fileSize:filename]] forKey: @"size"];
                // this will reverse the array so a directory will be erased last after it's empty
//                [trash_files insertObject: [filename stringByAppendingPathComponent: object] atIndex:0];
				[trash_files insertObject: fileDict atIndex: 0];
				totalFilesSize += [self fileSize: [filename stringByAppendingPathComponent: object]];
            }
            
        }

    }
    else
    {
		/*
		fileDict = [NSDictionary dictionaryWithObjectsAndKeys:
					filename, @"path",
					[self fileSize: filename], @"size",
					nil];
		*/
		[fileDict setObject: filename forKey: @"path"];
		[fileDict setObject: [NSNumber numberWithUnsignedLongLong: [self fileSize:filename]] forKey: @"size"];
		
		unsigned long long fooblat = 3;
		NSLog(@"The File size is %llu", [self fileSize: filename]);
        [trash_files insertObject: fileDict atIndex: 0];
		//totalFilesSize += [self fileSize: [filename stringByAppendingPathComponent: object]];  // No idea why it references "object" here
		totalFilesSize += [self fileSize: filename];
    }
    
    if (!timer)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval:0.0
                         target: self
                         selector: @selector(addNewFiles:)
                         userInfo: nil
                         repeats: YES];
    }

    return NO;
}

// =========================================================================
// (int) fileSize: (NSString *) path
// -------------------------------------------------------------------------
// Created: 8 August 2007 20:59
// Version: 3 November 2008 20:28
// =========================================================================
- (unsigned long long) fileSize: (NSString *) path
{
//	FSRef           fsRef;
//	FSCatalogInfo   fsInfo;
//	BOOL			isDir;
	
	NSDictionary *fileAttributes = [fm fileAttributesAtPath:[path stringByAppendingPathExtension:@"/..namedfork/rsrc/"] traverseLink:NO];

	/*
	if(FSPathMakeRef((unsigned char *) [path fileSystemRepresentation], &fsRef, NULL) == noErr) 
	{
		if(FSGetCatalogInfo(&fsRef, kFSCatInfoRsrcSizes, &fsInfo, NULL, NULL, NULL) == noErr)
		{
			if (fsInfo.rsrcLogicalSize > 0)
			{
				return (fsInfo.dataLogicalSize + fsInfo.rsrcLogicalSize);
			}
			else
			{
				return (fsInfo.dataLogicalSize);
			}
		}
	}
	else
	{
		return (0);
	}
	*/
	
	return (long long)([[fileAttributes objectForKey:NSFileSize] intValue]);
}

// =========================================================================
// (void) addNewFiles : (NSTimer *) aTimer
// -------------------------------------------------------------------------
// Add new files to the list of files that were dragged-n-dropped on the icon
// -------------------------------------------------------------------------
// Created: 30. March 2004 23:52
// Version: 30. March 2004 23:52
// =========================================================================
- (void) addNewFiles : (NSTimer *) aTimer
{
    [aTimer invalidate];
    timer = nil;
}


// =========================================================================
// (void) erase: 
// -------------------------------------------------------------------------
// NSFileManager: http://developer.apple.com/documentation/Cocoa/Reference/Foundation/Classes/NSFileManager_Class/Reference/Reference.html
// NSDirectoryEnumerator: http://developer.apple.com/documentation/Cocoa/Reference/Foundation/Classes/NSDirectoryEnumerator_Class/Reference/Reference.html
// -------------------------------------------------------------------------
// Unfortunately, all of the files in the Trash couldn't be erased at once.
// This error occurred: /bin/rm: /Users/admin/.Trash/*: No such file or directory
// [pEraser setArguments: [NSArray arrayWithObjects: @"-P", @"-r", [@"~/.Trash/*" stringByExpandingTildeInPath], nil]];
// -------------------------------------------------------------------------    
// Created: 2. June 2003 14:20
// Version: 1 November 2008 22:08
// =========================================================================
- (void) erase
{
	int number_of_real_files = 0;
	int j = 0;
    idx = 0;
    num_files = 0;
	
    num_files = [trash_files count];
		
	// If srm already exists, use that version, which will help comply as 
	// a Universal Binary to use the PPC or Intel version of srm
	if ([fm isExecutableFileAtPath: @"/usr/bin/srm"] == YES)
	{
		util_path = @"/usr/bin/srm";
	}
	else
	{
		util_path  = [[NSBundle mainBundle] pathForResource:@"srm" ofType:@""];
	}

	
	// Count the number of files to delete
	for (j = 0; j < num_files; j++)
	{
		if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: [trash_files pathAtIndex: j]] == YES ) // if this file is a package, find the number of files contained within
		{
			// enumerate the package
			NSDirectoryEnumerator *package_enumerator;
			id object = nil;
			BOOL isDir;
			
			package_enumerator = [fm enumeratorAtPath: [trash_files objectAtIndex: j]];
			
			while (object = [package_enumerator nextObject])
			{
				totalFilesSize += [self fileSize: [[trash_files objectAtIndex: j] stringByAppendingPathComponent: object]];
				// Need to check if a file is a directory or not...if so, don't count it!
				if ([fm fileExistsAtPath: [ [trash_files objectAtIndex: j] stringByAppendingPathComponent: object] isDirectory:&isDir] && isDir == NO)
				{
				
					if ([self containsResourceFork: [trash_files objectAtIndex: j]] == YES)
					{
						number_of_real_files+=2;
					}
					else
					{
						number_of_real_files++;
					}
				}
			}
		}
		else
		{
			if ([self containsResourceFork: [trash_files pathAtIndex: j]] == YES)
			{
				number_of_real_files+=2;
			}
			else
			{
				number_of_real_files++;
			}
		}
	}
	
    [indicator setMaxValue: number_of_real_files*100];
    
	[indicator setIndeterminate: NO];
    [indicator stopAnimation: self];
	[erasing_msg setStringValue:NSLocalizedString(@"ErasingMessage", nil)];

	// Throw a warning about erasing files.
	// Hold down the Option key when launching PE to prevent this warning from appearing.
	if (warnBeforeErasing == YES)
	{
		int choice = 0;
		
		if (files_were_dropped == YES && num_files == 1)	// Erasing one files
		{
			choice = NSRunAlertPanel(NSLocalizedString(@"ErrorTitle", nil),
			NSLocalizedString(@"ErasingFileWarning", nil), NSLocalizedString(@"OK", nil), 
			NSLocalizedString(@"Quit", nil), nil);
		}
		else if (files_were_dropped == YES && num_files > 1)	// Erasing several files
		{
			choice = NSRunAlertPanel(NSLocalizedString(@"ErrorTitle", nil),
			NSLocalizedString(@"ErasingFilesWarning", nil), NSLocalizedString(@"OK", nil), 
			NSLocalizedString(@"Quit", nil), nil);
		}
		else	// Erasing files from the Trash
		{
			choice = NSRunAlertPanel(NSLocalizedString(@"ErrorTitle", nil),
			NSLocalizedString(@"ErasingTrashWarning", nil), NSLocalizedString(@"OK", nil),
			NSLocalizedString(@"Quit", nil), nil);
		}

		if (NSCancelButton == choice) // Quit button
		{
			[NSApp terminate:self];
		}
		
	}
	
	
    if (idx < num_files)
    {
		[self selectNextFile];
    }
    else  // there are no files
    {
        [self shutdownPE];
    }

}


// =========================================================================
// (void) selectNextFile
// -------------------------------------------------------------------------
// Determine whether to erase a regular file, or to burn an optical disc
// -------------------------------------------------------------------------
// Created: 6 March 2007 20:10
// Version: 28 October 2008 22:38
// =========================================================================
- (void) selectNextFile
{
	if ([self isVolume: [trash_files pathAtIndex: idx]] == YES && [self isErasableDisc: [trash_files pathAtIndex: idx]])
	{
		[self eraseDisc];
	}
	else
	{
		[self runTask];
	}
}


// =========================================================================
// (void) eraseDisc
// -------------------------------------------------------------------------
// http://developer.apple.com/documentation/MusicAudio/Reference/DiscRecordingFrameworkRef/DRErase/Classes/DRErase/index.html#//apple_ref/occ/cl/DRErase
// NSLog(@"IORegistryEntry: %@", [[device info] objectForKey:DRDeviceIORegistryEntryPathKey]);
// -------------------------------------------------------------------------
// Created: 28 February 2007
// Version: 28 October 2008 22:38
// =========================================================================
- (void) eraseDisc
{	
	DRDevice* device;
	DRErase* erase;	

	[progress_msg setStringValue: [self fileNameString]];
	[fileIcon setImage:[[NSWorkspace sharedWorkspace] iconForFile:[trash_files pathAtIndex: idx]]];
	
	device = [DRDevice deviceForBSDName: [self bsdDevNode: [trash_files pathAtIndex: idx]]];

	if (device != nil)
	{
		erase = [[DRErase alloc] initWithDevice:device];
		
		if ([discErasingLevel isEqualToString:@"Quick"])
		{
			[erase setEraseType:DREraseTypeQuick];	
		}
		else
		{
			[erase setEraseType:DREraseTypeComplete];
		}

		// register to receive notification about the erase status.	
		[[DRNotificationCenter currentRunLoopCenter] addObserver:self	
		selector:@selector(eraseNotification:)	
		name:DREraseStatusChangedNotification 
		object:erase];
		
		[cancelButton setEnabled:NO];
		[cancelMenuItem setEnabled:NO];

		[erase start];
	}
	else
	{
		NSRunAlertPanel(NSLocalizedString(@"ErrorTitle",nil), NSLocalizedString(@"ErrorDeletingDiscMessage",nil), NSLocalizedString(@"OK",nil), nil, nil);
		
		// Continue on as if this was successful in erasing...
		[indicator incrementBy: 100.0];
		[self updateApplicationBadge];
		[self doneErasing:nil];
	}

} 


// =========================================================================
// (void) eraseNotification: (NSNotification*) notification
// -------------------------------------------------------------------------
// Receive notifications while the optical disc is being erased
// -------------------------------------------------------------------------
// Created: 28 February 2007
// Version: 10 March 2007 23:12
// =========================================================================
- (void) eraseNotification: (NSNotification*) notification	
{	
	// DRErase* erase = [notification object];	
	NSDictionary* status = [notification userInfo];	

	// States: DRStatusStatePreparing, DRStatusStateErasing, DRStatusStateDone, DRStatusStateFailed
	if ([[status objectForKey: DRStatusStateKey] isEqualToString: @"DRStatusStateDone"])
	{
		// kick out of function, reset, clean up, and move onto the next file
		[self doneErasing: nil];
	}
	else
	{
		int currentPercentageCD = [[status objectForKey: DRStatusPercentCompleteKey] floatValue] * 100;
		
		if (currentPercentageCD < 0)
			currentPercentageCD = 0;
		else if (currentPercentageCD > 100)
			currentPercentageCD = 100;
		
		// Create an updateProgressBar method
		if (currentPercentageCD >= lastPercentageCD)
		{
			[indicator incrementBy: currentPercentageCD - lastPercentageCD];
			[indicator displayIfNeeded];  // force indicator to draw itself
		}
		else
		{
			[indicator incrementBy: 100 - currentPercentageCD];
			[indicator displayIfNeeded];  // force indicator to draw itself
		}
		
		[fileSizeMsg setStringValue: [[[self formatFileSize: ([indicator doubleValue] / [indicator maxValue]) *totalFilesSize] stringByAppendingString: NSLocalizedString(@"of", nil)] stringByAppendingString: [self formatFileSize: (double)totalFilesSize]]];
		[self updateApplicationBadge];
		
		if (currentPercentageCD >= 100)
		{
			currentPercentageCD = 0;
			lastPercentageCD = 0;
		}
		else
		{
			lastPercentageCD = currentPercentageCD;
		}
		
		// If the optical disc erasing failed...
		if ([[status objectForKey: DRStatusStateKey] isEqualToString: @"DRStatusStateFailed"])
		{
			NSRunAlertPanel(NSLocalizedString(@"ErrorTitle",nil), NSLocalizedString(@"ErrorDeletingDiscMessage",nil), NSLocalizedString(@"OK",nil), nil, nil);
			[self doneErasing: nil];
		}
	
	}
	
}


// =========================================================================
// (void) runTask
// -------------------------------------------------------------------------
// Set the NSTask parameters and launch the task.  If a file is symbolic 
// link, remove it with rm, because srm will try and remove the original
// file instead of the symbolic link.
// -------------------------------------------------------------------------
// Created: 4. April 2004 23:35
// Version: 6 November 2008 4:57
// =========================================================================
- (void) runTask
{
    pEraser = [[NSTask alloc] init];  
    
    // If the file is a symbolic/soft link
    if ([self isFileSymbolicLink: [trash_files pathAtIndex: idx]] == YES)
    {
        [pEraser setLaunchPath:@"/bin/rm"];
        [pEraser setArguments: [NSArray arrayWithObjects: @"-Pv", [trash_files pathAtIndex: idx], nil] ];
    }
    else // regular file or directory
    {
        [pEraser setLaunchPath:util_path];
        [pEraser setArguments: [NSArray arrayWithObjects: @"-fvrz", [trash_files pathAtIndex: idx], nil] ];
    }
	
	
	// Throw a warning if a file cannot be erased
	if ([fm isDeletableFileAtPath:[trash_files pathAtIndex: idx]] == NO || 
		[self checkPermissions: [trash_files pathAtIndex: idx]] == NO)
	{
		int choice = NSRunAlertPanel(NSLocalizedString(@"ErrorTitle", nil),
        NSLocalizedString(@"ErrorDeletingMessage", nil), NSLocalizedString(@"OK", nil), 
        NSLocalizedString(@"Quit", nil), nil, [self currentFileName]);

		if (choice == 0) // Quit button
		{
			[[NSApplication sharedApplication] terminate:self];
		}
		else
		{
			// Act like the file was erased and move on to the next file
			[indicator incrementBy:100.0];
			[indicator displayIfNeeded];
			[ [NSNotificationCenter defaultCenter] postNotificationName: @"NSTaskDidTerminateNotification" object: self];
		}
		
	}	
	else
	{
//		NSFileHandle *handle;
		BOOL isDir;
     
		pipe = [[NSPipe alloc] init];
		
		[progress_msg setStringValue: [self fileNameString]];
		[fileIcon setImage:[[NSWorkspace sharedWorkspace] iconForFile:[trash_files pathAtIndex: idx]]];
    
		[pEraser setStandardOutput:pipe];
		[pEraser setStandardError:pipe];
		handle = [pipe fileHandleForReading];
		NSDictionary *fileAttributes = [fm fileAttributesAtPath:[trash_files pathAtIndex: idx] traverseLink:NO];
		
		// If the file is locked by the Finder, unlock it before deleting.
		if ([[fileAttributes objectForKey:NSFileImmutable] boolValue] == YES)
		{
			[fm changeFileAttributes: [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:NSFileImmutable] atPath:[trash_files pathAtIndex: idx]];
		}
		
		// If it is a directory or empty file, add 100 since it doesn't delete like normal files
		if (([fm fileExistsAtPath: [trash_files pathAtIndex: idx] isDirectory:&isDir] && isDir &&
			 [[NSWorkspace sharedWorkspace] isFilePackageAtPath: [trash_files pathAtIndex: idx]] == NO) )
		{
			[indicator incrementBy: 100.0]; // This was originally set to 99
		}
		else if ([[fileAttributes objectForKey:NSFileSize] intValue] == 0) // file is 0K in size
		{
			[indicator incrementBy: 100.0];
		}
					
		[pEraser launch];
		
		[NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
	}
    
}


// =========================================================================
// (void) outputData: (NSFileHandle *) current_handle
// -------------------------------------------------------------------------
// Direct the output data sent from the task to be read by the program
// -------------------------------------------------------------------------
// Created: 25 October 2005 19:14
// Version: 13 November 2008 21:45
// =========================================================================
- (void) outputData: (NSFileHandle *) current_handle
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSData *data;
//	unsigned int index = 0;
	int lastPercentage = 0;
	int currentPercentage = 0;
    
    while ([data=[current_handle availableData] length])
    {
        NSString *string = [[NSString alloc] initWithData:data encoding: NSASCIIStringEncoding];
		NSString *modifiedString = [[NSString alloc] initWithString: [string stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]];

		// What is setting index used for?  Old, unused code, perhaps?
//        if ([modifiedString length] < 4)
//		{
//			index = [modifiedString length];
//		}
//		else
//		{
//			index = 4;
//		}
		
		// stringByTrimmingCharactersInSet is a 10.2+ feature. 
		NSArray *splitString = [modifiedString componentsSeparatedByString: @"%"];
		
		currentPercentage = [[splitString objectAtIndex: 0] intValue];		

        [string release];

		if (currentPercentage >= lastPercentage)
		{
			[indicator incrementBy: currentPercentage - lastPercentage];
			[indicator displayIfNeeded];  // force indicator to draw itself
		}
		else
		{
			[indicator incrementBy: 100 - currentPercentage];
			[indicator displayIfNeeded];  // force indicator to draw itself
		}
		
		
		[fileSizeMsg setStringValue: [[[self formatFileSize: ([indicator doubleValue] / [indicator maxValue]) *totalFilesSize] stringByAppendingString: @" of "] stringByAppendingString: [self formatFileSize: (double)totalFilesSize]]];
		[self updateApplicationBadge];
		
		if (currentPercentage >= 100)
		{
			currentPercentage = 0;
			lastPercentage = 0;
		}
		else
		{
			lastPercentage = currentPercentage;
		}
    }
      
    [pool release];
}


// =========================================================================
// (NSString *) formatFileSize: (double) file_size
// -------------------------------------------------------------------------
//
// -------------------------------------------------------------------------
// Created: 8 August 2007 22:09
// Version: 16 July 2008 21:06
// =========================================================================
- (NSString *) formatFileSize: (double) file_size
{
	NSString *file_size_label;
	
	if ( (file_size / 1024) < 1.0)
		file_size_label = @" bytes";
	else if ((file_size / 1048576) < 1.0)
	{
		file_size = file_size / 1024;
		file_size_label = @" KB";
	}
	else if ((file_size / 1073741824) < 1.0)
	{
		file_size = file_size / 1048576;
		file_size_label = @" MB";
	}
	else
	{
		file_size = file_size / 1073741824;
		file_size_label = @" GB";
	}	
	
	return ([[NSString stringWithFormat: @"%.2f", file_size] stringByAppendingString:file_size_label]);
}

// =========================================================================
// - (void) updateApplicationBadge
// -------------------------------------------------------------------------
// http://www.macdevcenter.com/pub/a/mac/2001/10/19/cocoa.html?page=3
// [[NSColor colorWithCalibratedRed: 0.6 green: 0.6 blue: 0.8 alpha:1.0] set]; // create a custom color
// [[[NSColor orangeColor] colorWithAlphaComponent:0.7] set];
// -------------------------------------------------------------------------
// Created: November 2005
// Version: 19 November 2006 16:27
// =========================================================================
- (void) updateApplicationBadge 
{
	NSImage *icon = [NSImage imageNamed:@"NSApplicationIcon"];
	NSRect r = NSMakeRect(90.0, 10.0, 32.0, 32.0); 
	NSRect r2 = NSMakeRect(88.0, 5.0, 36.0, 35.0);
	
	[icon lockFocus];

	// Draw the badge image

	end_angle = 90.0 - ([indicator doubleValue] / [indicator maxValue]) * 360;

	NSBezierPath *bp = [NSBezierPath bezierPathWithOvalInRect:r];	
	NSBezierPath *bp2 = [NSBezierPath bezierPath];

	if (firstTimeHere == YES)
	{
		firstTimeHere = NO;

		// Draw the shadow behind the progress badge
		NSBezierPath *bp3 = [NSBezierPath bezierPathWithOvalInRect:r2];
		[[[NSColor blackColor] colorWithAlphaComponent:0.3] set];
		[bp3 fill];

		// If the background orange and white circle is drawn only once at 
		// this point, the outside edges are smoother, but the progress
		// meter inside becomes very jagged.
	}

	// Draw the background circle (white background with an orange edge)
	[bp setLineWidth: 5.0];
	[bp setFlatness:0.1];  // This smooths the edges by a bit
	[[NSColor orangeColor] set];
	[bp stroke];
	
	[[NSColor whiteColor] set];
	[bp fill];
	

	// Draw the progress meter
	[bp2 moveToPoint:NSMakePoint(106.0, 26.0)];
	[bp2 lineToPoint:NSMakePoint(106.0, 43.0)];
	[bp2 appendBezierPathWithArcWithCenter: NSMakePoint(106.0, 26.0) radius: 17.0 startAngle: 90.0 endAngle: end_angle clockwise: YES];

	[[NSColor orangeColor] set];
	[bp2 fill];


	[icon unlockFocus];
	[NSApp setApplicationIconImage:icon];
	
	// Clean up the icon before the application quits
	if (!registeredForTerminate) 
	{
		registeredForTerminate = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self 
								selector:@selector(appWillTerminateNotification:) 
								name:NSApplicationWillTerminateNotification 
								object:NSApp];
	}

}


// =========================================================================
// (NSString *) currentFileName
// -------------------------------------------------------------------------
// Retrieve the short version of the current file (i.e. "foo.txt") being 
// deleted (so no full path).
// -------------------------------------------------------------------------
// Created: 9 October 2005 17:30
// Version: 9 October 2005 17:30
// =========================================================================
- (NSString *) currentFileName
{
	return ([[trash_files pathAtIndex: idx] lastPathComponent]);
}


// =========================================================================
// (NSString *) fileNameString
// -------------------------------------------------------------------------
// If a file name is too long (over the length of the progress_msg field), 
// the entire string will not print properly in the text field in the 
// interface.  This checks if the file name exceeds the length limit, and
// if so, then it puts an ellipse (ellipsis) in the middle of the file name
// to abridge it.
// -------------------------------------------------------------------------
// Created: 2. April 2004 1:05
// Version: 28 October 2008 22:35
// =========================================================================
- (NSString *) fileNameString
{
//	return ([trash_files objectAtIndex: i]);
	
    NSMutableString *current_file_name = [[NSMutableString alloc] initWithString: [self currentFileName]];
    int cfl_length = [current_file_name length];
    float cfl_len = 0.0;
    float field_width = [progress_msg bounds].size.width;

    dict  = [ [NSMutableDictionary alloc] init];
    [dict setObject:[NSFont fontWithName:@"Lucida Grande Bold" size:11.0] forKey:NSFontAttributeName];
    cfl_len = [current_file_name sizeWithAttributes:dict].width;
    
    if (cfl_len > field_width)
    {
        [current_file_name replaceCharactersInRange: NSMakeRange(cfl_length-10, 3) withString:@"..."];
        
        while (cfl_len > field_width)
        {
            [current_file_name deleteCharactersInRange: NSMakeRange(cfl_length-11, 1)];
            cfl_length = [current_file_name length];
            cfl_len = [current_file_name sizeWithAttributes:dict].width;
        }
        
        [dict release];
        
        return (NSString *)current_file_name;
    }
    else
    {
        return (NSString *)current_file_name;
        
        [dict release];
    }
	
}


// =========================================================================
// (BOOL) checkPermissions: (NSString *)path
// -------------------------------------------------------------------------
// This bit of code is based from from tree_walker.c (lines 39-52), which is
// from the source code for srm.
// This is used to check if a file can be deleted or not.  It handles the 
// cases where the file isn't owned by the current users, which then has
// difficulty in deleting such files.
// -------------------------------------------------------------------------
// Created: 7 December 2006 19:30
// Version: 19 December 2006 22:13
// =========================================================================
- (BOOL) checkPermissions: (NSString *)path
{
	int fd;
	const char * cpath = [path UTF8String];
	
	if ( ((fd = open(cpath, O_WRONLY)) == -1) && (errno == EACCES) ) 
	{
		if ( chmod(cpath, S_IRUSR | S_IWUSR) == -1 ) 
		{
		  return (NO);
		}
	}

	close(fd);
	
	return (YES);
}


// =========================================================================
// (BOOL) containsResourceFork: (NSString *)path
// -------------------------------------------------------------------------
// Check to see if a file contains a resource fork.
// Should gather several of these file-related checks and put them into
// a separate extension class.
// -------------------------------------------------------------------------
// Created: 2 January 2007 19:49
// Version: 8 April 2007
// =========================================================================
- (BOOL) containsResourceFork: (NSString *)path 
{
	FSRef           fsRef;
	FSCatalogInfo   fsInfo;
	BOOL			isDir;

	// If path is a directory, automatically return NO
	if ( [fm fileExistsAtPath: path isDirectory:&isDir] && isDir )
	{
		return (NO);
	}
	else if(FSPathMakeRef((unsigned char *) [path fileSystemRepresentation], &fsRef, NULL) == noErr) 
	{
		if(FSGetCatalogInfo(&fsRef, kFSCatInfoRsrcSizes, &fsInfo, NULL, NULL, NULL) == noErr)
		{
			if (fsInfo.rsrcLogicalSize > 0)
			{
				return (YES);
			}
			else
			{
				return (NO);
			}
		}
	}
	   
	return (NO);
}


// =========================================================================
// (BOOL) isFileSymbolicLink: (NSString *)path
// -------------------------------------------------------------------------
// Check to see if a file is a symbolic/soft link, so the link
// can be deleted with rm instead of srm, so the original file is not 
// accidentally erased.
// -------------------------------------------------------------------------
// Version: 19. November 2004 21:28
// Created: 19. November 2004 21:28
// =========================================================================
- (BOOL) isFileSymbolicLink: (NSString *)path
{
    NSDictionary *fattrs = [fm fileAttributesAtPath: path traverseLink:NO];

    if ( [[fattrs objectForKey:NSFileType] isEqual: @"NSFileTypeSymbolicLink"])
    {
        return (YES);
    }
    else
    {
        return (NO);
    }

}


// =========================================================================
// (BOOL) isVolume: (NSString *) volumePath
// -------------------------------------------------------------------------
// Check to see if the current "file" is a mounted volume (CD, HD, etc.)
// -------------------------------------------------------------------------
// Created: 3 December 2005 21:15
// Version: 3 December 2005 21:15
// =========================================================================
- (BOOL) isVolume: (NSString *) volumePath
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


// =========================================================================
// (BOOL) isErasableDisc: (NSString *) volumePath
// -------------------------------------------------------------------------
// Check to see if the current "file" is erasable optical media (CD/DVD-RW)
// -------------------------------------------------------------------------
// Created: 9 March 2007 23:12
// Version: 9 March 2007 23:12
// =========================================================================
- (BOOL) isErasableDisc: (NSString *) volumePath
{
	// detect DRDevice and then check with mediaIsErasable or DRDeviceMediaIsErasableKey
	if ([self isVolume:volumePath] == YES)
	{
		DRDevice *device;
		
		// Determine if the media can be erased...
		device = [DRDevice deviceForBSDName: [self bsdDevNode: volumePath]];
		
		if (device != nil)
		{		
			if ([device mediaIsErasable] == YES)
			{	
				return (YES);
			}
			else
			{
				return (NO);
			}
		}
		else
		{
			return (NO);
		}
	}
	else
	{
		return (NO);
	}

}


// =========================================================================
// (NSString *) volumeType: (NSString *) volumePath
// -------------------------------------------------------------------------
// Portions of this code by Tjark Derlien and the CocoaTechFoundation 
// framework
// (BOOL)getInfoForFile:(NSString *)fullPath application:(NSString **) 
// appName type:(NSString **)type
// -------------------------------------------------------------------------
// Created: 4 December 2005 14:17
// Version: 4 December 2005 14:17
// =========================================================================
- (NSString *) volumeType: (NSString *) volumePath
{
	struct statfs stat;
	
	if (statfs([volumePath fileSystemRepresentation], &stat) == 0)
	{
		NSString *fileSystemName = [fm stringWithFileSystemRepresentation: stat.f_fstypename length: strlen(stat.f_fstypename)];
		
		if ([fileSystemName isEqualToString:@"hfs"])
			return (fileSystemName);	//HFS(+)
		else if ([fileSystemName isEqualToString:@"nfs"])
			return (fileSystemName);	//NFS (may also be FTP)
		else if ([fileSystemName isEqualToString:@"ufs"])
			return (fileSystemName);	//UFS
		else if ([fileSystemName isEqualToString:@"msdos"])
			return (fileSystemName);	//FAT (USB stick?)
		else if ([fileSystemName isEqualToString:@"afpfs"])
			return (fileSystemName);	//Apple Share
		else if ([fileSystemName isEqualToString:@"webdav"])
			return (fileSystemName);	//WebDAV
		else if ([fileSystemName isEqualToString:@"cddafs"])
			return (fileSystemName);	//audio CD
		else if ([fileSystemName isEqualToString:@"smbfs"])
			return (fileSystemName);	//SMB (Samba/Windows share)
		else if ([fileSystemName isEqualToString:@"cifs"])
			return (fileSystemName);	//CIFS (Windows share)
		else if ([fileSystemName isEqualToString:@"cd9660"])
			return (fileSystemName);	//data CD
		else if ([fileSystemName isEqualToString:@"udf"])
			return (fileSystemName);	//UDF (DVD)
		else if ([fileSystemName isEqualToString:@"ncp"])
			return (fileSystemName);	//Novell netware
		else
			return (@"");	// return an empty string
	}
	else
	{
		return (@"");
	}
}


// =========================================================================
// (NSString *) bsdDevNode: (NSString *) volumePath
// -------------------------------------------------------------------------
// Here's another interesting bit of code, that wasn't used, but somewhat
// similar idea to what was done in this method.
// http://snipplr.com/view/1645/given-a-mount-path-retrieve-a-usb-device-name/
// Return the "parent" BSD node name of a CD-RW/DVD-RW.  If the BSD name
// is "/dev/disk3s1s2", this method will return "disk3"
// -------------------------------------------------------------------------
// Created: 1 March 2007 21:16
// Version: 9 March 2007 23:00
// =========================================================================
- (NSString *) bsdDevNode: (NSString *) volumePath
{
	struct statfs devStats;
	
	statfs([volumePath UTF8String], &devStats);
	
	return ([[[[NSString alloc] initWithUTF8String:devStats.f_mntfromname] lastPathComponent] substringToIndex:5]);
}


// =========================================================================
// (void) doneErasing: (NSNotification *)aNotification
// -------------------------------------------------------------------------
// When a file is deleted, a notification is called which brings up this
// function.  If there are still files left to process in trash_files, 
// recursively run through the remainder 
// -------------------------------------------------------------------------
// Created: 2. June 2003 14:20
// Version: 8 April 2007
// =========================================================================
- (void) doneErasing: (NSNotification *)aNotification 
{
    idx++; // increment the counter here to prevent out of bound array errors
	
    if (idx >= num_files)  // Jobs are complete.  Quit the app.
    {
        if (files_were_dropped == NO)
        {
            // Update the Trash icon to be empty.  This doesn't work in Mac OS 10.1.
            [[NSWorkspace sharedWorkspace] noteFileSystemChanged:[@"~/.Trash/" stringByExpandingTildeInPath]];
            
            // Update .Trashes
            BOOL isDir;
            int j = 0;
            NSMutableString *currentDirectory = [[NSMutableString alloc] init];
            NSArray *volumes = [[NSArray alloc] initWithArray: [fm directoryContentsAtPath: @"/Volumes"]];  // Can also try mountedLocalVolumePaths

            for (j = 0; j < [volumes count]; j++)
            {
                // Check to see if the .Trashes exist, and if so, get the contents
                // of the .Trashes and add them to trash_files (full path)
                [currentDirectory setString: [[[@"/Volumes/" stringByAppendingPathComponent: [volumes objectAtIndex: j]]  
                                            stringByAppendingPathComponent: @".Trashes"]
                                            stringByAppendingPathComponent: uid]];
                                            
                if ( [fm fileExistsAtPath: currentDirectory isDirectory:&isDir] && isDir )
                {
                    [[NSWorkspace sharedWorkspace] noteFileSystemChanged: currentDirectory];
                }
                
            }
        
            [currentDirectory dealloc];
            [volumes dealloc];
        
        }
        
        [self shutdownPE];
    }
    else
    {
		if ([aNotification object] == nil)
		{
			[cancelButton setEnabled:YES];
			[cancelMenuItem setEnabled:YES];
		}
		else
		{
			[handle closeFile];
			[pipe release];
			[pEraser release];
			pEraser = nil;
        }
		
        [self selectNextFile];
    }

}


// =========================================================================
// (IBAction) cancelErasing: (id) sender
// -------------------------------------------------------------------------
// This is called when the Cancel button (or ESC key) is pressed.
// -------------------------------------------------------------------------
// Created: 10. October 2003 1:32
// Version: 28 October 2008 22:28
// =========================================================================
- (IBAction) cancelErasing: (id) sender
{
    idx = num_files;
	wasCanceled = YES;
    [pEraser terminate];
}


// =========================================================================
// (IBAction) openPreferencePane: (id) sender
// -------------------------------------------------------------------------
// Open the PE preference pane in the System Preferences
// Not used currently, will be necessary later...
// -------------------------------------------------------------------------
// Created: 10 July 2007 22:28
// Version: 10 July 2007 22:28
// =========================================================================
- (IBAction) openPreferencePane: (id) sender
{
	// ~/Library/PreferencePanes/Permanent Eraser.prefPane
	[[NSWorkspace sharedWorkspace] openFile: [@"~/Library/PreferencePanes/Permanent Eraser.prefPane" stringByExpandingTildeInPath]];
	// /Library/PreferencePanes/Permanent Eraser.prefPane
	// Otherwise, throw warning that a Pref window can't be opened or found
}


// =========================================================================
// (IBAction) goToProductPage: (id) sender
// -------------------------------------------------------------------------
// Created: 30 December 2007 22:31
// Version: 30 December 2007 22:31
// -------------------------------------------------------------------------
// Open a web browser to go to the product web page
// =========================================================================
- (IBAction) goToProductPage: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://www.edenwaith.com/products/permanent%20eraser/"]];
}


// =========================================================================
// (IBAction) sendFeedback: (id) sender
// -------------------------------------------------------------------------
// Created: 30 December 2007 22:31
// Version: 30 December 2007 22:31
// -------------------------------------------------------------------------
// Open a web browser to go to the product feedback web page
// =========================================================================
- (IBAction) sendFeedback: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"mailto:support@edenwaith.com?subject=Permanent%20Eraser%20Feedback"]];
}


// =========================================================================
// (void) sound: (NSSound *) sound didFinishPlaying: (BOOL) aBool
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 8 December 2007 18:35
// Version: 8 December 2007 18:35
// =========================================================================
- (void) sound: (NSSound *) sound didFinishPlaying: (BOOL) aBool
{
	[NSApp terminate: self];
}

// =========================================================================
// (void) shutdownPE
// -------------------------------------------------------------------------
// Unified method when to wrap the program up and close it.
// -------------------------------------------------------------------------
// Created: 20 April 2005 20:30
// Version: 28 October 2008 22:27
// =========================================================================
- (void) shutdownPE
{
    // Completely fill the progress bar, in case of any odd inaccuracies
	// Mac OS 10.2 sometimes has problems completely filling the bar at times,
	// but do not fill it completely if erasing was canceled.
	if (([indicator doubleValue] < [indicator maxValue]) && wasCanceled == NO)
	{
		[indicator incrementBy: [indicator maxValue] - [indicator doubleValue]];
		[self updateApplicationBadge];
	}
	
	if (beepBeforeTerminating == YES)
	{
		if ( idx == 0 && [fm fileExistsAtPath: @"/System/Library/Sounds/Funk.aiff"] == YES ) // If there are no files to erase
		{
			NSSound *emptySound = [[NSSound alloc] initWithContentsOfFile: @"/System/Library/Sounds/Funk.aiff" byReference: YES];
			[emptySound setDelegate:self];
			[emptySound play];
		//		sleep(1);
		//		[NSApp terminate: self];
		}
		else if ( [fm fileExistsAtPath: @"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/finder/empty trash.aif"] == YES )
		{
			NSSound *emptyTrashSound = [[NSSound alloc] initWithContentsOfFile: @"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/finder/empty trash.aif" byReference: YES];
			[emptyTrashSound setDelegate:self];
			[emptyTrashSound play];
		}
		else
		{
			NSBeep();
			sleep(1);  // Pause long enough for the sound to complete
			[NSApp terminate: self];
		}
	}
	else
	{
		[NSApp terminate: self];
	}

}


@end
