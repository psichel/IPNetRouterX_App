//
//  UDPServer.h
//  IPNetMonitorX
//
//  Created by psichel on Thu Nov 28 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates an UDP receive thread that waits for UDP
//  traffic and packages any UDP datagrams with a timestamp.
//

#import <Foundation/Foundation.h>
#import "PSServer.h"
#import "PSServerInterface.h"

// Globals
#ifndef UDPNotifications
extern NSString *UDPControllerNotification;
extern NSString *UDPMessageNotification;
extern NSString *UDPSocketNotification;
#endif

@interface UDPServer : PSServer
{
}
@end

#define kUDPBufferSize 2048
#define kControlBufferSize 64
	// used for recvmsg ancilliary data
