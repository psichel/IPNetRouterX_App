//
//  RouteOutput.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Tue Dec 30 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.

#import "RouteOutput.h"


@implementation RouteOutput
// ---------------------------------------------------------------------------------
//	sharedInstance
// ---------------------------------------------------------------------------------
+ (RouteOutput *) sharedInstance {
	static id sharedTask = nil;	
	if(sharedTask==nil) {
		sharedTask = [[NSMutableString alloc] initWithCapacity:512];
	}
	return sharedTask;
}

@end
