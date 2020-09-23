//
//  SendEmailServer.m
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  SendEmail client and server thread.  We use DO to isolate networking
//  in a thread safe container.
//
//  In this case, we don't want the UI to wait for sending Email to complete.

#import "SendEmailServer.h"
#import "PSURL.h"
#import "AppSupport.h"

@implementation SendEmailServer

#pragma mark -- Thread Server Interface --
// ---------------------------------------------------------------------------------
//	¥ synchStartService:
// ---------------------------------------------------------------------------------
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	int result = 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    PSURL* url=nil;

	NS_DURING    
		// The following line is an interesting optimisation.  We tell our proxy
		// to the controller object about the methods that we're going to
		// send to the proxy.    
		[controller setProtocolForProxy:@protocol(ControllerFromThread)];
		// init method vars
		[self setController:controller];

		// extract SendEmail parameters
		// sendEmailstart://localhost/filepath
		// terminate:
		url = [PSURL urlWithString:inURL];
		// dispatch commands
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}
		else if ([[url scheme] isEqualTo:kSendEmail])
			result = [self sendEmail:url withObject:anObject];
		else if ([[url scheme] isEqualTo:kServerTerminate])
			result = [self serverTerminate:url withObject:anObject];
		else {
			[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
		}
	NS_HANDLER
		NSLog(@"Exception during SendEmailServer.m synchStartService");
	NS_ENDHANDLER
    [pool release]; pool = nil;
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ sendEmail:withObject:
// ---------------------------------------------------------------------------------
// anObject is a dictionary containing the desired Email headers:
// "To", "Subject", "Date", and "Body"
- (int)sendEmail:(PSURL *)url withObject:(id)anObject
{
	BOOL result = -1;
	NSString* bodyText = nil;
	NSString* from = nil;
	// use UNIX sendmail instead of Message.framework
	// /usr/sbin/sendmail -t input-file
/*
To: psichel@sustworks.com
From: psichel@sustworks.com
Subject: Sendmail test
Content-type: text/html

This is a test of sendmail
.
*/
	// Specify content type just before body.
	// Body is separated from headers by a blank line.
	// Message ends with eof or line with a single period.

	// Plan: extract headers from dictionary to build input string
	// and then run sendmail in single send mode.
		// What if already running?
	NSString* key;
	NSString* value;
	NSMutableString* message = [NSMutableString stringWithCapacity:1024];
	NSEnumerator *en = [anObject keyEnumerator];
	while (key = [en nextObject]) {
		if ([key isEqualTo:@"Body"]) bodyText = [anObject objectForKey:key];
		else {
			value = [anObject objectForKey:key];
			[message appendFormat:@"%@: %@\n",key,value];
			if ([key isEqualTo:@"From"]) from = value;	// remember from address for us below
		}
	}
	if (bodyText) {
		// append message body and end of message marker
		[message appendFormat:@"Content-type: text/html\n\n%@\n.",bodyText];
			//NSLog(message);	// show what we got
		// try to send it
		NSString* path = @"/usr/sbin/sendmail";
		NSArray* args;
		if (from) {
			args = [NSArray arrayWithObjects:@"-t", @"-r", from, nil];
		}
		else args = [NSArray arrayWithObjects:@"-t", nil];
		NSString* output = nil;
		result = [AppSupport doTask:path arguments:args input:message output:&output error:nil];
			if (result && output) NSLog(@"UNIX sendmail output: %@",output);
	}
	else result = -1;
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ serverTerminate:withObject:
// ---------------------------------------------------------------------------------
- (int)serverTerminate:(PSURL *)url withObject:(id)anObject
{
	[self finish];
	return 0;
}

@end
