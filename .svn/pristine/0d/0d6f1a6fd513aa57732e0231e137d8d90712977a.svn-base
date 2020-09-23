//
//  IPNetClient.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 5/17/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

// Remote Control Client encapsulates sending control messages between a GUI
// and underlying network application running on another machine.

#import "IPNetClient.h"
#import "IPNetServer.h"
#import "IPSupport.h"
#import "PsClient.h"

@interface IPNetClient (PrivateMethods)
- (void)TCPConnection:(TCPConnection *)connection dispatchMessage:(NSMutableDictionary *)message;
@end

@implementation IPNetClient

+ (IPNetClient *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[IPNetClient alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		connectionList = nil;
		messageD = nil;
		lastOffset = 0;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[connectionList release]; connectionList = nil;
	[messageD release]; messageD = nil;
	[super dealloc];
}

// ---------------------------------------------------------------------------------
//	• connectToHost
// ---------------------------------------------------------------------------------
// Attempt to establish a connection to the requested host.
// On success, return TCPConnection object ready for client to setDelegate and
// sendData or receiveData.
// Keep peer name as a connection property.
- (TCPConnection *)connectToHost:(NSHost *)host {
	NSInputStream *iStream;
	NSOutputStream *oStream;
	NSData* addr = nil;	// get peer address from NSHost we're connecting to
	TCPConnection* connection = nil;
	NSString* str;

	// try to establish connection
	[NSStream getStreamsToHost:host port:IPNetPort inputStream:&iStream outputStream:&oStream];
	if (iStream && oStream) {		
		// get peer address to store with connection object
		addr = dataForAddress(ipForString([host address]), IPNetPort);
		//Associate streams with connection object
		connection = [[TCPConnection alloc] initWithPeerAddress:addr inputStream:iStream outputStream:oStream forServer:self];
		// remember peer name if any
		str = [host name];
		if (!str) str = [host address];
		[connection setProperty:str forKey:kPeerName];
		// make ourself the default connection delegate to parse data streams
		[connection setDelegate:self];
		// own our connections (keep a searchable connection table)
		if (!connectionList) connectionList = [[NSMutableArray alloc] init];
		[connectionList addObject:connection];
		[connection release];
				
	}
	return connection;
}

// ---------------------------------------------------------------------------------
//	• releaseConnection
// ---------------------------------------------------------------------------------
// use [connection invalidate] to close connection which will call here to release it
- (void)releaseConnection:(TCPConnection *)connection
{
	[connectionList removeObject:connection];
}

// ---------------------------------------------------------------------------------
//	• connectionCount
// ---------------------------------------------------------------------------------
- (int)connectionCount
{
	return [connectionList count];
}

// ---------------------------------------------------------------------------------
//	• findConnection:
// ---------------------------------------------------------------------------------
- (TCPConnection *)findConnection:(NSString *)hostName
{
	TCPConnection* returnValue = nil;
	TCPConnection* connection;
	NSEnumerator* en;
	NSString* peerName;
	
	if (!hostName) returnValue = [connectionList objectAtIndex:0];
	else {
		en = [connectionList objectEnumerator];
		while (connection = [en nextObject]) {
			peerName = [connection propertyForKey:kPeerName];
			if ([hostName isEqualTo:peerName]) {
				returnValue = connection;
				break;
			}
		}
	}
	return returnValue;
}


#pragma mark -- Message Dispatch --
// ---------------------------------------------------------------------------------
//	• TCPConnection:receiveData:
// ---------------------------------------------------------------------------------
// Return: YES return means that a complete request was parsed, and the caller
// should call again as the buffered bytes may have another complete
// request available.
- (BOOL)TCPConnection:(TCPConnection *)connection receiveData:(NSMutableData *)inData {
	BOOL returnValue = NO;
	int result;
	int startContent = 0;
	int endContent = 0;
	PSData inBuf;
	PSRange range;
	NSString* tag;
	NSString* startTag = nil;
	int size;
	
	// load up request dictionary from data
	if (!messageD) {
		messageD = [[NSMutableDictionary alloc] init];
		lastOffset = 0;
	}
	inBuf.bytes = [inData mutableBytes];
	inBuf.length = [inData length];
	inBuf.bufferLength = inBuf.length;
	inBuf.offset = lastOffset;
	do {
		tag = nil;
		size = 0;
		result = findTag(&inBuf, &range, &tag, &size);
		if (result < 0) break;
		if (result == 0) {
			// found openning tag;
			startContent = inBuf.offset;
			if ([tag isEqualTo:kRequest]) {
				// begin a new request
				[messageD removeAllObjects];
				[messageD setObject:kMessageStart forKey:kMessageStart];
				continue;
			}
			// remember tag string
			// No stack required since no other nesting is defined.  Ignore unmatched tags.
			startTag = tag;
			// skip size of enclosed data if specified
			inBuf.offset += size;
			if (inBuf.offset > inBuf.length) break;
		}
		else {
			// found closing tag
			if ([tag isEqualTo:kRequest]) {
				// end of request
				[messageD setObject:kMessageEnd forKey:kMessageEnd];
				// remove upto closing tag from inData
				int pos = range.location + range.length;		// end of closing tag
				int len = [inData length] - pos;				// length of remaining bytes in buffer
				memmove(inBuf.bytes, &inBuf.bytes[pos], len);	// slide data to start of buffer
				[inData setLength:len];							// set new length
				lastOffset = 0;									// reset offset
					// don't need to reset inBuf.length since we're exiting to be called again
				// indicate we parsed a complete request
				returnValue = YES;
				break;
			}
			// check for match
			if ([tag isEqualTo:startTag]) {
				// found tag pair, save data for key
				endContent = range.location;	// start of tag found
				NSData* content = [NSData dataWithBytes:&inBuf.bytes[startContent] length:endContent-startContent];
				[messageD setObject:content forKey:startTag];
				// don't reparse the same tag pair
				lastOffset = range.location + range.length;
			}
		}
	} while (inBuf.offset <= inBuf.length);
	// do we have a complete request?
	if ([messageD objectForKey:kMessageStart] && [messageD objectForKey:kMessageEnd]) {
		// dispatch message
		[self TCPConnection:connection  dispatchMessage:messageD];
	}

	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• dispatch message
// ---------------------------------------------------------------------------------
// Have a complete request with parameters in mutable dictionary as NSData objects for keys.
// Extract parameter data as NSStrings or unarchived objects and invoke requested target
// through corresponding ServiceNub.
// Lookup ServiceNub in serviceDictionary.  If not found, try to handle known targets
// including "create" to create a new server in a detached thread.
// Known targets: NKEServer, DHCPServer, createNewServer (object is name of server class)
- (void)TCPConnection:(TCPConnection *)connection dispatchMessage:(NSMutableDictionary *)message
{
	NSData* temp;
	NSString* target;
	NSString* replyTo = nil;
	NSString* serviceURL = nil;
	id anObject = nil;
	
	do {
		// Extract parameter data
		temp = [message objectForKey:kTarget];
		if (!temp) break;
		target = [[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding];
		
		temp = [message objectForKey:kReplyTo];
		if (temp) replyTo = [[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding];
		
		temp = [message objectForKey:kServiceURL];
		if (temp) serviceURL = [[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding];

		temp = [message objectForKey:kWithObject];
		if (temp) anObject = [NSKeyedUnarchiver unarchiveObjectWithData:temp];
		
		// look for message target
		PsClient* clientObject = [connection providerForKey:target];
		// invoke client with object received
		if (clientObject) [clientObject receiveDictionary:anObject];
		else NSLog(@"IPNetClient dispatchMessage unknown client: %@", target);
	} while (false);
}

@end
