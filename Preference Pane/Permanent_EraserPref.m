//
//  Permanent_EraserPref.m
//  Permanent Eraser
//
//  Created by Chad Armstrong on 2/20/07.
//  Copyright (c) 2007 Edenwaith. All rights reserved.
//

#import "Permanent_EraserPref.h"


@implementation Permanent_EraserPref

// Created: 26 July 2007 22:04
// Version: 1 August 2007
- (id) initWithBundle: (NSBundle *) bundle
{
	if ((self = [super initWithBundle:bundle]) != nil)
	{
		appID = CFSTR("com.edenwaith.permanenteraser");
		// prefs = [[NSUserDefaults standardUserDefaults] retain];
	}
	
	return self;
}


// =========================================================================
// (void) mainViewDidLoad
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Version: 3 August 21:55
// =========================================================================
- (void) mainViewDidLoad
{

	CFPropertyListRef warningValue;
	CFPropertyListRef discErasingLevel;
	CFPropertyListRef fileErasingLevel;
	
	warningValue = CFPreferencesCopyAppValue(CFSTR("WarnBeforeErasing"), appID);
	discErasingLevel = CFPreferencesCopyAppValue(CFSTR("DiscErasingLevel"), appID);
	fileErasingLevel = CFPreferencesCopyAppValue(CFSTR("FileErasingLevel"), appID);

	
	if (warningValue && CFGetTypeID(warningValue) == CFBooleanGetTypeID())
	{
		[warningCheckBox setState: CFBooleanGetValue(warningValue)];
	}
	else
	{
		[warningCheckBox setState: YES];
	}

	NSLog(@"discErasingLevel: %@", (NSString *)discErasingLevel);
	// NSRunAlertPanel(@"Hi",(NSString *)discErasingLevel,@"OK",nil, nil);

    if (discErasingLevel && ( CFGetTypeID(discErasingLevel) == CFStringGetTypeID() ) && ( [discErasingButton itemWithTitle: (NSString *)discErasingLevel] != nil ) )
    {
    
        [discErasingButton selectItemWithTitle: (NSString *)discErasingLevel];
    
    }
    else
    {
        [discErasingButton selectItemWithTitle: @"Complete"];
    }
	
	
    if (fileErasingLevel && ( CFGetTypeID(fileErasingLevel) == CFStringGetTypeID() ) && ( [fileErasingButton itemWithTitle: (NSString *)fileErasingLevel] != nil ) )
    {
    
        [fileErasingButton selectItemWithTitle: (NSString *)fileErasingLevel];
    
    }
    else
    {
        [fileErasingButton selectItemWithTitle: @"Gutmann (35x)"];
    }
	

//	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
//	[defaults addSuiteNamed:@"com.edenwaith.permanenteraser"];
//   NSLog (@"Path: %@", [[defaults objectForKey:@"iTunesRecentDatabasePaths"] objectAtIndex:0]);

//	if ([prefs objectForKey:@"WarnBeforeErasing"] != nil)
//	{
//		if ([prefs boolForKey:@"WarnBeforeErasing"] == NO)
//		{
//			[warningCheckBox setState: NO];
//		}
//		else
//		{
//			[warningCheckBox setState: YES];
//		}
//	}
//	else
//	{
//		[warningCheckBox setState: NO];
//	}
	


	// com.edenwaith.permanenteraser
	// This might be trying to open com.apple.systempreferences.plist
//	prefs = [[NSUserDefaults standardUserDefaults] retain];
//	[prefs addSuiteNamed: @"com.edenwaith.permanenteraser"];
//	
//	if ([prefs objectForKey: @"WarnBeforeErasing"] != nil) // && ( [compressionFileTypes containsObject: [NSUnarchiver unarchiveObjectWithData:textAsData]] == YES ) )
//    {
//		if ([prefs boolForKey:@"WarnBeforeErasing"] == YES)
//		{
//			[warningCheckBox setState:NSOnState];
//		}
//		else
//		{
//			[warningCheckBox setState:NSOffState];
//		}
//        // [compression_type selectItemWithTitle: [NSUnarchiver unarchiveObjectWithData:textAsData]];
//    
//    }
//    else
//    {
//		[warningCheckBox setState:NSOnState];
//        // [compression_type selectItemWithTitle: @"tgz"];
//    }
	
	// [prefs setBool:NO forKey: @"FooBar"];
	
}

// =========================================================================
// (IBAction) warningBoxClicked: (id) sender
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 17 July 2007 20:53
// Version: 1 August 2007
// =========================================================================
- (IBAction) warningBoxClicked: (id) sender
{
	// NSRunAlertPanel(@"Hi",@"Test message!",@"OK",nil, nil);
	CFPreferencesSetAppValue(CFSTR("WarnBeforeErasing"), [sender state] ? kCFBooleanTrue : kCFBooleanFalse, appID);
//	if ([sender state] == NSOnState)
//		[prefs setBool:YES forKey: @"WarnBeforeErasing"];
//	else
//		[prefs setBool:NO forKey: @"WarnBeforeErasing"];
	
	// Synchronize the preferences
//	[prefs synchronize];
	CFPreferencesAppSynchronize(appID);
}

// =========================================================================
// (IBAction) fileErasingSelected: (id) sender
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 29 July 2007 17:52
// Version: 1 August 2007 22:26
// =========================================================================
- (IBAction) fileErasingSelected: (id) sender
{
	// NSData *textAsData = [NSArchiver archivedDataWithRootObject: [sender titleOfSelectedItem]];
    // [prefs setObject:textAsData forKey: @"DiscErasingLevel"];
	
	CFPreferencesSetAppValue(CFSTR("FileErasingLevel"), [sender titleOfSelectedItem] , appID);
	CFPreferencesAppSynchronize(appID);
}


// =========================================================================
// (IBAction) discErasingSelected: (id) sender
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 29 July 2007 17:52
// Version: 1 August 2007 22:24
// =========================================================================
- (IBAction) discErasingSelected: (id) sender
{
	// NSData *textAsData = [NSArchiver archivedDataWithRootObject: [sender titleOfSelectedItem]];
    // [prefs setObject:textAsData forKey: @"DiscErasingLevel"];
	
	CFPreferencesSetAppValue(CFSTR("DiscErasingLevel"), [sender titleOfSelectedItem] , appID);
	CFPreferencesAppSynchronize(appID);
}


// =========================================================================
// (IBAction) checkForNewVersion: (id) sender
// -------------------------------------------------------------------------
// Added some new code to check if there is no network connection present.
// This resulted when the !%@# network went down at my house.  I learned
// something, but I still want my internet!  Screw MTV!  I want the Internet!
// -------------------------------------------------------------------------
// Created: 11 July 2007 20:42
// Version: 11 July 2007 20:42
// =========================================================================
- (IBAction) checkForNewVersion: (id) sender
{
    //NSString *currentVersionNumber = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *currentVersionNumber = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSDictionary *productVersionDict = [NSDictionary dictionaryWithContentsOfURL: [NSURL URLWithString:@"http://www.edenwaith.com/version.xml"]];
    NSString *latestVersionNumber = [productVersionDict valueForKey:@"Permanent Eraser"];
    int button = 0;

	// [lastCheckedTextField setStringValue:[[NSDate date] dateWithString: @"2002-01-17 22:38:14 +0000"]];
	[lastCheckedTextField setStringValue: [[NSDate date] descriptionWithLocale:  [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]] ];
//	[lastCheckedTextField setStringValue: [[NSCalendarDate calendarDate] descriptionWithLocale:  [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]] ];
    if ( latestVersionNumber == nil )
    {
        NSBeep();
        NSRunAlertPanel(@"Could not check for update", @"A problem arose while attempting to check for a new version of Permanent Eraser.  Edenwaith.com may be temporarily unavailable or your network may be down.", @"OK", nil, nil);
    }
    else if ( [latestVersionNumber isEqualTo: currentVersionNumber] )
    {
        NSRunAlertPanel(@"Software is Up-To-Date", @"You have the most recent version of Permanent Eraser.", @"OK", nil, nil);
    }
    else
    {
        // NSLog(@"%@ %@", currentVersionNumber, latestVersionNumber);
        //button = NSRunAlertPanel(@"New Version is Available", @"A new version of GUI Tar is available.", @"OK", @"Cancel", nil);
        button = NSRunAlertPanel(@"New Version is Available", @"Version %@ of Permanent Eraser is available.", @"Download", @"Cancel", @"More Info", latestVersionNumber);
        
        if (NSOKButton == button)
        {
            [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://www.edenwaith.com/downloads/permanent%20eraser.php"]];
        }
        else if (NSAlertOtherReturn == button) // More Info
        {
            [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://www.edenwaith.com/products/permanent%20eraser/index.php"]];
        }
    }
}

// =========================================================================
// (IBAction) openHelp: (id) sender
// -------------------------------------------------------------------------
// The Help system contents are too large for Mac OS 10.1's Help Viewer to
// handle, so a web browser is opened to view the Help files for Mac OS 10.1
// -------------------------------------------------------------------------
// Version: 11 July 2007 20:42
// Created: 11 July 2007 21:04
// =========================================================================
- (IBAction) openHelp: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL fileURLWithPath:[[[NSBundle mainBundle] pathForResource:@"Help" ofType:@""]  stringByAppendingString: @"/index.html"] ] ];
}

@end
