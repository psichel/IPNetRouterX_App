//
//  TDController.m
//  IPNetRouterX
//
//  Created by psichel on Wed Jan 24 2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing Traffic Discovery I/O in a separate thread
//  so we don't block while using NSPropertyListSerialization classes

#import "TDController.h"
#import "TDServer.h"

@implementation TDController

// ---------------------------------------------------------------------------------
//	¥ init and dealloc
// ---------------------------------------------------------------------------------
+ (TDController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[TDController allocWithZone:[self zone]] init];
	}
	return sharedTask;
}


- (TDController *)init {
    if (self = [super init]) {
		[self setServerClass:[TDServer class]];
		[self createNewServer:[TDServer class]];
    }
    return self;
}

@end
