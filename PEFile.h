//
//  PEFile.h
//  FileProj
//
//  Created by Chad Armstrong on 2/5/09.
//  Copyright 2009 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

@interface PEFile : NSObject 
{

	NSString			*_path;
	unsigned long long	_filesize;
	unsigned long long	_numberOfFiles;
	BOOL				_isDirectory;
	BOOL				_isPackage;
	BOOL				_isVolume;
	BOOL				_isOnSSD;
	BOOL				_isErasableDisc;
	BOOL				_isSymbolicLink;
	BOOL				_hasResourceFork;
	BOOL				_isDeletable;
}

- (id) initWithPath: (NSString *) filepath;
-(NSString *) path;
- (NSString *) fileName;
- (unsigned long long) filesize;
- (void) setFilesize: (unsigned long long) filesize;
- (unsigned long long) numberOfFiles;
- (void) setNumberOfFiles: (unsigned long long) numberOfFiles;
- (void) setIsDirectory: (BOOL) isDirectory;
- (BOOL) isDirectory;
- (void) setIsPackage: (BOOL) isPackage;
- (BOOL) isPackage;
- (BOOL) isVolume;
- (void) setIsVolume: (BOOL) isVolume;
- (BOOL) isOnSSD;
- (void) setIsOnSSD: (BOOL) isOnSSD;
- (BOOL) isErasableDisc;
- (void) setIsErasableDisc: (BOOL) isErasableDisc;
- (BOOL) isSymbolicLink;
- (void) setIsSymbolicLink: (BOOL) isSymbolicLink;
- (BOOL) hasResourcefork;
- (void) setHasResourceFork: (BOOL) hasResourcefork;
- (NSImage *) icon;

@end
