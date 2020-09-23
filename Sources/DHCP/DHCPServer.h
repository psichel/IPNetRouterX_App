//
//  DHCPServer.h
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  DHCP client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import <Foundation/Foundation.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class DHCPAction;
@class PSURL;


@interface DHCPServer : PSServer
{
	DHCPAction* dhcpAction;
	NSDictionary* prefs;
}
+ (DHCPServer *)sharedInstance;
- (BOOL)serverRestore;
@end

/*
#define kServerStart		@"dhcpstart"
#define kServerStop			@"dhcpstop"
#define kServerApply		@"applySettings"
#define kServerShowActive   @"reportState"
#define kServerTerminate	@"terminate"
*/
#define kServerWriteStatus  @"writeStatus"