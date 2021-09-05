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
		
		let str = "Some dummy text to get around Swift complaints"
		
		// NSStringPboardType isn't identified by Swift
//		guard let str = pasteboard.string(forType: PasteboardType.string) else {
//			error.pointee = errorMessage
//			return
//		}
	
		let alert = NSAlert()
		alert.messageText = "Hello \(str)"
		alert.informativeText = "Welcome in the service"
		alert.addButton(withTitle: "OK")
		alert.runModal()
	}
}
