//
//  ListenServer.m
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  Listen client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import "ListenServer.h"
#import "PSURL.h"

@implementation ListenServer

// -- Thread Server Interface --
- (oneway void)startService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
// see comments in PSServerInterface.h
{
    NSAutoreleasePool* pool = nil;
    PSURL* url=nil;
//	int result = 0;
    
    // The following line is an interesting optimisation.  We tell our proxy
    // to the controller object about the methods that we're going to
    // send to the proxy.    
    [controller setProtocolForProxy:@protocol(ControllerFromThread)];
    // init method vars
	pool = [[NSAutoreleasePool alloc] init];
	[self setController:controller];

	// extract Listen parameters
	// listen:  withObject:(IPHost *)host
	url = [[PSURL alloc] init];
	[url setStringValue:inURL];
	// dispatch commands
	if (mFinishFlag) {
		[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
	}
	else if ([[url scheme] isEqualTo:@"listen"]) {		
		// create a TCP socket
		
		// bind to local endpoint
		
		// set to listen

		// repeat until controller aborts
		while (![controller didUserAbort]) {			
			// accept connection requests
			
			if ([controller didUserAbort]) break;
			// check password
			
			// check request
			
			// pass back results (connected socket and remote peer)
		}
	}
	else {
		[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
	}

    [url release];
    [pool release]; pool = nil;
}

@end
