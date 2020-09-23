//
//  RouteOutput.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Fri Sep 16 2005.
//  Copyright (c) 2005 Sustainable Softworks, Inc. All rights reserved.

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
