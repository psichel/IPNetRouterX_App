//
//  ICMPServer.h
//  IPNetMonitorX
//
//  Created by psichel on Thu Nov 28 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates an ICMP receive thread that waits for ICMP
//  traffic and packages any ICMP datagrams with a timestamp.
//

#import <Foundation/Foundation.h>
//#import <AppKit/AppKit.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class IPHost;
@class IPICMPSocket;

// Globals
#ifndef ICMPNotifications
extern NSString *ICMPControllerNotification;
extern NSString *ICMPMessageNotification;
extern NSString *ICMPSocketNotification;
#endif

@interface ICMPServer : PSServer
{
}

@end

#define kURL_icmp	@"icmp"
#define kICMPBufferSize 4096
#define kControlBufferSize 32
	// used for recvmsg ancilliary data
