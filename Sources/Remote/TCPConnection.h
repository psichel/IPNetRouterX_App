//
//  TCPConnection.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 6/7/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//
// This class represents each established connection on the client or server side
// Overide or use delegate method below to specify connection specific data stream processing

#import <Cocoa/Cocoa.h>

@interface TCPConnection : NSObject {
@private
    id delegate;
    NSData *peerAddress;
    id server;
    NSMutableArray *requests;
    NSInputStream *istream;
    NSOutputStream *ostream;
    NSMutableData *ibuffer;
    NSMutableData *obuffer;
    BOOL isValid;
    NSMutableDictionary* propertyDictionary;
	NSMutableDictionary* providerDictionary;	// register provider name to object
}

- (id)initWithPeerAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr forServer:(id)serv;

- (id)delegate;
- (void)setDelegate:(id)value;

- (NSData *)peerAddress;

- (id)server;

//- (HTTPServerRequest *)nextRequest;
// get the next request that needs to be responded to

- (BOOL)isValid;
- (void)invalidate;
// shut down the connection

// connection attributes
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)anObject forKey:(NSString *)key;

- (id)providerForKey:(NSString *)key;
- (void)setProvider:(id)anObject forKey:(NSString *)key;

// send/receive connection data
- (void)sendData:(NSData *)outData;
@end

// delegate methods
@interface TCPConnection (TCPConnectionDelegateMethods)
- (BOOL)TCPConnection:(TCPConnection *)connection receiveData:(NSMutableData *)inData;
@end
