//
//  IPNetClient.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 5/17/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

// Remote Control Client encapsulates sending control messages between a GUI
// and underlying network application running on another machine.

#import <Cocoa/Cocoa.h>
@class TCPConnection;


@interface IPNetClient : NSObject {
	NSMutableArray *connectionList;				// remember our open connections
	NSMutableDictionary* messageD;		// collect response info
	int lastOffset;
}

+ (IPNetClient *)sharedInstance;
- (TCPConnection *)connectToHost:(NSHost *)host;
- (void)releaseConnection:(TCPConnection *)connection;
- (int)connectionCount;
- (TCPConnection *)findConnection:(NSString *)hostName;
// message dispatch
- (BOOL)TCPConnection:(TCPConnection *)connection receiveData:(NSMutableData *)inData;
//- (void)TCPConnection:(TCPConnection *)connection dispatchMessage:(NSMutableDictionary *)message;
@end

#define kPeerName @"PeerName"