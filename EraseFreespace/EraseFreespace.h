//
//  EraseFreespace.h
//  EraseFreespace
//
//  Created by Chad Armstrong on 9/27/17.
//  Copyright (c) 2017 Edenwaith, All Rights Reserved.
//

#import <Cocoa/Cocoa.h>
#import <Automator/AMBundleAction.h>

@interface EraseFreespace : AMBundleAction 
{
	NSTask *task;
	NSPipe *outputPipe;
}

- (id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo;
- (NSDictionary *)errorInfoWithMessage: (NSString *)errorMessage;
- (BOOL)isVolume: (NSString *) volumePath;
- (void) outputData: (NSFileHandle *) fileHandle;

@end
