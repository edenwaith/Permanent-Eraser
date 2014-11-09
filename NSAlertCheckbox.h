//
//  NSAlertCheckbox.h
//  PermanentEraser
//
//  Created by Chad Armstrong on 8/13/09.
//  Copyright 2009 Edenwaith. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// private methods
@interface NSAlert (CheckboxAdditions)

- (void)prepare;
- (id)buildAlertStyle:(int)fp8 title:(id)fp12 formattedMsg:(id)fp16 first:(id)fp20 second:(id)fp24 third:(id)fp28 oldStyle:(BOOL)fp32;
- (id)buildAlertStyle:(int)fp8 title:(id)fp12 message:(id)fp16 first:(id)fp20 second:(id)fp24 third:(id)fp28 oldStyle:(BOOL)fp32 args:(char *)fp36;

@end

@interface NSAlertCheckbox : NSAlert 
{
	NSButton *_checkbox;
}

+ (NSAlertCheckbox *)alertWithMessageText:(NSString *)message defaultButton:(NSString *)defaultButton alternateButton:(NSString *)alternateButton otherButton:(NSString *)otherButton informativeText:(NSString *)format;

- (BOOL)showsCheckbox;
- (void)setShowsCheckbox:(BOOL)showsCheckbox;

- (NSString *)checkboxText;
- (void)setCheckboxText:(NSString *)text;

- (int)checkboxState;
- (void)setCheckboxState:(int)state;

@end
