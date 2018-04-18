//
//  NSFileManager+Utils.m
//  PermanentEraser
//
//  Created by Chad Armstrong on 12/2/10.
//  Copyright 2010 Edenwaith. All rights reserved.
//

#import "NSFileManager+Utils.h"
#import "NSProcessInfo+PECocoaBackports.h"

@implementation NSFileManager (Utils)

// =========================================================================
// (BOOL) createDirectoryAtPathWithIntermediateDirectories: (NSString *) path attributes: (NSDictionary *) attributes
// -------------------------------------------------------------------------
// Recursively create a folder (and it's parent folders, if necessary)
// A category replacement for createDirectoryAtPath:withIntermediateDirectories:attributes:error:,  
// since that was introduced in Mac OS 10.5, and the current version of PE 
// still supports Mac OS 10.3.9.
// -------------------------------------------------------------------------
// Created: 2 December 2010
// Version: 4 December 2010 11:20
// =========================================================================
- (BOOL) createDirectoryAtPathWithIntermediateDirectories: (NSString *) path attributes: (NSDictionary *) attributes
{
	BOOL isDir;
	NSString *parentDirectory = [path stringByDeletingLastPathComponent];
	
	if (![self fileExistsAtPath: parentDirectory isDirectory:&isDir] && isDir)
	{
		// call ourself with the directory above...
		[self createDirectoryAtPathWithIntermediateDirectories: parentDirectory attributes: attributes];
	}
	
	// Parent directories have been created by now, if needed...
	if ([self fileExistsAtPath: path] == NO)
	{
		[self createDirectoryAtPath: path attributes: attributes];
	}
	
	return YES;
}


// =========================================================================
// (BOOL) isFileSymbolicLink: (NSString *)path
// -------------------------------------------------------------------------
// Check to see if a file is a symbolic/soft link, so the link
// can be deleted with rm instead of srm, so the original file is not 
// accidentally erased.
// -------------------------------------------------------------------------
// Version: 19. November 2004 21:28
// Created: 19. November 2004 21:28
// =========================================================================
- (BOOL) isFileSymbolicLink: (NSString *) path
{
    NSDictionary *fattrs = [self fileAttributesAtPath: path traverseLink:NO];
	
    if ( [[fattrs objectForKey:NSFileType] isEqual: @"NSFileTypeSymbolicLink"])
    {
        return (YES);
    }
    else
    {
        return (NO);
    }
	
}

// =========================================================================
// (BOOL) containsResourceFork: (NSString *)path
// -------------------------------------------------------------------------
// Check to see if a file contains a resource fork.
// Should gather several of these file-related checks and put them into
// a separate extension class.
// -------------------------------------------------------------------------
// Created: 2 January 2007 19:49
// Version: 8 April 2007
// =========================================================================
// TODO: Should move some of these methods to the NSFileManager+Utils category class
- (BOOL) containsResourceFork: (NSString *)path 
{
	FSRef           fsRef;
	FSCatalogInfo   fsInfo;
	BOOL			isDir;
	
	// If path is a directory, automatically return NO
	if ( [self fileExistsAtPath: path isDirectory:&isDir] && isDir )
	{
		return (NO);
	}
	else if (FSPathMakeRef((unsigned char *) [path fileSystemRepresentation], &fsRef, NULL) == noErr) 
	{
		// Another way to check for a resource fork is by using getxattr
		// ssize_t resourceForkSize = getxattr([pathToFile fileSystemRepresentation], "com.apple.ResourceFork", NULL, 0, 0, 0);
		if(FSGetCatalogInfo(&fsRef, kFSCatInfoRsrcSizes, &fsInfo, NULL, NULL, NULL) == noErr)
		{
			if (fsInfo.rsrcLogicalSize > 0)
			{
				return (YES);
			}
			else
			{
				return (NO);
			}
		}
	}
	
	return (NO);
}

// =========================================================================
// (FSRef) convertStringToFSRef: (NSString *) path
// -------------------------------------------------------------------------
// Convert NSString to FSRef
// -------------------------------------------------------------------------
// Created: 10 December 2009 22:37
// Version: 9 June 2010 21:23
// =========================================================================
- (FSRef) convertStringToFSRef: (NSString *) path
{
	// This converts an NSString path to a FSRef correctly.
	// The Dell Inspiron backup was sized properly at 20662092257, whereas the old method
	// returned the value 25893905653.  If a file name had a semi-colon in it, the entire
	// parent directory would be given as the file's size.
	FSRef output;
	
	NSURL *fileURL = [NSURL fileURLWithPath: path];
	
    if (!CFURLGetFSRef( (CFURLRef)fileURL, &output )) 
	{
        NSLog( @"Failed to create FSRef." );
    }	
	
	return output;
}

// =========================================================================
// (unsigned long long) fileSize: (NSString *) path
// -------------------------------------------------------------------------
// -------------------------------------------------------------------------
// Created: 10 December 2009 22:45
// Version: 21 May 2010 22:39
// =========================================================================
- (unsigned long long) fileSize: (NSString *) path
{
	unsigned long long pathFileSize = 0;
	
	if ([self isFileSymbolicLink: path] == YES)
	{
		NSDictionary *fattrs = [self fileAttributesAtPath: path traverseLink: NO];
		
		if (fattrs != nil)
		{
			NSNumber *numFileSize;
			
			numFileSize = [fattrs objectForKey: NSFileSize];
			pathFileSize = [numFileSize unsignedLongLongValue];
		}
	}
	else
	{
		FSRef ref = [self convertStringToFSRef: path];
		pathFileSize = [self fastFolderSizeAtFSRef: &ref];
	}
	
	return (pathFileSize);
}


// =========================================================================
// (unsigned long long) fastFolderSizeAtFSRef:(FSRef*)theFileRef
// -------------------------------------------------------------------------
// =========================================================================
- (unsigned long long) fastFolderSizeAtFSRef:(FSRef*)theFileRef
{
	FSIterator	thisDirEnum = NULL;
	unsigned long long totalSize = 0;
	
	
	// Iterate the directory contents, recursing as necessary
	if (FSOpenIterator(theFileRef, kFSIterateFlat, &thisDirEnum) == noErr)
	{
		const ItemCount kMaxEntriesPerFetch = 256;
		ItemCount actualFetched;
		FSRef	fetchedRefs[kMaxEntriesPerFetch];
		FSCatalogInfo fetchedInfos[kMaxEntriesPerFetch];
		
		OSErr fsErr = FSGetCatalogInfoBulk(thisDirEnum, kMaxEntriesPerFetch, &actualFetched,
										   NULL, kFSCatInfoDataSizes | kFSCatInfoRsrcSizes | kFSCatInfoNodeFlags, fetchedInfos,
										   fetchedRefs, NULL, NULL);
		while ((fsErr == noErr) || (fsErr == errFSNoMoreItems))
		{
			ItemCount thisIndex;
			for (thisIndex = 0; thisIndex < actualFetched; thisIndex++)
			{
				// Recurse if it's a folder
				if (fetchedInfos[thisIndex].nodeFlags & kFSNodeIsDirectoryMask)
				{
					totalSize += [self fastFolderSizeAtFSRef:&fetchedRefs[thisIndex]];
				}
				else
				{
					// add the size for this item
					totalSize += fetchedInfos[thisIndex].dataLogicalSize + fetchedInfos[thisIndex].rsrcLogicalSize;
				}
			}
			
			if (fsErr == errFSNoMoreItems)
			{
				break;
			}
			else
			{
				// get more items
				fsErr = FSGetCatalogInfoBulk(thisDirEnum, kMaxEntriesPerFetch, &actualFetched,
											 NULL, kFSCatInfoDataSizes | kFSCatInfoNodeFlags, fetchedInfos,
											 fetchedRefs, NULL, NULL);
			}
		}
		FSCloseIterator(thisDirEnum);
	}
	else
	{
		FSCatalogInfo		fsInfo;
		
		if(FSGetCatalogInfo(theFileRef, kFSCatInfoDataSizes | kFSCatInfoRsrcSizes, &fsInfo, NULL, NULL, NULL) == noErr)
		{
			if (fsInfo.rsrcLogicalSize > 0)
			{
				totalSize += (fsInfo.dataLogicalSize + fsInfo.rsrcLogicalSize);
			}
			else
			{
				totalSize += (fsInfo.dataLogicalSize);
			}
		}
	}
	
	return totalSize;
}

// =========================================================================
// (NSString *) formatFileSize: (double) fileSize
// -------------------------------------------------------------------------
// Should (double) file)_size be changed to unsigned long long?
// -------------------------------------------------------------------------
// Created: 8 August 2007 22:09
// Version: 16 February 2015 15:02
// =========================================================================
- (NSString *) formatFileSize: (double) fileSize
{
	NSString *fileSizeLabel;
	double baseSize = 1024.0;	// For Mac OS 10.6+, set this to 1000.0
		
	if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 6, 0}] == YES)
	{
		baseSize = 1000.0;
	}
	
	if ( (fileSize / baseSize) < 1.0)
	{
		if (fileSize == 1.0)
		{
			fileSizeLabel = @" byte";
		}
		else 
		{
			fileSizeLabel = @" bytes";
		}
	}
	else if ((fileSize / pow(baseSize, 2)) < 1.0)
	{
		fileSize = fileSize / baseSize;
		fileSizeLabel = @" KB";
	}
	else if ((fileSize / pow(baseSize, 3)) < 1.0)
	{
		fileSize = fileSize / pow(baseSize, 2);
		fileSizeLabel = @" MB";
	}
	else
	{
		fileSize = fileSize / pow(baseSize, 3);
		fileSizeLabel = @" GB";
	}	
	
	return ([NSString stringWithFormat: @"%.2f%@", fileSize, fileSizeLabel]);
}

// =========================================================================
// (BOOL) isSolidState: (UInt8 const *) cpath
// -------------------------------------------------------------------------
// Check to see if a given file is located on a Solid State Drive (SSD)
// -------------------------------------------------------------------------
// Added 18 March 2012 18:06
// =========================================================================
- (BOOL) isSolidState: (UInt8 const *) cpath
{       
	FSRef volRef;   
	CFMutableDictionaryRef classesToMatch = nil;
	
    if (noErr == FSPathMakeRef( cpath, &volRef, NULL))
	{
		FSCatalogInfo volCatInfo;
		if (noErr == FSGetCatalogInfo(&volRef, kFSCatInfoVolume, &volCatInfo, NULL, NULL, NULL))
		{
			CFStringRef idStr = NULL;
			if (noErr == FSCopyDiskIDForVolume(volCatInfo.volume, &idStr))
			{                               
				NSString *str = (NSString*)idStr;
				//NSLog(@"Checking bsd disk %@",str);
				
				// create matching dictionary
				classesToMatch = IOBSDNameMatching(kIOMasterPortDefault,0,[str UTF8String]);
				
				if (idStr) CFRelease(idStr);    
			}
		}
    }
	
	if (classesToMatch == NULL) {
		NSLog(@"Could not find io classes of disk");
		return NO;
	}
	
	// get iterator of matching services
	io_iterator_t entryIterator;
	
	if (KERN_SUCCESS != IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatch, &entryIterator))
	{
		NSLog(@"Can't iterate services");
		return NO;
	}
	
	BOOL isSolidState = NO;
	
	// iterate over all found medias
	io_object_t serviceEntry, parentMedia;
	while (serviceEntry = IOIteratorNext(entryIterator)) 
	{
		int maxlevels = 8;
		do
		{
			kern_return_t kernResult = IORegistryEntryGetParentEntry(serviceEntry, kIOServicePlane, &parentMedia);
			IOObjectRelease(serviceEntry);  
			
			if (KERN_SUCCESS != kernResult) {
				serviceEntry = 0;
				NSLog(@"Error while getting parent service entry");
				break;
			}
			
			serviceEntry = parentMedia;                     
			if (!parentMedia) break; // finished iterator
			
			CFTypeRef res = IORegistryEntryCreateCFProperty(serviceEntry, CFSTR(kIOPropertyDeviceCharacteristicsKey), kCFAllocatorDefault, 0);
			if (res)
			{
				NSString *type = [(NSDictionary*)res objectForKey:(id)CFSTR(kIOPropertyMediumTypeKey)];             
				//NSLog(@"Found disk %@",res);
				isSolidState = [@"Solid State" isEqualToString:type]; type = nil;
				CFRelease(res);
				if (isSolidState) break;
			}
		}
		while(maxlevels--);
		
		if (serviceEntry) IOObjectRelease(serviceEntry);
	}
	IOObjectRelease(entryIterator);
	
	return isSolidState;
}

// =========================================================================
// (NSString *) isDirectoryEmpty: (NSString *) path
// -------------------------------------------------------------------------
// 
// -------------------------------------------------------------------------
// Created: 27 November 2009 23:35
// Version: 6 April 2018 20:49
// =========================================================================
- (BOOL) isDirectoryEmpty: (NSString *) path
{
	NSArray *dirContents = [self subpathsAtPath: path];
	
	if (dirContents != nil && [dirContents count] == 0)
	{
		return YES;
	}
	else 
	{
		return NO;
	}
	
}

@end
