//
//  Permanent_EraserPref.h
//  Permanent Eraser
//
//  Created by Chad Armstrong on 2/20/07.
//  Copyright (c) 2007 Edenwaith. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>


@interface Permanent_EraserPref : NSPreferencePane 
{
	NSUserDefaults			*prefs;
	CFStringRef				appID;
	NSMutableString			*lastCheckedDate;
	IBOutlet NSPopUpButton	*fileErasingButton;
	IBOutlet NSPopUpButton	*discErasingButton;
	IBOutlet NSButton		*warningCheckBox;
	IBOutlet NSTextField	*lastCheckedTextField;

}

- (id) initWithBundle: (NSBundle *) bundle;
- (void) mainViewDidLoad;

- (IBAction) warningBoxClicked: (id) sender;
- (IBAction) fileErasingSelected: (id) sender;
- (IBAction) discErasingSelected: (id) sender;

- (IBAction) checkForNewVersion: (id) sender;
- (IBAction) openHelp: (id) sender;

@end
