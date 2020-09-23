//
//  NSException_Extensions.h
//
//  Created by psichel on Tues Dec 23 2003.
//  Copyright (c) 2001 Sustainable Softworks, Inc. All rights reserved.
//
//	Work around synchronization bug in [NSException date] versus UNIX gettimeofday()

#import "NSException_Extensions.h"
#import <Foundation/Foundation.h>
#import <ExceptionHandling/NSExceptionHandler.h>

@implementation NSException (PSExtensions)
- (void)printStackTrace 
{
    NSString *stack = [[self userInfo] objectForKey:NSStackTraceKey];
    if (stack) {
        NSTask *ls = [[NSTask alloc] init];
        NSString *pid = [[NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]] stringValue];
        NSMutableArray *args = [NSMutableArray arrayWithCapacity:30];
 
        [args addObject:@"-p"];
        [args addObject:pid];
        [args addObjectsFromArray:[stack componentsSeparatedByString:@"  "]];
        // Note: function addresses are separated by double spaces, not a single space.
 
        [ls setLaunchPath:@"/usr/bin/atos"];
        [ls setArguments:args];
        [ls launch];
        [ls release];
 
    } else {
        NSLog(@"No stack trace available.");
    }
}

@end
