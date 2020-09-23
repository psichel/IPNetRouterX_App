//
//  DHCPAction.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Wed Nov 12 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PsClient.h"
@class UDPServer;
@class IPUDPSocket;
@class IPNetMessage;
@class DHCPState;
@class DHCPLogger;
@class DHCPServer;
@class DHCPState;

extern NSString *DHCPLoggerNotification;

@interface DHCPAction : NSObject {
	NSTimer*		eventTimer;
	NSMutableArray*	messageQ;
	BOOL			mDataFlag;
	// test state
	id				delegate;
	PsClient*		mClient;			// UDP receive thread
	int				mServerSockfd;		// our DHCP Server socket
	int				mAbortFD;
	IPUDPSocket*	mUDPSendSocket;
	bool			mWriteStatusFlag;   // use to cache writes
	NSMutableArray*  mResponseArray;	// hold pending response data
	NSMutableDictionary* mBPFSenders;		// dictionary of BPFTransmit objects as needed for each active port
	NSArray*		messageTypes;
	int				mLoopCount;
	// helpers
	DHCPState*		dhcpState;
	NSMutableDictionary* mParameterUpdates;		// collect parameter updates
	// buffer to assemble log messages
	NSMutableString* mLogMessage;
	// network buffers
    NSMutableData*	mSendBuf;
}

+ (DHCPAction *)sharedInstance;
- (DHCPState *)dhcpState;
- (void)setDhcpState:(DHCPState *)value;
- (id)delegate;
- (void)setDelegate:(DHCPServer *)value;

- (int)startServing;
- (int)stopServing;
// logistics
- (void)eventTimer:(id)timer;
- (BOOL)readStatusTable;
- (BOOL)writeStatusTable;
- (BOOL)writeStatusEntry:(u_int32_t)leaseAddress;
- (void)receiveDictionary:(NSDictionary *)dictionary;
- (void)messageNotification:(NSNotification *)aNotification;
@end


