//  PEController.m
//  PermanentEraser
//
//  Created by Chad Armstrong on Mon Jun 02 2003.
//  Copyright (c) 2003-2015 Edenwaith. All rights reserved.
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
#import "PreferencesController.h"

@implementation PEController


// =========================================================================
// (id) init
// -------------------------------------------------------------------------
// Initialize variables and set up notifications.
// -------------------------------------------------------------------------
// Created: 2. June 2003 14:20
// Version: September 2009
// =========================================================================
- (id) init 
{
    self = [super init];

    fm					= [NSFileManager defaultManager];
    trash_files			= [[NSMutableArray alloc] init];
	badge				= [[CTProgressBadge alloc] init];
    pEraser				= nil; 		// initialize the NSTask
	preparationThread   = nil;
    filesWereDropped 	= NO;
    uid					= [[NSString alloc] initWithFormat:@"%d", getuid()];
//	uid					= [NSString stringWithFormat: @"%d", getuid()];	// This has issues and doesn't save properly on Mac OS 10.3 and 10.4
//	uid					= [[NSNumber numberWithInt: getuid()] stringValue]; 
 	originalIcon		= [NSImage imageNamed:@"PE"]; 
	end_angle			= 90.0;
	lastPercentageCD	= 0;
	totalFilesSize		= 0;
	
	firstTimeHere				= YES;
	wasCanceled					= NO;
	beepBeforeTerminating		= YES;
	suppressCannotEraseWarning	= NO;
	isCurrentlyErasingDisc		= NO;
	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	   
    [[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(doneErasing:) 
												 name:NSTaskDidTerminateNotification 
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(privilegedTaskFinished:) 
												 name:STPrivilegedTaskDidTerminateNotification 
											   object:nil];

	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(appWillTerminateNotification:) 
												 name:NSApplicationWillTerminateNotification 
											   object:NSApp];

	// If the ALT/Option key is pressed when PE is launched, do not show
	// the warning dialog.  This is similar to holding down the Option
	// key when selecting the Empty Trash menu from Finder.
	if ([NSEvent isOptionKeyDown] == YES)
	{
		warnBeforeErasing = NO;
		suppressCannotEraseWarning = YES;
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
// Version: 26 March 2018 21:50
// =========================================================================
- (void) dealloc 
{
	// Remove all observed notifications, such as NSTaskDidTerminateNotification, STPrivilegedTaskDidTerminateNotification, 
	// NSApplicationWillTerminateNotification, etc.
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[badge release];
	[pipe release];
    [pEraser release];
	pEraser = nil;
    [uid release];
    [trash_files release];
	
	if (privilegedTask != nil) 
	{
		[privilegedTask release];
		privilegedTask = nil;
	}
	
	if (preparationThread != nil)
	{
		[preparationThread release];
		preparationThread = nil;
	}
	
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
// Version: 10 December 2016 22:00
// =========================================================================
- (void) awakeFromNib 
{
	[NSApp activateIgnoringOtherApps:YES]; // Bring app to foreground
	
	[theWindow setBackgroundColor:[NSColor colorWithCalibratedRed: 0.909 green: 0.909 blue: 0.909 alpha:1.0]];
	[theWindow display];  // redraw the window to display the light grey background.
	[theWindow center];	// center the window on the screen
	
	[erasingMsg setStringValue:NSLocalizedString(@"PreparingMessage", nil)];
	
	// Use a spinning indeterminate progress meter when retrieving the list of files
	[indicator setIndeterminate: YES];
	[indicator setUsesThreadedAnimation:YES];
    [indicator startAnimation: self];
		
	// Since the indicator has different heights, depending on the version of Mac OS X,
	// Adjust the y coordinate for cancelButton to align with the indicator
	NSRect cancelButtonFrame = [cancelButton frame];
	float updatedCancelButtonY = cancelButtonFrame.origin.y;
	
	if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 10, 0}] == YES)
	{	// Yosemite and later
		cancelButtonFrame.origin.y = updatedCancelButtonY-2.0;
		[cancelButton setFrame: cancelButtonFrame];
	}
	else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 7, 0}] == YES)
	{	// Lion through Mavericks
		cancelButtonFrame.origin.y = updatedCancelButtonY-2.5;
		[cancelButton setFrame: cancelButtonFrame];
	}
	
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
	
	
	if ([prefs objectForKey: @"OpticalDiscErasingLevel"] != nil)
    {
		discErasingLevel = [[NSMutableString alloc] initWithString:[prefs objectForKey: @"OpticalDiscErasingLevel"]];
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
	
	[self checkInstalledPlugins];
}


// =========================================================================
// (void) applicationDidFinishLaunching: (NSNotification *)
// -------------------------------------------------------------------------
// Need to make the PEController a delegate of the File Owner
// -------------------------------------------------------------------------
// Created: 2. June 2003
// Version: 30 November 2014 20:39
// =========================================================================
- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{	
    if (filesWereDropped != YES) // Search for files in .Trash and .Trashes
    {	
		NSBundle *dockBundle = [NSBundle bundleWithPath:@"/System/Library/CoreServices/Dock.app"];
		
		if (dockBundle != nil)
		{
			NSString *trashFullPath = [dockBundle pathForResource:@"trashfull" ofType:@"png"];
			
			if (trashFullPath != nil)
			{
				NSImage *trashFullImage = [[NSImage alloc] initWithContentsOfFile:trashFullPath];
				[fileIcon setImage: trashFullImage];
				[trashFullImage release];
			}
		}
		
        // Use the enumerator to try and read from the local Trash, which will hopefully pre-populate
        // this app in the Full Disk Access list.
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:[@"~/.Trash/" stringByExpandingTildeInPath]];
		
		// Need to check if the ap can read from the user's local ~/.Trash.  If it is not possible to see the files 
		// in the user's local Trash, the app probably requires Full Disk Access to be enabled (in macOS Catalina and later)
		// Instruct the user to enable Full Disk Access and then quit the app.
		if ([[enumerator allObjects] count] == 0 && [fm isReadableFileAtPath:[@"~/.Trash" stringByExpandingTildeInPath]] == NO)
		{						
			NSAlert *alert = [NSAlert alertWithMessageText: NSLocalizedString(@"ErrorTitle", nil)
											 defaultButton: NSLocalizedString(@"OpenSecurityPreferences", nil)
										   alternateButton: NSLocalizedString(@"Quit", nil)
											   otherButton: nil
								 informativeTextWithFormat: NSLocalizedString(@"CannotAccessTrash", nil)];
			
			// This takes the user to the Enable Full Disk Access section in the Help files
			[alert setHelpAnchor:@"full-disk-access-help"];
			[alert setShowsHelp: YES];
			[alert setAlertStyle: NSCriticalAlertStyle];
			
			[alert beginSheetModalForWindow: theWindow modalDelegate:self didEndSelector:@selector(fullDiskAccessAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];			
		}
		else 
		{	
			 // Perhaps consider naming the thread...
			preparationThread = [[NSThread alloc] initWithTarget:self selector:@selector(prepareFiles) object:nil];
			
			[[NSNotificationCenter defaultCenter] addObserver:self	
															selector:@selector(preparationFinished:)	
																name:NSThreadWillExitNotification 
															  object:preparationThread];
			
			[preparationThread start];
		}
		
    }
}


// =========================================================================
// (void) prepareFiles
// -------------------------------------------------------------------------
// Prepare the files in the Trash(es) to be erased
// -------------------------------------------------------------------------
// Crreated: 10 December 2014 22:22
// =========================================================================
- (void) prepareFiles
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	BOOL isDir;
	id object = nil;
	int j = 0;
	NSDirectoryEnumerator *enumerator;
	NSArray *volumes = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	
	
	// Note: It seems that it thinks that .DS_Store is also a volume.  Avoid this.
	for (j = 0; j < [volumes count]; j++)
	{
		// Check to see if the .Trashes exist, and if so, get the contents
		// of the .Trashes and add them to trash_files (full path)			
		NSString *currentDirectory = [NSString stringWithString: [[[volumes objectAtIndex:j]
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
					[self addFileToArray: [currentDirectory stringByAppendingPathComponent: object]];
					[enumerator skipDescendents];
				}
				else
				{
					totalFilesSize += [fm fileSize: [currentDirectory stringByAppendingPathComponent: object]];
					// this will reverse the array so a directory will be erased last after it is empty
					[self addFileToArray: [currentDirectory stringByAppendingPathComponent: object]];
				}
			}
		}            
	}
	
	// Get the files in the home account's Trash
	enumerator = [fm enumeratorAtPath:[@"~/.Trash/" stringByExpandingTildeInPath]];
	
	while (object = [enumerator nextObject])
	{
		// check for bundled files, i.e. .app, .rtfd, etc.
		if ( [fm fileExistsAtPath: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object] isDirectory:&isDir] && isDir &&
			[[NSWorkspace sharedWorkspace] isFilePackageAtPath: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object]] == YES )
		{
			// Generate a dictionary and insert that into the trash_files array
			[self addFileToArray: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object]];
			[enumerator skipDescendents];
		}
		else
		{
			// Generate a dictionary and insert that into the trash_files array
			// this will reverse the array so a directory will be erased last after it's empty
			[self addFileToArray: [[@"~/.Trash/" stringByExpandingTildeInPath] stringByAppendingPathComponent: object]];				
		}
	}
	
	[pool release];
	
	[NSThread exit];
}


// =========================================================================
// (void)preparationFinished: (NSNotification *)aNotification 
// -------------------------------------------------------------------------
// Call back method when the preparation thread is finished
// -------------------------------------------------------------------------
// Crreated: 10 December 2014
// Version:  13 September 2015
// =========================================================================
- (void)preparationFinished: (NSNotification *)aNotification 
{
	if (preparationThread != nil && wasCanceled == NO)
	{
		[[NSNotificationCenter defaultCenter] removeObserver: self name: NSThreadWillExitNotification object: preparationThread];
		[preparationThread release], preparationThread = nil;
		
		[self performSelectorOnMainThread:@selector(erase) withObject:nil waitUntilDone:NO];
	}
}

// Method for debugging 
- (void)checkRunningThreadFromMethod: (NSString *)methodName {
	BOOL isRunningOnMainThread = [[NSThread currentThread] isMainThread];
	NSLog(@"Running on main thread from %@ : %@", methodName, isRunningOnMainThread ? @"Yes" : @"No");
}

// =========================================================================
// (void) application:(NSApplication*) openFiles:
// -------------------------------------------------------------------------
// This method is only called when a file is dragged-n-dropped onto the
// PE icon.  The timer is called to add each of the new files.
// This method is initially called after applicationWillFinishLaunching, but
// before applicationDidFinishLaunching.  Subsequent calls to this method
// can be called after applicationDidFinishLaunching, which was often
// seen in Yosemite with a large batch of files.
// -------------------------------------------------------------------------
// Created: 2009 or 2010
// Version: 21 March 2015 17:25
// =========================================================================
- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames
{	
    BOOL isDir;
	BOOL isDir2;
    id object = nil;
	int fn_idx = 0;
	
	if ([filenames count] > 0)
	{
		filesWereDropped = YES;
	}
	
	for (fn_idx = 0; fn_idx < [filenames count]; fn_idx++)
	{
		NSString *filename = [filenames objectAtIndex: fn_idx];
		
		// Set this up to identify only burnable discs
		if ([self isVolume: filename] == YES && [self isErasableDisc: filename])
		{
			[self addFileToArray: filename];
		}
		else if ([fm fileExistsAtPath: filename isDirectory:&isDir] && isDir &&
				 [[NSWorkspace sharedWorkspace] isFilePackageAtPath: filename] == NO && 
				 [fm isFileSymbolicLink: filename] == NO)
		{
			NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: filename];
			
			[self addFileToArray: filename];
			
			while (object = [enumerator nextObject])
			{
				// if an item within the folder is a package
				if ( [fm fileExistsAtPath: [filename stringByAppendingPathComponent: object] isDirectory:&isDir2] && isDir2 &&
					[[NSWorkspace sharedWorkspace] isFilePackageAtPath: [filename stringByAppendingPathComponent: object]] == YES )
				{
					[self addFileToArray: [filename stringByAppendingPathComponent: object]];
					[enumerator skipDescendents];
				}
				else
				{				 
					[self addFileToArray: [filename stringByAppendingPathComponent: object]];
				}
			}
		}
		else
		{
			[self addFileToArray: filename];		
		}
	}
    
	// Fire timer at some later time. A timeInterval of 0.0 tells the run loop
	// to process this right away, but first it has to get through all the pending
	// open file messages.
    if (!timer)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval:0.0
												 target: self
											   selector: @selector(addNewFiles:)
											   userInfo: nil
												repeats: YES];
    }	
}


// =========================================================================
// (void) addNewFiles : (NSTimer *) aTimer
// -------------------------------------------------------------------------
// Add new files to the list of files that were dragged-n-dropped on the icon
// This method is called by the timer that is set-up in the application:openFile:
// method.
// -------------------------------------------------------------------------
// Created: 30 March 2004 23:52
// Version: 21 March 2015 20:27
// =========================================================================
- (void) addNewFiles: (NSTimer *) aTimer
{
    [aTimer invalidate];
    timer = nil;

	[self erase];
}


// =========================================================================
// (void) addFileToArray: (NSString *) filename
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 29 June 2009 22:30
// Version: 30 March 2018 22:43
// =========================================================================
- (void) addFileToArray: (NSString *) filePath
{
	PEFile *tempPEFile = [[PEFile alloc] initWithPath: filePath];
	BOOL isDir3;
	
	// Symbolic link
	[tempPEFile setIsSymbolicLink: [fm isFileSymbolicLink: filePath]];
	
	// File size
	if ([fm fileExistsAtPath: filePath isDirectory:&isDir3] && isDir3 &&
		[tempPEFile isSymbolicLink] == NO )
	{
		[tempPEFile setIsDirectory: YES];
		
		if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: filePath] == YES)
		{
			[tempPEFile setIsPackage: YES];
			[tempPEFile setFilesize: [fm fileSize: filePath]];
		}
		else if ([self isVolume: filePath] == YES && [self isErasableDisc: filePath])	// erasable disc
		{
			[tempPEFile setIsPackage: NO];
			[tempPEFile setFilesize: [fm fileSize: filePath]];
		}
		else	// otherwise, just a directory
		{
			[tempPEFile setIsPackage: NO];
			[tempPEFile setFilesize: 1];
		}
	}
	else
	{
		[tempPEFile setFilesize: [fm fileSize: filePath]];
		[tempPEFile setIsDirectory: NO];
		[tempPEFile setIsPackage: NO];
	}
	
	// Is Volume + Is Erasable Disc
	if ([self isVolume: filePath] == YES)
	{
		[tempPEFile setIsVolume: NO];
		if ([self isErasableDisc: filePath] == YES)
		{
			[tempPEFile setIsErasableDisc: YES];
		}
		else
		{
			[tempPEFile setIsErasableDisc: NO];
		}
		
	}
	else
	{
		[tempPEFile setIsVolume: NO];
		[tempPEFile setIsErasableDisc: NO];
	}
	
	// This check can only be done on Mac OS 10.6+
	if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 6, 0}] == YES)	
	{
		[tempPEFile setIsOnSSD: [fm isSolidState: [filePath fileSystemRepresentation]]];
	}
	else 
	{
		[tempPEFile setIsOnSSD: NO];
	}

	
	// Resource Fork
	[tempPEFile setHasResourceFork: [fm containsResourceFork: filePath]];
	
	// Calculate total file size
	if ( ([tempPEFile isErasableDisc] == YES) || ([tempPEFile isDirectory] == NO) )
	{
		totalFilesSize += [tempPEFile filesize];
	}

	// Packages are treated as one file so it looks like just the bundle is being erased
	if ([tempPEFile isPackage] == YES)
	{
		totalFilesSize += [tempPEFile filesize];
		[tempPEFile setNumberOfFiles: [self countNumberOfFiles: [tempPEFile path]]];
	}
	else
	{
		if ([tempPEFile hasResourcefork] == YES)
		{
			[tempPEFile setNumberOfFiles: 2];
		}
		else
		{
			[tempPEFile setNumberOfFiles: 1]; // For all other files, folders, and non-bundles, set to 1
		}
	}
	
	// Check if a file can be deleted, and if not, if it can be deleted by using 
	// escalated permissions.  In most cases, a file is deletable.  But if it 
	// returns back 'no', then perform additional checks to determine if it is 
	// a write issue or if the file is on a read-only disk.
	BOOL requiresAuthorization = NO; // Check if admin rights are needed to delete
	BOOL isWritable            = YES; // Can the file be written over
	BOOL isPathDeletable       = YES; // Is the enclosing path writable 
	BOOL isFileDeletable       = YES; // By default, assume the file can be deleted
	int  deleteErrno           = 0; 
	
	NSDictionary *fileAttributes = [fm fileAttributesAtPath:filePath traverseLink:NO];
	
	// If the file is locked by the Finder, unlock it before checking if it can be deleted.
	if ([[fileAttributes objectForKey:NSFileImmutable] boolValue] == YES)
	{
		NSError *error = nil;
		if ([fm setAttributes: [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:NSFileImmutable] ofItemAtPath:filePath error: &error] == NO) {
			NSLog(@"Error trying to set the NSFileImmutable attribute: %@", [error localizedDescription]);
		}
	}
	
	// Check if the file can be overwritten and deleted.  If there is an error,
	// save the value of the system errno, since it can easily be changed by
	// the system if another error occurs.
	
	// Check if the enclosing path is writable so the file can be deleted
	isPathDeletable = [fm isDeletableFileAtPath: filePath];
	
	if (isPathDeletable == NO) {
		deleteErrno = errno;
		perror("isPathDeletable error");
	}
	
	// Check if the file can be overwritten and deleted
	isWritable = [fm isWritableFileAtPath: filePath];
	
	if (isWritable == NO) {
		deleteErrno = errno;
		perror("isWritable error");
	}
	
	if (isPathDeletable == NO || isWritable == NO) 
	{
		NSNumber *originalPermissions = [fileAttributes objectForKey: NSFilePosixPermissions];
		mode_t permissionsMask = 0700;
		mode_t updatedPermissions = [originalPermissions shortValue] | permissionsMask;  // Updated set of permissions
		NSDictionary *attribs = [NSDictionary dictionaryWithObject:[NSNumber numberWithShort:updatedPermissions] forKey:NSFilePosixPermissions];
		NSError *error = nil;
		
#ifdef MAC_APP_STORE
		// In most cases, this should be set to NO, but perfom one check to see if the current
		// user can update the file's permissions so it can be deleted.
		if (([fm setAttributes: attribs ofItemAtPath: filePath error: &error] == YES) && (isPathDeletable == YES))
		{
			isFileDeletable = YES;
		}
		else 
		{
			// Since admin rights cannot be granted for MAS apps, set this to NO
			isFileDeletable = NO;
		}
#else
		if (deleteErrno == EPERM) // Error 1 - Operation not permitted
		{
			requiresAuthorization = YES;
		} 
		else if (deleteErrno == EACCES) // Error 13 - Permissions error
		{
			// Try and update the permissions.  If possible, authorization is not necessary
			if ([fm setAttributes: attribs ofItemAtPath: filePath error: &error] == YES)
			{
				// As long as an enclosing folder(s) are writable, the file can be deleted
				// Otherwise, if the enclosing folder is read-only, then the file may be
				// modified and overwritten, but the original file cannot be deleted, so
				// authorization is needed to fully delete the file.
				if (isPathDeletable == YES) {
					// Was able to modify the permissions
					requiresAuthorization = NO;
				} else {
					requiresAuthorization = YES;
				}
			}
			else 
			{	// Was not able to modify the permissions, will need authorization
				if ([STPrivilegedTask authorizationFunctionAvailable] == YES) 
				{
					requiresAuthorization = YES;
				} 
				else 
				{
					// If AuthorizationExecuteWithPrivileges no longer works, then this
					// file cannot be deleted.
					isFileDeletable = NO;
				}
			} 
		} 
		else if (deleteErrno == EROFS) // Error 30 - Read-only file system
		{
			isFileDeletable = NO;
		}
		else 
		{	
			char *errorMsg = strerror(deleteErrno);
			NSLog(@"Other error detecting deletability: %s (%d)", errorMsg, deleteErrno);
		}
#endif
	}
	
	[tempPEFile setIsDeletable: isFileDeletable requiresAuthorizationToDelete: requiresAuthorization];
	
	[trash_files insertObject: tempPEFile atIndex: 0];
	
	[tempPEFile release];
}


// =========================================================================
// (unsigned long long) countNumberOfFiles: (NSString *) path
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 23 August 2009
// Version: 23 August 2009
// =========================================================================
- (unsigned long long) countNumberOfFiles: (NSString *) path
{
	unsigned long long numFiles = 0;
	
	NSDirectoryEnumerator *package_enumerator;
	id object = nil;
	BOOL isDir;
	
	package_enumerator = [fm enumeratorAtPath: path];
	
	while (object = [package_enumerator nextObject])
	{
		if ([fm fileExistsAtPath: [path stringByAppendingPathComponent: object] isDirectory:&isDir] && isDir == NO)
		{
			if ([fm containsResourceFork: [path stringByAppendingPathComponent: object]] == YES)
			{
				numFiles+=2;
			}
			else
			{
				numFiles++;
			}
		}
	}
	
	return (numFiles);	
}


// =========================================================================
// (void) checkInstalledPlugins
// -------------------------------------------------------------------------
// Check if a plug-in is installed, and if so, update to the most up-to-date
// version, if necessary
// -------------------------------------------------------------------------
// Created: 2 January 2012 14:11
// Version: 10 December 2016 23:30
// =========================================================================
- (void) checkInstalledPlugins
{
	NSString *oldPluginPath = nil;
	NSString *newPluginPath = nil;
	
	// Get installed plugin path and app's plugin path
	if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 6, 0}] == YES) // Mac OS 10.6 or later
	{
		oldPluginPath = [@"~/Library/Services/Erase.workflow" stringByExpandingTildeInPath];
		newPluginPath = [[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent: @"Erase.workflow"];
		
	}
	
	// Check if plugin is installed
	if ([fm fileExistsAtPath: oldPluginPath] == YES && [fm fileExistsAtPath: newPluginPath] == YES)
	{
		// Check if installed plugin is older than app's version
		NSDictionary *oldPluginAttr = [fm fileAttributesAtPath:oldPluginPath traverseLink:NO];
		NSDictionary *newPluginAttr = [fm fileAttributesAtPath:newPluginPath traverseLink:NO];
		
		NSDate *oldPluginDate = [oldPluginAttr objectForKey: NSFileModificationDate];
		NSDate *newPluginDate = [newPluginAttr objectForKey: NSFileModificationDate];
		
		if (oldPluginDate != nil && newPluginDate != nil)
		{
			if ([newPluginDate compare: oldPluginDate] ==  NSOrderedDescending)
			{
				if ([fm removeFileAtPath: oldPluginPath handler: nil] == NO)
				{
					NSLog(@"Failed to remove old plugin at %@", oldPluginPath);
				}
				
				// Install new version of plugin
				if ([fm copyPath: newPluginPath	toPath: oldPluginPath handler:nil] == NO)
				{
					NSLog(@"Failed installing the new plugin at %@", oldPluginPath);
				}
			}
		}
	}
}


#pragma mark -

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
// Version: 30 November 2014 21:03
// =========================================================================
- (void) erase
{
//	[self checkRunningThreadFromMethod: @"erase"];
    idx = 0;
    num_files = 0;
    num_files = [trash_files count];
	
    [indicator setMaxValue: totalFilesSize*100];
	[indicator setIndeterminate: NO];
    [indicator stopAnimation: self];
	
	[erasingMsg setStringValue:NSLocalizedString(@"ErasingMessage", nil)];
	
	// Throw a warning about erasing files.
	// Hold down the Option key when launching PE to prevent this warning from appearing.
	if (warnBeforeErasing == YES)
	{	
		if (filesWereDropped == YES && num_files == 1)	// Erasing one file
		{
			NSAlert *alert = [NSAlert alertWithMessageText: NSLocalizedString(@"ErrorTitle", nil)
											 defaultButton: NSLocalizedString(@"OK", nil)
										   alternateButton: NSLocalizedString(@"Quit", nil)
											   otherButton: nil
								 informativeTextWithFormat: [NSString stringWithFormat: NSLocalizedString(@"ErasingFileWarning", nil), [[trash_files objectAtIndex: idx] fileName]] ];
						
			[alert setShowsSuppressionButton: YES];
			[[alert suppressionButton] setTitle:NSLocalizedString(@"DoNotShowMessage", nil)];
			[[alert suppressionButton] setState:NSOffState];

			[alert beginSheetModalForWindow: theWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];			
		}
		else if (filesWereDropped == YES && num_files > 1)	// Erasing several files
		{		
			NSAlert *alert = [NSAlert alertWithMessageText: NSLocalizedString(@"ErrorTitle", nil)
											 defaultButton: NSLocalizedString(@"OK", nil)
										   alternateButton: NSLocalizedString(@"Quit", nil)
											   otherButton: nil
								 informativeTextWithFormat: NSLocalizedString(@"ErasingFilesWarning", nil)];
			
			[alert setShowsSuppressionButton: YES];
			[[alert suppressionButton] setTitle: NSLocalizedString(@"DoNotShowMessage", nil)];
			[[alert suppressionButton] setState: NSOffState];

			[alert beginSheetModalForWindow: theWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
		else	// Erasing files from the Trash
		{
			NSAlert *alert = [NSAlert alertWithMessageText: NSLocalizedString(@"ErrorTitle", nil)
															 defaultButton: NSLocalizedString(@"OK", nil)
														   alternateButton: NSLocalizedString(@"Quit", nil)
															   otherButton: nil
														   informativeTextWithFormat: NSLocalizedString(@"ErasingTrashWarning", nil)];
			
			[alert setShowsSuppressionButton: YES];
			[[alert suppressionButton] setTitle: NSLocalizedString(@"DoNotShowMessage", nil)];
			[[alert suppressionButton] setState: NSOffState];
			
			[alert beginSheetModalForWindow: theWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}		
	}
	else	// no warning displayed, start erasing
	{
		if (idx < num_files)
		{
			[self selectNextFile];
		}
		else  // there are no files
		{
			[self shutdownPE];
		}
	}
}


// =========================================================================
// (void) alertDidEnd: (NSAlertCheckbox *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo
// -------------------------------------------------------------------------
// Instead of using a modal alert, run as a sheet so the Preferences can
// be accessed easily.
// -------------------------------------------------------------------------
// Created: 29 December 2010 20:30
// Version: 29 December 2010 20:30
// =========================================================================
- (void) alertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
	if ([[alert suppressionButton] state] == NSOnState)	
	{
		[prefs setBool:NO forKey: @"WarnBeforeErasing"];
	}
	
	if (NSAlertSecondButtonReturn == returnCode || NSCancelButton == returnCode)	// Quit
	{
		[NSApp terminate:self];
	}
	else
	{
		if (idx < num_files)
		{
			[self selectNextFile];
		}
		else  // there are no files
		{
			[self shutdownPE];
		}
	}
}


// =========================================================================
// (void) fullDiskAccessAlertDidEnd
// -------------------------------------------------------------------------
// Call back method from the NSAlert which checks if Full Disk Access needs
// to be enabled.
// -------------------------------------------------------------------------
// Crreated: Mid-May 2020
// =========================================================================
- (void) fullDiskAccessAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (NSAlertSecondButtonReturn == returnCode || NSCancelButton == returnCode)	// Quit
	{
		[NSApp terminate:self];
	}
	else 
	{
		// macOS Mojave and later have Full Disk Access in the Security & Privacy pane
		if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 14, 0}] == YES)
		{
			// Reference for all of the preference anchors: https://apple.stackexchange.com/questions/361045/open-system-preferences-privacy-full-disk-access-with-url
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]];
			[NSApp terminate:self];
		}
		else
		{
			// For pre-Mojave versions of macOS/Mac OS X, have NSWorkspace directly open the Security pane
			NSURL *url = [NSURL fileURLWithPath:@"/System/Library/PreferencePanes/Security.prefPane"];
			if (url != NULL)
			{
				[[NSWorkspace sharedWorkspace] openURL:url];
			}
			
			[NSApp terminate:self];
		}
	}
}


// =========================================================================
// (void) selectNextFile
// -------------------------------------------------------------------------
// Determine whether to erase a regular file, or to burn an optical disc
// -------------------------------------------------------------------------
// Created: 6 March 2007 20:10
// Version: 29 June 2009 21:32
// =========================================================================
- (void) selectNextFile
{
	if ([[trash_files objectAtIndex: idx] isErasableDisc] == YES)
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
// Version: 6 December 2010 21:35
// =========================================================================
- (void) eraseDisc
{	
	DRDevice* device;
	DRErase* erase;	

	[erasingMsg setStringValue: [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"ErasingMessage", nil), [self fileNameString]]];
	[fileIcon setImage: [[trash_files objectAtIndex: idx] icon]];

	device = [DRDevice deviceForBSDName: [self bsdDevNode: [[trash_files objectAtIndex: idx] path]]];	

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
		isCurrentlyErasingDisc = YES;

		[erase start];
	}
	else
	{
		NSRunAlertPanel(NSLocalizedString(@"ErrorTitle",nil), NSLocalizedString(@"ErrorDeletingDiscMessage",nil), NSLocalizedString(@"OK",nil), nil, nil);
		
		// Continue on as if this was successful in erasing...
        [self updateIndicator: [[trash_files objectAtIndex: idx] filesize] * 100.0];
		
		
		// Does the badge update properly on macOS Mojave and Catalina?
		[badge badgeApplicationDockIconWithProgress:([indicator doubleValue] / [indicator maxValue]) insetX:2 y:0];
		[self doneErasing:nil];
	}

} 


// =========================================================================
// (void) eraseNotification: (NSNotification*) notification
// -------------------------------------------------------------------------
// Receive notifications while the optical disc is being erased
// -------------------------------------------------------------------------
// Created: 28 February 2007
// Version: 6 December 2010 21:35
// =========================================================================
- (void) eraseNotification: (NSNotification*) notification	
{	
	// DRErase* erase = [notification object];	
	NSDictionary* status = [notification userInfo];	
	unsigned long long currentFileSize = [[trash_files objectAtIndex: idx] filesize];

	// States: DRStatusStatePreparing, DRStatusStateErasing, DRStatusStateDone, DRStatusStateFailed
	if ([[status objectForKey: DRStatusStateKey] isEqualToString: @"DRStatusStateDone"])
	{
		isCurrentlyErasingDisc = NO;
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
			[self updateIndicator: (currentPercentageCD - lastPercentageCD)  * currentFileSize/[[trash_files objectAtIndex: idx] numberOfFiles]];
		}
		else
		{
			[self updateIndicator: (100 - currentPercentageCD) * currentFileSize/[[trash_files objectAtIndex: idx] numberOfFiles]];
		}
		
		[fileSizeMsg setStringValue: [[[fm formatFileSize: ([indicator doubleValue] / [indicator maxValue]) *totalFilesSize] stringByAppendingString: NSLocalizedString(@"Of", nil)] stringByAppendingString: [fm formatFileSize: (double)totalFilesSize]]];
		[badge badgeApplicationDockIconWithProgress:([indicator doubleValue] / [indicator maxValue]) insetX:2 y:0];
		
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
			isCurrentlyErasingDisc = NO;
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
// Created: 4 April 2004 23:35
// Version: 8 April 2018 11:56
// =========================================================================
- (void) runTask
{	
	PEFile *currentFile = [trash_files objectAtIndex: idx];
	
	// Check if the file can be deleted, but needs admin rights
	if (([currentFile isDeletable] == YES) && ([currentFile requiresAuthorizationToDelete] == YES)) 
	{
		[self setupPrivilegedTaskWithFile: currentFile];

	}
	else if (([currentFile isDeletable] == NO) || 
		(([currentFile isDirectory] == YES) && ([currentFile isPackage] == NO) && ([[NSFileManager defaultManager] isDirectoryEmpty: [currentFile path]] == NO)))
	{
		// If the file cannot be deleted, or it is a folder which still contains files which haven't been deleted
		int choice = -1; // alert button selection
		
		if (suppressCannotEraseWarning == NO)
		{
			NSAlert *alert = [NSAlert alertWithMessageText: NSLocalizedString(@"ErrorTitle", nil)
															 defaultButton: NSLocalizedString(@"OK", nil)
														   alternateButton: NSLocalizedString(@"Quit", nil)
															   otherButton: nil
														   informativeTextWithFormat: [NSString stringWithFormat: NSLocalizedString(@"ErrorDeletingMessage", nil), [currentFile fileName]] ];

			[alert setShowsSuppressionButton: YES];
			[[alert suppressionButton] setTitle: NSLocalizedString(@"DoNotShowMessage", nil)];
			[[alert suppressionButton] setState: NSOffState];
			
			choice = [alert runModal];
			
			if ([[alert suppressionButton] state] == NSOnState) 
			{
				// This setting is not saved permanently and is only set on a per-session basis
				suppressCannotEraseWarning = YES;
			}
		}

		if (choice == 0) // Quit button
		{
			[[NSApplication sharedApplication] terminate:self];
		}
		else
		{
			// Act like the file was erased and move on to the next file
			// [indicator incrementBy:[currentFile filesize]*100.0];
			[self updateIndicator: [currentFile filesize]*100.0];
			[[NSNotificationCenter defaultCenter] postNotificationName: @"NSTaskDidTerminateNotification" object: self];
		}
	}
	else
	{
		[self setupTaskWithFile: currentFile];
	}
    
}

// =========================================================================
// (void) setupPrivilegedTaskWithFile: (PEFile *)currentFile
// -------------------------------------------------------------------------
// Set up the path and arguments for the STPrivilegedTask to delete a file.
// -------------------------------------------------------------------------
// Created: 7 April 2018 18:00
// Version: 8 April 2018 11:49
// =========================================================================
- (void) setupPrivilegedTaskWithFile: (PEFile *)currentFile 
{
	// This file can be deleted, but it will require authorization privileges to erase it.		
	if (privilegedTask == nil)
	{
		privilegedTask = [[STPrivilegedTask alloc] init];
	}
	
	// If the file is a symbolic/soft link
	if ([currentFile isSymbolicLink] == YES)
	{
		[privilegedTask setLaunchPath:@"/bin/rm"];
		[privilegedTask setArguments: [NSArray arrayWithObjects: @"-Pv", [currentFile path], nil] ];
	}
	else // regular file or directory
	{
		NSString *utilPath  = [[NSBundle mainBundle] pathForResource:@"srm" ofType:@""];
		
		[privilegedTask setLaunchPath:utilPath];
		
		// If the file is on a SSD, only erase once to prevent unnecessary wear on an SSD
		if (([currentFile isOnSSD] == YES) ||
			([[prefs objectForKey: @"FileErasingLevel"] isEqualToString: NSLocalizedString(@"FileErasingSimple", nil)]) ) // 1-pass
		{
			[privilegedTask setArguments: [NSArray arrayWithObjects: @"-fsvrz", [currentFile path], nil] ];
		}
		else if ([[prefs objectForKey: @"FileErasingLevel"] isEqualToString: NSLocalizedString(@"FileErasingDoE", nil)]) // 3-pass DOE
		{
			[privilegedTask setArguments: [NSArray arrayWithObjects: @"-fEvrz", [currentFile path], nil] ];
		}
		else if ([[prefs objectForKey: @"FileErasingLevel"] isEqualToString: NSLocalizedString(@"FileErasingGutmann", nil)]) // 35-pass Gutmann Method
		{
			[privilegedTask setArguments: [NSArray arrayWithObjects: @"-fvrz", [currentFile path], nil] ];
		}
		else // Default 7-pass DoD
		{
			[privilegedTask setArguments: [NSArray arrayWithObjects: @"-fmvrz", [currentFile path], nil] ];
		}
	}
	
	[erasingMsg setStringValue: [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"ErasingMessage", nil), [self fileNameString]]];
	
	if ([currentFile icon] != nil)
	{
		[fileIcon setImage: [currentFile icon]];
	}
	
	NSDictionary *fileAttributes = [fm fileAttributesAtPath: [currentFile path] traverseLink:NO];
	
	// If it is a directory or empty file, add 100 since it doesn't delete like normal files
	// Note: Might want to reconsider incrementing at all since files of 0 size normally wouldn't add anything 
	// to the progress bar...
	if (([currentFile isDirectory] == YES) && ([currentFile isPackage] == NO))
	{
        [self updateIndicator: 100.0];
	}
	else if ([[fileAttributes objectForKey:NSFileSize] intValue] == 0) // file is 0 bytes in size
	{
        [self updateIndicator: 100.0];
	}
	
	// Due to security limitations, once the privileged task is launched, it cannot be canceled
	[cancelButton setEnabled:NO];
	[cancelMenuItem setEnabled:NO];
	
	// Launch it, user is prompted for password
	OSStatus err = [privilegedTask launch];
	
	if (err != errAuthorizationSuccess) 
	{
		// TODO: Should I throw up an alert dialog if the file couldn't be deleted here?
		if (err == errAuthorizationCanceled) {
			NSLog(@"User canceled STPrivilegedTask");
		} else if (err == errAuthorizationFnNoLongerExists) {
			NSLog(@"AuthorizationExecuteWithPrivileges is not available");
		} else {
			NSLog(@"Could not launch STPrivilegedTask.");
		}
		
		// If there was an error, make the appropriate updates and then 
		// call the notification to move onto the next file
		// [indicator incrementBy:[currentFile filesize]*100.0];
		[self updateIndicator: [currentFile filesize]*100.0];
		[[NSNotificationCenter defaultCenter] postNotificationName: STPrivilegedTaskDidTerminateNotification object: self];
	} 
	else 
	{
		[NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: [privilegedTask outputFileHandle]];
	}
}

// =========================================================================
// (void) setupTaskWithFile: (PEFile *)currentFile
// -------------------------------------------------------------------------
// Set up the path and arguments for the NSTask to delete a file.
// -------------------------------------------------------------------------
// Created: 7 April 2018 22:00
// Version: 7 April 2018 22:00
// =========================================================================
- (void) setupTaskWithFile: (PEFile *)currentFile
{
	if (pEraser == nil)
	{
		pEraser = [[NSTask alloc] init];
	}
	
	// If the file is a symbolic/soft link
	if ([[trash_files objectAtIndex: idx] isSymbolicLink] == YES)
	{
		[pEraser setLaunchPath:@"/bin/rm"];
		[pEraser setArguments: [NSArray arrayWithObjects: @"-Pv", [[trash_files objectAtIndex: idx] path], nil] ];
	}
	else // regular file or directory
	{
		NSString *utilPath  = [[NSBundle mainBundle] pathForResource:@"srm" ofType:@""];
		
		[pEraser setLaunchPath:utilPath];
		
		// If the file is on a SSD, only erase once to prevent unnecessary wear on an SSD
		if (([[trash_files objectAtIndex: idx] isOnSSD] == YES) ||
			([[prefs objectForKey: @"FileErasingLevel"] isEqualToString: NSLocalizedString(@"FileErasingSimple", nil)]) ) // 1-pass
		{
			[pEraser setArguments: [NSArray arrayWithObjects: @"-fsvrz", [[trash_files objectAtIndex: idx] path], nil] ];
		}
		else if ([[prefs objectForKey: @"FileErasingLevel"] isEqualToString: NSLocalizedString(@"FileErasingDoE", nil)]) // 3-pass DOE
		{
			[pEraser setArguments: [NSArray arrayWithObjects: @"-fEvrz", [[trash_files objectAtIndex: idx] path], nil] ];
		}
		else if ([[prefs objectForKey: @"FileErasingLevel"] isEqualToString: NSLocalizedString(@"FileErasingGutmann", nil)]) // 35-pass Gutmann Method
		{
			[pEraser setArguments: [NSArray arrayWithObjects: @"-fvrz", [[trash_files objectAtIndex: idx] path], nil] ];
		}
		else // Default 7-pass DoD
		{
			[pEraser setArguments: [NSArray arrayWithObjects: @"-fmvrz", [[trash_files objectAtIndex: idx] path], nil] ];
		}
	}
	
	pipe = [[NSPipe alloc] init];
	
	[erasingMsg setStringValue: [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"ErasingMessage", nil), [self fileNameString]]];
	
	if ([[trash_files objectAtIndex: idx] icon] != nil)
	{
		[fileIcon setImage: [[trash_files objectAtIndex: idx] icon]];
	}
    
	[pEraser setStandardOutput:pipe];
	[pEraser setStandardError:pipe];
	handle = [pipe fileHandleForReading];
	
	NSDictionary *fileAttributes = [fm fileAttributesAtPath: [[trash_files objectAtIndex: idx] path] traverseLink:NO];
	
	// If it is a directory or empty file, add 100 since it doesn't delete like normal files
	// Note: Might want to reconsider incrementing at all since files of 0 size normally wouldn't add anything 
	// to the progress bar...
	if (([[trash_files objectAtIndex: idx] isDirectory] == YES) && ([[trash_files objectAtIndex: idx] isPackage] == NO))
	{
		[indicator incrementBy: 100.0];
	}
	else if ([[fileAttributes objectForKey:NSFileSize] intValue] == 0) // file is 0K in size
	{
		[indicator incrementBy: 100.0];
	}
	
	[pEraser launch];
	
	[NSThread detachNewThreadSelector: @selector(outputData:) toTarget: self withObject: handle];
}

// =========================================================================
// (void) outputData: (NSFileHandle *) current_handle
// -------------------------------------------------------------------------
// Direct the output data sent from the task to be read by the program
// -------------------------------------------------------------------------
// Created: 25 October 2005 19:14
// Version: 17 August 2011 18:16
// =========================================================================
- (void) outputData: (NSFileHandle *) current_handle
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSData *data;
	int lastPercentage = 0;
	int currentPercentage = 0;
	unsigned long long currentFileSize = [[trash_files objectAtIndex: idx] filesize];
    unsigned long long numberOfFiles = [[trash_files objectAtIndex: idx] numberOfFiles];
	
	// Catch NSFileHandleOperationException which occurred when trying to erase symlinks
	@try 
	{
	
		while ( ([data=[current_handle availableData] length] > 0) && (totalFilesSize != 0) )
		{
			NSString *string = [[NSString alloc] initWithData:data encoding: NSASCIIStringEncoding];
            // Strip whitespace and newline characters
			NSString *modifiedString = [[NSString alloc] initWithString: [string stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            // NSLog(@"PE:: modifiedString: %@", modifiedString);
            
            // There are casese where there might be multiple lines being sent, so perhaps it would make more sense to
            // check the currentPercentage by either the last value (e.g. 50%, 75%, 100%).
			NSArray *splitString = [modifiedString componentsSeparatedByString: @"%"];
			
            // Crash mentions index 1 trying to access an array beyond the bounds [0...0]
            
            // Seeing an occasional crash which is resulting in an out of array bounds issue.  Probably happening here.
            if ([splitString count] > 0)
            {
                currentPercentage = [[splitString objectAtIndex: 0] intValue];
                // NSLog(@"PE:: currentPercentage: %d", currentPercentage);
            }
            else 
            {
                // NSLog(@"PE:: Error!  splitString is empty!");
            }

            if (string != nil)
            {
                [string release];
            }
            
            if (modifiedString != nil)
            {
                [modifiedString release];
            }
			
            // unsigned long long numberOfFiles = [[trash_files objectAtIndex: idx] numberOfFiles];
            
            // Probably should not call updateIndicator here since it is also updating the fileSizeMsg,
            // but update the updateIndicator call to use GCD so other places which do call it
            // will have the updated method.
            
            // What if I changed this to dispatch_sync, instead?  Would that fix the crashing?
            // Is this only crashing near the end, or is it random?
            // Why do I seem to see this more often on Mojave and Catalina?
            dispatch_sync(dispatch_get_main_queue(), ^{
                // If it is an application, need to keep in mind there are extra files inside, so taking the currentFileSize won't work.
                if (currentPercentage >= lastPercentage)
                {
                    [indicator incrementBy: (currentPercentage - lastPercentage) * currentFileSize/numberOfFiles];
                    [indicator displayIfNeeded];
                }
                else
                {
                    [indicator incrementBy: (100 - currentPercentage) * currentFileSize/numberOfFiles];
                    [indicator displayIfNeeded];
                }
                
                [fileSizeMsg setStringValue: [[[fm formatFileSize: ([indicator doubleValue] / [indicator maxValue]) *totalFilesSize] stringByAppendingString: NSLocalizedString(@"Of", nil)] stringByAppendingString: [fm formatFileSize: (double)totalFilesSize]]];
			});
            
			[badge badgeApplicationDockIconWithProgress:([indicator doubleValue] / [indicator maxValue]) insetX:2 y:0];
			
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
	
	}
	@catch (NSException *exception) 
	{
		NSLog(@"PE:: Exception name: %@ Reason: %@", [exception name], [exception reason]);
	}
	@finally 
	{
	}
	
    [pool release];
	
	[NSThread exit];
}


// =========================================================================
// - (void) updateIndicator: (double) delta
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 21 June 2020 10:52
// Version: 21 June 2020 10:52
// =========================================================================
- (void) updateIndicator: (double) delta
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [indicator incrementBy:delta];
        [indicator displayIfNeeded];
    });
}


// =========================================================================
// - (void) updateApplicationBadge
// -------------------------------------------------------------------------
// This method has been deprecated and replaced with the CTProgressBadge
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


/*	
	float size = 16.0;
	float scaleFactor = size/16;
	float stroke = 2*scaleFactor;	//native size is 16 with a stroke of 2
	float shadowBlurRadius = 1*scaleFactor;
	float shadowOffset = 1*scaleFactor;
	float shadowOpacity = .3;	
	
	[NSGraphicsContext saveGraphicsState];
		NSShadow *theShadow = [[NSShadow alloc] init];
		[theShadow setShadowOffset: NSMakeSize(0,-shadowOffset)];
		[theShadow setShadowBlurRadius:shadowBlurRadius];
		[theShadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:shadowOpacity]];
		[theShadow set];
		[theShadow release];
		[[NSColor orangeColor] set];
		[[NSBezierPath bezierPathWithOvalInRect:r] fill];
	[NSGraphicsContext restoreGraphicsState];	
	
	[[NSColor whiteColor] set];
	//NSBezierPath *slice = [NSBezierPath bezierPath];
	[bp2 moveToPoint:NSMakePoint(NSMidX(r),NSMidY(r))];
	[bp2 appendBezierPathWithArcWithCenter:NSMakePoint(NSMidX(r),NSMidY(r)) radius:NSHeight(r)/2-stroke startAngle:90 endAngle:end_angle clockwise:NO];	
//	[bp2 appendBezierPathWithArcWithCenter:NSMakePoint(NSMidX(r),NSMidY(r)) radius:NSHeight(r)/2-stroke startAngle:90 endAngle:90-progress*360 clockwise:NO];
	[bp2 moveToPoint:NSMakePoint(NSMidX(r),NSMidY(r))];
	[bp2 fill];
*/	
	
	[icon unlockFocus];
	[NSApp setApplicationIconImage:icon];
	
	// Clean up the icon before the application quits
	if (!registeredForTerminate) 
	{
		registeredForTerminate = YES;
//		[[NSNotificationCenter defaultCenter] addObserver:self 
//								selector:@selector(appWillTerminateNotification:) 
//								name:NSApplicationWillTerminateNotification 
//								object:NSApp];
	}

}


#pragma mark -
#pragma mark File Methods

// =========================================================================
// (NSString *) fileNameString
// -------------------------------------------------------------------------
// If a file name is too long (over the length of the eraseMsg field), 
// the entire string will not print properly in the text field in the 
// interface.  This checks if the file name exceeds the length limit, and
// if so, then it puts an ellipse (ellipsis) in the middle of the file name
// to abridge it.
// -------------------------------------------------------------------------
// Created: 2. April 2004 1:05
// Version: 16 March 2012 20:10
// =========================================================================
- (NSString *) fileNameString
{
	return ([[trash_files objectAtIndex: idx] fileName]);
	
	/*
	 // Deprecated code.  Just use IB to truncate the end of the text field
    NSMutableString *current_file_name = [[NSMutableString alloc] initWithString: [[trash_files objectAtIndex: idx] fileName]];
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
        [dict release];
		
        return (NSString *)current_file_name;
    }
	 */
	
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
	BOOL isWritable = YES;
	
	if ( ((fd = open(cpath, O_WRONLY)) == -1) && (errno == EACCES) ) 
	{
		if ( chmod(cpath, S_IRUSR | S_IWUSR) == -1 ) 
		{
			isWritable = NO;
		}
	}

	close(fd);
	
	return isWritable;
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
	NSArray *volumesList = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	
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
// This method returns the file system type name.  This has been updated so
// it should return any potential value, not just known types such as
// hfs, nfs, ufs, msdos, afpfs, webdav, cddafs, smbfs, cifs, cd9660,
// udf, ncp, etc.  There is always the possibility of new or rare file systems
// such as the new Apple File System (apfs).
// 
// Portions of this code by Tjark Derlien and the CocoaTechFoundation 
// framework
// (BOOL)getInfoForFile:(NSString *)fullPath application:(NSString **) 
// appName type:(NSString **)type
// 
// NOTE: This appears to be an unused method now.  If used in the future,
// probably should put it into a category or other helper utility.
// -------------------------------------------------------------------------
// Created: 4 December 2005 14:17
// Version: 21 January 2018 16:04
// =========================================================================
- (NSString *) volumeType: (NSString *) volumePath
{
	struct statfs stat;
	
	if (statfs([volumePath fileSystemRepresentation], &stat) == 0)
	{
		NSString *fileSystemName = [fm stringWithFileSystemRepresentation: stat.f_fstypename length: strlen(stat.f_fstypename)];
		
		// Check that the fileSystemName is not nil or an empty string
		if ([fileSystemName length] != 0) 
		{	// return the file system type
			return fileSystemName;
		}
		else
		{
			// If fileSystemName is nil or an empty string, return an empty string
			return @"";
		}
	}
	else
	{
		return @"";
	}
}


// =========================================================================
// (NSString *) bsdDevNode: (NSString *) volumePath
// -------------------------------------------------------------------------
// Return the "parent" BSD node name of a CD-RW/DVD-RW.  If the BSD name
// is "/dev/disk3s1s2", this method will return "disk3"
// Here's another interesting bit of code, that wasn't used, but somewhat
// similar idea to what was done in this method.
// http://snipplr.com/view/1645/given-a-mount-path-retrieve-a-usb-device-name/
// -------------------------------------------------------------------------
// Created: 1 March 2007 21:16
// Version: 17 August 2011 18:06
// =========================================================================
- (NSString *) bsdDevNode: (NSString *) volumePath
{
	struct statfs devStats;
	
	statfs([volumePath UTF8String], &devStats);
	
	NSString *bsdNodePath = [[[NSString alloc] initWithUTF8String:devStats.f_mntfromname] autorelease];
	
	return ([[bsdNodePath lastPathComponent] substringToIndex:5]);
}

#pragma mark -
#pragma mark Shutdown methods

// =========================================================================
// (void) doneErasing: (NSNotification *)aNotification
// -------------------------------------------------------------------------
// When a file is deleted, a notification is called which brings up this
// function.  If there are still files left to process in trash_files, 
// recursively run through the remainder 
// -------------------------------------------------------------------------
// Created: 2. June 2003 14:20
// Version: 14 December 2009 22:00
// =========================================================================
- (void) doneErasing: (NSNotification *)aNotification 
{
    idx++; // increment the counter here to prevent out of bound array errors

    if (idx >= num_files)  // Jobs are complete.  Quit the app.
    {
        if (filesWereDropped == NO)
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
        
            [currentDirectory release];
            [volumes release];
        
        }
        
        [self shutdownPE];
    }
    else
    {
		if ([aNotification object] == nil)	// Sent after erasing an optical disc or STPrivilegedTask
		{
			[cancelButton setEnabled:YES];
			[cancelMenuItem setEnabled:YES];
		}
		else
		{
			if (handle != nil)
			{
				[handle closeFile];
				handle = nil;
			}
			
			if (pipe != nil)
			{
				[pipe release];
				pipe = nil;
			}
			
			if (pEraser != nil)
			{
				[pEraser release];
				pEraser = nil;
			}
			
        }
		
        [self selectNextFile];
    }
}


// =========================================================================
// (void) privilegedTaskFinished: (NSNotification *) aNotification
// -------------------------------------------------------------------------
// Notification method which is called after a STPrivilegedTask completes.
// Release the privilegedTask and then call doneErasing which will then
// move on to the next set of steps.
// -------------------------------------------------------------------------
// Version: 26 March 2018 21:44
// =========================================================================
- (void) privilegedTaskFinished: (NSNotification *) aNotification 
{	
	if (privilegedTask != nil) 
	{
		[privilegedTask release];
		privilegedTask = nil;
	}
	
	[self doneErasing:nil];
}


// =========================================================================
// (IBAction) cancelErasing: (id) sender
// -------------------------------------------------------------------------
// This is called when the Cancel button (or ESC key) is pressed.
// -------------------------------------------------------------------------
// Created: 10. October 2003 1:32
// Version: 13 December 2014 19:36
// =========================================================================
- (IBAction) cancelErasing: (id) sender
{
	[cancelButton setEnabled:NO];
	
	if (preparationThread != nil && [preparationThread isExecuting] == YES)
	{
		[preparationThread cancel];
		
		// An alternative method might be to periodically check the state of the 
		// thread in the preparingFiles method, and shutting down if the thread 
		// has been marked as cancelled, but that could potentially take more time
		// rather than just shutting down at this point.
		[preparationThread release], preparationThread = nil;
		wasCanceled = YES;
		
		// TODO: If the alert dialog is starting to drop down, dismiss it
		
		if ([[NSThread currentThread] isMainThread] == NO)
		{
			[self performSelectorOnMainThread:@selector(shutdownPE) withObject:nil waitUntilDone:NO];
		}
		else
		{
			[self shutdownPE];
		}
	}
	else // Stop erasing files
	{
		idx = num_files;
		wasCanceled = YES;
		
		if (pEraser != nil)
		{
			[pEraser terminate];
		}
	}
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
// Version: 14 December 2009 22:00
// =========================================================================
- (void) shutdownPE
{
    // Completely fill the progress bar, in case of any odd inaccuracies
	// Mac OS 10.2 sometimes has problems completely filling the bar at times,
	// but do not fill it completely if erasing was canceled.
	if (([indicator doubleValue] < [indicator maxValue]) && wasCanceled == NO)
	{
		[self updateIndicator: [indicator maxValue] - [indicator doubleValue]];
	}
	
	if (beepBeforeTerminating == YES)
	{
		// If there are no files to erase, give the warning 'funk' sound
		if ( idx == 0 && [fm fileExistsAtPath: @"/System/Library/Sounds/Funk.aiff"] == YES ) 
		{
			NSSound *emptySound = [[[NSSound alloc] initWithContentsOfFile: @"/System/Library/Sounds/Funk.aiff" byReference: YES] autorelease];
			[emptySound setDelegate:self];
			[emptySound play];
		}
		// For Mac OS 10.7 Lion
		else if ( [fm fileExistsAtPath: @"/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/finder/empty trash.aif"] == YES )
		{
			NSSound *emptyTrashSound = [[[NSSound alloc] initWithContentsOfFile: @"/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/finder/empty trash.aif" byReference: YES] autorelease];
			[emptyTrashSound setDelegate:self];
			[emptyTrashSound play];
		}
		// Pre-Lion Empty Trash sound location
		else if ( [fm fileExistsAtPath: @"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/finder/empty trash.aif"] == YES )
		{
			NSSound *emptyTrashSound = [[[NSSound alloc] initWithContentsOfFile: @"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/finder/empty trash.aif" byReference: YES] autorelease];
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


#pragma mark -
#pragma mark General menu methods

// =========================================================================
// (BOOL) validateMenuItem: (NSMenuItem*) menuItem
// -------------------------------------------------------------------------
// Validate the menu items whether they should be enabled or not.
// This case is only for the Preferences menu item, which should be disabled
// when either the privileged task is running or a disc is being erased, 
// since those particular tasks cannot be paused while in operation.
// -------------------------------------------------------------------------
// Created: 8 April 2018 16:50
// Version: 8 April 2018 16:50
// =========================================================================
- (BOOL) validateMenuItem: (NSMenuItem*) menuItem
{
    SEL action = [menuItem action];
	
    if (action == @selector(openPreferences:)) {
		if ((privilegedTask != nil) &&  ([privilegedTask isRunning] == YES)) {
			return NO;
		} else if (isCurrentlyErasingDisc == YES) {
			return NO;
		} else {
			return YES;
		}
    } 
	
	return [menuItem isEnabled];
}

// =========================================================================
// (IBAction) openPreferences: (id) sender
// -------------------------------------------------------------------------
// Show the Preferences window
// -------------------------------------------------------------------------
// Created: 13 June 2010 14:18
// Version: 30 December 2010 13:11
// =========================================================================
- (IBAction) openPreferences: (id) sender
{
	// What if a disc is getting erased, then the NSTask isn't being used...
	if ((pEraser != nil) && ([pEraser isRunning] == YES))
	{
		BOOL suspendResult = [pEraser suspend]; // returns YES if successful
		
		if (NO == suspendResult)
		{
			// error: wasn't able to suspend the task
			NSLog(@"Error suspending erasing task.");
		} 
		else
		{
			[PreferencesController sharedWindowController];
		}
	}
	else if ((privilegedTask != nil) &&  ([privilegedTask isRunning] == YES))
	{	// Cannot suspend a privileged task while it is running
		NSLog(@"Cannot open Preferences while this privileged task is running.");
	}			 
	else if (isCurrentlyErasingDisc == YES)
	{
		// Do not open Preferences if a disc is being erased.
		NSLog(@"Cannot open Preferences while a disc is being erased.");
	}
	else
	{
		[PreferencesController sharedWindowController];
	}
}


// =========================================================================
// - (void) preferencesClosed
// -------------------------------------------------------------------------
// Called after Preferences window closes
// -------------------------------------------------------------------------
// Created: 16 July 2010 21:36
// Version: 11 January 2011 15:40
// =========================================================================
- (void) preferencesClosed
{
	// If the NSTask was paused, tell it to resume
	if ([pEraser isRunning] == YES)
	{
		BOOL resumeResult = [pEraser resume];
		
		if (NO == resumeResult)
		{	// Error resuming NSTask
		}
	}

	prefs = [[NSUserDefaults standardUserDefaults] retain];
	
	if ([prefs objectForKey:@"BeepBeforeTerminating"] != nil)
	{
		beepBeforeTerminating = [prefs boolForKey:@"BeepBeforeTerminating"];
	}
	else
	{
		beepBeforeTerminating = YES;
	}
	
	if ([prefs objectForKey: @"OpticalDiscErasingLevel"] != nil)
	{
		[discErasingLevel setString: [prefs objectForKey: @"OpticalDiscErasingLevel"]];
	}
	else
	{
		discErasingLevel = [[NSMutableString alloc] initWithString:@"Complete"];
	}
	
	if ([prefs objectForKey: @"FileErasingLevel"] != nil)
	{
		[fileErasingLevel setString: [prefs objectForKey: @"FileErasingLevel"]];
	}
	else
	{
		// Assign a default fileErasingLevel
	}
}

// =========================================================================
// (IBAction) goToProductPage: (id) sender
// -------------------------------------------------------------------------
// Open a web browser to go to the product web page
// -------------------------------------------------------------------------
// Created: 30 December 2007 22:31
// Version: 30 December 2007 22:31
// =========================================================================
- (IBAction) goToProductPage: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://www.edenwaith.com/products/permanent%20eraser/"]];
}


// =========================================================================
// (IBAction) sendFeedback: (id) sender
// -------------------------------------------------------------------------
// Send feedback to the support e-mail
// -------------------------------------------------------------------------
// Created: 30 December 2007 22:31
// Version: 30 December 2007 22:31
// =========================================================================
- (IBAction) sendFeedback: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"mailto:support@edenwaith.com?subject=Permanent%20Eraser%20Feedback"]];
}

@end
