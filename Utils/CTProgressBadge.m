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

#import "CTProgressBadge.h"


@implementation CTProgressBadge

- (id)init
{
	self = [super init];
  
	if (self != nil)
	{
		foregroundColor = nil;
		backgroundColor = nil;
		
	//	[self setForegroundColor:[NSColor colorWithDeviceRed:131./255 green:163./255 blue:212./255 alpha:1]];
		[self setForegroundColor: [NSColor orangeColor]];
		[self setBackgroundColor:[NSColor whiteColor]];
	}
	
	return self;
}



- (void)dealloc
  {
  if(foregroundColor != nil)
	[foregroundColor release];
  if(backgroundColor != nil)
    [backgroundColor release];
  [super dealloc];
  }

+ (CTProgressBadge *)systemBadge
  {
  id newInstance = [[[self class] alloc] init];
  
  return [newInstance autorelease];
  }

+ (CTProgressBadge *)badgeWithForeGroundColor:(NSColor *)foregroundColor backgroundColor:(NSColor *)backgroundColor;
  {
  id newInstance = [[[self class] alloc] init];
  
  [newInstance setForegroundColor:foregroundColor];
  [newInstance setBackgroundColor:backgroundColor];
  
  return [newInstance autorelease];
  }
#pragma mark -


#pragma mark Appearance
- (void)setForegroundColor:(NSColor *)theColor;
  {
  if(foregroundColor != nil)
	[foregroundColor release];
  
  foregroundColor = theColor;
  [foregroundColor retain];
  }
- (void)setBackgroundColor:(NSColor *)theColor;
  {
  if(backgroundColor != nil)
	[backgroundColor release];
  
  backgroundColor = theColor;
  [backgroundColor retain];
  }

- (NSColor *)foregroundColor
  {
  return foregroundColor;
  }
- (NSColor *)backgroundColor
  {
  return backgroundColor;
  }
#pragma mark -


#pragma mark Drawing
- (NSImage *)progressBadgeOfSize:(float)size withProgress:(float)progress
  {
  float scaleFactor = size/16;
  float stroke = 1.5*scaleFactor;	//native size is 16 with a stroke of 2
  float shadowBlurRadius = 1*scaleFactor;
  float shadowOffset = 1*scaleFactor;
  
  float shadowOpacity = .4;
  
  NSRect pieRect = NSMakeRect(shadowBlurRadius,shadowBlurRadius+shadowOffset,size,size);
  
  NSImage *progressBadge = [[NSImage alloc] initWithSize:NSMakeSize(size + 2*shadowBlurRadius,
																	size + 2*shadowBlurRadius+1)];
  
  [progressBadge lockFocus];
	  [NSGraphicsContext saveGraphicsState];
		  NSShadow *theShadow = [[NSShadow alloc] init];
		  [theShadow setShadowOffset: NSMakeSize(0,-shadowOffset)];
		  [theShadow setShadowBlurRadius:shadowBlurRadius];
		  [theShadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:shadowOpacity]];
		  [theShadow set];
		  [theShadow release];
			  [foregroundColor set];
			//[[NSColor redColor] set];
			  [[NSBezierPath bezierPathWithOvalInRect:pieRect] fill];
	  [NSGraphicsContext restoreGraphicsState];
	  
		if(progress <= 0)
		{
			[backgroundColor set];
			[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMinX(pieRect)+stroke,NSMinY(pieRect)+stroke,
															   NSWidth(pieRect)-2*stroke,NSHeight(pieRect)-2*stroke)] fill];
		}
		else if(progress < 1)
		{
			[backgroundColor set];
			NSBezierPath *slice = [NSBezierPath bezierPath];
			[slice moveToPoint:NSMakePoint(NSMidX(pieRect),NSMidY(pieRect))];
			[slice appendBezierPathWithArcWithCenter:NSMakePoint(NSMidX(pieRect),NSMidY(pieRect)) radius:NSHeight(pieRect)/2-stroke startAngle:90 endAngle:90-progress*360 clockwise:NO];
			[slice moveToPoint:NSMakePoint(NSMidX(pieRect),NSMidY(pieRect))];
			[slice fill];
		}
  [progressBadge unlockFocus];
  
  return [progressBadge autorelease];
  }

- (NSImage *)badgeOverlayImageWithProgress:(float)progress insetX:(float)dx y:(float)dy
  {
  NSImage *badgeImage = [self progressBadgeOfSize:42 withProgress:progress];
  NSImage *overlayImage = [[NSImage alloc] initWithSize:NSMakeSize(128,128)];
  
  //draw large icon in the upper right corner of the overlay image
  [overlayImage lockFocus];
	  NSSize badgeSize = [badgeImage size];
	  // [badgeImage compositeToPoint:NSMakePoint(128-dx-badgeSize.width,128-dy-badgeSize.height) operation:NSCompositeSourceOver];  
	  [badgeImage compositeToPoint:NSMakePoint(128-dx-badgeSize.width, dy) operation:NSCompositeSourceOver];  
  [overlayImage unlockFocus];
  
  return [overlayImage autorelease];
  }

- (void)badgeApplicationDockIconWithProgress:(float)progress insetX:(float)dx y:(float)dy
  {
  NSImage *appIcon      = [NSImage imageNamed:@"NSApplicationIcon"];
  NSImage *badgeOverlay = [self badgeOverlayImageWithProgress:progress insetX:dx y:dy];
  
  //Put the appIcon underneath the badgeOverlay
  [badgeOverlay lockFocus];
	[appIcon compositeToPoint:NSZeroPoint operation:NSCompositeDestinationOver];
  [badgeOverlay unlockFocus];
//  [[badgeOverlay TIFFRepresentation] writeToFile:@"/tmp/badge.tif" atomically:NO];
  [NSApp setApplicationIconImage:badgeOverlay];
  }



@end
