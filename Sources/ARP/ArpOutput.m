//
//  ArpOutput.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Tue Dec 30 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.

#import "ArpOutput.h"


@implementation ArpOutput
// ---------------------------------------------------------------------------------
//	sharedInstance
// ---------------------------------------------------------------------------------
+ (ArpOutput *) sharedInstance {
	static id sharedTask = nil;	
	if(sharedTask==nil) {
		sharedTask = [[NSMutableString alloc] initWithCapacity:512];
	}
	return sharedTask;
}

@end
