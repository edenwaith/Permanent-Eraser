//
//  NSEvent+ModifierKeys.h
//  PermanentEraser
//
//  Created by Chad Armstrong on 1/10/07.
//  Copyright 2007 Edenwaith. All rights reserved.
//
//  Code reference: http://www.cocoadev.com/index.pl?TestForKeyDownOnLaunch

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@interface NSEvent (ModifierKeys)

+ (BOOL) isControlKeyDown;
+ (BOOL) isOptionKeyDown;
+ (BOOL) isCommandKeyDown;
+ (BOOL) isShiftKeyDown;

@end