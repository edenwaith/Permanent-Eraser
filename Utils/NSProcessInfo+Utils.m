//
//  NSProcessInfo+Utils.m
//  PermanentEraser
//
//  Created by Chad Armstrong on 12/24/14.
//  Copyright 2014 Edenwaith. All rights reserved.
//

#import "NSProcessInfo+Utils.h"


@implementation NSProcessInfo (Utils)

// Created: 24 December 2014 23:00
- (PEOperatingSystemVersion)osVersion
{
    PEOperatingSystemVersion v = {0, 0, 0};
    SInt32 major = 0, minor = 0, patch = 0;

    if (Gestalt(gestaltSystemVersionMajor, &major) != noErr) return v;
    if (Gestalt(gestaltSystemVersionMinor, &minor) != noErr) return v;
    if (Gestalt(gestaltSystemVersionBugFix, &patch) != noErr) return v;

    v.majorVersion = major;
    v.minorVersion = minor;
    v.patchVersion = patch;
	
    return v;
}

// Created: 25 December 2014 0:30
- (BOOL)isOperatingSystemEqualToVersion:(PEOperatingSystemVersion)version
{
	const PEOperatingSystemVersion systemVersion = [self osVersion];
	
	BOOL isEqual =  (systemVersion.majorVersion == version.majorVersion) &&
	(systemVersion.minorVersion == version.minorVersion) &&
	(systemVersion.patchVersion == version.patchVersion);
	
	return isEqual;
}

// =========================================================================
// (BOOL)isOperatingSystemGreaterThanVersion:(PEOperatingSystemVersion)version
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 24 December 2014 23:00
// Version: 24 December 2014 23:00
// =========================================================================
- (BOOL)isOperatingSystemGreaterThanVersion:(PEOperatingSystemVersion)version
{
	const PEOperatingSystemVersion systemVersion = [self osVersion];
	

}

// Created: 24 December 2014 23:00
- (BOOL)isOperatingSystemLessThanVersion:(PEOperatingSystemVersion)version
{
	const PEOperatingSystemVersion systemVersion = [self osVersion];
	
    if (systemVersion.majorVersion == version.majorVersion) 
	{
        if (systemVersion.minorVersion == version.minorVersion) 
		{
            return systemVersion.patchVersion < version.patchVersion;
        }
		
        return systemVersion.minorVersion < version.minorVersion;
    }
	
    return systemVersion.majorVersion < version.majorVersion;
}

@end
