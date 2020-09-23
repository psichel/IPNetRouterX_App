//
//  TCPConnection.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 6/7/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import "TCPConnection.h"
#import "IPNetServer.h"

@interface TCPConnection (PrivateMethods)
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent;
- (BOOL)processIncomingBytes;
- (void)processOutgoingBytes;
- (void)sendData:(NSData *)outData;
@end

@implementation TCPConnection

- (id)init {
    [self dealloc];
    return nil;
}

// ---------------------------------------------------------------------------------
//	• initWithPeerAddress:inputStream:outputStream:forServer:
// ---------------------------------------------------------------------------------
- (id)initWithPeerAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr forServer:(id)serv {
    peerAddress = [addr copy];
    server = serv;
    istream = [istr retain];
    ostream = [ostr retain];
    [istream setDelegate:self];
    [ostream setDelegate:self];
    [istream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:(id)kCFRunLoopCommonModes];
    [ostream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:(id)kCFRunLoopCommonModes];
    [istream open];
    [ostream open];
    isValid = YES;
	propertyDictionary = [[NSMutableDictionary alloc] init];
	providerDictionary = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc {
    [self invalidate];
    [peerAddress release];
	[propertyDictionary release]; propertyDictionary = nil;
	[providerDictionary release]; providerDictionary = nil;
    [super dealloc];
}

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)value {
    delegate = value;
}

- (NSData *)peerAddress {
    return peerAddress;
}

- (id)server {
    return server;
}

/*
- (IPNetServerRequest *)nextRequest {
    unsigned idx, cnt = requests ? [requests count] : 0;
    for (idx = 0; idx < cnt; idx++) {
        id obj = [requests objectAtIndex:idx];
        if ([obj response] == nil) {
            return obj;
        }
    }
    return nil;
}
*/

// connection attributes
// ---------------------------------------------------------------------------------
//	• propertyForKey
// ---------------------------------------------------------------------------------
- (id)propertyForKey:(NSString *)key {
	return [propertyDictionary objectForKey:key];
}
// ---------------------------------------------------------------------------------
//	• setProperty:forKey:
// ---------------------------------------------------------------------------------
- (void)setProperty:(id)anObject forKey:(NSString *)key {
	[propertyDictionary setObject:anObject forKey:key];
}

// ---------------------------------------------------------------------------------
//	• providerForKey
// ---------------------------------------------------------------------------------
- (id)providerForKey:(NSString *)key {
	return [providerDictionary objectForKey:key];
}
// ---------------------------------------------------------------------------------
//	• setProvider:forKey:
// ---------------------------------------------------------------------------------
- (void)setProvider:(id)anObject forKey:(NSString *)key {
	[providerDictionary setObject:anObject forKey:key];
}

// shutdown
- (BOOL)isValid {
    return isValid;
}

// ---------------------------------------------------------------------------------
//	• invalidate
// ---------------------------------------------------------------------------------
- (void)invalidate {
    if (isValid) {
        isValid = NO;
        [istream close];
        [ostream close];
        [istream release];
        [ostream release];
        istream = nil;
        ostream = nil;
        [ibuffer release];
        [obuffer release];
        ibuffer = nil;
        obuffer = nil;
        [requests release];
        requests = nil;
		// server owns connections
		[server releaseConnection:self];
        //[self release];
        // This last line removes the implicit retain the TCPConnection
        // has on itself, given by the IPNetServer when it abandoned the
        // new connection.
    }
}

#pragma mark -- stream data processing --

// ---------------------------------------------------------------------------------
//	• stream:handleEvent:
// ---------------------------------------------------------------------------------
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent {
    switch(streamEvent) {
    case NSStreamEventHasBytesAvailable:;
        uint8_t buf[16 * 1024];
        uint8_t *buffer = NULL;
        unsigned int len = 0;
        if (![istream getBuffer:&buffer length:&len]) {
            int amount = [istream read:buf maxLength:sizeof(buf)];
            buffer = buf;
            len = amount;
        }
        if (0 < len) {
            if (!ibuffer) {
                ibuffer = [[NSMutableData alloc] init];
            }
            [ibuffer appendBytes:buffer length:len];
        }
        do {} while ([self processIncomingBytes]);
        break;
    case NSStreamEventHasSpaceAvailable:;
        [self processOutgoingBytes];
        break;
    case NSStreamEventEndEncountered:;
        [self processIncomingBytes];
        if (stream == ostream) {
            // When the output stream is closed, no more writing will succeed and
            // will abandon the processing of any pending requests and further
            // incoming bytes.
            [self invalidate];
        }
        break;
    case NSStreamEventErrorOccurred:;
        NSLog(@"IPNetServer stream error: %@", [stream streamError]);
        break;
    default:
        break;
    }
}

// ---------------------------------------------------------------------------------
//	• processIncomingBytes
// ---------------------------------------------------------------------------------
// Some data has arrived on the stream and is sitting in
// [ibuffer bytes] with [ibuffer length].
//
// Return: YES return means that a complete request was parsed, and the caller
// should call again as the buffered bytes may have another complete
// request available.
//
// Overide or use delegate method below to specify connection specific data stream processing
- (BOOL)processIncomingBytes {
	BOOL returnValue = NO;

    if ([self delegate] && [[self delegate] respondsToSelector:@selector(TCPConnection:receiveData:)]) { 
        returnValue = [[self delegate] TCPConnection:self receiveData:ibuffer];
    }

    return returnValue;
}

// ---------------------------------------------------------------------------------
//	• TCPConnection:receiveData:
// ---------------------------------------------------------------------------------
// Return: YES return means that a complete request was parsed, and the caller
// should call again as the buffered bytes may have another complete
// request available.
- (BOOL)TCPConnection:(TCPConnection *)connection receiveData:(NSMutableData *)inData {
	BOOL returnValue = NO;
	// delegate method
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• processOutgoingBytes
// ---------------------------------------------------------------------------------
    // Write as many bytes as possible, from buffered bytes in obuffer.
- (void)processOutgoingBytes {
    
    if (![ostream hasSpaceAvailable]) {
        return;
    }

    unsigned olen = [obuffer length];
    if (0 < olen) {
        int writ = [ostream write:[obuffer bytes] maxLength:olen];
        // buffer any unwritten bytes for later writing
        if (writ < olen) {
            memmove([obuffer mutableBytes], [obuffer mutableBytes] + writ, olen - writ);
            [obuffer setLength:olen - writ];
            return;
        }
        [obuffer setLength:0];
    }
}

// ---------------------------------------------------------------------------------
//	• sendData:
// ---------------------------------------------------------------------------------
// send outData to connection peer
- (void)sendData:(NSData *)outData
{
    if (!obuffer) {
        obuffer = [[NSMutableData alloc] init];
    }
	[obuffer appendData:outData];
	[self processOutgoingBytes];
}

@end
