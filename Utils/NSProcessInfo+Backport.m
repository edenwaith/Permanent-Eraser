//
//  NSProcessInfo+Backport.m
//  PermanentEraser
//
//  Created by Chad Armstrong on 12/13/14.
//  Copyright 2014 Edenwaith. All rights reserved.
//

#import "NSProcessInfo+Backport.h"


@implementation NSProcessInfo (Backport)

+ (void)wml_addSelector:(SEL)originalSelector implementedWithSelector:(SEL)newSelector {
    if (![self instancesRespondToSelector:originalSelector]) {
        Method newMethod = class_getInstanceMethod(self, newSelector);
        class_addMethod(self, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    }
}

+ (void)load {
    @autoreleasepool {
        if (![self isSubclassOfClass:[NSProcessInfo class]]) {
            return;
        }
        
        [self wml_addSelector:@selector(operatingSystemVersion)
      implementedWithSelector:@selector(wml_operatingSystemVersion)];
        
        [self wml_addSelector:@selector(isOperatingSystemAtLeastVersion:)
      implementedWithSelector:@selector(wml_isOperatingSystemAtLeastVersion:)];
    }
}

- (NSOperatingSystemVersion)wml_operatingSystemVersion {
    static NSOperatingSystemVersion version;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *components = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
        if (components.count > 0) {
            version.majorVersion = [components[0] integerValue];
            if (components.count >= 2) {
                version.minorVersion = [components[1] integerValue];
                if (components.count >= 3) {
                    version.patchVersion= [components[2] integerValue];
                }
            }
        }
    });
    return version;
}

- (BOOL)wml_isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    NSOperatingSystemVersion myVersion = self.operatingSystemVersion;
    if (myVersion.majorVersion > version.majorVersion) {
        return YES;
    } else if (myVersion.majorVersion == version.majorVersion) {
        if (myVersion.minorVersion > version.minorVersion) {
            return YES;
        } else if (myVersion.minorVersion == version.minorVersion) {
            return myVersion.patchVersion >= version.patchVersion;
        }
    }
    return NO;
}

@end