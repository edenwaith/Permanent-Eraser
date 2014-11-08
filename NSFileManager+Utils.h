//
//  NSFileManager+Utils.h
//  PermanentEraser
//
//  Created by Chad Armstrong on 12/2/10.
//  Copyright 2010 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSFileManager (Utils)

- (BOOL) createDirectoryAtPathWithIntermediateDirectories: (NSString *) path attributes: (NSDictionary *) attributes;

- (BOOL) isFileSymbolicLink: (NSString *) path;
- (FSRef) convertStringToFSRef: (NSString *) path;
- (unsigned long long) fileSize: (NSString *) path;
- (unsigned long long) fastFolderSizeAtFSRef:(FSRef*)theFileRef;
- (NSString *) formatFileSize: (double) file_size;

@end
