//
//  PEFile.m
//  FileProj
//
//  Created by Chad Armstrong on 2/5/09.
//  Copyright 2009 Edenwaith. All rights reserved.
//

#import "PEFile.h"

@implementation PEFile

- (id) initWithPath: (NSString *)filepath
{
	self = [super init];
	
	if (_path == nil)
	{
		_path = filepath;
	}
	
	if (_path != nil)
	{
		[_path retain];  // retain the path or it will get lost
	}
	
	return (self);
}

- (NSString *) path
{
	return (_path);
}

// (NSString *) fileName
// Return just the name of the file (last path component)
// Created: 19 May 2009 22:24
- (NSString *) fileName
{
	return ([_path lastPathComponent]);
}

- (unsigned long long) filesize
{
	return (_filesize);
}

- (void) setFilesize: (unsigned long long) filesize
{
	_filesize = filesize;
}

- (unsigned long long) numberOfFiles
{
	return (_numberOfFiles);
}

- (void) setNumberOfFiles: (unsigned long long) numberOfFiles
{
	_numberOfFiles = numberOfFiles;
}


- (void) setIsDirectory: (BOOL) isDirectory
{
	_isDirectory = isDirectory;
}

- (BOOL) isDirectory
{
	return (_isDirectory);
}

- (void) setIsPackage: (BOOL) isPackage
{
	_isPackage = isPackage;
}

- (BOOL) isPackage
{
	return (_isPackage);
}

- (BOOL) isVolume
{
	return (_isVolume);
}

- (void) setIsVolume: (BOOL) isVolume
{
	_isVolume = isVolume;
}

- (BOOL) isErasableDisc
{
	return (_isErasableDisc);
}

- (void) setIsErasableDisc: (BOOL) isErasableDisc
{
	_isErasableDisc = isErasableDisc;		
}


- (BOOL) isSymbolicLink
{
	return (_isSymbolicLink);
}


- (void) setIsSymbolicLink: (BOOL) isSymbolicLink
{
	_isSymbolicLink = isSymbolicLink;
}


- (BOOL) hasResourcefork
{
	return (_hasResourceFork);
}


- (void) setHasResourceFork: (BOOL) hasResourcefork;
{
	_hasResourceFork = hasResourcefork;
}


- (NSImage *) icon
{
	return ([[NSWorkspace sharedWorkspace] iconForFile: _path]);
}

@end
