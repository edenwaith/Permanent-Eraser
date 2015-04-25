//
//  PEAppDelegate.m
//  Permanent Eraser
//
//  Created by Chad Armstrong on 10/13/14.
//  Copyright 2014 Edenwaith. All rights reserved.
//

#import "PEAppDelegate.h"

@implementation PEAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
	isCurrentlyErasing = NO;
	[self setupStatusBarItem];

}

- (void)dealloc
{
	[super dealloc];
}

#pragma mark -
#pragma mark Status Menu Methods

- (void)setupStatusBarItem
{
	statusBarItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	[statusBarItem setImage:[NSImage imageNamed:@"full_trash"]];
	[statusBarItem setAlternateImage:[NSImage imageNamed:@"full_trash_alt"]];
	[statusBarItem setHighlightMode:YES];
	
	[statusBarItem setMenu:statusMenu];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	if ([item action] == @selector(eraseTrash:)) {
		return (!isCurrentlyErasing);
	}
	
	if ([item action] == @selector(eraseFiles:)) {
		return YES;
	}
	
	return YES;
}

- (IBAction)eraseTrash:(id)sender
{
	[statusBarItem setImage:[NSImage imageNamed:@"empty_trash"]];
	[statusBarItem setAlternateImage:[NSImage imageNamed:@"empty_trash_alt"]];
	isCurrentlyErasing = YES;
}

- (IBAction)eraseFiles:(id)sender
{
	isCurrentlyErasing = NO;
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    int result = 0;
    
    [openPanel setCanChooseDirectories:YES];
    
    result = [openPanel runModalForDirectory:nil file:nil types:nil];
    
    if (result == NSOKButton) 
    {

    } 
}

- (IBAction)openPreferences:(id)sender
{
	
}


- (IBAction)permanentEraserWebsite:(id)sender
{
	
}

- (IBAction)sendFeedback:(id)sender
{
	
}

- (IBAction)quitApplication:(id)sender
{
	[NSApp terminate:self];
}


@end
