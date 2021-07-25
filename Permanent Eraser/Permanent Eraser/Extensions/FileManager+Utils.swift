//
//  FileManager+Utils.swift
//  Permanent Eraser
//
//  Created by Chad Armstrong on 7/24/21.
//

import Foundation

extension FileManager {
	
	// https://stackoverflow.com/questions/2188469/how-can-i-calculate-the-size-of-a-folder
	// https://gist.github.com/NikolaiRuhe/408cefb953c4bea15506a3f80a3e5b96
	
	/// Calculate the allocated size of a directory and all its contents on the volume.
	///
	/// As there's no simple way to get this information from the file system the method
	/// has to crawl the entire hierarchy, accumulating the overall sum on the way.
	/// The resulting value is roughly equivalent with the amount of bytes
	/// that would become available on the volume if the directory would be deleted.
	///
	/// - note: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
	/// directories, hard links, ...).
	public func allocatedSizeOfDirectory(at directoryURL: URL) throws -> UInt64 {

		let allocatedSizeResourceKeys: Set<URLResourceKey> = [
			.isRegularFileKey,
			.fileAllocatedSizeKey,
			.totalFileAllocatedSizeKey,
		]
		
		// The error handler simply stores the error and stops traversal
		var enumeratorError: Error? = nil
		func errorHandler(_: URL, error: Error) -> Bool {
			enumeratorError = error
			return false
		}

		// We have to enumerate all directory contents, including subdirectories.
		let enumerator = self.enumerator(at: directoryURL,
										 includingPropertiesForKeys: Array(allocatedSizeResourceKeys),
										 options: [],
										 errorHandler: errorHandler)!

		// We'll sum up content size here:
		var accumulatedSize: UInt64 = 0

		// Perform the traversal.
		for item in enumerator {

			// Bail out on errors from the errorHandler.
			if enumeratorError != nil { break }

			// Add up individual file sizes.
			let contentItemURL = item as! URL
			accumulatedSize += try contentItemURL.regularFileAllocatedSize()
		}

		// Rethrow errors from errorHandler.
		if let error = enumeratorError { throw error }

		return accumulatedSize
	}
	
//	func localize() -> String {
//		return NSLocalizedString(self, comment: self)
//	}
}
