//
//  BPFTransmit.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on 8/23/05.
//  Copyright 2005 Sustainable Softworks Inc. All rights reserved.
//

#import "BPFTransmit.h"
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/errno.h>
#include <sys/socket.h>
#include <ctype.h>
#import <net/if.h>
#import <net/ethernet.h>
//#import <net/firewire.h>
#import "firewire.h"
#import <net/if_arp.h>
#import <netinet/in.h>
#import <netinet/udp.h>
#import <netinet/in_systm.h>
#import <netinet/ip.h>
#import <arpa/inet.h>
#import "IPICMPSocket.h"		// OpenRawSocket

#import "bpflib.h"

static int get_bpf_fd(char * if_name);

@implementation BPFTransmit

- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
		bsdName = nil;
		hwType = 0;
		bpf_fd = -1;
    }
    return self;
}
- (void)dealloc {
	[self setBsdName:nil];
	if (bpf_fd >= 0) bpf_dispose(bpf_fd);
	[super dealloc];
}

// ---------------------------------------------------------------------------
//		¥ initWithName
// ---------------------------------------------------------------------------
- (id)initWithName:(NSString*)name type:(int)type
{
	BPFTransmit* bpfTransmit = [self init];
	[bpfTransmit setBsdName:name];
	[bpfTransmit setHwType:type];
	return bpfTransmit;
}

// ---------------------------------------------------------------------------
//		¥ setBsdName
// ---------------------------------------------------------------------------
- (NSString*)bsdName { return bsdName; }
- (void)setBsdName:(NSString*)value
{
	[value retain];
	[bsdName release];
	bsdName = value;
}

// ---------------------------------------------------------------------------
//		¥ setHwType
// ---------------------------------------------------------------------------
- (int)hwType { return hwType; }
- (void)setHwType:(int)value
{
	hwType = value;
}

// need this to build against 10.2.8 SDK
#define ARPHRD_IEEE1394	24	/* IEEE1394 hardware address */
// ---------------------------------------------------------------------------
//		¥ sendData
// ---------------------------------------------------------------------------
// send hardware unicast or broadcast out specified interface using bpf tap
// dp points to the packet buffer
// ipOffset is the offset of an IP datagram in the buffer and must leave
//   enough room for the desired frame header
// hwDest is the hardware destination address to use in the frame header
//  if not specified, use hardware broadcast
- (int)sendData:(u_int8_t*)dp ipOffset:(int)ipOffset ipLen:(int)ipLen
hwDest:(u_int8_t*)hwDest hwDestLen:(int)hwDestLen
{
	int status = 0;
    static int	first = 1;
    static int 	ip_id = 0;

    if (first) {
	first = 0;
	ip_id = random();
    }

	do {
	    int frameOffset;
		int frameLen;
		// Resolve hwType if not specified
		if (hwType == 0) {
			if (hwDestLen == 6) hwType = ARPHRD_ETHER;
			if (hwDestLen == 8) hwType = ARPHRD_IEEE1394;
		}
		// get bpf_fd if needed
		if (bpf_fd < 0) bpf_fd = get_bpf_fd((char*)[bsdName cString]);
		if (bpf_fd < 0) {
			status = -1;
			break;
		}
	    switch (hwType) {
			default:
			case ARPHRD_ETHER:
			{
				struct ether_header *	eh_p;
				if (ipOffset < sizeof(*eh_p)) {
					NSLog(@"BPFTransmit: ipOffset too small for Ethernet frame header");
					status = -1;
					break;
				}
				frameOffset = ipOffset - sizeof(*eh_p);
				frameLen = ipLen + sizeof(*eh_p);
				eh_p = (struct ether_header *)&dp[frameOffset];
				// fill in the ethernet header
				if (hwDest == NULL) {
					memset(eh_p->ether_dhost, 0xff, sizeof(eh_p->ether_dhost));
				}
				else {
					bcopy(hwDest, eh_p->ether_dhost, sizeof(eh_p->ether_dhost));
				}
				eh_p->ether_type = htons(ETHERTYPE_IP);
				break;
			}
			case ARPHRD_IEEE1394:
			{
				struct firewire_header *	fh_p;
				if (ipOffset < sizeof(*fh_p)) {
					NSLog(@"BPFTransmit: ipOffset too small for firewire frame header");
					status = -1;
					break;
				}
				frameOffset = ipOffset - sizeof(*fh_p);
				frameLen = ipLen + sizeof(*fh_p);
				fh_p = (struct firewire_header *)&dp[frameOffset];
				// fill in the firewire header
				memset(fh_p->firewire_dhost, 0xff, sizeof(fh_p->firewire_dhost));				   
				fh_p->firewire_type = htons(ETHERTYPE_IP);
				break;
			}
	    }	// switch (hwType)
		if (status < 0) break;
	
	    status = bpf_write(bpf_fd, &dp[frameOffset], frameLen);
	    if (status < 0) {
			NSLog(@"BPFTransmit: bpf_write(%@) failed: %s (%d)",
		       bsdName, strerror(errno), errno);
	    }
	} while (0);
    return (status);
}

@end

static int 
get_bpf_fd(char * if_name)
{
    int bpf_fd;

	//bpf_fd = bpf_new();
	bpf_fd = OpenRawSocket([NSArray arrayWithObject:@"-bpf"]);
    if (bpf_fd < 0) {
		// BPF transmit unavailable
		NSLog(@"Transmitter: bpf_fd() failed, %s (%d)",
			   strerror(errno), errno);
    }
    else if (bpf_filter_receive_none(bpf_fd) < 0) {
		NSLog(@"Transmitter: failed to set filter, %s (%d)",
			   strerror(errno), errno);
		bpf_dispose(bpf_fd);
		bpf_fd = -1;
    }
    else if (bpf_setif(bpf_fd, if_name) < 0) {
		NSLog(@"Transmitter: bpf_setif(%s) failed: %s (%d)", if_name,
			   strerror(errno), errno);
		bpf_dispose(bpf_fd);
		bpf_fd = -1;
    }

    return (bpf_fd);
}
