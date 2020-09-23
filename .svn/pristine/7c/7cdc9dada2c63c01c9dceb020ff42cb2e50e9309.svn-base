//
//  DHCPController.h
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  DHCP client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import <Cocoa/Cocoa.h>

@class PsClient;
@class DHCPLogger;
@class DHCPState;

@interface DHCPController : NSObject
{
	PsClient*		mClient;
	id				callbackTarget;
	DHCPState*		dhcpState;		// mirror DHCP Server state
	DHCPLogger*		dhcpLogger;
}
+ (DHCPController *)sharedInstance;
- (DHCPState *)dhcpState;
- (void)setDhcpState:(DHCPState *)value;
- (void)setCallbackTarget:(id)value;
- (void)receiveNotification:(NSNotification *)aNotification;
// talk to server
- (BOOL)connectToExistingServer:(int)limit showActive:(BOOL)doReport;
- (BOOL)connectToServer;
- (void)receiveDictionary:(NSDictionary *)dictionary;
// DHCP control
- (BOOL)dhcpServerOn:(BOOL)value;
- (void)abort;
- (void)dhcpApply:(NSDictionary *)setting;
- (void)dhcpShowActive;
- (void)writeStatus;
@end
