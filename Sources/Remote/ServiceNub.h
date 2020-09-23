//
//  ServiceNub.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 6/8/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//
//	Translate PSServerInterface object messages to and from
//  serialized TCP messages for remote app control
//  The server nub acts as a standin or proxy for the remote client

#import <Cocoa/Cocoa.h>
#import "PSServerInterface.h"
#import "TCPConnection.h"


@interface ServiceNub : NSObject <ControllerFromThread> {
	TCPConnection* connection;
	Class		serverClass;
	id			remoteServer;
	NSString*	replyTo;
}
- (ServiceNub *)initWithConnection:(TCPConnection *)connection from:(NSString *)replyToName;
- (id)server;
- (void)setServer:(id)server;
- (NSString *)replyTo;
- (void)setReplyTo:(NSString *)value;
// create and kill servers running in their own thread
- (BOOL)createNewServer:(Class)serverClass;
- (void)killServer;
- (void)connectionDidDie:(NSNotification *)aNotification;


@end
