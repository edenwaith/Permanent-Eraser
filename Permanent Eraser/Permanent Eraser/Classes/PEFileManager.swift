//
//  PEFileManager.swift
//  Permanent Eraser
//
//  Created by Chad Armstrong on 9/6/21.
//

import Cocoa

class PEFileManager: NSObject {

	static let sharedManager = PEFileManager()
	var files = [PEFile]()
	
	
	/// Add a list of files (specified by their URL) to be monitored by PEFileManager
	/// - Parameter files: An array of file URLs
	public func addFiles(files: [URL]) {
		// Iterate over the list of URLs to create new PEFile models
		for url in files {
			
		}
	}
}
