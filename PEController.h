//  PEController.h
//  PermanentEraser
//
//  Created by Chad Armstrong on Mon Jun 02 2003.
//  Copyright (c) 2003-2008 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

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
	NSFileHandle	*handle;
    NSTask			*pEraser;
    NSFileManager 	*fm;  
    NSMutableArray 	*trash_files;
    
    NSTimer			*timer;
    
    BOOL			files_were_dropped;	// were files dropped on the icon?
	BOOL			firstTimeHere;		// indicates first pass through the application
	BOOL			warnBeforeErasing;	// pop up warning message before deleting files
	BOOL			registeredForTerminate;
	BOOL			wasCanceled;
	BOOL			beepBeforeTerminating;
	    
    int				i;					// counter for number of files launched
    int				num_files;			// total number of files to erase
	int				lastPercentageCD;
	
	float			end_angle;			// end angle for drawing the arc in the badge
    
    NSString		*uid;				// User identification number
    NSString		*util_path;
    
    NSMutableDictionary	*dict;
    
    IBOutlet id				theWindow;

    IBOutlet NSTextField	*progress_msg;
	IBOutlet NSTextField	*erasing_msg;
	
	IBOutlet NSButton		*cancelButton;
	IBOutlet NSMenuItem		*cancelMenuItem;

    IBOutlet NSProgressIndicator	*indicator;
	
	NSColor			*color;
	NSImage			*badgeImage;
	NSImage			*originalIcon;
	
	NSPipe			*pipe;
	
	NSUserDefaults	*prefs;
	
}

- (void) appWillTerminateNotification: (NSNotification *)aNotification;
- (void) applicationDidFinishLaunching: (NSNotification *) aNotification;
- (BOOL) application: (NSApplication *)theApplication openFile: (NSString *)filename;
- (void) addNewFiles : (NSTimer *) aTimer;
- (void) erase;
- (void) selectNextFile;
- (void) eraseDisc;
- (void) eraseNotification: (NSNotification*) notification;
- (void) runTask;
- (void) outputData: (NSFileHandle *) handle;
- (void) updateApplicationBadge;
- (NSString *) currentFileName;
- (NSString *) fileNameString;
- (BOOL) checkPermissions: (NSString *)path;
- (BOOL) containsResourceFork:(NSString *)path;
- (BOOL) isFileSymbolicLink: (NSString *)path;
- (BOOL) isVolume: (NSString *) volumePath;
- (BOOL) isErasableDisc: (NSString *) volumePath;
- (NSString *) volumeType: (NSString *) volumePath;
- (NSString *) bsdDevNode: (NSString *) volumePath;
- (void) doneErasing: (NSNotification *)aNotification;
- (IBAction) cancelErasing: (id) sender;
- (IBAction) goToProductPage: (id) sender;
- (IBAction) sendFeedback: (id) sender;
- (void) sound: (NSSound *) sound didFinishPlaying: (BOOL) aBool;
- (void) shutdownPE;

@end
