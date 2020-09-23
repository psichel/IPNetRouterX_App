//
//  SentryTest.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Mon Mar 10 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//  Run tests in a separate thread so we don't block the UI.

#import "SentryTest.h"
#import "SentryLogger.h"
#import PS_TNKE_INCLUDE
#import "kft.h"
#import "kftTrigger.h"
#import "kftDelay.h"
#import "kftConnectionTable.h"
#import "kftBridgeTable.h"
#import "kftSupport.h"
#import "IPKSupport.h"
#import "IPSupport.h"
#import "IPTypes.h"
#import "ipkTypes.h"
#import "kftPanther.h"
#import "NSDate_extensions.h"
#import "SentryModel.h"
#ifdef IPNetRouter
	#import "kftNatTable.h"
	#import "kftPortMapTable.h"
	#import "PortMapEntry.h"
	#import "PortMapTable.h"
#endif
#import "FilterTypes.h"

#include <sys/types.h>
#include <net/if_types.h>
#include <net/ethernet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/mbuf.h>
#import <arpa/inet.h>	// inet_aton
#include <netinet/tcp_seq.h>	// sequence number compare macros SEQ_LT, SEQ_LEQ, SEQ_GT, SEQ_GEQ(a,b)

#define EJUSTRETURN -2
#define MBUF_SIZE 128

extern attach_t PROJECT_attach[kMaxAttach+1];

@interface SentryTest (PrivateMethods)
- (int)doTest;
- (void)initializePacket:(KFT_packetData_t*)packet;
- (void)sendPackets:(KFT_packetData_t*)packet;
- (int)verifyPacket:(KFT_packetData_t*)packet;
@end

@implementation SentryTest

// ---------------------------------------------------------------------------------
//	¥ synchStartService:
// ---------------------------------------------------------------------------------
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	int result = 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NS_DURING    
		// The following line is an interesting optimisation.  We tell our proxy
		// to the controller object about the methods that we're going to
		// send to the proxy.    
		[controller setProtocolForProxy:@protocol(ControllerFromThread)];
		// init method vars
		[self setController:controller];

		// extract sentrytest URL parameters
		// sentrytest:
		// dispatch commands
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}
		else if ([inURL isEqualTo:kSentryTest]) {
			//result = [self doTest:inURL withObject:anObject];
			NSLog(@"Begin filter on test packets");
			result = [self doTest];
			KFT_filterUpdate();
			NSLog(@"End filter on test packets");
		}
		else {
			[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
		}
	NS_HANDLER
		NSLog(@"Exception during SentryTest.m synchStartService");
	NS_ENDHANDLER
	
	// create and run test thread as a single shot and then terminate immediately
	[self finish];

    [pool release]; pool = nil;
	return result;
}


#define TEST_BUFFER_SIZE 2048
// ---------------------------------------------------------------------------
//	¥ doTest
// ---------------------------------------------------------------------------
// build mbuf with empty packet and call sendPackets to fill in and send as
// a sequence of test packets
- (int)doTest
{
	// allocate buffers to hold packet info (on stack)
	UInt8 dataBuf[TEST_BUFFER_SIZE];
	PSData inBuf;
	KFT_packetData_t packet;
	mbuf_t m;	// pointer to mbuf chain for datagram
	mbuf_t *mbuf_ptr;
	char *frame_header;
	char **frame_ptr;
	int i;
		// init buffer descriptor
	inBuf.bytes = &dataBuf[0];
	inBuf.length = 0;
	inBuf.bufferLength = TEST_BUFFER_SIZE;
	inBuf.offset = 0;
		// setup attach instance (handled by [SentryModel apply])
	// build a simple mbuf to hold some packet data
		// for more information on mbufs, see TCP/IP Illustrated Volume 2,
		// "The Implementation" by Wright and Stevens
	m = (mbuf_t)inBuf.bytes;
	mbuf_ptr = &m;
	bzero(inBuf.bytes, MBUF_SIZE);	// size of mbuf
	inBuf.offset += 28;	// skip to mbuf data area
	// frame header
	frame_header = (char *)&inBuf.bytes[inBuf.offset];
	for (i=0; i<14; i++) frame_header[i] = i;
	frame_ptr = &frame_header;
	inBuf.offset += 14;
	inBuf.length = 128;
	//m->m_next = 0;
	mbuf_setnext(m, 0);
	//m->m_nextpkt = 0;
	mbuf_setnextpkt(m, 0);
	//m->m_len = 500;
	mbuf_setlen(m, 500);
	//m->m_data = frame_header;
	mbuf_setdata(m, frame_header, 500);
	//m->m_type = MT_DATA;
	mbuf_settype(m, MT_DATA);
	//m->m_flags = M_PKTHDR;
	mbuf_setflags(m, M_PKTHDR);
	//m->m_pkthdr.len = 120;
	mbuf_pkthdr_setlen(m, 120);
	//m->m_pkthdr.rcvif = nil;
	mbuf_pkthdr_setrcvif(m, nil);
		// init packet
	bzero(&packet, sizeof(packet));
	// passed in
	packet.mbuf_ptr = mbuf_ptr;
	packet.frame_ptr = frame_ptr;
	packet.myAttach = &PROJECT_attach[1];	// use first valid attach
	// packet info
	packet.ipOffset = 14;
	packet.direction = kDirectionInbound;
	packet.ifType = IFT_ETHER;
	packet.ifHeaderLen = 14;
	// pass empty IP datagram to test generator
	[self sendPackets:&packet];
	return 0;
}

#define kTestAll 0
// ---------------------------------------------------------------------------
//	¥ sendPackets
// ---------------------------------------------------------------------------
// generate a sequence of test packets for selected test using passed in packet template
- (void)sendPackets:(KFT_packetData_t*)packet
{
	mbuf_t m;
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	icmp_header_t* icmpHeader;
	int result;

	m = *(packet->mbuf_ptr);
	ipHeader = (ip_header_t *)&m->m_data[packet->ipOffset];
	tcpHeader = (tcp_header_t*)((UInt8*)ipHeader + 20);
	icmpHeader = (icmp_header_t*)((UInt8*)ipHeader + 20);
		// recalculate IP header checksum
	//ipHeader->checksum = IpSum((u_int16_t*)ipHeader, (u_int16_t*)((UInt8*)ipHeader + 20));
		// specify data content
	//strcpy(&m->m_data[40+packet->ipOffset], "GET /test/image/xxx  ");
	// reset AVL trees
	KFT_triggerStart();
	KFT_connectionStart();
#if IPNetRouter
	KFT_natStart();
#endif

#define INTERNAL_IF "en0"
#define EXTERNAL_IF "en2"
#pragma mark test trigger table (single)
	// test trigger table (single)
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress -= 1;
			// add one item
		NSLog(@"add item(s) to trigger table");
		for (i=0; i<1; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// test port 25
			tcpHeader->dstPort = 25;
			// send packet
			[self verifyPacket:packet];
		}
			// test for item in table
		NSLog(@"test for item in trigger table");
		[self initializePacket:packet];
		tcpHeader->dstPort = 80;
		[self verifyPacket:packet];
		// expected result
		// total packets 2
		// one trigger on port 25
		// one triggered address dropped
		KFT_filterPeriodical();
	}

#pragma mark test trigger table (single age out)
	// test trigger table (single age out)
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
			// add one item
		NSLog(@"add 1 item to trigger table");
		// test port 25
		tcpHeader->dstPort = 25;
		// send packet
		[self verifyPacket:packet];
			// test for item in table
		NSLog(@"test for item in trigger table");
		[self initializePacket:packet];
		tcpHeader->dstPort = 80;
		[self verifyPacket:packet];
			// sleep to let it age
		[NSThread sleepUntilDate:[NSDate
			dateWithTimeIntervalSinceNow:(NSTimeInterval)1.1] ];
		i = KFT_triggerAgeWithLimit(1);
		NSLog(@"aged out %d", i);
			// test item has aged out
		NSLog(@"test for item in trigger table");
		[self initializePacket:packet];
		tcpHeader->dstPort = 80;
		[self verifyPacket:packet];
		// expected result
		// total packets 3
		// one trigger on port 25
		// one triggered address dropped
		// one gets through because trigger aged out
		KFT_filterPeriodical();
	}

#pragma mark test trigger table (multiple)
	// test trigger table (multiple)
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress -= 1;
		NSLog(@"Load trigger table");
		for (i=0; i<25; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// test port 25
			tcpHeader->dstPort = 25;
			// send packet
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();		// force tables to update before sleep
		[NSThread sleepUntilDate:[NSDate
			dateWithTimeIntervalSinceNow:(NSTimeInterval)2.1] ];
		for (i=25; i<75; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// test port 25
			tcpHeader->dstPort = 25;
			// send packet
			[self verifyPacket:packet];
		}
		for (i=75; i<100; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// test port 23
			tcpHeader->dstPort = 23;
			// send packet
			[self verifyPacket:packet];
		}
		i = KFT_triggerAgeWithLimit(2);
		NSLog(@"aged out %d older than 1", i);
		// test which are still in trigger table
		NSLog(@"test against trigger table");
		[self initializePacket:packet];
		ipHeader->srcAddress -= 1;
		for (i=0; i<100; i+=5) {
			ipHeader->srcAddress += 5;
			tcpHeader->dstPort = 80;
			[self verifyPacket:packet];
		}
		i = KFT_triggerAgeWithLimit(10);
		NSLog(@"aged out %d older than 10", i);
		// expected result
		// total packet 120
		// 100 triggered port (25 on port 23, 75 on port 25)
		// 15 triggered address
		// 5 bypass trigger becuase aged out
		KFT_filterPeriodical();
	}

#pragma mark test delay table
	// test delay table
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress += 1024;
		tcpHeader->code = kCodeRST;
		NSLog(@"Sending packets with TCP RST flag");
		for (i=0; i<20; i++) {
			ipHeader->srcAddress += 1;
			// send packet
			[self verifyPacket:packet];
			// practice aging out early entries
		}
		KFT_delayAge(1);
		for (i=0; i<20; i++) {
			ipHeader->srcAddress += 1;
			// send packet
			[self verifyPacket:packet];
			// practice aging out early entries
		}
		KFT_delayAge(1);
		// make sure table is empty
		for (i=0; i<25; i++) {
			ipHeader->srcAddress += 1;
			// send packet
			[self verifyPacket:packet];
			// practice aging out early entries
		}
		KFT_delayAge(0);
		// expected result in Sentry Log
		// see "Delay packet, next entry: xx packet consumed for each packet sent
		// See "Inject packet, from delay entry: xx as corresponding entries are aged out
		// See Delay table compacted kft_delayNextEntry: xx when aging is complete.
		KFT_filterPeriodical();
	}

#pragma mark test idle time
	// test idle time
	if (kTestAll || 0) {
		int i;
		for (i=0; i<300; i++) KFT_filterUpdate();	// 5 minutes
		KFT_filterPeriodical();
	}

#pragma mark test logging load
	// test logging load
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress += 2000;
		for (i=0; i<20; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// dest port 20
			tcpHeader->dstPort = 20;
			// send packet
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();
	}

#pragma mark test interface
	// test interface
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		// en0
		// select corresponding attach instance
		i = KFT_attachIndexForName("en0");
		if (i) {
			NSLog(@"Simulating packet received on en0");
			packet->myAttach = &PROJECT_attach[i];
			[self verifyPacket:packet];
		}
		// en1
		// select corresponding attach instance
		i = KFT_attachIndexForName("en1");
		if (i) {
			NSLog(@"Simulating packet received on en1");
			packet->myAttach = &PROJECT_attach[i];
			[self verifyPacket:packet];
		}
		// en2
		// select corresponding attach instance
		i = KFT_attachIndexForName("en2");
		if (i) {
			NSLog(@"Simulating packet received on en2");
			packet->myAttach = &PROJECT_attach[i];
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();
	}
	
#pragma mark test src/dst net
	// test src/dst network
	if (kTestAll || 1) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress = ipForString(@"192.168.0.10");
		for (i=0; i<20; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// send packet
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();
		NSLog(@"Simulated packets from 192.168.0.11-30");
	}

#pragma mark test TCP ports
	// test TCP ports
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress += 2000;
		for (i=0; i<200; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// dest port
			tcpHeader->dstPort = i;
			// send packet
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();
	}

#pragma mark test UDP ports
	// test UDP ports
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress += 2500;
		for (i=0; i<200; i++) {
			ipHeader->protocol = IPPROTO_UDP;
			// vary source address
			ipHeader->srcAddress += 1;
			// dest port 25
			tcpHeader->dstPort = i;
			// send packet
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();
	}	

#pragma mark test ICMP type and code
	// test ICMP type and code
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress += 3000;
		for (i=0; i<15; i++) {
			ipHeader->protocol = IPPROTO_ICMP;
			// ICMP type and code
			icmpHeader->type = i;
			icmpHeader->code = i;
			// send packet
			[self verifyPacket:packet];
		}
		for (i=0; i<15; i++) {
			ipHeader->protocol = IPPROTO_ICMP;
			// ICMP type and code
			icmpHeader->type = kIcmpTypeDestUnreachable;
			icmpHeader->code = i;
			// send packet
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();
	}	

#pragma mark test content filtering
	// test content filtering
	if (kTestAll || 0) {
		NSLog(@"Test content filtering");
		// packet starts at ipOffset with 20 byte IP header, 20 byte tcpHeader, followed by tcp data
		[self initializePacket:packet];
		ipHeader->srcAddress += 4004;
		strcpy(&m->m_data[40+packet->ipOffset], "GET /index.html HTTP/1.1");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];	

		[self initializePacket:packet];
		ipHeader->srcAddress += 40005;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[160+packet->ipOffset], "doubleclick.net");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark test URL keyword filtering
	// test URL keyword filtering
	if (kTestAll || 0) {
		NSLog(@"Test URL keyword filtering");
		[self initializePacket:packet];
		ipHeader->srcAddress += 4004;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[140+packet->ipOffset], "ads.x10.com");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];	

		[self initializePacket:packet];
		ipHeader->srcAddress += 40005;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[160+packet->ipOffset], "doubleclick.net");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4006;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[180+packet->ipOffset], "exitfuel.com");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4007;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[200+packet->ipOffset], "internetfuel");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4008;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[200+packet->ipOffset], "valueclick.net");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4009;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[200+packet->ipOffset], "xxx");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4010;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[200+packet->ipOffset], "my name");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4011;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[200+packet->ipOffset], "test data");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4012;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[200+packet->ipOffset], "test2");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark test drop connection
	// test drop connection
	if (kTestAll || 0) {
		NSLog(@"Test drop connection");
		[self initializePacket:packet];
		ipHeader->srcAddress += 4001;
		strcpy(&m->m_data[60+packet->ipOffset], "defAULT.ida  ");
		[self verifyPacket:packet];

		[self initializePacket:packet];
		ipHeader->srcAddress += 4003;
		//strcpy(&m->m_data[60+packet->ipOffset], "GET ");	// within [0:32]
		//strcpy(&m->m_data[70+packet->ipOffset], "GET ");	// not within [0:32]
		strcpy(&m->m_data[60+packet->ipOffset], "Get ");	// mixed case within [0:32]
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[140+packet->ipOffset], "www.adsource.net");
		packet->direction = kDirectionInbound;
		[self verifyPacket:packet];	

		[self initializePacket:packet];
		ipHeader->srcAddress += 4003;
		strcpy(&m->m_data[120+packet->ipOffset], "Host: ");
		strcpy(&m->m_data[140+packet->ipOffset], "www.adsource.net");
		packet->direction = kDirectionOutbound;
		[self verifyPacket:packet];	
		KFT_filterPeriodical();
	}

#pragma mark short IP header
	// short IP header
	if (kTestAll || 0) {
		[self initializePacket:packet];
		ipHeader->hlen = 0x44;
		// send packet
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark short TCP header
	// short TCP header
	if (kTestAll || 0) {
		[self initializePacket:packet];
		tcpHeader->hlen = 0x40;
		// send packet
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark fragment offset
	// fragment offset
	if (kTestAll || 0) {
		[self initializePacket:packet];
		ipHeader->fragmentOffset = 1;
		// send packet
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark not IP v4
	// not IP v4
	if (kTestAll || 0) {
		[self initializePacket:packet];
		ipHeader->hlen = 55;
		// send packet
		[self verifyPacket:packet];
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark other transport protocol
	// other transport protocol
	if (kTestAll || 0) {
		[self initializePacket:packet];
		ipHeader->protocol = 47;
		// test port 25
		tcpHeader->dstPort = 25;
		// send packet
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark mbuf params	
	// test mbuf params
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		ipHeader->srcAddress += 5000;
		for (i=0; i<100; i++) {
			// vary source address
			ipHeader->srcAddress += 1;
			// mbuf params
			if (m->m_len > 20) m->m_len -= 10;
			// send packet
			[self verifyPacket:packet];
		}
		KFT_filterPeriodical();
	}

#pragma mark test MAC address filtering
	// test MAC address filtering
	if (kTestAll || 0) {
		u_int8_t* dp;
		int i;
		[self initializePacket:packet];
		dp = (u_int8_t*)*packet->frame_ptr;
		// send packet
		packet->direction = kDirectionInbound;
		for (i=0; i<12; i++) dp[i] = i+1;	// MAC address 01:02:03:04:05:06 -> 07:08:09:0A:0B:0C
		[self verifyPacket:packet];
		packet->direction = kDirectionOutbound;
		for (i=0; i<12; i++) dp[i] = i;		// MAC address 00:01:02:03:04:05 -> 06:07:08:09:0A:0B
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}

#pragma mark test bandwidth management
	// test bandwidth management
	if (kTestAll || 0) {
		int i;
		u_int32_t tempAddress;
		u_int16_t tempPort;
		int segmentLength;
		// endpoint sequence info (for direction of transfer)
		u_int32_t mySeqNext;	// -->	inbound	next byte to transfer or ACK expected
		u_int32_t myAckSent;	// -->	inbound ACK we sent
		int32_t   myActualWin;	// advertised window
		int32_t	  myApparentWin;
		
		u_int32_t peerSeqNext;	// <--	outbound
		u_int32_t peerAckSent;	// <--
		int32_t peerActualWin;
		int32_t peerApparentWin;
		
		[self initializePacket:packet];
		{
			int attachIndex = KFT_attachIndexForName("en0");
			packet->myAttach = &PROJECT_attach[attachIndex];	// Built-in Ethernet (en0)
			packet->myAttach->attachIndex = attachIndex;
		}
		// setup isn
		mySeqNext = 64000;
		peerAckSent = 64000;
		peerActualWin = 32768;
		peerApparentWin = 1500;	 // set for first packet since response not seen yet
		
		peerSeqNext = 32000;
		myAckSent = 32000;
		myActualWin = 32768;
		myApparentWin = 32768;
		// get current time
		struct timeval now_tv;
		gettimeofday(&now_tv, NULL);
		int lastTime = now_tv.tv_sec;
		
		NSTimeInterval start = [NSDate psInterval];
		int byteCount = 0;
		int sendCount = 0;
		int testDirection = kDirectionOutbound;
		int closeState = 0;
		i = -1;	// loop count
		while (1) {
			i++;
			if (i > 2000) break;	// defensive
			//if (sendCount > 50) break;
			if (sendCount > 50) {
				if (closeState >= 2) break;
				closeState++;
			}
			// -- send packet Out --> (1500)
			packet->direction = testDirection;
			if ((i == 0) || (closeState)) ipHeader->totalLength = 40;
			else ipHeader->totalLength = 1500;
			segmentLength = ipHeader->totalLength - 40;
			(*packet->mbuf_ptr)->m_pkthdr.len =  ipHeader->totalLength + packet->ipOffset;
			// syn and ack flags
			tcpHeader->code = 0;
			if (i == 0) {
				tcpHeader->code = kCodeSYN;
				segmentLength += 1;
			}
			else {
				// ack every other packet
				if (i%2 == 1) {
					tcpHeader->code = kCodeACK;
					myAckSent = peerSeqNext;
				}
			}
			if (closeState == 1) {
				tcpHeader->code = kCodeFIN;
				segmentLength += 1;
			}
			if (closeState > 1) {
				tcpHeader->code = kCodeACK;
				myAckSent = peerSeqNext;
			}
			// sequence numbers
			tcpHeader->seqNumber = mySeqNext;
			tcpHeader->ackNumber = myAckSent;
			tcpHeader->windowSize = myActualWin;	// actual window size from receiver
			// check if I can send this packet (fits in current receive window)
			if ( SEQ_GEQ((peerAckSent + peerApparentWin),(mySeqNext + segmentLength)) || closeState) {
				#if DEBUG_RATE_LIMITING_1
					KFT_logText("\nSENDING outbound 1460 bytes window ", &peerApparentWin);
				#endif
				[self verifyPacket:packet];
				// -- packet was sent, update seq info
				// notice filter may have changed the windowSize,
				// turned off ACK, or adjusted the ACK amount
				sendCount++;
				mySeqNext += segmentLength;
				// window size and ACK number are only valid with ACK
				if (tcpHeader->code & kCodeACK) {
					myAckSent = tcpHeader->ackNumber;
					myApparentWin = tcpHeader->windowSize;
				}
				byteCount += ipHeader->totalLength;
			}
			else {
				#if DEBUG_RATE_LIMITING_1
					KFT_logText("\nwaiting for moveWindow_tv", NULL);
				#endif
					// pause for window to move
				[NSThread sleepUntilDate:[NSDate
					dateWithTimeIntervalSinceNow:(NSTimeInterval)0.005] ];
				#if 1
					KFT_connectionEntry_t* cEntry = NULL;
					KFT_connectionInfo_t*	myInfo;
					KFT_connectionInfo_t*	peerInfo;
					// handle any pending ACKs that are ready
					cEntry = KFT_callbackAction();
					if (cEntry) {
						// get my and peer info
							// callback direction is the direction of the ACK that is pending
							// we ACK segments from the peer list.
						if (cEntry->callbackDirection == 1 - testDirection) {
							myInfo = &cEntry->rInfo;
							peerInfo = &cEntry->sInfo;
						}
						else {
							myInfo = &cEntry->sInfo;
							peerInfo = &cEntry->rInfo;
						}
						#if DEBUG_RATE_LIMITING_1
							KFT_logText("\nSentryTest ACK via callbackAction", NULL);
						#endif
						peerAckSent = myInfo->prevAckNum;
						peerApparentWin = myInfo->prevAckWin;
					}
				#endif
			}
			if (closeState >= 2) break;

			// now send a response by modifying same test packet
			// -- send packet --> in (0) (ACK only)
			packet->direction = 1 - testDirection;
			ipHeader->totalLength = 40;
			segmentLength = ipHeader->totalLength - 40;
			(*packet->mbuf_ptr)->m_pkthdr.len =  ipHeader->totalLength + packet->ipOffset;
			// syn and ack flags
			tcpHeader->code = 0;
			if (i == 0) {
				tcpHeader->code = kCodeSYN + kCodeACK;	// first response needs to include SYN+ACK
				segmentLength += 1;
			}
			else {
				// ack every other packet
				if (i%2 == 1) {
					tcpHeader->code = kCodeACK;
				}
			}
			if (closeState == 1) {
				tcpHeader->code = kCodeFIN + kCodeACK;
				segmentLength += 1;
			}
			// don't send empty ACK packets if no ACK
			if ((segmentLength == 0) && ((tcpHeader->code & kCodeACK) == 0)) continue;
				//KFT_logText("\nRESPONDING outbound ACK ", NULL);
				//KFT_logHex((u_int8_t*)&peerAckSent, 8);
			// sequence numbers
			tcpHeader->seqNumber = peerSeqNext;
			tcpHeader->ackNumber = mySeqNext;		// try to ACK the last segment we sent
			tcpHeader->windowSize = peerActualWin;	// actual window size from receiver
				// swap source & dest
			tempAddress = ipHeader->srcAddress;
			tempPort = tcpHeader->srcPort;
			ipHeader->srcAddress = ipHeader->dstAddress;
			tcpHeader->srcPort = tcpHeader->dstPort;
			ipHeader->dstAddress = tempAddress;
			tcpHeader->dstPort = tempPort;
			// try to send packet
			result = [self verifyPacket:packet];
			if (result == 0) {	
				// -- packet was sent, update seq info
				// notice filter may have changed the windowSize,
				// turned off ACK, or adjusted the ACK amount
				peerSeqNext += segmentLength;
				// window size and ack number are only valid with ACK
				if (tcpHeader->code & kCodeACK) {
					peerAckSent = tcpHeader->ackNumber;
					peerApparentWin = tcpHeader->windowSize;
				}
			}
				// revert source & dest
			tempAddress = ipHeader->srcAddress;
			tempPort = tcpHeader->srcPort;
			ipHeader->srcAddress = ipHeader->dstAddress;
			tcpHeader->srcPort = tcpHeader->dstPort;
			ipHeader->dstAddress = tempAddress;
			tcpHeader->dstPort = tempPort;

			// force tables to update every second like NKE
			gettimeofday(&now_tv, NULL);
			if (now_tv.tv_sec != lastTime) {
				lastTime = now_tv.tv_sec;
				// age connection table to update rate limiting info
				KFT_connectionAge(0);
				KFT_filterUpdate();
			}
			// loop to repeat
		}
		// update filter counts for end of test
		KFT_connectionAge(0);
		KFT_connectionAge(0);
		KFT_filterUpdate();
		NSTimeInterval stop = [NSDate psInterval];
		NSTimeInterval elapsed = stop - start;
		double rate = (double)byteCount/elapsed;
		rate = rate/100;	// convert to Kbps
		NSLog(@"Bytes: %d elapsed: %0.2f rate: %0.2f Kbps",byteCount, elapsed, rate);
		KFT_filterPeriodical();
	}

#pragma mark test Dead Gateway detection
	// test dead gateway detection and failover
	if (kTestAll || 0) {
		int i;
		[self initializePacket:packet];
		packet->direction = kDirectionOutbound;
		ipHeader->dstAddress = ipForString(@"209.68.51.199");
		tcpHeader->code = kCodeSYN;
		// repeat outbound SYN packets test failover
		for (i=0; i<4; i++) {
			// send packet
			[self verifyPacket:packet];
		}
		// reset dupSynCount for next time
		tcpHeader->code = 0;
		[self verifyPacket:packet];
		KFT_filterPeriodical();
	}
	
#pragma mark test NAT (UDP, TCP)
// must set public IP to match network prefs panel
#define PUBLIC_IP @"10.17.0.16"
#define PRIVATE_IP @"192.168.17.19"
	// test NAT (UDP, TCP)
	if (kTestAll || 0) {
		NSLog(@"Test NAT for TCP, UDP");
		// outbound from behind gateway (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionOutbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];	// Built-in Ethernet (en0)
		ipHeader->protocol = IPPROTO_UDP;
		ipHeader->srcAddress = ipForString(@"192.168.17.19"); 
		ipHeader->dstAddress = ipForString(@"192.168.200.2");
		// send packet
		[self verifyPacket:packet];
		// verify outbound NAPT was successful
		if (ipForString(PUBLIC_IP) != ipHeader->srcAddress) NSLog(@"Test NAT: outbound address translation failed %@",stringForIP(ipHeader->srcAddress));
		if (44000 != tcpHeader->srcPort) NSLog(@"Test NAT: outbound port translation failed %d",tcpHeader->srcPort);
		
		// inbound from outside gateway (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];	// Built-in Ethernet (en0)
		ipHeader->protocol = IPPROTO_UDP;
		ipHeader->srcAddress = ipForString(@"192.168.200.1");
		ipHeader->dstAddress = ipForString(PUBLIC_IP);
		tcpHeader->srcPort = 80;
		tcpHeader->dstPort = 44000;
		// send packet
		[self verifyPacket:packet];		
		// verify reverse NAPT was successful
		if (ipForString(@"192.168.17.19") != ipHeader->dstAddress) NSLog(@"Test NAT: inbound address translation failed %@", stringForIP(ipHeader->dstAddress));
		if (44000 != tcpHeader->dstPort) NSLog(@"Test NAT: outbound port translation failed %d",tcpHeader->dstPort);
#ifdef IPNetRouter
		// age nat table to test aging and update
		KFT_natAge();
		KFT_filterPeriodical();
#endif
	}
#pragma mark Inbound Port Mapping
#define REMOTE_IP @"192.168.0.1"
#if IPNetRouter
	// test inbound port mapping
	if (kTestAll || 0) {
		// define test endpoints
		u_int16_t publicPort = 401;
		u_int16_t privatePort = 400;
		#define kMaxAddress 4
		u_int32_t publicIP[kMaxAddress];
		u_int32_t privateIP[kMaxAddress];
		publicIP[0] = ipForString(@"192.168.0.16");		// apparent
		privateIP[0] = ipForString(@"10.17.0.20");	// actual
		// static NAT
		publicIP[1] = ipForString(@"192.168.0.41");
		publicIP[2] = ipForString(@"192.168.0.42");
		publicIP[3] = ipForString(@"192.168.0.43");
		privateIP[1] = ipForString(@"10.17.0.21");
		privateIP[2] = ipForString(@"10.17.0.22");
		privateIP[3] = ipForString(@"10.17.0.23");
		NSLog(@"Test Inbound Port Mapping Public:401->Private:400");
		int i;
		for (i=0; i<kMaxAddress; i++) {
			// configure port mapping table
			PortMapEntry* portMap = [[[PortMapEntry alloc] init] autorelease];
			[portMap setApparentAddress:stringForIP(publicIP[i])];
			[portMap setActualAddress:stringForIP(privateIP[i])];
			if (i == 0) {
				[portMap setApparentPort:[NSString stringWithFormat:@"%d",publicPort]];
				[portMap setActualPort:[NSString stringWithFormat:@"%d",privatePort]];
			} else {
				[portMap setApparentPort:@"0"];		// static NAT map all ports
				[portMap setActualPort:@"0"];
			}
			[portMap setProtocol:[NSString stringWithFormat:@"%d",IPPROTO_TCP]];
			[portMap setComment:[NSString stringWithFormat:@"Test inbound port mapping (%d)",i]];
			[[[[SentryModel sharedInstance] sentryState] portMapTable] insertObject:portMap];
		}
		// download table to kernel or working copy
		[[SentryModel sharedInstance] downloadPortMapTable];
		// test the port mappings we just defined
		for (i=0; i<kMaxAddress; i++) {	
			// inbound from outside gateway (remote endpoint is 192.168.0.1:80)
			[self initializePacket:packet];
			packet->direction = kDirectionInbound;
			packet->myAttach = &PROJECT_attach[KFT_attachIndexForName(EXTERNAL_IF)];
			ipHeader->protocol = IPPROTO_TCP;
			ipHeader->srcAddress = ipForString(REMOTE_IP);
			tcpHeader->srcPort = 80;
			ipHeader->dstAddress = publicIP[i];
			tcpHeader->dstPort = publicPort;
				// send packet
			[self verifyPacket:packet];		
			// verify inbound mapping was successful
			if (privateIP[i] != ipHeader->dstAddress)
				NSLog(@"Port mapping(%d): inbound address translation failed actual dst %@ != %@",
					i,stringForIP(ipHeader->dstAddress),stringForIP(privateIP[i]));
			if (i == 0) {	// port is only mapped for non static case
				if (privatePort != tcpHeader->dstPort)
					NSLog(@"Port mapping(%d): inbound port translation failed %d != %D",i,tcpHeader->dstPort,privatePort);
			}
			// outbound from behind gateway (remote endpoint is 192.168.0.1:80)
			[self initializePacket:packet];
			packet->direction = kDirectionOutbound;
			packet->myAttach = &PROJECT_attach[KFT_attachIndexForName(EXTERNAL_IF)];
			ipHeader->protocol = IPPROTO_TCP;
			ipHeader->srcAddress = privateIP[i]; 
			ipHeader->dstAddress = ipForString(REMOTE_IP);
			tcpHeader->srcPort = privatePort;
			tcpHeader->dstPort = 80;
				// send packet
			[self verifyPacket:packet];
			// verify outbound NAPT was successful
			if (publicIP[i] != ipHeader->srcAddress)
				NSLog(@"Port mapping(%d): outbound address translation failed apparent src %@ != %@",i,stringForIP(ipHeader->srcAddress), stringForIP(publicIP[i]));
			if (i == 0) {	// port is only mapped for non static case
				if (publicPort != tcpHeader->srcPort)
					NSLog(@"Port mapping(%d): outbound port translation failed %d",i,tcpHeader->srcPort);
			}
		}
		KFT_filterPeriodical();
	}
#endif

#pragma mark Transparent Proxy
#if IPNetRouter
	// test transparent proxy
	if (kTestAll || 0) {
		// define test endpoints
		u_int16_t publicPort = 80;
		u_int16_t privatePort = 8080;
		u_int16_t remotePort = 32000;
		//u_int32_t publicIP = ipForString(@"192.168.0.40");		// apparent
		u_int32_t privateIP = ipForString(@"192.168.17.20");	// actual
		u_int32_t remoteIP = ipForString(@"192.168.17.2");		// remote
		u_int32_t redirectIP = ipForString(@"17.17.17.17");		// redirect
		NSLog(@"Test Transparent Proxy Public:80->Private:8080");
		{
			// configure port mapping table
			PortMapEntry* portMap = [[[PortMapEntry alloc] init] autorelease];
			[portMap setApparentAddress:stringForIP(0)];
			[portMap setActualAddress:stringForIP(privateIP)];
			[portMap setApparentPort:[NSString stringWithFormat:@"%d",publicPort]];
			[portMap setActualPort:[NSString stringWithFormat:@"%d",privatePort]];
			[portMap setProtocol:[NSString stringWithFormat:@"%d",IPPROTO_TCP]];
			[portMap setComment:[NSString stringWithFormat:@"Test transparent proxy"]];
			[[[[SentryModel sharedInstance] sentryState] portMapTable] insertObject:portMap];
		}
		// download table to kernel or working copy
		[[SentryModel sharedInstance] downloadPortMapTable];
		// test the port mappings we just defined
		int i;
		for (i=0; i<4; i++) {	
			// inbound from inside gateway
			[self initializePacket:packet];
			packet->direction = kDirectionInbound;
			packet->myAttach = &PROJECT_attach[KFT_attachIndexForName(INTERNAL_IF)];
			ipHeader->protocol = IPPROTO_TCP;
			ipHeader->srcAddress = remoteIP;
			tcpHeader->srcPort = remotePort;
			ipHeader->dstAddress = redirectIP+i;
			tcpHeader->dstPort = publicPort;
				// send packet
			[self verifyPacket:packet];		
			// verify inbound mapping was successful
			if (ipHeader->dstAddress != privateIP)
				NSLog(@"Transparent proxy(%d): inbound address translation failed %@",
					i,stringForIP(ipHeader->dstAddress));
			if (tcpHeader->dstPort != privatePort)
				NSLog(@"Transparnet proxy(%d): inbound port translation failed %d",i,tcpHeader->dstPort);
			// outbound from behind gateway testing local NAT
			// reply to packet received
			//[self initializePacket:packet];
			packet->direction = kDirectionInbound;	
			packet->myAttach = &PROJECT_attach[KFT_attachIndexForName(INTERNAL_IF)];
			ipHeader->protocol = IPPROTO_TCP;
			// to received src EP
			ipHeader->dstAddress = ipHeader->srcAddress;
			tcpHeader->dstPort = tcpHeader->srcPort;
			// from private EP
			ipHeader->srcAddress = privateIP; 
			tcpHeader->srcPort = privatePort;
				// send packet
			[self verifyPacket:packet];
				// process outbound
//			packet->direction = kDirectionOutbound;	
//			[self verifyPacket:packet];
			// verify local NAT was successful
			if (ipHeader->dstAddress != remoteIP)
				NSLog(@"Transparent proxy(%d): response dest address translation failed %@",
					i,stringForIP(ipHeader->dstAddress));
			if (tcpHeader->dstPort != remotePort)
				NSLog(@"Transparent proxy(%d): response dest port translation failed %d",i,tcpHeader->dstPort);
			
			if (ipHeader->srcAddress != redirectIP+i)
				NSLog(@"Transparent proxy(%d): response src address translation failed %@",i,stringForIP(ipHeader->srcAddress));
			if (tcpHeader->srcPort != publicPort)
				NSLog(@"Transparent proxy(%d): respons src port translation failed %d",i,tcpHeader->srcPort);
		}
		KFT_natAge();
		KFT_filterPeriodical();
	}
#endif

#pragma mark Transparent Proxy Local
#if IPNetRouter
	// test transparent proxy local
	if (kTestAll || 0) {
		// define test endpoints
		u_int16_t publicPort = 80;
		u_int16_t privatePort = 8080;
		u_int16_t remotePort = 32000;
		//u_int32_t publicIP = ipForString(@"192.168.0.40");	// apparent
		u_int32_t privateIP = ipForString(@"192.168.17.1");		// actual (transparent proxy server)
		u_int32_t remoteIP = ipForString(@"192.168.17.7");		// remote (client IP)
		u_int32_t redirectIP = ipForString(@"17.17.17.17");		// redirect (requested IP)
		NSLog(@"Test Transparent Proxy Local Public:80->Private:8080");
		{
			// configure port mapping table
			PortMapEntry* portMap = [[[PortMapEntry alloc] init] autorelease];
			[portMap setApparentAddress:stringForIP(0)];
			[portMap setActualAddress:stringForIP(privateIP)];
			[portMap setApparentPort:[NSString stringWithFormat:@"%d",publicPort]];
			[portMap setActualPort:[NSString stringWithFormat:@"%d",privatePort]];
			[portMap setProtocol:[NSString stringWithFormat:@"%d",IPPROTO_TCP]];
			[portMap setLocalProxy:[NSNumber numberWithInt:1]];
			[portMap setComment:[NSString stringWithFormat:@"Test transparent proxy"]];
			[[[[SentryModel sharedInstance] sentryState] portMapTable] insertObject:portMap];
		}
		// download table to kernel or working copy
		[[SentryModel sharedInstance] downloadPortMapTable];
		// test the port mappings we just defined
		int i;
		for (i=0; i<4; i++) {	
			// inbound from inside gateway
			[self initializePacket:packet];
			packet->direction = kDirectionInbound;
			packet->myAttach = &PROJECT_attach[KFT_attachIndexForName(INTERNAL_IF)];
			ipHeader->protocol = IPPROTO_TCP;
			ipHeader->srcAddress = remoteIP;
			tcpHeader->srcPort = remotePort+i;
			ipHeader->dstAddress = redirectIP+i;
			tcpHeader->dstPort = publicPort;
				// send packet
			[self verifyPacket:packet];		
			// verify inbound mapping was successful
			if (ipHeader->dstAddress != privateIP)
				NSLog(@"Transparent proxy(%d): inbound address translation failed %@",
					i,stringForIP(ipHeader->dstAddress));
			if (tcpHeader->dstPort != privatePort)
				NSLog(@"Transparnet proxy(%d): inbound port translation failed %d",i,tcpHeader->dstPort);
			NSLog(@"local proxy(%d): source endpoint %@:%d",i,stringForIP(ipHeader->srcAddress),tcpHeader->srcPort);
			// outbound from local proxy server
			// reply to packet received
			//[self initializePacket:packet];
			packet->direction = kDirectionOutbound;	
			packet->myAttach = &PROJECT_attach[KFT_attachIndexForName(INTERNAL_IF)];
			ipHeader->protocol = IPPROTO_TCP;
			// to received src EP
			ipHeader->dstAddress = ipHeader->srcAddress;
			tcpHeader->dstPort = tcpHeader->srcPort;
			// from private EP
			ipHeader->srcAddress = privateIP; 
			tcpHeader->srcPort = privatePort;
				// send packet
			[self verifyPacket:packet];
				// process outbound
//			packet->direction = kDirectionOutbound;	
//			[self verifyPacket:packet];
			// verify local NAT was successful
			if (ipHeader->dstAddress != remoteIP)
				NSLog(@"Transparent proxy(%d): response dest address translation failed %@",
					i,stringForIP(ipHeader->dstAddress));
			if (tcpHeader->dstPort != remotePort+i)
				NSLog(@"Transparent proxy(%d): response dest port translation failed %d",i,tcpHeader->dstPort);
			
			if (ipHeader->srcAddress != redirectIP+i)
				NSLog(@"Transparent proxy(%d): response src address translation failed %@",i,stringForIP(ipHeader->srcAddress));
			if (tcpHeader->srcPort != publicPort)
				NSLog(@"Transparent proxy(%d): response src port translation failed %d",i,tcpHeader->srcPort);
		}
		KFT_natAge();
		KFT_filterPeriodical();
	}
#endif

#pragma mark test Single Ethernet NAT (UDP, TCP)
	// test Single Ethernet NAT (UDP, TCP)
	// public IP: PUBLIC_IP
	// private IP: 10.0.17.1
	// LAN host IP: 10.0.17.2
	if (kTestAll || 0) {
		NSLog(@"Test Single Ethernet NAT for TCP, UDP");
		// outbound from behind gateway (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];	// Built-in Ethernet (en0)
		ipHeader->protocol = IPPROTO_UDP;
		ipHeader->srcAddress = ipForString(@"10.0.17.2"); 
		ipHeader->dstAddress = ipForString(@"192.168.0.1");
		// send packet
		[self verifyPacket:packet];
		// forward back out same interface
		packet->natEntry = nil; // erase any previous nat result
		packet->direction = kDirectionOutbound;
		[self verifyPacket:packet];
		// verify outbound NAPT was successful
		if (ipForString(PUBLIC_IP) != ipHeader->srcAddress)
			NSLog(@"Test Single Ethernet NAT: outbound srcAddress translation failed %@",
			stringForIP(ipHeader->srcAddress));
		if (44000 != tcpHeader->srcPort)
			NSLog(@"Test Single Ethernet NAT: outbound srcPort translation failed %d",
			tcpHeader->srcPort);
		if (ipForString(@"192.168.0.1") != ipHeader->dstAddress)
			NSLog(@"Test Single Ethernet NAT: outbound dstAddress translation failed %@",
			stringForIP(ipHeader->dstAddress));
		if (80 != tcpHeader->dstPort)
			NSLog(@"Test Single Ethernet NAT: outbound dstPport translation failed %d",
			tcpHeader->srcPort);
		
		// inbound from outside gateway (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];	// Built-in Ethernet (en0)
		ipHeader->protocol = IPPROTO_UDP;
		ipHeader->srcAddress = ipForString(@"192.168.0.1");
		ipHeader->dstAddress = ipForString(PUBLIC_IP);
		tcpHeader->srcPort = 80;
		tcpHeader->dstPort = 44000;
		packet->natEntry = nil; // erase any previous nat result
		// send packet
		[self verifyPacket:packet];		
		// forward back out same interface
		packet->direction = kDirectionOutbound;
		packet->natEntry = nil; // erase any previous nat result
		[self verifyPacket:packet];
		// verify reverse NAPT was successful
		if (ipForString(@"10.0.17.2") != ipHeader->dstAddress) 
			NSLog(@"Test Single Ethernet NAT: inbound dstAddress translation failed %@",
			stringForIP(ipHeader->dstAddress));
		if (44000 != tcpHeader->dstPort)
			NSLog(@"Test Single Ethernet NAT: inbound dstPort translation failed %d",
			tcpHeader->dstPort);
		if (ipForString(@"192.168.0.1") != ipHeader->srcAddress) 
			NSLog(@"Test Single Ethernet NAT: inbound srcAddress translation failed %@",
			stringForIP(ipHeader->srcAddress));
		if (80 != tcpHeader->srcPort)
			NSLog(@"Test Single Ethernet NAT: inbound srcPort translation failed %d",
			tcpHeader->srcPort);
		KFT_filterPeriodical();
	}

#pragma mark test NAT (ICMP)
	// test NAT (ICMP)
	// public IP: PUBLIC_IP
	// private IP: 192.168.17.19
	if (kTestAll || 0) {
		NSLog(@"Test NAT for ICMP");
		// internal inbound  (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en1")];
		ipHeader->protocol = IPPROTO_ICMP;
		ipHeader->srcAddress = ipForString(@"192.168.17.19"); 
		ipHeader->dstAddress = ipForString(@"192.168.0.1");
		tcpHeader->srcPort = 0;
		tcpHeader->dstPort = 0;
		// send packet
		[self verifyPacket:packet];
		// verify internal inbound NAPT was successful
		if (ipForString(@"192.168.17.19") != ipHeader->srcAddress) NSLog(@"Test NAT (ICMP): internal inbound srcAddress failed %@", stringForIP(ipHeader->srcAddress));
		if (ipForString(@"192.168.0.1") != ipHeader->dstAddress) NSLog(@"Test NAT (ICMP): internal inbound dstAddress failed %@", stringForIP(ipHeader->dstAddress));

		// outbound from behind gateway (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionOutbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];
		ipHeader->protocol = IPPROTO_ICMP;
		ipHeader->srcAddress = ipForString(@"192.168.17.19"); 
		ipHeader->dstAddress = ipForString(@"192.168.0.1");
		tcpHeader->srcPort = 0;
		tcpHeader->dstPort = 0;
		// send packet
		[self verifyPacket:packet];
		// verify outbound NAPT was successful
		if (ipForString(PUBLIC_IP) != ipHeader->srcAddress) NSLog(@"Test NAT (ICMP): outbound address translation failed %@", stringForIP(ipHeader->srcAddress));
		
		// inbound from outside gateway (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];
		ipHeader->protocol = IPPROTO_ICMP;
		ipHeader->srcAddress = ipForString(@"192.168.0.1");
		ipHeader->dstAddress = ipForString(PUBLIC_IP);
		tcpHeader->srcPort = 0;
		tcpHeader->dstPort = 0;
		// send packet
		[self verifyPacket:packet];		
		// verify reverse NAPT was successful
		if (ipForString(@"192.168.17.19") != ipHeader->dstAddress) NSLog(@"Test NAT (ICMP): inbound address translation failed %@", stringForIP(ipHeader->dstAddress));

		// send another to capture ICMP mapping
		[self initializePacket:packet];
		packet->direction = kDirectionOutbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];
		ipHeader->protocol = IPPROTO_ICMP;
		ipHeader->srcAddress = ipForString(@"192.168.17.20"); 
		ipHeader->dstAddress = ipForString(@"192.168.0.1");
		tcpHeader->srcPort = 0;
		tcpHeader->dstPort = 0;
		// send packet
		[self verifyPacket:packet];
		// verify outbound NAPT was successful
		if (ipForString(PUBLIC_IP) != ipHeader->srcAddress) NSLog(@"Test NAT (ICMP): outbound address translation failed %@", stringForIP(ipHeader->srcAddress));
		
		// inbound from outside gateway (ports are TCP 44000 and 80)
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];
		ipHeader->protocol = IPPROTO_ICMP;
		ipHeader->srcAddress = ipForString(@"192.168.0.1");
		ipHeader->dstAddress = ipForString(PUBLIC_IP);
		tcpHeader->srcPort = 0;
		tcpHeader->dstPort = 0;
		// send packet
		[self verifyPacket:packet];		
		// verify reverse NAPT was successful
		if (ipForString(@"192.168.17.19") != ipHeader->dstAddress) NSLog(@"Test NAT (ICMP): inbound address translation captured");
		KFT_filterPeriodical();
	}
	
#pragma mark test Local NAT
	// test Local NAT
	// public IP: PUBLIC_IP
	// private IP: 192.168.17.1
	// private LAN host1: 192.168.17.19
	// port mapping PUBLIC_IP:80 -> 192.168.17.19:80 (PL host1)
	if (kTestAll || 0) {
		KFT_natEntry_t entry;
		NSLog(@"Test local NAT");
		// load port mapping table
		bzero(&entry, sizeof(KFT_natEntry_t));
		entry.apparent.port = 80;
		entry.apparent.protocol = IPPROTO_TCP;
		entry.apparent.address = ipForString(PUBLIC_IP);
		entry.actual.port = 80;
		entry.actual.protocol = IPPROTO_TCP;
		entry.actual.address = ipForString(@"192.168.17.19");
//		entry.lastTime = (int)[NSDate dateWithTimeIntervalSince1970];
//		entry.flags = kNatFlagPermanent;
#ifdef IPNetRouter
		KFT_portMapAddCopy(&entry);
#endif
		// request from PL host1 -> PL host1, port 44000 to 80
		[self initializePacket:packet];
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en1")];	// packet arrives via AirPort (en1)
//		packet->direction = kDirectionOutbound;
//		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];	// packet arrives via AirPort (en0)
		ipHeader->protocol = IPPROTO_TCP;
		ipHeader->srcAddress = ipForString(@"192.168.17.19");   // actual source
		tcpHeader->srcPort = 44000;
		ipHeader->dstAddress = ipForString(PUBLIC_IP);	// apparent dest
		tcpHeader->dstPort = 80;
		// send packet
		[self verifyPacket:packet];
		// verify inbound NAPT was successfull
		if (ipForString(@"192.168.17.19") != ipHeader->dstAddress) NSLog(@"Test Local NAT request: inbound dstAddress translation failed %@",stringForIP(ipHeader->dstAddress));
		if (80 != tcpHeader->dstPort) NSLog(@"Test Local NAT request: inbound port translation failed");
		// verify outbound NAPT was successful
		if (ipForString(PUBLIC_IP) != ipHeader->srcAddress) NSLog(@"Test Local NAT request: outbound srcAddress translation failed %@",stringForIP(ipHeader->srcAddress));
		if (44000 != tcpHeader->srcPort) NSLog(@"Test Local NAT request: outbound port translation failed %d", tcpHeader->srcPort);
		
		// response from PL host1 -> PL host 1
		[self initializePacket:packet];
		packet->natEntry = nil; // erase any previous nat result
		packet->direction = kDirectionInbound;
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en1")];	// packet arrives via AirPort (en1)
//		packet->direction = kDirectionOutbound;
//		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];	// packet arrives via AirPort (en0)
		ipHeader->protocol = IPPROTO_TCP;
		ipHeader->srcAddress = ipForString(@"192.168.17.19");
		tcpHeader->srcPort = 80;
		ipHeader->dstAddress = ipForString(PUBLIC_IP);	// apparent client
		tcpHeader->dstPort = 44000;
		// send packet
		[self verifyPacket:packet];
		// verify inbound NAPT was successfull
			// responds to actual source
		if (ipForString(@"192.168.17.19") != ipHeader->dstAddress) NSLog(@"Test Local NAT response: inbound dstAddress translation failed %@",stringForIP(ipHeader->dstAddress));
		if (44000 != tcpHeader->dstPort) NSLog(@"Test Local NAT response: inbound port translation failed");
		// verify outbound NAPT was successful
			// from apparent dest
		if (ipForString(PUBLIC_IP) != ipHeader->srcAddress) NSLog(@"Test Local NAT response: outbound srcAddress translation failed %@",stringForIP(ipHeader->srcAddress));
		if (80 != tcpHeader->srcPort)
			NSLog(@"Test Local NAT response: outbound port translation failed %d", tcpHeader->srcPort);
		KFT_filterPeriodical();
	}

#pragma mark test Ethernet bridging
	// test Ethernet bridging
	if (kTestAll || 0) {
		u_int8_t* dp;
		int i;
		// setup interfaces
		#if 0   // use Apply
		PROJECT_attach[1].filterID = 1;
		memcpy(PROJECT_attach[1].kftInterfaceEntry.bsdName, "en0", 4);
		PROJECT_attach[1].kftInterfaceEntry.bridgeOn = 1;

		PROJECT_attach[2].filterID = 2;
		memcpy(PROJECT_attach[2].kftInterfaceEntry.bsdName, "en1", 4);
		PROJECT_attach[2].kftInterfaceEntry.bridgeOn = 1;

		PROJECT_attach[3].filterID = 3;
		memcpy(PROJECT_attach[3].kftInterfaceEntry.bsdName, "en2", 4);
		PROJECT_attach[3].kftInterfaceEntry.bridgeOn = 1;
		#endif
		// setup to test bridging
		NSLog(@"Test Ethernet bridging");
		KFT_bridgeStart();
		[self initializePacket:packet];
		dp = (u_int8_t*)*packet->frame_ptr;
		bzero(dp, 12);
		// send packet
		packet->ifType = IFT_ETHER;
		packet->ifHeaderLen = ETHER_HDR_LEN;
		packet->direction = kDirectionInbound;
		// HW 1-7 are on en0
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];  // Ethernet built-in en0
			// should be bridged as broadcast since dest is not in table
		for (i=1; i<7; i++) {
			dp[5] = i;  // send from 1...7
			dp[11] = i+8;
			result = [self verifyPacket:packet];
			if (result == EJUSTRETURN) KFT_logText("\n-packet was deleted",NULL);
			else KFT_logText("\n-packet passed on filterID:", (int*)&packet->myAttach->filterID);
		}
		// 8-14 our on en1
			// should be bridged as unicast since dest is in table
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en1")];  // AirPort en1
		for (i=9; i<15; i++) {
			dp[5] = i;  // send from 8...15
			dp[11] = i-8; // to 1
			result = [self verifyPacket:packet];
			if (result == EJUSTRETURN) KFT_logText("\n-packet was deleted",NULL);
			else KFT_logText("\n-packet passed on filterID:", (int*)&packet->myAttach->filterID);
		}
		// repeat 1-7, should b e bridged as unicast since dest is in table
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];  // Ethernet built-in en0
		for (i=1; i<7; i++) {
			dp[5] = i;  // send from 1...7
			dp[11] = i+8; // to 8
			result = [self verifyPacket:packet];
			if (result == EJUSTRETURN) KFT_logText("\n-packet was deleted",NULL);
			else KFT_logText("\n-packet passed on filterID:", (int*)&packet->myAttach->filterID);
		}
		KFT_filterPeriodical();
	}

#pragma mark test matching internal/external interface
	// test matching internal/external interface
	if (kTestAll || 0) {
		// setup interfaces
		#if 0   // use Apply
		PROJECT_attach[1].filterID = 1;
		memcpy(PROJECT_attach[1].kftInterfaceEntry.bsdName, "en0", 4);

		PROJECT_attach[2].filterID = 2;
		memcpy(PROJECT_attach[2].kftInterfaceEntry.bsdName, "en1", 4);
		#endif
		// setup to test bridging
		NSLog(@"Test matching internal/external interface");
		[self initializePacket:packet];
		tcpHeader->dstPort = 80;	// try http request
		tcpHeader->code = kCodeSYN;
		packet->direction = kDirectionInbound;
		// receive on en0
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];  // Ethernet built-in en0
		NSLog(@"Receive 1 on en0");
		result = [self verifyPacket:packet];
		// receive on en1
		packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en1")];  // AirPort en1
		NSLog(@"Receive 2 on en1");
		result = [self verifyPacket:packet];
		result = [self verifyPacket:packet];	// send twice to distinguish
		KFT_filterPeriodical();
	}

#pragma mark end of test cases
	// force tables to update
	KFT_filterPeriodical();
	[NSThread sleepUntilDate:[NSDate
		dateWithTimeIntervalSinceNow:(NSTimeInterval)1.1] ];
	KFT_triggerAgeWithLimit(10);
}

// ---------------------------------------------------------------------------
//	¥ initializePacket
// ---------------------------------------------------------------------------
// load IP and TCP header for template test packet
- (void)initializePacket:(KFT_packetData_t*)packet
{
	mbuf_t m;
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	// load ip header
	m = *(packet->mbuf_ptr);
	ipHeader = (ip_header_t *)&m->m_data[packet->ipOffset];
	ipHeader->hlen = 0x45;
	ipHeader->totalLength = 400;
	ipHeader->identification = 17;
	ipHeader->fragmentOffset = 0;
	ipHeader->ttl = 64;
	ipHeader->protocol = IPPROTO_TCP;
	//inet_aton("10.1.1.1", (struct in_addr*)&ipHeader->srcAddress);
	ipHeader->srcAddress = ipForString(@"10.1.1.1");
	//inet_aton("192.168.0.1", (struct in_addr*)&ipHeader->dstAddress);
	ipHeader->dstAddress = ipForString(@"192.168.0.1");
	ipHeader->checksum = 0;
	ipHeader->checksum = IpSum((u_int16_t*)ipHeader, (u_int16_t*)((UInt8*)ipHeader + 20));
	// load tcp header
	tcpHeader = (tcp_header_t*)((UInt8*)ipHeader + 20);
	tcpHeader->srcPort = 44000;
	tcpHeader->dstPort = 80;
	tcpHeader->seqNumber = 1000;
	tcpHeader->ackNumber = 1000;
	tcpHeader->hlen = 0x50;
	tcpHeader->code = kCodeACK;
	tcpHeader->windowSize = 32768;
	// clear out previous content (if any)
	bzero(&m->m_data[40+packet->ipOffset], 300);
	// default to inbound
	packet->direction = kDirectionInbound;
	// default to en0
	packet->myAttach = &PROJECT_attach[KFT_attachIndexForName("en0")];
	// clear any previous NAT info
	packet->natEntry = nil;
	// clear previous redirect
	bzero(&packet->redirect, sizeof(KFT_redirect_t));
	if (1) {
		// force tables to update
		KFT_filterPeriodical();
		// sleep to all timeofday() to advance
		[NSThread sleepUntilDate:[NSDate
			dateWithTimeIntervalSinceNow:(NSTimeInterval)1.0] ];
	}
}

// ---------------------------------------------------------------------------
//	¥ verifyPacket
// ---------------------------------------------------------------------------
// send packet to filter engine to be processed and verify mbuf structure and result.
//  restore *mbuf_ptr if packet was deleted
- (int)verifyPacket:(KFT_packetData_t*)packet
{	
	int result;
	
	packet->leafAction = 0;
	packet->dontLog = 0;
	packet->connectionEntry = nil;	// reset entry in case previously found
	
	// convert to network byte order
	packet->swap = kHostByteOrder;
	KFT_htonPacket(packet, kOptionNone);
	// count traffic
	int len = mbuf_pkthdr_len(*packet->mbuf_ptr);
	if (packet->direction == kDirectionInbound) packet->myAttach->receiveCount += len;
	else packet->myAttach->sendCount += len;
	
	// send packet to filter engine
	result = KFT_processPacket(packet);
	
	if ((*packet->mbuf_ptr == NULL) && (result == EJUSTRETURN)) {
		// packet was deleted
		if (0) NSLog(@"packet was deleted");
		if (0) [[SentryLogger sharedInstance] logMessage:@"mbuf was released"];
		*packet->mbuf_ptr = (mbuf_t)(*packet->frame_ptr - 28);
	}
	else {
		if (*packet->mbuf_ptr != (mbuf_t)(*packet->frame_ptr - 28))
			NSLog(@"packet pointers were modified");
		if (result > 0)
			NSLog(@"error result %d from KFT_processPacket", result);
		else if (result == EJUSTRETURN)
			[[SentryLogger sharedInstance] logMessage:@" packet consumed"];
	}
	// convert result back to host byte order
	KFT_ntohPacket(packet, kOptionNone);
	// caller will examine response
	return result;
}

@end
