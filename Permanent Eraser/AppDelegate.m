//
//  AppDelegate.m
//  Permanent Eraser
//
//  Created by Chad Armstrong on 6/4/18.
//  Copyright © 2018 Edenwaith. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSMenu *statusMenu;
@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem *statusBarItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
	self.isCurrentlyErasing = NO;
	[self setupStatusBarItem];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

#pragma mark - tatus Menu Methods

- (void)setupStatusBarItem
{
	self.statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	[self.statusBarItem setImage:[NSImage imageNamed:@"full_trash"]];
	[self.statusBarItem setAlternateImage:[NSImage imageNamed:@"full_trash_alt"]];
	[self.statusBarItem setHighlightMode:YES];
	
	[self.statusBarItem setMenu:self.statusMenu];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	if ([item action] == @selector(eraseTrash:)) {
		return (!self.isCurrentlyErasing);
	}
	
	if ([item action] == @selector(eraseFiles:)) {
		return YES;
	}
	
	return YES;
}

- (IBAction)eraseTrash:(id)sender
{
	[self.statusBarItem setImage:[NSImage imageNamed:@"empty_trash"]];
	[self.statusBarItem setAlternateImage:[NSImage imageNamed:@"empty_trash_alt"]];
	self.isCurrentlyErasing = YES;
}

- (IBAction)eraseFiles:(id)sender
{
	self.isCurrentlyErasing = NO;
	
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
