//
//  IPNetServer.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 5/17/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

// IPNetServer encapsulates receiving and responding to remote app
// control messages from a GUI network client.

#import <Cocoa/Cocoa.h>
#import "TCPServer.h"
#import "TCPConnection.h"
#import "kftSupport.h"

@class ServiceNub;

#define IPNetPort 5287
// message tags
#define kRequest		@"request"
#define kTarget			@"to"
#define kReplyTo		@"from"
#define kServiceURL		@"URL"
#define kWithObject		@"object"
// dictionary tags
#define kMessageStart	@"messageStart"
#define kMessageEnd		@"messageEnd"

@interface IPNetServer : TCPServer {
	NSMutableArray *connectionList;
	NSMutableDictionary* messageD;
	int lastOffset;
}

+ (IPNetServer *)sharedInstance;

- (void)startServing;
- (void)stopServing;
- (int)connectionCount;
- (void)releaseConnection:(TCPConnection *)connection;
// message dispatch
- (BOOL)TCPConnection:(TCPConnection *)connection receiveData:(NSMutableData *)inData;
//- (void)TCPConnection:(TCPConnection *)connection dispatchMessage:(NSMutableDictionary *)message;
- (Class)serverClassForName:(NSString *)name;
@end


@interface IPNetServer (IPNetServerDelegateMethods)
- (void)IPNetServer:(IPNetServer *)serv didMakeNewConnection:(TCPConnection *)conn;
// If the delegate implements this method, this is called  
// by an IPNetServer when a new connection comes in.  If the
// delegate wishes to refuse the connection, then it should
// invalidate the connection object from within this method.
@end

int findTag(PSData* inBuf, PSRange* outRange, NSString **tag, int *size);

