//  PEController.h
//  PermanentEraser
//
//  Created by Chad Armstrong on Mon Jun 02 2003.
//  Copyright (c) 2003-2015 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

#import "PEFile.h"
#import "CTProgressBadge.h"
#import "NSProcessInfo+PECocoaBackports.h"

#include <unistd.h>		// required to retrieve uid
#include <sys/param.h>
#include <sys/mount.h>	// required for statfs
#include <sys/types.h>
// Next three libraries required for the checkPermissions method
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>


@interface PEController : NSObject
{
    NSTask			*pEraser;
    NSFileManager 	*fm;  
    NSMutableArray 	*trash_files;
	NSFileHandle	*handle;
    
    NSTimer			*timer;
    
    BOOL			filesWereDropped;	// were files dropped on the icon?
	BOOL			firstTimeHere;		// indicates first pass through the application
	BOOL			warnBeforeErasing;	// pop up warning message before deleting files
	BOOL			suppressCannotEraseWarning;	// whether to display warning when a file can't be erased
	BOOL			registeredForTerminate;
	BOOL			wasCanceled;
	BOOL			beepBeforeTerminating;
	BOOL			isCurrentlyErasingDisc;		// flag to determine if an optical disc is being erased
	    
    int				idx;				// counter for number of files launched (formerly named 'i')
    int				num_files;			// total number of files to erase -- might need to remove this...
	int				lastPercentageCD;
	unsigned long long	totalFilesSize;
	
	float			end_angle;			// end angle for drawing the arc in the badge
    
    NSString		*uid;				// User identification number
    NSString		*util_path;
	NSMutableString	*discErasingLevel;
	NSMutableString	*fileErasingLevel;
    
    NSMutableDictionary	*dict;
    
    IBOutlet id				theWindow;

	IBOutlet NSTextField	*erasingMsg;
	IBOutlet NSTextField	*fileSizeMsg;
	
	IBOutlet NSImageView	*fileIcon;
	
	IBOutlet NSButton		*cancelButton;
	IBOutlet NSMenuItem		*cancelMenuItem;

    IBOutlet NSProgressIndicator	*indicator;
	
	NSColor			*color;
	NSImage			*badgeImage;
	NSImage			*originalIcon;
	CTProgressBadge *badge;
	
	NSPipe			*pipe;
	NSThread		*preparationThread;
	
	NSUserDefaults	*prefs;
}


- (void) appWillTerminateNotification: (NSNotification *)aNotification;
- (void) applicationDidFinishLaunching: (NSNotification *) aNotification;
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames;
- (void) prepareFiles;
- (void) addFileToArray: (NSString *) filename;
- (unsigned long long) countNumberOfFiles: (NSString *) path;
- (void) checkInstalledPlugins;

- (FSRef) convertStringToFSRef: (NSString *) path ;
- (unsigned long long) fileSize: (NSString *) path;
- (unsigned long long) fastFolderSizeAtFSRef:(FSRef*)theFileRef;
//- (NSString *) formatFileSize: (double) file_size;
- (void) addNewFiles : (NSTimer *) aTimer;
- (void) erase;
- (void) alertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo;
- (void) selectNextFile;
- (void) eraseDisc;
- (void) eraseNotification: (NSNotification*) notification;
- (void) runTask;
- (void) outputData: (NSFileHandle *) handle;
- (void) updateIndicator;
- (void) updateApplicationBadge;

- (NSString *) currentFileName;
- (NSString *) fileNameString;
- (BOOL) checkPermissions: (NSString *)path;
- (BOOL) containsResourceFork:(NSString *)path;
- (BOOL) isVolume: (NSString *) volumePath;
- (BOOL) isErasableDisc: (NSString *) volumePath;
- (NSString *) volumeType: (NSString *) volumePath;
- (NSString *) bsdDevNode: (NSString *) volumePath;
- (BOOL) directoryIsEmpty: (NSString *) path;

- (void) doneErasing: (NSNotification *)aNotification;
- (void) sound: (NSSound *) sound didFinishPlaying: (BOOL) aBool;
- (void) shutdownPE;

- (IBAction) openPreferencePane: (id) sender;
- (IBAction) openPreferences: (id) sender;
- (void) preferencesClosed;
- (IBAction) goToProductPage : (id) sender;
- (IBAction) sendFeedback: (id) sender;
- (IBAction) cancelErasing: (id) sender;


@end
