//
//  ServiceNub.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 6/8/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//
//	Translate PSServerInterface object messages to and from
//  serialized TCP messages for remote app control.
//  The server nub acts as a standin or proxy for responding to the remote client
//
// The nub is initialized with a TCPConnection.  There are two ways it can
// be associated with a server object:
// (1) The object can be set explicitly by name;
// (2) An object of the requested class is created and run in a separate
//     thread using Cocoa's Distributed Objects mechanism.
// Either case is initiated by request from ServerDispatch.
//
// Connection data is parsed by the IPNetServer (or helper) since there
// could be many nubs associated with a single connection, one for each
// remote service being controlled.

#import "ServiceNub.h"
#import "kftSupport.h"
#import "IPNetServer.h"

@implementation ServiceNub

- (id)init {
    [self dealloc];
    return nil;
}

- (void)dealloc {
    [super dealloc];
}

// ---------------------------------------------------------------------------
//	• initWithConnection:
// ---------------------------------------------------------------------------
- (ServiceNub *)initWithConnection:(TCPConnection *)conn from:(NSString *)replyToName
{
	connection = conn;
	serverClass = nil;
	remoteServer = nil;
	replyTo = nil;
	[self setReplyTo:replyToName];

    return self;
}

// ---------------------------------------------------------------------------
//	• setServer
// ---------------------------------------------------------------------------
- (id)server { return remoteServer; }
- (void)setServer:(id)value {
	[value retain];
	[remoteServer release];
	remoteServer = value;
}

- (NSString *)replyTo { return replyTo; }
- (void)setReplyTo:(NSString *)value
{
	[value retain];
	[replyTo release];
	replyTo = value;
}


#pragma mark -- create and kill servers that run in their own thread --
// ---------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------
- (BOOL)createNewServer:(Class)serverClass
{
	return YES;
}

// ---------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------
- (void)killServer
{
}

// ---------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------
- (void)connectionDidDie:(NSNotification *)aNotification
{
}

#pragma mark -- <ControllerFromThread> --
// ---------------------------------------------------------------------------
//	• receiveDictionary:
// ---------------------------------------------------------------------------
// update parameters passed in dictionary
// Catch exceptions since this might be called by DO proxy.
- (void)receiveDictionary:(NSDictionary *)dictionary
{
	// setup autorelease pool so we free any objects used in message processing
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NS_DURING
		// encode dictionary as NSData
		NSData* data = [NSKeyedArchiver archivedDataWithRootObject:dictionary];
		int len = [data length];
		// build response message and send it
		// <request>
		// <target>replyTo</target>
		// <object:len>NSData</object>
		// </request>
		
		// setup a big enough buffer
		NSMutableData* outData = [NSMutableData dataWithCapacity:len+200];
		if (outData) {
			PSData outBuf;
			outBuf.bytes = [outData mutableBytes];
			outBuf.length = [outData length];
			outBuf.bufferLength = outBuf.length;
			outBuf.offset = 0;
			
			// <request>
			appendCString(&outBuf, "<");
			appendCString(&outBuf, (char *)[kRequest cStringUsingEncoding:NSASCIIStringEncoding] );
			appendCString(&outBuf, ">\r");
			
			// <target>replyTo</target>
			appendCString(&outBuf, "<");
			appendCString(&outBuf, (char *)[kTarget cStringUsingEncoding:NSASCIIStringEncoding]);
			appendCString(&outBuf, ">");
			appendCString(&outBuf, (char *)[replyTo cStringUsingEncoding:NSASCIIStringEncoding]);
			appendCString(&outBuf, "</");
			appendCString(&outBuf, (char *)[kTarget cStringUsingEncoding:NSASCIIStringEncoding]);
			appendCString(&outBuf, ">\r");
			
			// <object:len>data</object>
			appendCString(&outBuf, "<");
			appendCString(&outBuf, (char *)[kWithObject cStringUsingEncoding:NSASCIIStringEncoding]);
			appendCString(&outBuf, ":");
			appendInt(&outBuf, len);
			appendCString(&outBuf, ">");
			memcpy(&outBuf.bytes[outBuf.offset], [data bytes], len);	// data object
			outBuf.offset += len;
			appendCString(&outBuf, "</");
			appendCString(&outBuf, (char *)[kWithObject cStringUsingEncoding:NSASCIIStringEncoding]);
			appendCString(&outBuf, ">\r");
			
			// </request>
			appendCString(&outBuf, "</");
			appendCString(&outBuf, (char *)[kRequest cStringUsingEncoding:NSASCIIStringEncoding] );
			appendCString(&outBuf, ">\r");
			
			// set actual length
			[outData setLength:outBuf.offset];
			// send response up TCP connection to client target
			[connection sendData:outData];
		}
	NS_HANDLER
		NSString* statusInfo = @"Exception during Server Nub receiveDictionary";
		NSLog(statusInfo);
	NS_ENDHANDLER
	[pool release];
}

// ---------------------------------------------------------------------------
//	• didUserAbort
// ---------------------------------------------------------------------------
// Test if user pressed abort or other redirection
// note value returned (two way).
- (BOOL)didUserAbort
{
	return NO;
}

@end
