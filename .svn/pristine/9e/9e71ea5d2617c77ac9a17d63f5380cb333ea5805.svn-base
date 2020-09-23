//
//  DHCPTypes.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Mon Dec 1 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//

#include "dhcp.h"		// pick up protocol definitions

#define kMaxServerDim	4
#define kMaxServerIndex 3
#define kNoServerIndex	255
#define kBSDNameLength	8
NSString* kDHCPStatusFileName	= @"DHCP Server Status";

struct dhcp_option {
	u_int8_t	option;
	u_int8_t	len;
	u_int16_t	offset;
};
typedef struct dhcp_option dhcp_option_t;

// DHCP request (collect DHCP message information)
struct dhcp_request {
	u_int8_t*	data;	// pointer to buffer containing DHCP request
	u_int32_t	size;	// size of data in buffer
	u_int16_t	offset;	// offset to next item in buffer
	u_int16_t	remotePort;
	u_int32_t	remoteAddr;
	u_int32_t	localAddr;		// IP_RCVIFADDR
	u_int32_t   localMask;
	u_int32_t	localTarget;	// IP_RCVDSTADDR
	u_int32_t   netMask;        // of attached network: from network lease data
	u_int32_t   netNumber;      // of attached network: use giaddr if present, or local target
	u_int32_t	yiaddr;			// address found to assign
	int32_t		leaseTime;		// lease Time to assign
	u_int8_t	leaseState;		// previous existing lease state if any
	Boolean		useClientID;	// remember how we matched client
	Boolean		needPing;		// test new address before assigning
	char 		bsdName[kBSDNameLength];	// corresponding interface name (CString)
	// options
	u_int8_t	dhcpMessageType;
	u_int32_t	addressRequest;
	u_int32_t	dhcpServerID;
	dhcp_option_t subnetMask;
	dhcp_option_t hostName;
	dhcp_option_t addressTime;
	dhcp_option_t overload;
	dhcp_option_t parameterList;
	dhcp_option_t dhcpMessage;
	dhcp_option_t dhcpMaxMsgSize;
	dhcp_option_t renewalTime;
	dhcp_option_t rebindingTime;
	dhcp_option_t classID;
	dhcp_option_t clientID;
};
typedef struct dhcp_request dhcp_request_t;

// DHCP response buffer
#define kMaxResponseLen	1460
struct dhcp_response {
	u_int32_t	xid;			// identify element
	u_int16_t	dataLen;
	u_int16_t	maxLen;
	u_int32_t	ciaddr;			// copied from request
	u_int32_t	localAddr;		// copied from request
	u_int32_t   localMask;
	NSTimeInterval	timeStamp;  // time when placed on response array (seconds since 1970)
	u_int32_t	yiaddr;			// assigned address
	u_int32_t	remoteAddr;		// copied from request
	u_int8_t	leaseState;		// previous existing lease state if any, copied from req
	u_int8_t	respondVia;
	u_int8_t	dhcpMessageType;
	u_int8_t	responseState;	// is response ready, waiting for ping, etc...
	char 		bsdName[kBSDNameLength];	// corresponding interface name (CString)
	// data buffer
	u_int8_t	frameBuf[16];			// ethernet or firewire frame header 
	u_int8_t	headerBuf[28];			// ip and udp header
	u_int8_t	buf[kMaxResponseLen];	// minimum requirement is 576
};
typedef struct dhcp_response dhcp_response_t;

// definitions for respondVia
#define kViaNone			0
#define kViaUnicast			1
	// IP unicast to existing ciaddr
#define kViaBroadcast		2
	// IP local broadcast (all 1's addr)
#define kViaHardwareUnicast	3
	// stuff ARP cache, then unicast to MAC addr
#define kViaRelayAgent		4
	// send response to relay agent
#define kBroadcastFlag		0x8000
// definitions for responseStatus
#define kRSNone				0
#define kRSReady			1
	// ready to be sent
#define kRSPing				2
	// waiting for ping to timeout
// when to check timeouts
#define kIdleDefault		5000
	// test every 5 seconds
#define kIdleRestart		2000
	// restart after 2 second
#define kIdleData			250
	// data waiting, every 250 ms
#define kDHCPRetryCount		10
	// number times to try restarting
// sequence number used to ID our own pings
#define kDHCPServerSN		0x0328


// lease state in DHCP Status element
#define kLeaseNone			0
#define kLeaseOffered		1
#define kLeaseBound			2
#define kLeaseReleased		3
#define kLeaseExpired		4
#define kLeaseDeclined		5
#define kLeaseInUse			6
#define kLeaseBootp			7

NSString* kLeaseNoneStr				= @"none";
NSString* kLeaseOfferedStr			= @"offered";
NSString* kLeaseBoundStr		    = @"bound";
NSString* kLeaseReleasedStr			= @"released";
NSString* kLeaseExpiredStr			= @"expired";
NSString* kLeaseDeclinedStr			= @"declined";
NSString* kLeaseInUseStr		    = @"in use";
NSString* kLeaseBootpStr		    = @"BOOTP";
/*
const NSString* kDHCPStatusStr		    = @"+dhcpStatus";
const NSString* kDHCPStaticCfgStr	    = @"+dhcpStatic";
const NSString* kDHCPDynamicCfgStr	    = @"+dhcpDynamic";
const NSString* kDHCPLeaseDataStr	    = @"+dhcpLeaseOptions";
const NSString* kDHCPmLeaseDataStr	    = @"-dhcpLeaseOptions";

const NSString* kDHCPServerOnStr		= @"#DHCPServerOn";
const NSString*	kDHCPVerboseLoggingStr	= @"#DHCPVerboseLogging";
*/

#define kLeaseOfferPeriod		120
	// period for changing offered to expired
#define kLeaseGracePeriod		120
	// grace period for changing bound to expired
#define kLeaseReclaimPeriod		5184000
	// 60 days

