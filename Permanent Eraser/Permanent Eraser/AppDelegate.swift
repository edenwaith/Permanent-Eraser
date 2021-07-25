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

	@IBAction func seletFilesToDelete(_ sender: Any) {
		
		// Set up options for the open panel
		let openPanel = NSOpenPanel()
		openPanel.allowsMultipleSelection = true
		openPanel.canChooseDirectories = true
		openPanel.canCreateDirectories = false
		openPanel.canChooseFiles = true
		
		openPanel.begin { (result) -> Void in
			if result == NSApplication.ModalResponse.OK {
				// Get list of files and collate them
				let urls = openPanel.urls
				var totalSize: UInt64 = 0
				
				for url in urls {
					
					let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
					// Should also test that if something is a package, is it checked in the previous statement?  Yep, for an app, it sees the package as a directory.
					let isPackage = (try? url.resourceValues(forKeys:[.isPackageKey]))?.isPackage ?? false
					
					if isDirectory == true || isPackage == true {
						totalSize += (try? FileManager.default.allocatedSizeOfDirectory(at: url)) ?? 0
					} else {
						totalSize += (try? url.regularFileAllocatedSize()) ?? 0
					}
					print("url: \(url)")
				}
				
				print("totalSize: \(totalSize)")
			}
		}
		
		
		
		
		// For testing purposes, display size of selected file(s)
	}
	
	
	@IBAction func quitApplication(_ sender: Any) {
		NSApp.terminate(sender)
	}
}

