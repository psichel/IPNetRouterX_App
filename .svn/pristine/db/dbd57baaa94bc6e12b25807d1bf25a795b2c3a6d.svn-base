//
//  SendSendEmailController.m
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  SendEmail client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import "SendEmailController.h"
#import "SendEmailServer.h"

@implementation SendEmailController

// ---------------------------------------------------------------------------------
//	¥ init and dealloc
// ---------------------------------------------------------------------------------
+ (SendEmailController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[SendEmailController allocWithZone:[self zone]] init];
	}
	return sharedTask;
}


- (SendEmailController *)init {
    if (self = [super init]) {
		[self setServerClass:[SendEmailServer class]];
		[self createNewServer:[SendEmailServer class]];
    }
    return self;
}

@end
