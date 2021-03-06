//
//  URLAction.m
//  IPNetMonitorX
//
//  Created by psichel on Mon Sep 13 2004.
//  Copyright (c) 2004 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing a URL as a network probe

#import "URLAction.h"
#import "PSArrayTable.h"

#if !BUILD_AS_HELPER_TOOL
#import "IPLookupController.h"
#endif
#import "PSURL.h"
#import "IPSupport.h"
#import "IPKSupport.h"
#import "IPICMPSocket.h"
#import "ICMPController.h"
#import "ICMPNotifications.h"
#import "IPNetMessage.h"

#import "ping.h"
#import "ICMPController.h"
#import "ICMPNotifications.h"
#import "IPHost.h"
#import "IPTCPSocket.h"

#import "NSDate_Extensions.h"

#define kTimeInterval   5

@interface URLAction (PrivateMethods)
- (int)lookup:(NSString *)urlString;
- (int)tcp:(NSString *)urlString;
- (int)ftp:(NSString *)urlString;
// ping
- (int)ping:(NSString *)urlString;
- (int)sendPing:(NSString *)urlString;
- (IPHost *)target;
- (void)setTarget:(IPHost *)value;
- (void)receiveData:(IPNetMessage *)inMessage;
@end

@implementation URLAction

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
	if (self = [super init]) {
        // initialize our instance variables
		// ping
		mTarget =  nil;
		mSequenceNumber = 1717;
		mPingInProgress = NO;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	[self serverTerminate:nil];
	[self setTarget:nil];
    [super dealloc];
}

// ---------------------------------------------------------------------------
//	¥ synchStartService:fromController:withObject:
// ---------------------------------------------------------------------------
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	// override to perform thread services
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	int result = 0;
    
    // The following line is an interesting optimisation.  We tell our proxy
    // to the controller object about the methods that we're going to
    // send to the proxy.    
    [controller setProtocolForProxy:@protocol(ControllerFromThread)];
    // init method vars	
	[self setController:controller];

	// extract parameters
	NSString* urlString = inURL;
	if (!urlString) urlString = [anObject objectForKey:kServerRequest];
	// dispatch commands
	NS_DURING
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}
		else if ([urlString hasPrefix:kServerStop])
			result = [self serverTerminate:anObject];
		else if ([urlString hasPrefix:@"lookup:"]) {
			result = [self lookup:urlString];
		}
		else if ([urlString hasPrefix:@"ping:"]) {
			result = [self ping:urlString];
		}
		else if ([urlString hasPrefix:@"tcp:"]) {
			result = [self tcp:urlString];
		}
		else if ([urlString hasPrefix:@"scan:"]) {  // re-interpret scan as ping for backward compatiblity
			result = [self ping:urlString];
		}
		else {
			// handle other URLs including http and ftp
			result = [self ftp:urlString];
		}
	NS_HANDLER
		NSLog(@"Exception during URL %@",urlString);
	NS_ENDHANDLER

    [pool release]; pool = nil;
	return result;
}


// ---------------------------------------------------------------------------------
//	¥ serverTerminate:
// ---------------------------------------------------------------------------------
- (int)serverTerminate:(NSDictionary *)plist
{
	// no longer checking for scan events
	[self finish];
	return 0;
}


#pragma mark -- URL actions --

// ---------------------------------------------------------------------------------
//	¥ lookup
// ---------------------------------------------------------------------------------
- (int)lookup:(NSString *)urlString
{
	int returnValue = -1;
	NSString* resultString;
    PSURL* url;

    NSString* lookupTarget;
	IPHost* target;
	u_int32_t address;
	in6_addr_t address6;
	int addressFamily;
    
	do {
		// extract url
		url = [PSURL urlWithString:urlString];
		// borrow code from lookup server
         // extract lookup parameters
        // <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
        lookupTarget = [url host];
        if ([lookupTarget length] == 0) {
            [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Please specify a target",@"specify target")];
            break;
        }
		// have lookup string, check for dotted quad
		addressFamily = isIPAddress(lookupTarget, &address, &address6);
		if (addressFamily) {
			target = [[[IPHost alloc] init] autorelease];
			if (addressFamily == AF_INET) [target setHAddress:address];
			else if (addressFamily == AF_INET6) [target setNAddress:(u_int8_t *)&address6 size:16]; 
			if ([target addressToName]) {
				returnValue = 0;
				resultString = [NSString stringWithFormat:@" OK (%@)",[target addressString]];
			}
			else {
				resultString = [NSString stringWithFormat:@" Down (%@)",[target addressString]];
			}
		}
		else {
			target = [[[IPHost alloc] initWithName:lookupTarget] autorelease];
			if ([target nameToAddress]) {
				returnValue = 0;
				resultString = [NSString stringWithFormat:@" OK (%@)",[target name]];
			}
			else {
				resultString = [NSString stringWithFormat:@" Down (%@)",[target name]];
			}
		}
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ tcp
// ---------------------------------------------------------------------------------
- (int)tcp:(NSString *)urlString
{
	int returnValue = -1;
	NSString* resultString = nil;
    PSURL* url;
	IPHost* target;

    // probe for TCP listener
    // 0=connection succeeded, -1=connection error, ETIMEDOUT, ECONNREFUSED
    IPTCPSocket* theSocket = nil;
    do {
		// find target
		url = [PSURL urlWithString:urlString];
		target = [[[IPHost alloc] initWithName:[url host]] autorelease];
		[target nameToAddress];
		[target setPort:[[url port] intValue]];
        // get a TCP socket
        theSocket = [[IPTCPSocket alloc] init];
        if (!theSocket || ([theSocket socket]<0)) {
            resultString = NSLocalizedString(@"unix TCP socket error",@"unix TCP socket error");
            break;
        }    
        // try to connect
        returnValue = [theSocket connectTo:target withTimeOut:(NSTimeInterval)0.4];
        [theSocket setRST];        
		if (returnValue == 0) {
			resultString = [NSString stringWithFormat:@" OK (%@)",[target name]];
		}
		else {
			resultString = [NSString stringWithFormat:@" Down (%@)",[target name]];
		}
    } while (false);
	[theSocket release];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ ftp
// ---------------------------------------------------------------------------------
- (int)ftp:(NSString *)urlString
{
	int returnValue = -1;
	NSString* resultString = nil;
	int len;
	
	NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
	if ((len = [data length])) {
		returnValue = 0;
		resultString = [NSString stringWithFormat:@" OK (%d)",len];
		// pass back whatever we got
		[self updateParameter:kURLData withObject:data];
	}
	else {
		resultString = @" Down";
		// pass back empty data to indicate we didn't get any
		[self updateParameter:kURLData withObject:[NSData data]];
	}
	return returnValue;
}

#pragma mark -- ping --
// ---------------------------------------------------------------------------------
//	¥ ping
// ---------------------------------------------------------------------------------
- (int)ping:(NSString *)urlString
{
	int returnValue = -1;
	NSString* resultString = nil;
	// setup to receive ICMP
	[[ICMPController sharedInstance] addObserver:self
		withSelector:@selector(messageNotification:)];
	// send ping
	returnValue = [self sendPing:urlString];
	// wait for response or time out
	int j;
	BOOL timedOut = YES;
	for (j=0; j<10; j++) {
		if (!mPingInProgress) {
			timedOut = NO;
			break;
		}
		// pause .25 second
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
	}
	if (timedOut) {
		resultString = @" Down";
		mPingInProgress = NO;
	}
	else returnValue = 0;
	// stop receiving ICMP
	[[ICMPController sharedInstance] removeObserver:self];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ sendPing
// ---------------------------------------------------------------------------------
- (int)sendPing:(NSString *)urlString
{
	int returnValue = -1;
	NSString* resultString = nil;
    PSURL* url;
    // setup to send packet
	NSMutableData* sendBuf;
	IPHost* target;
    icmp_header_t*	icmp_header;
    UInt8*		data;
    SInt32		tSize, iSize;
    int			result = 0;
    
    do {
		// find target
		url = [PSURL urlWithString:urlString];
		target = [[[IPHost alloc] initWithName:[url host]] autorelease];
		[target nameToAddress];

        // setup send buffer
		sendBuf = [NSMutableData dataWithCapacity:255];
        if (!sendBuf) break;
        
        // determine packet size (must be an even number between 28 and 2048)
        tSize = 52;
        iSize = tSize - 20;	// icmp size less IP header
        // set buffer size
        [sendBuf setLength:iSize];
        // setup access to send buffer
		icmp_header = [sendBuf mutableBytes];
        data = (UInt8*)icmp_header;
        
        // Initialize ICMP header (8 bytes)
        icmp_header->type = ICMP_ECHO;	// 8=echo request
        icmp_header->code = 0;
        icmp_header->checksum = 0;
        icmp_header->identifier = htons(19);
        icmp_header->seqNumber = htons(++mSequenceNumber);
        
        // ICMP data
        memcpy((char*)&data[8], "©Sustainable Softworks ", 24);
        data[30] = 0;
        data[31] = 0;
        if (iSize > 32) {
                UInt16 i;
                for (i=32; i<iSize; i++) data[i] = i;
        }
        icmp_header->checksum = htons(IpSum((UInt16*)&data[0], (UInt16*)&data[iSize]));
    
        // send data
		[self setTarget:target];		
        result = [[ICMPController sharedInstance] sendTo:target data:sendBuf];
        if (result == 0) {
			resultString = NSLocalizedString(@" send failed",@" send failed");
		}
		else {
			mPingInProgress = YES;
			returnValue = 0;
		}
    } while (false);
	return returnValue;
}

- (IPHost *)target { return mTarget; }
- (void)setTarget:(IPHost *)value {
	[value retain];
	[mTarget release];
	mTarget = value;
}

- (void)messageNotification:(NSNotification *)aNotification {
	[[self retain] autorelease];	// defensive, don't die while handling notification
    // receive ICMP message notification
    IPNetMessage* message;
    if ((message = [[aNotification userInfo]
        objectForKey:ICMPMessageNotification])) {
		if (mPingInProgress) {
			NS_DURING
				[self receiveData:message];
			NS_HANDLER
				NSLog(@"URLAction -messageNotification uncaught exception");
			NS_ENDHANDLER
		}
    }
}

// process receive network data
- (void)receiveData:(IPNetMessage *)inMessage {
    //- (void)receiveData:(NSMutableData *)inData from:(IPHost *)host {
    UInt32 inDataSize;		// size of the data
    UInt8* dp;
    ip_header_t* ip_header;
    ip_header_t* ip_header2;	// triggering datagram
    icmp_header_t* icmp_header;
    icmp_header_t* icmp_header2;
    udp_header_t* udp_header;

    dp = (UInt8*)[[inMessage data] bytes];
    inDataSize = [[inMessage data] length];
    // setup pointer to ip header
    ip_header = (ip_header_t*)dp;
    // setup pointer to icmp header
    icmp_header = (icmp_header_t*)&dp[(ip_header->hlen & 0x0F) * 4];
    // setup pointer to ip header of triggering datagram
    ip_header2 = (ip_header_t*)&icmp_header->data[0];
    // setup pointer to icmp header of triggering datagram
    icmp_header2 = (icmp_header_t*)&icmp_header->data[(ip_header2->hlen & 0x0F) * 4];
    udp_header = (udp_header_t*)&icmp_header->data[(ip_header2->hlen & 0x0F) * 4];

	// did we get an ICMP echo reply
    if (
        (icmp_header->type == kIcmpEchoReply) &&
        (ntohs(icmp_header->seqNumber) == mSequenceNumber) &&	// correct sequence#
        (ntohl(ip_header->srcAddress) == [mTarget v4Address])
    ) {
		mPingInProgress = NO;		
    }
    // did we get a ICMP "time limit exceeded"?
    else if (
        (icmp_header->type == kIcmpTypeTimeExceeded) &&
        (ntohl(ip_header2->dstAddress) == [mTarget v4Address])
    ) {
        [self updateParameter:@"statusInfoAppend" withObject:NSLocalizedString(@"Target out of range",@"Target out of range")];
		mPingInProgress = NO;
    }
    // did we get a ICMP "destination unreachable"?
    else if (
        (icmp_header->type == kIcmpTypeDestUnreachable) &&
        (ntohl(ip_header2->dstAddress) == [mTarget v4Address])		// dest address matches
    ) do {
        [self updateParameter:@"statusInfoAppend" withObject:@" !reach"];
		mPingInProgress = NO;
    } while (false);	// end destination unreachable
}

@end



// ---------------------------------------------------------------------------------
//	¥ 
// ---------------------------------------------------------------------------------
