//
//  NSProcessInfo+Utils.h
//  PermanentEraser
//
//  Created by Chad Armstrong on 12/24/14.
//  Copyright 2014 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct {
    NSInteger majorVersion;
    NSInteger minorVersion;
    NSInteger patchVersion;
} PEOperatingSystemVersion;

@interface NSProcessInfo (Utils)

- (PEOperatingSystemVersion)osVersion;
- (BOOL)isOperatingSystemEqualToVersion:(PEOperatingSystemVersion)version;
- (BOOL)isOperatingSystemGreaterThanVersion:(PEOperatingSystemVersion)version;
- (BOOL)isOperatingSystemLessThanVersion:(PEOperatingSystemVersion)version;

@end
