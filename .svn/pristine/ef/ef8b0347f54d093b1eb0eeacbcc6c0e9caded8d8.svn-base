//
//  FirewallOptions.m
//  IPNetSentryX
//
//  Created by Peter Sichel on 10/14/05.
//  Copyright 2005 Sustainable Softworks. All rights reserved.
//

#import "FirewallOptions.h"


@implementation FirewallOptions

+ (FirewallOptions *)sharedInstance
{
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[FirewallOptions alloc] init];
	}
	return sharedTask;
}

- (id)init
{
    NSString *path;
    if (self = [super init]) {
        path=[[NSBundle mainBundle] pathForResource:@"FirewallOptions" ofType:@"plist"];
        optionsDictionary = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
        if (!optionsDictionary) {
			NSBeep();
			NSLog(@"FirewallOptions could not find path for resource FirewallOptions");
		}
    }
    return self;
}
- (void)dealloc
{
    [optionsDictionary release];
    [super dealloc];
}

- (NSDictionary *)optionsDictionary { return optionsDictionary; }

@end
