//
//  NSFileManager+Utils.h
//  PermanentEraser
//
//  Created by Chad Armstrong on 12/2/10.
//  Copyright 2010 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <paths.h>
#include <sys/param.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOBSD.h>
#include <IOKit/storage/IOBlockStorageDevice.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/Kext/KextManager.h>

#ifndef kIOPropertyMediumTypeKey
#define kIOPropertyMediumTypeKey		"Medium Type"
#endif 

@interface NSFileManager (Utils)

- (BOOL) createDirectoryAtPathWithIntermediateDirectories: (NSString *) path attributes: (NSDictionary *) attributes;

- (BOOL) isFileSymbolicLink: (NSString *) path;
- (BOOL) containsResourceFork: (NSString *)path;
- (FSRef) convertStringToFSRef: (NSString *) path;
- (unsigned long long) fileSize: (NSString *) path;
- (unsigned long long) fastFolderSizeAtFSRef:(FSRef*)theFileRef;
- (NSString *) formatFileSize: (double) file_size;
- (BOOL) isSolidState: (UInt8 const *) cpath;
- (BOOL) isDirectoryEmpty: (NSString *) path;

@end
