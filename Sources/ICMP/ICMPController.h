//
//  ICMPController.h
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
#import <Cocoa/Cocoa.h>
#import "PsClient.h"
@class IPICMPSocket;
@class IPHost;

// Globals
#ifndef ICMPNotifications
extern NSString *ICMPControllerNotification;
extern NSString *ICMPMessageNotification;
extern NSString *ICMPSocketNotification;
#endif

@interface ICMPController : NSObject
{
    PsClient*		mClient;
	IPICMPSocket*	mICMPSocket;
    BOOL			mIsReceiving;
}
+ (ICMPController *)sharedInstance;
    // returns a shared instance of the class
- (BOOL)startReceiving;
    // start ICMP service
- (void)addObserver:(id)target withSelector:(SEL)method;
    // notify receiver for any ICMP received
- (void)removeObserver:(id)target;
- (ssize_t)sendTo:(IPHost *)host data:(NSData *)data;
    // send ICMP data
- (void)receiveDictionary:(NSDictionary *)dictionary;
// send ping
- (int)sendPing:(u_int32_t)inPingAddress;
@end
