//
//  ICMPController.m
//  IPNetMonitorX
//
//  Created by psichel on Mon Nov 19 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates an ICMP listener that timestamps received data
//  before waking other threads.  Uses NSNotificationCenter to
//  distribute incoming ICMP to requesting clients.  By doing
//  all ICMP from a single recvfrom listener, we avoid having
//  to wake up many pthreads for every ICMP datagram received.
//
#import "ICMPServer.h"
#import "IPICMPSocket.h"
#import "IPNetMessage.h"
#import "ping.h"
#import "IPKSupport.h"

// Globals
NSString *ICMPControllerNotification = @"ICMPControllerNotification";
NSString *ICMPMessageNotification = @"ICMPMessageNotification";
NSString *ICMPSocketNotification = @"ICMPSocketNotification";
#define ICMPNotifications 1
#import "ICMPController.h"

@implementation ICMPController

//- init and dealloc
+ (ICMPController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[ICMPController allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

- (id) init {
    if (self = [super init]) {
        mClient = nil;
		mIsReceiving = NO;
        mICMPSocket = nil;
    }
    return self;
}

- (void)dealloc {
	if (mICMPSocket) {
        [mICMPSocket release];
        mICMPSocket = nil;
    }
	[mClient abort];
	[mClient setCallbackTarget:nil];
	[mClient release];		mClient = nil;
    [super dealloc];
}

- (BOOL)startReceiving {
    do {
        if (mIsReceiving) break;	// don't allow multiples        
        // create ICMP Server object running as a detached thread
		if (!mClient) {
			mClient = [[PsClient alloc] init];
			[mClient setCallbackTarget:self];
			[mClient setServerClass:[ICMPServer class]];
		}
        if (![mClient isConnected]) [mClient createNewServer:[ICMPServer class]];
        if ([mClient isConnected]) {
            // get a raw socket
            if (!mICMPSocket) {
				int socket;
                mICMPSocket = [[IPICMPSocket alloc] init];
				// configure socket options for ICMP
				socket = [mICMPSocket socket];
				if (socket > 0) {
					int value, result;
					value = 1;
					result = setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &value, sizeof(int));
					if (result < 0) {
						result = errno;
						NSLog(@"%s", strerror(result));
						break;
					}
				}
            }
            if (!mICMPSocket || ([mICMPSocket socket]<0)) {
                NSDictionary* myDictionary;
                myDictionary = [NSDictionary dictionaryWithObject:NSLocalizedString(@"unix socket error",@"unix socket error") forKey:@"statusInfo"];
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:ICMPControllerNotification
                    object:self
                    userInfo:myDictionary];
                break;
            }
            // launch service
            [mClient startService:[NSString stringWithFormat:@"icmp://%d",[mICMPSocket socket]] withObject:nil];
            mIsReceiving = YES;
        }
		else {
			NSLog(@"Failed to connect with ICMPServer");
		}
    } while (false);
    return mIsReceiving;
}

- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:ICMPMessageNotification 
    object:self];
}

- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:ICMPMessageNotification
        object:self];
}

- (ssize_t)sendTo:(IPHost *)host data:(NSData *)data {
    ssize_t result = 0;
    if (mICMPSocket) {
        result = [mICMPSocket sendTo:host data:data];
    }
    return result;
}


// -- <ControllerFromThread> --
// ---------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
{
    NSEnumerator *enumerator = [dictionary keyEnumerator];
    id key;
    id object;

	if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
		if (mICMPSocket) {
			[mICMPSocket release];
			mICMPSocket = nil;
		}
		mIsReceiving = NO;
	}
	
	else {
		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			object = [dictionary objectForKey:key];
			// notify clients
			if ([key isEqualTo:ICMPMessageNotification]) {
				// notify listeners with ICMP message received
				[[NSNotificationCenter defaultCenter]
					postNotificationName:ICMPMessageNotification
					object:self
					userInfo:dictionary];
//				YieldToAnyThread();
				break;	// only one message per update
			}
			else {
				// pass any other message as ICMPControllerNotification
				// probably a "statusInfo" string
				[[NSNotificationCenter defaultCenter]
					postNotificationName:ICMPControllerNotification
					object:self
					userInfo:dictionary];
				break;	// only one item per update
			}
		}   // while ((key = [enumerator nextObject]))
	}
}

#pragma mark - send ping -

// ---------------------------------------------------------------------------
//		¥ SendPing
// ---------------------------------------------------------------------------
- (int)sendPing:(u_int32_t)inPingAddress
{
    // setup to send packet
	IPHost* target;
	NSMutableData* sendBuf = [NSMutableData dataWithCapacity:100];
    icmp_header_t*	icmp_header;
    UInt8*		data;
    SInt32		tSize, iSize;
    int			result = 0; // number of bytes sent
    
    do {
        // set destination
		target = [[[IPHost alloc] init] autorelease];
		[target setHAddress:inPingAddress];
		// setup access to send buffer
        //[sendBuf retain];
        icmp_header = [sendBuf mutableBytes];
        data = (UInt8*)icmp_header;
        
        // determine packet size (must be an even number between 28 and 2048)
        tSize = 52;
        iSize = tSize - 20;	// icmp size less IP header
        // set buffer size
        [sendBuf setLength:iSize];
        
        // Initialize ICMP header (8 bytes)
        icmp_header->type = ICMP_ECHO;	// 8=echo request
        icmp_header->code = 0;
        icmp_header->checksum = 0;
        icmp_header->identifier = htons(0x1717);
        icmp_header->seqNumber = htons(0x1717);
        
        // ICMP data
        memcpy((char*)&data[8], "Â©Sustainable Softworks ", 24);
        data[30] = 0;
        data[31] = 0;
        if (iSize > 32) {
                UInt16 i;
                for (i=32; i<iSize; i++) data[i] = i;
        }
        icmp_header->checksum = IpSum((UInt16*)&data[0], (UInt16*)&data[iSize]);
    
        // send data
        result = [self sendTo:target data:sendBuf];
        // ping will often fail normally if there's no host
//		if (result == 0) NSLog( NSLocalizedString(@"send failed",@"send failed") );
    } while (NO);
	return result;
}

@end
