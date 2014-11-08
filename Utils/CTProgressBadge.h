//
//  CTProgressBadge.m
//  CTProgressBadge
//
//  Created by Chad Weider on 7/28/06.
//  Written by Chad Weider.
//  
//  Released into public domain on 4/10/08.
//
//  Version: 1.0

#import <Cocoa/Cocoa.h>


@interface CTProgressBadge : NSObject
  {
  NSColor *foregroundColor;
  NSColor *backgroundColor;
  }

+ (CTProgressBadge *)systemBadge;
+ (CTProgressBadge *)badgeWithForeGroundColor:(NSColor *)foregroundColor backgroundColor:(NSColor *)backgroundColor;

- (NSImage *)progressBadgeOfSize:(float)size withProgress:(float)progress;

- (NSImage *)badgeOverlayImageWithProgress:(float)progress insetX:(float)dx y:(float)dy;		//Returns a transparent 128x128 image
																							//  with Large badge inset dx/dy from the upper right
- (void)badgeApplicationDockIconWithProgress:(float)progress insetX:(float)dx y:(float)dy;		//Badges the Application's icon with <value>
																							//	and puts it on the dock

- (void)setForegroundColor:(NSColor *)theColor;					//Sets the color used on badge
- (void)setBackgroundColor:(NSColor *)theColor;					//Sets the color 


@end
