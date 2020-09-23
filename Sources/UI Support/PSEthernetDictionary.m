//
//  PSEthernetDictionary.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on Fri Jun 21 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//

#import "PSEthernetDictionary.h"

@implementation PSEthernetDictionary
+ (PSEthernetDictionary *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[PSEthernetDictionary alloc] init];
	}
	return sharedTask;
}

- init
{
    NSString *path;
    if (self = [super init]) {
        path=[[NSBundle mainBundle] pathForResource:@"ethernetNames" ofType:@"plist"];
        ethernetNames = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
        if (!ethernetNames) {
			NSLog(@"PSEthernetDictionary could not find path for resource ethernetNames %@", path);
		}
        nameCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc
{
    [ethernetNames release];
    [nameCache release];
    [super dealloc];
}

- (NSString *)orgForEthernetAddress:(NSString *)macAddress {
	NSString* returnValue = nil;
	if ([macAddress length]) {
		NSString* oui;
		NSString* org;
		oui = [macAddress substringToIndex:8];
		org = [nameCache objectForKey:oui];
		if (!org) org = [ethernetNames objectForKey:oui];
		if (org) {
			[nameCache setObject:org forKey:oui];
			returnValue = org;
		}
	}
	return returnValue;
}

@end
