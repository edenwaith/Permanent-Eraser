//
//  URL+Utils.swift
//  Permanent Eraser
//
//  Created by Chad Armstrong on 7/24/21.
//

import Foundation

extension URL {
	
	func regularFileAllocatedSize() throws -> UInt64 {
		
		let allocatedSizeResourceKeys: Set<URLResourceKey> = [
			.isRegularFileKey,
			.fileSizeKey, // this is experimental and returns just bytes
			.fileAllocatedSizeKey,
			.totalFileAllocatedSizeKey,
		]
		
		let resourceValues = try self.resourceValues(forKeys: allocatedSizeResourceKeys)

		// We only look at regular files.
		guard resourceValues.isRegularFile ?? false else {
			return 0
		}

		// To get the file's size we first try the most comprehensive value in terms of what
		// the file may use on disk. This includes metadata, compression (on file system
		// level) and block size.
		// In case totalFileAllocatedSize is unavailable we use the fallback value (excluding
		// meta data and compression) This value should always be available.
		
		// Experimental
		// return UInt64(resourceValues.fileSize ?? 0)
		
		// This is the real return statement
		return UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
	}
}
