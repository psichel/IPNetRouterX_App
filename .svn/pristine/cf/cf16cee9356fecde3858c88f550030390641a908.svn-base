//
//  SentryTest.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Mon Mar 10 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//  Packet filter test harness and collection of test cases.
/*

Design Overview:

synchStartService - Run tests in a separate thread so we don't block the UI
doTest - build mbuf and packet structure, call sendPackets to run test cases
sendPackets - initializePacket, modify contents to define test case, call verifyPacket
initializePacket - initialize IP and TCP header with default values, set packet to inbound on en0
verifyPacket - call KFT_processPacket() to process packet and examine resulting mbuf
	to confirm whether packet was deleted or consumed.

*/

#import <Foundation/Foundation.h>
#import "PSServer.h"
#import "ipkTypes.h"

@interface SentryTest : PSServer {
}
@end

#define kSentryTest		@"sentrytest"
