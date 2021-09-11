//
//  ContextualMenuServiceProvider.swift
//  Permanent Eraser
//
//  Created by Chad Armstrong on 9/2/21.
//
//	Services references:
//	- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html
//	- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html#//apple_ref/doc/uid/20000852-CHDJDFIC
//	- https://stackoverflow.com/questions/41442474/how-to-register-service-from-app-in-macos-application
//	- https://izziswift.com/unable-to-add-item-in-finders-contextual-menu-using-services-in-cocoa/
//	- http://www.nongnu.org/gstutorial/en/ch16.html

import Foundation
import Cocoa

class ContextualMenuServiceProvider: NSObject {

	let errorMessage = NSString(string: "Could not find the text for parsing.")

	@objc func eraseService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
		
		NSLog("PE3:: pasteboard: \(pasteboard)")
		
		if let pBoardTypes = pasteboard.types {
			NSLog("PE3:: Number of pasteboard types: \(pBoardTypes.count)")
			NSLog("PE3:: Pasteboard Types: \(pBoardTypes)")
		}
		
		/*
		
		6 Pasteboard types found
		PE3:: Pasteboard Types:
		[__C.NSPasteboardType(_rawValue: public.file-url),
		__C.NSPasteboardType(_rawValue: CorePasteboardFlavorType 0x6675726C),
		__C.NSPasteboardType(_rawValue: dyn.ah62d4rv4gu8y6y4grf0gn5xbrzw1gydcr7u1e3cytf2gn),
		__C.NSPasteboardType(_rawValue: NSFilenamesPboardType),
		__C.NSPasteboardType(_rawValue: dyn.ah62d4rv4gu8yc6durvwwaznwmuuha2pxsvw0e55bsmwca7d3sbwu),
		__C.NSPasteboardType(_rawValue: Apple URL pasteboard type)]
		
		*/
		
		// https://stackoverflow.com/questions/31320947/nsurl-returns-files-id-instead-of-files-path
		// Returns a string like: file:///.file/id=6571367.8622082855
		// Resolve the file URL with Applescript: osascript -e 'get posix path of posix file "file:///.file/id=6571367.4833330"'
		// Reference: https://stackoverflow.com/questions/37351647/get-path-from-os-x-file-reference-url-alias-file-file-id
		
		// NSFilenamesPboardType // Unavailable in Swift, use PasteboardType.fileURL
		// NSPasteboard.PasteboardType.fileURL
		guard let pboardInfo = pasteboard.string(forType: NSPasteboard.PasteboardType.fileURL) else { //
			
			let alert = NSAlert()
			alert.messageText = "Piss off error \(errorMessage)"
			alert.informativeText = "Welcome to the service"
			alert.addButton(withTitle: "OK")
			alert.runModal()
			
			return
		}
	
		// Changing the file reference URL to a path-based URL: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html#//apple_ref/doc/uid/TP40010672-CH3-SW6
		let urlPath = URL(fileURLWithPath: pboardInfo)
		let standardizedURL = URL(fileURLWithPath: pboardInfo).standardized
		
		// Add this single file to the list of files to delete
		PEFileManager.sharedManager.addFiles(files: [standardizedURL])
		
		// Next up, once all of the files have been added, then start deleting.
		
		let pboardInfoType = type(of: pboardInfo)
		let alert = NSAlert()
		alert.messageText = "Hola info \(pboardInfo) of type \(pboardInfoType) at \(urlPath.absoluteURL)"
		alert.informativeText = "Standardized URL: \(standardizedURL)"
		// alert.informativeText = "Pasteboard Types \(String(describing: pBoardTypes)) (\(pBoardTypes?.count))"
		alert.addButton(withTitle: "OK")
		alert.runModal()
	}
}
