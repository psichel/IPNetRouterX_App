//
//  ListenController.m
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  Listen client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import "ListenServer.h"
#import "ListenController.h"

@implementation ListenController

// ---------------------------------------------------------------------------------
//	¥ init and dealloc
// ---------------------------------------------------------------------------------
+ (ListenController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[ListenController allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

- (id) init {
    if (self = [super init]) {
		[self setServerClass:[ListenServer class]];
		[self createNewServer:[ListenServer class]];
    }
    return self;
}

@end
