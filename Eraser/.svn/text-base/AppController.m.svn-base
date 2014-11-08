/*
     File:       AppController.m
 
     Contains:   Application delegate class illustrating how to setup and start an erase.
 
     Version:    Technology: Mac OS X
                 Release:    Mac OS X
 
     Copyright:  (c) 2004 by Apple Computer, Inc., all rights reserved
 
     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:
 
                     http://developer.apple.com/bugreporter/
*/
/*
 File:  AppController.m
 
 Copyright:  © Copyright 2004 Apple Computer, Inc. All rights reserved.
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms,
 please do not use, install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
 copyrights in this original Apple software (the "Apple Software"), to use,
 reproduce, modify and redistribute the Apple Software, with or without
 modifications, in source and/or binary forms; provided that if you redistribute
 the Apple Software in its entirety and without modifications, you must retain
 this notice and the following text and disclaimers in all such redistributions of
 the Apple Software.  Neither the name, trademarks, service marks or logos of
 Apple Computer, Inc. may be used to endorse or promote products derived from the
 Apple Software without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or implied,
 are granted by Apple herein, including but not limited to any patent rights that
 may be infringed by your derivative works or by other works in which the Apple
 Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
 WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
 COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
 OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
 (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#import "AppController.h"

#import <DiscRecording/DiscRecording.h>
#import <DiscRecordingUI/DiscRecordingUI.h>

@implementation AppController

/* When the application finishes launching, we'll set up a notification to be sent when the
   erase completes. This notification is sent by the DREraseProgressPanel to observers
   when the erase is 100% finished.
*/
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
	[(NSNotificationCenter *)[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eraseCompleted:) name:DREraseProgressPanelDidFinishNotification object:nil];
	
	[self eraseCompleted:nil];
}

/* Every time the erase completes, put up the erase dialog and let the user pick another
   drive to use for erasing discs. */
- (void) eraseCompleted:(NSNotification*)aNotification
{
	DREraseSetupPanel*	esp = [DREraseSetupPanel setupPanel];
	
	[esp setDelegate:self];

	if ([esp runSetupPanel] == NSOKButton)
	{
		DREraseProgressPanel*	epp = [DREraseProgressPanel progressPanel];

		[epp setDelegate:self];

		[epp beginProgressPanelForErase:[esp eraseObject]];

		/* If you wanted to run this as a sheet you would have done
			[epp beginProgressSheetForErase:[esp eraseObject] modalForWindow:esp];
		*/
	}
	else
		[NSApp terminate:self];
}

/* We're implementing some of these setup panel delegate methods to illustrate what you could do to control a
	erase setup. */
	

/* This delegate method is called when a device is plugged in and becomes available for use. It's also
	called for each device connected to the machine when the panel is first shown. 
	
	Its's possible to query the device and ask it just about anything to determine if it's a device
	that should be used.
	
	Just return YES for a device you want and NO for those you don't. */
- (BOOL) setupPanel:(DRSetupPanel*)aPanel deviceCouldBeTarget:(DRDevice*)device
{
#if 0
	// This bit of code shows how to filter devices bases on the properties of the device
	// For example, it's possible to limit the drives displayed to only those hooked up over
	// firewire, or converesely, you could NOT show drives if there was some reason to. 
	NSDictionary*	deviceInfo = [device info];
	if ([[deviceStatus objectForKey:DRDevicePhysicalInterconnectKey] isEqualToString:DRDevicePhysicalInterconnectFireWire])
		return YES;
	else
		return NO;
#else
	return YES;
#endif
}

/* OK, nothing fancy here. we just want to illustrate that it's possible for a delegate of the 
	progress panel to alter how the erase is handled once it completes. You may want to put up
	your own dialog, sent a notification if you're in the background, or just ignore it no matter what.
	
	We'll just NSLog the fact it finished (for good or bad) and return YES to indicate
	that we didn't handle it ourselves and that the progress panel should continue on its
	merry way. */
- (BOOL) eraseProgressPanel:(DREraseProgressPanel*)theErasePanel eraseDidFinish:(DRErase*)erase
{
	NSDictionary*	eraseStatus = [erase status];
	NSString*		state = [eraseStatus objectForKey:DRStatusStateKey];
	
	if ([state isEqualToString:DRStatusStateFailed])
	{
		NSDictionary*	errorStatus = [eraseStatus objectForKey:DRErrorStatusKey];
		NSString*		errorString = [errorStatus objectForKey:DRErrorStatusErrorStringKey];
		
		NSLog(@"The erase failed (%@)!", errorString);
	}
	else
		NSLog(@"Erase finished fine");
	
	return YES;
}

@end
