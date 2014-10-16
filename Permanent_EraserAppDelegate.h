//
//  Permanent_EraserAppDelegate.h
//  Permanent Eraser
//
//  Created by Chad Armstrong on 10/13/14.
//  Copyright 2014 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Permanent_EraserAppDelegate : NSObject { // <NSApplicationDelegate> {
    NSWindow *window;
	NSStatusItem *statusBarItem;
	IBOutlet NSMenu *statusMenu;
	BOOL isCurrentlyErasing;
}

- (void)setupStatusBarItem;
- (IBAction)eraseTrash:(id)sender;
- (IBAction)eraseFiles:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)permanentEraserWebsite:(id)sender;
- (IBAction)sendFeedback:(id)sender;
- (IBAction)quitApplication:(id)sender;

@end
