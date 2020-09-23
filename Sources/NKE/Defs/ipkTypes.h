//
// ipkTypes.h
// IPNetSentryX
//
// Created by Peter Sichel on Thu Nov 14 2002.
// Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
// IPNetSentry_NKE and IPNetRouter_NKE shared types
// This module is designed to be tested as client code and then incorporated
// as part of our NKE

#ifndef _H_ipkTypes
#define _H_ipkTypes
#pragma once

#include <sys/types.h>
#include <sys/time.h>
#include <sys/queue.h>
#include <libkern/OSTypes.h>
#if TIGER
#include <netinet/kpi_ipfilter.h>
#include <sys/kpi_mbuf.h>
#include <net/kpi_interface.h>
#include <net/kpi_interfacefilter.h>
#else
#include "kftPanther.h"
#endif

#define kBSDNameLength	8
#define kServiceIDNameLength 48
#define kFHMaxLen 20

// Ethernet or Hardware address format
typedef struct {
	u_int8_t octet[6];
} EthernetAddress_t;

typedef struct {
	u_int8_t octet[16];
} HardwareAddress16_t;

// ---------------------------------------------------------------------------
// InterfaceEntry
// ---------------------------------------------------------------------------
// define interfaceEntry to represent interface attach parameters
typedef struct netNumber {
	u_int32_t	address;
	u_int32_t	mask;
} netNumber_t;

typedef struct	KFT_interfaceEntry {
	char 		bsdName[kBSDNameLength];	// corresponding interface name (CString)
	char		serviceID[kServiceIDNameLength];
    netNumber_t ifNet;
	netNumber_t natNet;
	netNumber_t singleNet;
	netNumber_t excludeNet;
	u_int32_t	exposedHost;
	u_int8_t	exposedHostSelection;
	u_int8_t	filterOn;			// IP filter on this interface
	u_int8_t	externalOn;
	u_int8_t	natOn;				// NAT on this interface
    
	u_int8_t	bridgeOn;			// bridge on this interface?
	u_int8_t	protocolFilter;		// 0=interface filter, 1=protocol filter
    u_int8_t    pad1;
    u_int8_t    pad2;
} KFT_interfaceEntry_t;

// ---------------------------------------------------------------------------
// Control and Attach instance
// ---------------------------------------------------------------------------
// maximum number of controllers and DLIL attachments use index values 1..n
// 0 is reserved for "not found"
#define kMaxControl	8
#define kMaxAttach 8
#define kMessageMaskServer				0x01
#define kMessageMaskGUI					0x02
#define kMessageMaskServerGUI			0x03
#define kMessageMaskTrafficDiscovery	0x04
#define kMessageMaskAll		0xFFFF

// controller instance
typedef struct controlE {
#if TIGER
	socket_t ctl;				// Non-null if controlled
#else
    struct socket *ctl;			// Non-null if controlled
#endif
    int monitorOn;				// master on/off for this controller
    int nkeSends;				// count packets sent upstream since last request
								// so we don't flood input queue when no one is listening
	u_int32_t messageMask;		// which messages this controller wants
    u_int8_t attachMap[kMaxAttach+1]; // map of corresponding DLIL attachments if any
								// map[i]>0 if attached
} control_t;

// DLIL attach instance
typedef struct attachE {
#if TIGER
	ipfilter_t ipFilterRef;
	interface_filter_t ifFilterRef;
#else
    u_long filterID;		// attached filterID needed to detach this filter
	u_long tigerPad;
#endif
    KFT_interfaceEntry_t kftInterfaceEntry;
	// monitor tool
    int32_t sendCount;		// traffic stats for instance
    int32_t receiveCount;
    int32_t sendStamp;		// capture and hold previous counts for reporting
    int32_t receiveStamp;
	// bridging
	ifnet_t ifnet_ref;		// the ifnet we attached to
	EthernetAddress_t ea;
	u_int8_t pad1;
	u_int8_t pad2;
	u_int8_t pad3;
	u_int8_t promiscOn;		// remember promisc setting for this interface
	u_int8_t muteOn;		// mute bridging on this interface
	u_int8_t attachIndex;   // remember our own attach index for convenience
	// failover
	int32_t activeConnections;
	int32_t failedConnections;
} attach_t;

// ---------------------------------------------------------------------------
// Advanced Routing Table
// ---------------------------------------------------------------------------
#define kMaxRoute 8
typedef struct KFT_routeEntry {
	char 		bsdName[kBSDNameLength];	// corresponding interface name (CString)
	u_int32_t	gatewayIP;
	u_int8_t	gatewayHA[8];
	// failover stats
	int32_t		activeConnections;
	int32_t		failedConnections;
	// more
	u_int8_t	attachIndex;				// lookup from bsdName
	int8_t		pad1;
	int16_t		flags;
} KFT_routeEntry_t;

typedef struct KFT_stat64 {
	int64_t count;
	int64_t previous;
	int64_t delta;
    int64_t pad1;
} KFT_stat64_t;

typedef struct KFT_stat {
	int32_t count;
	int32_t previous;
	int32_t delta;
    int32_t pad1;
} KFT_stat_t;

// ---------------------------------------------------------------------------
// MemStat Entry
// ---------------------------------------------------------------------------
	// ident
#define kMemStat_avlTree 1
#define kMemStat_avlNode 2
#define kMemStat_trigger 3
#define kMemStat_connection 4
#define kMemStat_nat 5
#define kMemStat_portMap 6
#define kMemStat_callback 7
#define kMemStat_fragment 8
#define kMemStat_last 9
typedef struct KFT_memStat {
	int32_t type;
	int32_t freeCount;
	int32_t tableCount;
	int32_t allocated;
	int32_t released;
	int32_t allocFailed;
	int32_t leaked;
    int32_t pad1;
} KFT_memStat_t;

// ---------------------------------------------------------------------------
// Filter Entry
// ---------------------------------------------------------------------------
// define filter table entry
#define kPropertySize 128
#define kPropertyReserve 32
#define kNodeNumberSize 16
#define kNodeNameSize 32
typedef struct KFT_filterEntry {
	u_int16_t nodeCount;
	u_int16_t parentIndex;
	u_int8_t pad0;
	u_int8_t enabled;
	u_int8_t nodeNumber[kNodeNumberSize];
	u_int8_t nodeName[kNodeNameSize];
	u_int8_t property;
	u_int8_t relation;
	u_int8_t filterAction;
	u_int8_t expandedState;
	u_int32_t lastTime;
	KFT_stat64_t match;
	KFT_stat64_t byte;
	// route to info
	u_int32_t routeNextHop;			// next hop IP address (parameter for routeTo action)
	u_int8_t routeHardwareAddress[8]; // HW address of destination
	// rate limit info
	int32_t rateLimit;				// rate limit in bits/sec
	int32_t activeCount;			// active connections seen matching this rule during last interval
	int32_t activeCountAdjusted;	// adaptive count updated each interval based on observed error
	int32_t intervalBytes;			// bytes transferred matching rate limit rule
	// property value and parameter info
	u_int8_t propertyValue[kPropertySize];	// |propertyValue ->  <- parameterValue|
	u_int8_t pad1;
	u_int8_t pad2;
	u_int8_t propertyEnd;
	u_int8_t parameterStart;
} KFT_filterEntry_t;

// ---------------------------------------------------------------------------
// Trigger Entry
// ---------------------------------------------------------------------------
// define trigger table entry used to maintain triggered addresses
#define kTriggeredBySize 48
typedef struct KFT_triggerEntry {
	u_int32_t address;  // address and type are used together as an 8-byte key
	u_int32_t type;
	u_int32_t endOffset;		// offset to last address in range
	u_int32_t lastTime;
	SLIST_ENTRY(KFT_triggerEntry) entries;	// free list
	u_int8_t duration;	
	u_int8_t flags;
	u_int8_t pad0;
	u_int8_t pad1;
	KFT_stat_t match;
	char triggeredBy[kTriggeredBySize];		// PString
} KFT_triggerEntry_t;
#define kTriggerTypeTrigger 0
#define kTriggerTypeAddress 1
#define kTriggerTypeAuthorize 2
#define kTriggerTypeInvalid 3
#define kTriggerDurationMax 6
#define kTriggerFlagDelete 1
#define kTriggerFlagUpdate 2
#define kTriggerFlagTagAll 4
#define kTriggerFlagRemoveTagged 8

typedef struct KFT_triggerKey {
	u_int32_t address;  // address and type are used together as an 8-byte key
	u_int32_t type;
} KFT_triggerKey_t;

// ---------------------------------------------------------------------------
// Connection Endpoint
// ---------------------------------------------------------------------------
// define Connection endpoint, MSB->LSB: protocol, port, address
// so that adjacent entries will be in protocol, port order.
typedef struct KFT_connectionEndpoint {
	u_int16_t port;
	u_int8_t  pad;
	u_int8_t  protocol;
	u_int32_t address;
} KFT_connectionEndpoint_t;

// ---------------------------------------------------------------------------
// NAT Entry
// ---------------------------------------------------------------------------
// define NAT table
typedef struct KFT_natEntry {
	KFT_connectionEndpoint_t apparent;
	KFT_connectionEndpoint_t actual;
	KFT_connectionEndpoint_t remote;
	KFT_connectionEndpoint_t proxy;
	u_int32_t	lastTime;			// NSTimeInterval since 1970
	u_int32_t	expireTime;			// for NAT-PMP entries with a fixed life
	u_int16_t	flags;
	u_int8_t	inactive;
	u_int8_t	localProxy;					// local transparent proxy
	char 		bsdName[kBSDNameLength];	// corresponding interface name (CString)
	// NAPT
	u_int32_t   seqFINLocal;		// seq# to check for last ACK
	u_int32_t   seqFINPeer;
	u_int16_t	endOffset;			// offset to last port in port range
    u_int16_t   pad;
//	u_int16_t	identification;		// from IP header
//	u_int16_t	fragmentOffset;
//	u_int32_t	seqInitial;			// used to offset seq and ack #'s
//	int16_t		seqOffset;			//   for content masquerading
//	u_int32_t	seqInitial2;		// used to offset seq and ack #'s
//	int16_t		seqOffset2;			//   for content masquerading
//	int16_t		seqOffsetPrev;
	SLIST_ENTRY(KFT_natEntry) entries;	// free list
} KFT_natEntry_t;

// Values for NAT entry Flags
	// NKE flags for tacking entry status
#define kNatFlagFINLocal		1		// Seen TCP FIN from local host
#define kNatFlagFINPeer			2		// Seen TCP FIN from peer
#define kNatFlagFINAckLocal		4		// Seen TCP FIN Ack from local host
#define kNatFlagFINAckPeer		8		// Seen TCP FIN Ack from peer

#define kNatFlagNatPMP			0x20	// This is a NAT-PMP entry that expires
#define kNatFlagProxy			0x40	// Transparent proxy entry
#define kNatFlagNonSyn			0x80	// Sent more than a Syn
	// shared flags for signalling between NKE and client
#define kNatFlagDelete			0x0100
#define kNatFlagUpdate 			0x0200
#define kNatFlagRemoveAll		0x0400

// ---------------------------------------------------------------------------
// Fragment Entry
// ---------------------------------------------------------------------------
// define IP Fragment table
typedef struct KFT_fragmentId {
	u_int32_t srcAddress;
	u_int16_t identification;
	u_int16_t pad;
} KFT_fragmentId_t;

typedef struct KFT_fragmentEntry {
	KFT_fragmentId_t fragment;
	u_int32_t	lastTime;			// NSTimeInterval since 1970 (in seconds)
	u_int16_t	srcPort;			// source and dest ports needed to lookup connection entry
	u_int16_t	dstPort;			// for subsequent fragments
	SLIST_ENTRY(KFT_fragmentEntry) entries;	// free list
} KFT_fragmentEntry_t;


// ---------------------------------------------------------------------------
// Connection Entry
// ---------------------------------------------------------------------------
// define connection table entry used to maintain connection state

typedef struct KFT_connectionInfo {		// one for each direction received (r) and sent (s)
	u_int32_t targetBytes;  // target bytes to transfer this interval if rate limited
	u_int32_t isn;			// seq number of first byte transferred
	u_int32_t seqNext;		// seq of last byte transferred plus 1 or ack number expected
	
	int32_t targetWindow;	// target window size to send to peer if rate limited
	u_int32_t prevAckNum;	// the last seq number we Acked
	int32_t prevAckWin;		// the advertised window sent with the Ack
	int32_t prevRWin;		// previous actual window size received;
	int32_t uncountedMove;	// ackNum beyond previous window limit, record uncounted move
	u_int32_t prevWindowStart;	// windowStart when window limit was last moved.
	struct timeval moveWindow_tv;	// when the receive window should next be moved

	u_int16_t scale;		// window scale factor
	u_int16_t mss;			// mss option sent to peer
	u_int16_t rateLimitRule; // index of rule in filter table (for rate limit bandwidth bytes/sec)
	u_int8_t callbackPending;	// Delayed window move waiting to be delivered (on callback tree)
	u_int8_t pad;
} KFT_connectionInfo_t;

typedef struct KFT_connectionEntry {
	KFT_connectionEndpoint_t remote;
	KFT_connectionEndpoint_t local;
	KFT_stat_t	dataIn;
	KFT_stat_t	dataOut;
	u_int32_t	lastTime;
	u_int32_t	firstTime;
	u_int32_t	connectionLogTime;
	u_int32_t	rxLastTime;			// last receive time for failover
	u_int32_t	flags;
	u_int8_t	dropCount;
	u_int8_t	dupSynCount;		// duplicate sent SYN for failover
	u_int8_t	icmpType;
	u_int8_t	icmpCode;
	// connection state
	u_int32_t   seqFINLocal;		// seq# to check for last ACK
	u_int32_t   seqFINPeer;
	// bandwidth management
	KFT_connectionInfo_t rInfo;
	KFT_connectionInfo_t sInfo;
//	KFT_seqList_t rSeqList;
//	KFT_seqList_t sSeqList;
	struct timeval callbackKey_tv;
	u_int32_t callbackKeyUnique;	// distinguish similar callback times
	u_int8_t callbackDirection;
	// frame header info used by source aware routing, rate limiting, respondACk
	u_int8_t rxAttachIndex;		// interface where packet arrived from (if rx seen)
	u_int8_t attachFailed;		// where connection failedover from (if any)
	u_int8_t viaGateway;		// destination is not directly attached
	u_int8_t txAttachIndex;		// tx attach
	u_int8_t pad;
	u_int8_t rxfhlen;			// rx frame header len
	u_int8_t txfhlen;			// tx frame header len
	u_int8_t rxfh[kFHMaxLen];	// rx frame header
	u_int8_t txfh[kFHMaxLen];	// tx frame header
	SLIST_ENTRY(KFT_connectionEntry) entries;	// free list
} KFT_connectionEntry_t;

typedef struct KFT_trafficEntry {
	KFT_connectionEndpoint_t remote;
	KFT_connectionEndpoint_t local;
	KFT_stat_t	dataIn;
	KFT_stat_t	dataOut;
	u_int32_t	trafficDiscoveryTime;
	u_int32_t	flags;
	u_int8_t	icmpType;
	u_int8_t	icmpCode;
	u_int8_t	attachInfo;
	u_int8_t	pad;
	char 		bsdName[kBSDNameLength];	// corresponding interface name (CString)
} KFT_trafficEntry_t;

// Values for Connection entry Flags
#define kConnectionFlagFINLocal			1		// Seen TCP FIN from local host
#define kConnectionFlagFINPeer			2		// Seen TCP FIN from peer
#define kConnectionFlagFINAckLocal		4		// Seen TCP FIN Ack from local host
#define kConnectionFlagFINAckPeer		8		// Seen TCP FIN Ack from peer
#define kConnectionFlagFailoverRequest1	0x10	// dead gateway, failover requested
#define kConnectionFlagFailoverRequest2	0x20	// dead gateway, failover requested
#define kConnectionFlagClosed			0x40	// Closed by firewall
#define kConnectionFlagNonSyn			0x80	// Sent more than a Syn
#define kConnectionFlagDelete			0x0100
#define kConnectionFlagUpdate 			0x0200
#define kConnectionFlagPassiveOpen		0x0400	// connection initiated from outside

// reserve bandwidth info
#define kMaxReserve 7
typedef struct KFT_reserveInfo {	// one for each direction
	u_int16_t reserve[kMaxReserve];
	u_int16_t lastRule;			// index of last rate limit rule
} KFT_reserveInfo_t;

// ---------------------------------------------------------------------------
// Bridge Entry
// ---------------------------------------------------------------------------
// define bridge table entry used to do Ethernet bridging (16 bytes/entry)
typedef struct KFT_bridgeEntry {
	u_int32_t attachIndex;			// data link (port) packet arrived on
	u_int32_t lastTime;			// last time we saw or used this address (tv_sec)
	EthernetAddress_t ea;		// hardware MAC address
	u_int8_t conflictCount;		// count port conflicts
	u_int8_t flags;
} KFT_bridgeEntry_t;
#define kBridgeFlagOutbound			0x01	// direction of packet seen
#define kBridgeFlagDelete			0x40
#define kBridgeFlagUpdate 			0x80


// ---------------------------------------------------------------------------
// packet data
// ---------------------------------------------------------------------------
// Structure used to keep track of how packets are re-routed.
// We remember the original values and update the ones in the packet
// so we can reverse any changes consistently.
typedef struct KFT_redirect {
	u_int8_t attachIndex;		// which port were redirecting to
	int8_t pad;
	int8_t originalAttachIndex;
	int8_t originalDirection;
} KFT_redirect_t;

// structure used to pass around packets
typedef struct KFT_packetData {
	ifnet_t ifnet_ref;
	protocol_family_t protocol;
	mbuf_t *mbuf_ptr;	// pointer to mbuf chain
	char	**frame_ptr;		// frame pointer
	attach_t* myAttach;	// pointer to interface attach instance for this datagram
	KFT_filterEntry_t* kftEntry;	// matching filter entry
	KFT_triggerEntry_t* triggerEntry;	// matching trigger entry
	KFT_connectionEntry_t* connectionEntry;	// matching connection state entry
	KFT_natEntry_t* natEntry;	// matching nat entry if any
	u_int8_t* datagram;	// start of datagram in first mbuf
	int segmentLen;		// length of data segment
	u_int16_t   rateLimitInRule;
	u_int16_t   rateLimitOutRule;
	u_int16_t	ipOffset;	// integer offset to start of IP datagram within mbuf data
	u_int16_t	matchOffset;	// base for relative data content matching
	u_int16_t	textOffset;		// display what we found
	u_int16_t	textLength;
	int8_t direction;	// 0=output, 1=input (from which intercept was called)
	u_int8_t ifType;		// from ifnet 
	u_int8_t ifHeaderLen;	// length of frame header
	u_int8_t ipHeaderLen;
	u_int8_t transportHeaderLen;
	u_int8_t leafAction;	// remember leaf action for children if any
	u_int8_t dontLog;		// mark as not to be logged (1 = dont log)
	u_int8_t bridgeNonIP;			// Ethernet and not IP
	u_int8_t modifyReady;   // packet is ready to be modified
	u_int8_t localProxy;	// port map for local transparent proxy
	u_int8_t swap;			// remember if we have done ntohPacket
	u_int8_t pad1;
	KFT_redirect_t redirect;	// used for advanced routing
} KFT_packetData_t;

#endif
