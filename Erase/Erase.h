//
//  Erase.h
//  Erase
//
//  Created by Chad Armstrong on 5/11/07.
//  Copyright 2007 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Automator/AMBundleAction.h>

@interface Erase : AMBundleAction 
{
}

- (id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo;

@end
