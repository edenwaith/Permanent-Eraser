//
//  AppDelegate.swift
//  Permanent Eraser
//
//  Created by Administrator on 11/16/20.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    
	@IBOutlet weak var statusBarMenu: NSMenu!
	var statusBarItem: NSStatusItem!
	

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
		setupStatusBarMenu()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

	// MARK: -
	
	func setupStatusBarMenu() {
		
		statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
		// statusBarItem.button?.image = NSImage(named: NSImage.trashFullName)
		if #available(macOS 11.0, *) {
			if let trashImage = NSImage(systemSymbolName: "trash", accessibilityDescription: "Permanent Eraser") {
				trashImage.isTemplate = false
				statusBarItem.button?.image = trashImage
			}
		} else {
			// Fallback on earlier versions
			statusBarItem.button?.image = NSImage(named: NSImage.trashEmptyName)
		}
		
		statusBarItem.menu = self.statusBarMenu
	}

	@IBAction func quitApplication(_ sender: Any) {
		NSApp.terminate(sender)
	}
}

