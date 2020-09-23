// ===========================================================================
//	dhcp.h			©1999 Sustainable Softworks, All rights reserved.
// ===========================================================================
// dhcp protocol definitions

#ifndef _H_dhcp
#define _H_dhcp
#pragma once

// DHCP protocol ports
#define kDHCPServerPort			67
#define kDHCPClientPort			68
#define kBroadcastAddr			0xFFFFFFFF

// DHCP option codes
#define kOptionPad				0
#define kOptionSubnetMask		1
#define kOptionRouters			3
#define kOptionDomainServer		6
#define kOptionHostName			12
#define kOptionDomainName		15
#define kOptionAddressRequest   50
#define kOptionAddressTime		51
	// use Server Name & Bootfile Name for options
#define kOptionOverload			52
#define kOptionDHCPMessageType	53
#define kOptionDHCPServerID		54
#define kOptionParameterList	55
#define kOptionDHCPMessage		56
#define kOptionDHCPMaxMsgSize   57
#define kOptionRenewalTime		58
#define kOptionRebindingTime	59
#define kOptionClassID			60
#define kOptionClientID			61

#define kOptionEnd				255

// DHCP message types
#define kDHCPBootp				0
#define kDHCPDiscover			1
#define kDHCPOffer				2
#define kDHCPRequest			3
#define kDHCPDecline			4
#define kDHCPAck				5
#define kDHCPNack				6
#define kDHCPRelease			7
#define kDHCPInform				8

#define kBootRequest			1
#define kBootReply				2

// DHCP UDP message
typedef struct DHCPMessage {
	u_int8_t	op;					// operation (1=request, 2=reply)
	u_int8_t	htype;				// hardware type (1=Ethernet)
	u_int8_t	hlen;				// hardware address length (6 for Ethernet)
	u_int8_t	hops;				// client sets to 0, used by relay agents
	u_int32_t	xid;				// match requestes with responses
	u_int16_t	secs;				// elapsed seconds since client began aquisition process
	u_int16_t	flags;				// flags (MSB=1 for broadcast response)
	u_int32_t	ciaddr;				// if client is already bound
	u_int32_t	yiaddr;				// address to be assigned
	u_int32_t	siaddr;				// next server to use in bootstrap
	u_int32_t	giaddr;				// relay agent IP addr
	u_int8_t	chaddr[16];			// client hardware address
	char		sname[64];			// optional server host name
	char		file[128];			// Boot file name (null terminate)
	u_int8_t	options[312];		// Optional parameters field
} DHCPMessage_t;

#endif