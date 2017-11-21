//
//  PreferencesController.h
//  PermanentEraser
//
//  Created by Administrator on 6/16/10.
//  Copyright 2010 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PEController.h"
#import "NSFileManager+Utils.h"

@interface PreferencesController : NSWindowController 
{
	IBOutlet NSView *generalPreferenceView;
	IBOutlet NSView *updatePreferenceView;
	IBOutlet NSView *pluginsPreferenceView;
	IBOutlet NSView *activeContentView;
	
	id		toolbar;
	
	IBOutlet NSPopUpButton	*fileErasingButton;
	IBOutlet NSPopUpButton	*opticalDiscErasingButton;
	IBOutlet NSTextField	*fileErasingLabel;
	IBOutlet NSTextField	*discErasingLabel;
	IBOutlet NSButton		*warnBeforeErasingButton;
	IBOutlet NSButton		*playSoundsButton;
	
	IBOutlet NSButton		*checkNowButton;
	IBOutlet NSTextField	*lastCheckedLabel; // Label which says: "Last checked:"
	IBOutlet NSTextField	*lastCheckedTextField;
	
	IBOutlet NSButton		*pluginInstalledButton;
	IBOutlet NSTextField	*pluginMsgField;
	NSString				*pluginPath;
}

+ (PreferencesController *) sharedWindowController;
//+ (PreferencesController *) sharedWindowControllerWithDelegate: (id) delegate;
+ (NSString *) nibName;

- (void) prefWindowClosed: (NSNotification *) aNotification;
- (void) loadSettings;

- (void)togglePreferenceView:(NSString *)identifier;
- (void)toggleActivePreferenceView:(id)sender;
- (void)setActiveView:(NSView *)view animate:(BOOL)flag;

- (IBAction) fileErasingLevelSelected: (id) sender;
- (IBAction) opticalDiscErasingLevelSelected: (id) sender;
- (IBAction) warnBeforeErasingSelected: (id) sender;
- (IBAction) playSoundsSelected: (id) sender;

- (IBAction) checkForNewVersion: (id) sender;
- (NSString *) formatLocalizedDate: (NSDate *) theDate;

- (IBAction) installPluginSelected: (id) sender;
- (void) removeOldPlugin;
- (NSString *) displayLocalizedPath: (NSString *) path;
- (IBAction) openHelpPage: (id) sender;

@end
