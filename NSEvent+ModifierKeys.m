//
//  NSEvent+ModifierKeys.m
//  PermanentEraser
//
//  Created by Chad Armstrong on 1/10/07.
//  Copyright 2007 Edenwaith. All rights reserved.
//

#import "NSEvent+ModifierKeys.h"


@implementation NSEvent (ModifierKeys)

+ (BOOL) isControlKeyDown
{
    return (GetCurrentKeyModifiers() & controlKey) != 0;
}

+ (BOOL) isOptionKeyDown
{
    return (GetCurrentKeyModifiers() & optionKey) != 0;
}

+ (BOOL) isCommandKeyDown
{
    return (GetCurrentKeyModifiers() & cmdKey) != 0;
}

+ (BOOL) isShiftKeyDown
{
    return (GetCurrentKeyModifiers() & shiftKey) != 0;
}

@end
