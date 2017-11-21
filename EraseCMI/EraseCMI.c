/*
	File:		EraseCMI.c

	Contains:	Sample contextual menu plugin.

	Version:	Mac OS X

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
				("Apple") in consideration of your agreement to the following terms, and your
				use, installation, modification or redistribution of this Apple software
				constitutes acceptance of these terms.  If you do not agree with these terms,
				please do not use, install, modify or redistribute this Apple software.

				In consideration of your agreement to abide by the following terms, and subject
				to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
				copyrights in this original Apple software (the "Apple Software"), to use,
				reproduce, modify and redistribute the Apple Software, with or without
				modifications, in source and/or binary forms; provided that if you redistribute
				the Apple Software in its entirety and without modifications, you must retain
				this notice and the following text and disclaimers in all such redistributions of
				the Apple Software.  Neither the name, trademarks, service marks or logos of
				Apple Computer, Inc. may be used to endorse or promote products derived from the
				Apple Software without specific prior written permission from Apple.  Except as
				expressly stated in this notice, no other rights or licenses, express or implied,
				are granted by Apple herein, including but not limited to any patent rights that
				may be infringed by your derivative works or by other works in which the Apple
				Software may be incorporated.

				The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
				WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
				WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
				PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
				COMBINATION WITH YOUR PRODUCTS.

				IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
				CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
				GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
				ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
				OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
				(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
				ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

	Copyright © 2002-2003 Apple Computer, Inc., All Rights Reserved
*/

#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <CoreFoundation/CFPlugInCOM.h>

// -----------------------------------------------------------------------------
//	References
// -----------------------------------------------------------------------------
// Inside Contextual Menu Items, Part 1: http://www.macdevcenter.com/pub/a/mac/2004/05/28/cm_pt1.html
// Inside Contextual Menu Items, Part 2: http://www.macdevcenter.com/pub/a/mac/2004/06/04/cm_pt2.html
// Writing Contextual Menu Plugins for OS X, part 1: http://www.mactech.com/articles/mactech/Vol.18/18.08/MenuPlugins/index.html
// Writing Contextual Menu Plugins for OS X, part 2: http://www.mactech.com/articles/mactech/Vol.19/19.01/1901MenuPlugins/index.html
// UUID Generator: http://www.hsoi.com/hsoishop/software/

// -----------------------------------------------------------------------------
//	constants
// -----------------------------------------------------------------------------

// Use John C. Daub's UUID Generator to create a UUID
// UUID: 2E346CBE-AF56-400F-AC71-FE81BF1BB3CD
#define kEraseCMPluginFactoryID	( CFUUIDGetConstantUUIDWithBytes( NULL,0x2E,0x34,0x6C,0xBE,0xAF,0x56,0x40,0x0F,0xAC,0x71,0xFE,0x81,0xBF,0x1B,0xB3,0xCD ) )
/*2E346CBE-AF56-400F-AC71-FE81BF1BB3CD*/

//#define kEraseCMIFactoryID	( CFUUIDGetConstantUUIDWithBytes( NULL,		\
	0xC5, 0x2C, 0x25, 0x66, 0x3D, 0xC1, 0x11, 0xD5, 		\
	0xBB, 0xA3, 0x00, 0x30, 0x65, 0xB3, 0x00, 0xBC ) )
	// "C52C2566-3DC1-11D5-BBA3-003065B300BC"

#define scm_require(condition,location)		\
			if ( !(condition) )	\
				goto location;
#define scm_require_noerr(value,location)	\
			scm_require((value)==noErr,location)

// -----------------------------------------------------------------------------
//	typedefs
// -----------------------------------------------------------------------------

// The layout for an instance of EraseCMIType.
typedef struct EraseCMIType
{
	ContextualMenuInterfaceStruct	*cmInterface;
	CFUUIDRef						factoryID;
	UInt32							refCount;
 } EraseCMIType;

#pragma mark -
#pragma mark Prototypes

// -----------------------------------------------------------------------------
//	prototypes
// -----------------------------------------------------------------------------
//	Forward declaration for the IUnknown implementation.
//
static void DeallocEraseCMIType(
		EraseCMIType	*thisInstance );
static OSStatus AddCommandToList(CFStringRef	inCommandCFStringRef,
								 SInt32			inCommandID,
								 AEDescList*	ioCommandList);
static OSStatus AddCommandToAEDescList(
		ConstStr255Param	inCommandString,
		TextEncoding		inEncoding,
		DescType			inDescType,
		SInt32				inCommandID,
		MenuItemAttributes	inAttributes,
		UInt32				inModifiers,
		AEDescList*			ioCommandList);
static OSStatus CreateSampleSubmenu(
		AEDescList*			ioCommandList);
static OSStatus CreateSampleDynamicItems(
		AEDescList*			ioCommandList);

#pragma mark -

// -----------------------------------------------------------------------------
//	EraseCMIQueryInterface
// -----------------------------------------------------------------------------
//	Implementation of the IUnknown QueryInterface function.
//
static HRESULT EraseCMIQueryInterface(
		void*		thisInstance,
		REFIID		iid,
		LPVOID*		ppv )
{
	// Create a CoreFoundation UUIDRef for the requested interface.
	CFUUIDRef	interfaceID = CFUUIDCreateFromUUIDBytes( NULL, iid );

	// Test the requested ID against the valid interfaces.
	if ( CFEqual( interfaceID, kContextualMenuInterfaceID ) )
	{
		// If the TestInterface was requested, bump the ref count,
		// set the ppv parameter equal to the instance, and
		// return good status.
		( ( EraseCMIType* ) thisInstance )->cmInterface->AddRef(
				thisInstance );
		*ppv = thisInstance;
		CFRelease( interfaceID );
		return S_OK;
	}
	else if ( CFEqual( interfaceID, IUnknownUUID ) )
	{
		// If the IUnknown interface was requested, same as above.
		( ( EraseCMIType* ) thisInstance )->cmInterface->AddRef(
			thisInstance );
		*ppv = thisInstance;
		CFRelease( interfaceID );
		return S_OK;
	}
	else
	{
		// Requested interface unknown, bail with error.
		*ppv = NULL;
		CFRelease( interfaceID );
		return E_NOINTERFACE;
	}
}

// TRY TO CONVERT AN AEDesc TO AN FSRef
//     As per Apple Technical Q&A QA1274
//     eg: http://developer.apple.com/qa/qa2001/qa1274.html
//     Returns 'noErr' if OK, or an 'OSX result code' on error.
//
static int AEDescToFSRef(const AEDesc* desc, FSRef* fsref) {
    OSStatus err = noErr;
    AEDesc coerceDesc;
    // If AEDesc isn't already an FSRef, convert it to one
    if ( desc->descriptorType != typeFSRef ) {
		if ( ( err = AECoerceDesc(desc, typeFSRef, &coerceDesc) ) == noErr ) {
			// Get FSRef out of AEDesc
			err = AEGetDescData(&coerceDesc, fsref, sizeof(FSRef));
			AEDisposeDesc(&coerceDesc);
		}
    } else {
		err = AEGetDescData(desc, fsref, sizeof(FSRef));
    }
    return( err );
}

// -----------------------------------------------------------------------------
//	EraseCMIAddRef
// -----------------------------------------------------------------------------
//	Implementation of reference counting for this type. Whenever an interface
//	is requested, bump the refCount for the instance. NOTE: returning the
//	refcount is a convention but is not required so don't rely on it.
//
static ULONG EraseCMIAddRef( void *thisInstance )
{
	( ( EraseCMIType* ) thisInstance )->refCount += 1;
	return ( ( EraseCMIType* ) thisInstance)->refCount;
}

// -----------------------------------------------------------------------------
// EraseCMIRelease
// -----------------------------------------------------------------------------
//	When an interface is released, decrement the refCount.
//	If the refCount goes to zero, deallocate the instance.
//
static ULONG EraseCMIRelease( void *thisInstance )
{
	( ( EraseCMIType* ) thisInstance )->refCount -= 1;
	if ( ( ( EraseCMIType* ) thisInstance )->refCount == 0)
	{
		DeallocEraseCMIType(
				( EraseCMIType* ) thisInstance );
		return 0;
	}
	else
	{
		return ( ( EraseCMIType*) thisInstance )->refCount;
	}
}

#pragma mark -

// -----------------------------------------------------------------------------
//	EraseCMIExamineContext
// -----------------------------------------------------------------------------
//	The implementation of the ExamineContext test interface function.
//
static OSStatus EraseCMIExamineContext(
	void*				thisInstance,
	const AEDesc*		inContext,
	AEDescList*			outCommandPairs )
{
	// Sequence the command ids
	SInt32	theCommandID = 943; // I'm 943!
//	SInt32	result;

//	printf( "EraseCMI->EraseCMIExamineContext(): instance 0x%x, inContext 0x%x, outCommandPairs 0x%x\n",
//			( unsigned ) thisInstance,
//			( const unsigned ) inContext,
//			( unsigned ) outCommandPairs );

	// Verify that we've got an up-to-date CMM
//	verify_noerr( Gestalt( gestaltContextualMenuAttr, &result ) );
//	if ( ( result & ( 1 << gestaltContextualMenuHasAttributeAndModifierKeys ) ) != 0 )
//		printf( "EraseCMI: CMM supports Attributes and Modifiers keys\n" );
//	else
//		printf( "EraseCMI: CMM DOES NOT support Attributes and Modifiers keys\n" );
//	if ( ( result & ( 1 << gestaltContextualMenuHasUnicodeSupport ) ) != 0 )
//		printf( "EraseCMI: CMM supports typeUnicodeText and typeCFStringRef\n" );
//	else
//		printf( "EraseCMI: CMM DOES NOT support typeUnicodeText and typeCFStringRef\n" );
	
	// CMI Check List
	// + Only allow as a Finder CMI
	// + Generate the menu item's name
	// + Create localizations
	// + Support Unicode menu names
	// + Handle the request
	// + Find PE on the system (Use Launch Services)
	// + Generate an array of files to send to PE
	// + Send files to PE using LSLaunchFSRefSpec
	// + Build as Universal Binary
	
	ProcessInfoRec procInfo;
	ProcessSerialNumber curProcess;
	Str255 procName;
	FSSpec appFSSpec;
	Boolean isFinder = FALSE;
	
	// Is this the Finder? Let's find out
	procInfo.processInfoLength = sizeof(ProcessInfoRec);
	procInfo.processName = procName;
	procInfo.processAppSpec = &appFSSpec;
	GetFrontProcess(&curProcess);
	
	if (noErr == GetProcessInformation(&curProcess, &procInfo)) 
	{
		CFStringRef tempCFStringRef = CFStringCreateWithPascalString( NULL, (ConstStr255Param) &procName, kCFStringEncodingMacRoman);
		
		if (CFStringCompare( tempCFStringRef, CFSTR("Finder"), kCFCompareCaseInsensitive) == kCFCompareEqualTo) 
		{
			isFinder = TRUE;
		}
		
		CFRelease(tempCFStringRef);
	}
		
	// this is a quick sample that looks for text in the context descriptor
	
	// make sure the descriptor isn't null
	if ( inContext != NULL && isFinder == TRUE)
	{
		long numItems = 0;
		OSErr err = AECountItems(inContext, &numItems);
		// As a Finder plug-in, the main bundle ID is com.apple.finder, instead of com.edenwaith.EraseCMI
		CFBundleRef pluginBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.edenwaith.EraseCMI"));
		
		if (err != noErr) {
			return (true);
		}
		
		if (numItems == 1)
		{
			FSRef fsref;
			
			// On fail, filter should return true by default
			if ( AEDescToFSRef(inContext, &fsref) != noErr ) {
				return (true);
			}
			
			CFStringRef displayName;
			LSCopyDisplayNameForRef( &fsref, &displayName );
			
			CFStringRef localizedString = CFCopyLocalizedStringFromTableInBundle(CFSTR("EraseItem"), CFSTR("Localizable"), pluginBundle, "Erase file");
			CFStringRef menuName = CFStringCreateWithFormat( kCFAllocatorDefault, NULL, localizedString, displayName);
			
			if ( menuName != NULL )
			{
				OSStatus theError = noErr;
				theError = AddCommandToList(menuName, theCommandID, outCommandPairs );
				
				if (theError != noErr) 
				{
					fprintf(stderr, "Error creating the menu name\n");
				}
				
				// Be a good memory steward and clean up!
				CFRelease(menuName);
			}
			
			if (localizedString != NULL)
			{
				CFRelease(localizedString);
			}
		}
		else // Multiple items selected
		{
			CFStringRef localizedString = CFCopyLocalizedStringFromTableInBundle(CFSTR("EraseItems"), CFSTR("Localizable"), pluginBundle, "Erase file");
			CFStringRef menuName = CFStringCreateWithFormat( kCFAllocatorDefault, NULL, localizedString, numItems);
			
			if (menuName != NULL)
			{
				OSStatus theError = noErr;
				theError = AddCommandToList(menuName, theCommandID, outCommandPairs );
				
				if (theError != noErr) 
				{
					fprintf(stderr, "Error creating the menu name\n");
				}
				
				CFRelease(menuName);
			}
			
			if (localizedString != NULL)
			{
				CFRelease(localizedString);
			}
		}

		// Add line separator
		AddCommandToAEDescList( NULL, 0, typeNull, 0, kMenuItemAttrSeparator, 0, outCommandPairs );
	}
	else
	{
		fprintf(stderr, "EraseCMIExamineContext: Hey! What's up with the NULL descriptor?\n" );
	}

	return noErr;
}

// -----------------------------------------------------------------------------
//	EraseCMIHandleSelection
// -----------------------------------------------------------------------------
//	The implementation of the HandleSelection test interface function.
//
static OSStatus EraseCMIHandleSelection(
	void*				thisInstance,
	AEDesc*				inContext,
	SInt32				inCommandID )
{
//	LSLaunchFSRefSpec Format
//	struct LSLaunchFSRefSpec {
//		const FSRef *       appRef;                 /* app to use, can be NULL*/
//		UInt32              numDocs;                /* items to open/print, can be zero*/
//		const FSRef *       itemRefs;               /* array of FSRefs, ignored when numDocs is zero*/
//		const AEDesc *      passThruParams;         /* passed untouched to application as optional event parameter, */
//		/* with keyword keyAEPropData (can be NULL)*/
//		LSLaunchFlags       launchFlags;
//		void *              asyncRefCon;            /* used if you register for app birth/death notification*/
//	};
	
	CFStringRef bundleID = CFSTR("com.edenwaith.permanenteraser");
	OSErr err = noErr;
	FSRef appFSRef;
	long numItems = 0, i = 0;
	
	LSFindApplicationForInfo(kLSUnknownCreator, bundleID, NULL, &appFSRef, NULL);
	
	// To verify the name of the app
//	CFStringRef name;
//	LSCopyDisplayNameForRef(&appFSRef, &name);
//	CFShow(name);
	
	err = AECountItems (inContext, &numItems);
	
	FSRef itemRefs[numItems];
	
	for (i = 1; i <= numItems; i++)
	{
		FSRef tempFSRef;
		int index = i-1; // itemRefs index, which starts at 0, not 1
		AEKeyword keyword;
		AEDesc tempdesc = {typeNull, NULL};

		err = AEGetNthDesc (inContext, i, typeFSRef, &keyword, &tempdesc);
		
		if (AEDescToFSRef(&tempdesc, &tempFSRef) == noErr) 
		{
			itemRefs[index] = tempFSRef;
		}
		
		AEDisposeDesc (&tempdesc);
	}
	
	LSLaunchFSRefSpec spec;
	spec.appRef = &appFSRef;
	spec.numDocs = numItems;
	spec.itemRefs = itemRefs;
	spec.passThruParams = NULL;
	spec.launchFlags = kLSLaunchNoParams; // kLSLaunchDontAddToRecents | kLSLaunchDontSwitch | kLSLaunchNoParams | kLSLaunchAsync;
	spec.asyncRefCon = NULL;
	
	OSStatus statusErr = LSOpenFromRefSpec(&spec, NULL);
	
	if (statusErr != noErr) {
		fprintf(stderr, "Could not launch the app");
	}
	
	return noErr;
}

static Boolean getFileObject (const AEDesc *desc, AEDesc *resultDesc)
{
	AEDesc tempDesc = {typeNull, NULL};
	Boolean flFile = false;
	OSErr err = noErr;
	
	if ((*desc).descriptorType == typeAlias) {
		if (resultDesc != nil)
            return (AEDuplicateDesc (desc, resultDesc) == noErr);   
		else
            return (true);
	} 
	
	err = AECoerceDesc (desc, typeAlias, &tempDesc);
	if ((err == noErr) &&
		(tempDesc.descriptorType == typeAlias)) {      
		flFile = true;
		
		if (resultDesc != nil)
            flFile =(AEDuplicateDesc (&tempDesc, resultDesc)
					 == noErr);
	} 
	AEDisposeDesc (&tempDesc);
	return (flFile);
}

// -----------------------------------------------------------------------------
//	PostMenuCleanup
// -----------------------------------------------------------------------------
//	The implementation of the PostMenuCleanup test interface function.
//
static void EraseCMIPostMenuCleanup( void *thisInstance )
{
	printf( "EraseCMI->EraseCMIFinishedExamining(): instance 0x%x\n",
			( unsigned ) thisInstance );

	// No need to clean up.  We are a tidy folk.
}

// -----------------------------------------------------------------------------
//	testInterfaceFtbl	definition
// -----------------------------------------------------------------------------
//	The TestInterface function table.
//
static ContextualMenuInterfaceStruct testInterfaceFtbl =
			{ 
				// Required padding for COM
				NULL,
		
				// These three are the required COM functions
				EraseCMIQueryInterface,
				EraseCMIAddRef, 
				EraseCMIRelease, 
		
				// Interface implementation
				EraseCMIExamineContext,
				EraseCMIHandleSelection,
				EraseCMIPostMenuCleanup
			}; 

// -----------------------------------------------------------------------------
//	AllocEraseCMIType
// -----------------------------------------------------------------------------
//	Utility function that allocates a new instance.
//
static EraseCMIType* AllocEraseCMIType(
		CFUUIDRef		inFactoryID )
{
	
	// Allocate memory for the new instance.
	EraseCMIType *theNewInstance;
	theNewInstance = ( EraseCMIType* ) malloc(
			sizeof( EraseCMIType ) );

	// Point to the function table
	theNewInstance->cmInterface = &testInterfaceFtbl;

	// Retain and keep an open instance refcount<
	// for each factory.
	theNewInstance->factoryID = CFRetain( inFactoryID );
	CFPlugInAddInstanceForFactory( inFactoryID );

	// This function returns the IUnknown interface
	// so set the refCount to one.
	theNewInstance->refCount = 1;
	return theNewInstance;
}

// -----------------------------------------------------------------------------
//	DeallocEraseCMIType
// -----------------------------------------------------------------------------
//	Utility function that deallocates the instance when
//	the refCount goes to zero.
//
static void DeallocEraseCMIType( EraseCMIType* thisInstance )
{
	CFUUIDRef	theFactoryID = thisInstance->factoryID;
	free( thisInstance );
	if ( theFactoryID )
	{
		CFPlugInRemoveInstanceForFactory( theFactoryID );
		CFRelease( theFactoryID );
	}
}

// -----------------------------------------------------------------------------
//	EraseCMIFactory
// -----------------------------------------------------------------------------
//	Implementation of the factory function for this type.
//
void* EraseCMIFactory(
		CFAllocatorRef		allocator,
		CFUUIDRef			typeID )
{
	// If correct type is being requested, allocate an
	// instance of TestType and return the IUnknown interface.
	if ( CFEqual( typeID, kContextualMenuTypeID ) )
	{
		EraseCMIType *result;
		result = AllocEraseCMIType( kEraseCMPluginFactoryID );
		return result;
	}
	else
	{
		// If the requested type is incorrect, return NULL.
		return NULL;
	}
}

#pragma mark -

// -----------------------------------------------------------------------------
//	AddCommandToList
// -----------------------------------------------------------------------------
static OSStatus AddCommandToList(CFStringRef	inCommandCFStringRef,
									  SInt32	inCommandID,
									AEDescList*	ioCommandList)
{
	OSStatus anErr = noErr;
	AERecord theCommandRecord = { typeNull, NULL };
	CFStringRef tCFStringRef = inCommandCFStringRef;
	CFIndex length = CFStringGetLength(tCFStringRef);
    const UniChar* dataPtr = CFStringGetCharactersPtr(tCFStringRef);
	const UniChar* tempPtr = nil;
	
    if (dataPtr == NULL)
	{
		tempPtr = (UniChar*) NewPtr(length * sizeof(UniChar));
		if (nil == tempPtr) {
			goto AddCommandToAEDescList_fail;
		}
		
		CFStringGetCharacters(tCFStringRef, CFRangeMake(0,length), (UniChar*) tempPtr);
		dataPtr = tempPtr;
	}
	
	if (nil == dataPtr) {
		goto AddCommandToAEDescList_fail;
	}
	
	// create an apple event record for our command
	anErr = AECreateList( NULL, 0, true, &theCommandRecord );
	require_noerr( anErr, AddCommandToAEDescList_fail );
	
	// stick the command text into the aerecord
	anErr = AEPutKeyPtr( &theCommandRecord, keyAEName, typeUnicodeText, dataPtr, length * sizeof(UniChar));
	require_noerr( anErr, AddCommandToAEDescList_fail );
	
	// stick the command ID into the AERecord
	anErr = AEPutKeyPtr( &theCommandRecord, keyContextualMenuCommandID,
						typeLongInteger, &inCommandID, sizeof( inCommandID ) );
	require_noerr( anErr, AddCommandToAEDescList_fail );
	
	// stick this record into the list of commands that we are
	// passing back to the CMM
	anErr = AEPutDesc(ioCommandList, 			// the list we're putting our command into
					  0, 						// stick this command onto the end of our list
					  &theCommandRecord );		// the command I'm putting into the list
	
AddCommandToAEDescList_fail:
	// clean up after ourself; dispose of the AERecord
	AEDisposeDesc( &theCommandRecord );
	
	if (nil != tempPtr) {
		DisposePtr((Ptr) tempPtr);
	}
	
    return anErr;
	
} // AddCommandToList

// -----------------------------------------------------------------------------
//	AddCommandToAEDescList
// -----------------------------------------------------------------------------
static OSStatus AddCommandToAEDescList(
	ConstStr255Param		inCommandString,
	TextEncoding			inEncoding,
	DescType				inDescType,
	SInt32					inCommandID,
	MenuItemAttributes		inAttributes,
	UInt32					inModifiers,
	AEDescList*				ioCommandList)
{
	OSStatus theError = noErr;
	AERecord theCommandRecord = { typeNull, NULL };
	
	// create an apple event record for our command
	theError = AECreateList( NULL, kAEDescListFactorNone, true, &theCommandRecord );
	require_noerr( theError, AddCommandToAEDescList_fail );
	
	// stick the command text into the AERecord
	if ( inCommandString != NULL )
	{
		if ( inDescType == typeChar )
		{
			theError = AEPutKeyPtr( &theCommandRecord, keyAEName, typeChar,
				&inCommandString[1], StrLength( inCommandString ) );
			require_noerr( theError, AddCommandToAEDescList_fail );
		}
		else if ( inDescType == typeStyledText )
		{
			AERecord	textRecord;
			WritingCode	writingCode;
			AEDesc		textDesc;
			
			theError = AECreateList( NULL, kAEDescListFactorNone, true, &textRecord );
			require_noerr( theError, AddCommandToAEDescList_fail );
			
			theError = AEPutKeyPtr( &textRecord, keyAEText, typeChar,
				&inCommandString[1], StrLength( inCommandString ) );
			require_noerr( theError, AddCommandToAEDescList_fail );
			
			RevertTextEncodingToScriptInfo( inEncoding, &writingCode.theScriptCode,
				&writingCode.theLangCode, NULL );
			theError = AEPutKeyPtr( &textRecord, keyAEScriptTag, typeIntlWritingCode,
				&writingCode, sizeof( writingCode ) );
			require_noerr( theError, AddCommandToAEDescList_fail );

			theError = AECoerceDesc( &textRecord, typeStyledText, &textDesc );
			require_noerr( theError, AddCommandToAEDescList_fail );
			
			theError = AEPutKeyDesc( &theCommandRecord, keyAEName, &textDesc );
			require_noerr( theError, AddCommandToAEDescList_fail );
			
			AEDisposeDesc( &textRecord );
		}
		else if ( inDescType == typeIntlText )
		{
			IntlText*	intlText;
			ByteCount	size = sizeof( IntlText ) + StrLength( inCommandString ) - 1;
			
			// create an IntlText structure with the text and script
			intlText = (IntlText*) malloc( size );
			RevertTextEncodingToScriptInfo( inEncoding, &intlText->theScriptCode,
				&intlText->theLangCode, NULL );
			BlockMoveData( &inCommandString[1], &intlText->theText, StrLength( inCommandString ) );
			
			theError = AEPutKeyPtr( &theCommandRecord, keyAEName, typeIntlText, intlText, size );
			free( (char*) intlText );
			require_noerr( theError, AddCommandToAEDescList_fail );
		}
		else if ( inDescType == typeUnicodeText )
		{
			CFStringRef str = CFStringCreateWithPascalString( NULL, inCommandString, inEncoding );
			if ( str != NULL )
			{
				Boolean doFree = false;
				CFIndex sizeInChars = CFStringGetLength( str );
				CFIndex sizeInBytes = sizeInChars * sizeof( UniChar );
				const UniChar* unicode = CFStringGetCharactersPtr( str );
				if ( unicode == NULL )
				{
					doFree = true;
					unicode = (UniChar*) malloc( sizeInBytes );
					CFStringGetCharacters( str, CFRangeMake( 0, sizeInChars ), (UniChar*) unicode );
				}
				
				theError = AEPutKeyPtr( &theCommandRecord, keyAEName, typeUnicodeText, unicode, sizeInBytes );
					
				CFRelease( str );
				if ( doFree )
					free( (char*) unicode );
				
				require_noerr( theError, AddCommandToAEDescList_fail );
			}
		}
		else if ( inDescType == typeCFStringRef )
		{
			CFStringRef str = CFStringCreateWithPascalString( NULL, inCommandString, inEncoding );
			if ( str != NULL )
			{
				theError = AEPutKeyPtr( &theCommandRecord, keyAEName, typeCFStringRef, &str, sizeof( str ) );
				require_noerr( theError, AddCommandToAEDescList_fail );
				
				// do not release the string; the Contextual Menu Manager will release it for us
			}
		}
	}
		
	// stick the command ID into the AERecord
	if ( inCommandID != 0 )
	{
		theError = AEPutKeyPtr( &theCommandRecord, keyContextualMenuCommandID,
				typeLongInteger, &inCommandID, sizeof( inCommandID ) );
		require_noerr( theError, AddCommandToAEDescList_fail );
	}
	
	// stick the attributes into the AERecord
	if ( inAttributes != 0 )
	{
		theError = AEPutKeyPtr( &theCommandRecord, keyContextualMenuAttributes,
				typeLongInteger, &inAttributes, sizeof( inAttributes ) );
		require_noerr( theError, AddCommandToAEDescList_fail );
	}
	
	// stick the modifiers into the AERecord
	if ( inModifiers != 0 )
	{
		theError = AEPutKeyPtr( &theCommandRecord, keyContextualMenuModifiers,
				typeLongInteger, &inModifiers, sizeof( inModifiers ) );
		require_noerr( theError, AddCommandToAEDescList_fail );
	}
	
	// stick this record into the list of commands that we are
	// passing back to the CMM
	theError = AEPutDesc(
			ioCommandList, 			// the list we're putting our command into
			0, 						// stick this command onto the end of our list
			&theCommandRecord );	// the command I'm putting into the list
	
AddCommandToAEDescList_fail:
	// clean up after ourself; dispose of the AERecord
	AEDisposeDesc( &theCommandRecord );

    return theError;
    
} // AddCommandToAEDescList

// -----------------------------------------------------------------------------
//	CreateSampleSubmenu
// -----------------------------------------------------------------------------
static OSStatus CreateSampleSubmenu(
	AEDescList*		ioCommandList)
{
	OSStatus	theError = noErr;
	
	AEDescList	theSubmenuCommands = { typeNull, NULL };
	AERecord	theSupercommand = { typeNull, NULL };
	Str255		theSupercommandText = "\pSubmenu Here";
	
	// the first thing we should do is create an AEDescList of
	// subcommands

	// set up the AEDescList
	theError = AECreateList( NULL, 0, false, &theSubmenuCommands );
	require_noerr( theError, CreateSampleSubmenu_Complete_fail );

	// stick some commands in this subcommand list
	theError = AddCommandToAEDescList( "\pSubcommand 1", kTextEncodingMacRoman, typeChar,
			1001, 0, 0, &theSubmenuCommands );
	require_noerr( theError, CreateSampleSubmenu_CreateDesc_fail );
	
	// another
	theError = AddCommandToAEDescList( "\pAnother Subcommand", kTextEncodingMacRoman, typeChar,
			1002, 0, 0, &theSubmenuCommands );
	require_noerr( theError, CreateSampleSubmenu_fail );
	
	// yet another
	theError = AddCommandToAEDescList( "\pLast One", kTextEncodingMacRoman, typeChar, 
			1003, 0, 0, &theSubmenuCommands);
	require_noerr( theError, CreateSampleSubmenu_fail );
		
	// now, we need to create the supercommand which will "own" the
	// subcommands.  The supercommand lives in the root command list.
	// this looks very much like the AddCommandToAEDescList function,
	// except that instead of putting a command ID in the record,
	// we put in the subcommand list.

	// create an apple event record for our supercommand
	theError = AECreateList( NULL, 0, true, &theSupercommand );
	require_noerr( theError, CreateSampleSubmenu_fail );
	
	// stick the command text into the aerecord
	theError = AEPutKeyPtr(&theSupercommand, keyAEName, typeChar,
		&theSupercommandText[1], StrLength( theSupercommandText ) );
	require_noerr( theError, CreateSampleSubmenu_fail );
	
	// stick the subcommands into into the AERecord
	theError = AEPutKeyDesc(&theSupercommand, keyContextualMenuSubmenu,
		&theSubmenuCommands);
	require_noerr( theError, CreateSampleSubmenu_fail );
	
	// stick the supercommand into the list of commands that we are
	// passing back to the CMM
	theError = AEPutDesc(
		ioCommandList,		// the list we're putting our command into
		0,					// stick this command onto the end of our list
		&theSupercommand);	// the command I'm putting into the list
	
	// clean up after ourself
CreateSampleSubmenu_fail:
	AEDisposeDesc(&theSubmenuCommands);

CreateSampleSubmenu_CreateDesc_fail:
	AEDisposeDesc(&theSupercommand);

CreateSampleSubmenu_Complete_fail:
    return theError;
    
} // CreateSampleSubmenu

// -----------------------------------------------------------------------------
//	CreateSampleDynamicItems
// -----------------------------------------------------------------------------
static OSStatus CreateSampleDynamicItems(
		AEDescList*			ioCommandList)
{
	OSStatus	theError = noErr;
	
	// add a command
	theError = AddCommandToAEDescList( "\pClose", 2001, kTextEncodingMacRoman, typeChar,
			kMenuItemAttrDynamic, 0, ioCommandList );
	require_noerr( theError, CreateSampleDynamicItems_fail );
	
	// another
	theError = AddCommandToAEDescList( "\pClose All", kTextEncodingMacRoman, typeChar,
			2002, kMenuItemAttrDynamic, kMenuOptionModifier, ioCommandList );
	require_noerr( theError, CreateSampleDynamicItems_fail );
	
	// yet another
	theError = AddCommandToAEDescList( "\pClose All Without Saving", kTextEncodingMacRoman, typeChar,
			2003, kMenuItemAttrDynamic, kMenuOptionModifier | kMenuShiftModifier, ioCommandList );
	require_noerr( theError, CreateSampleDynamicItems_fail );
	
CreateSampleDynamicItems_fail:
	return theError;
	
} // CreateSampleDynamicItems
