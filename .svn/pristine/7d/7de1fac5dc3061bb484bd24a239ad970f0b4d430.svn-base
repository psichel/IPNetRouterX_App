//
// kftBridge.h
// IPNetRouterX
//
// Created by Peter Sichel on Tues Jun 10 2003.
// Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Bridge Table and support functions
//
#include <sys/types.h>
#include "ipkTypes.h"

// KFT_bridgeEntry defined in ipkTypes.h
/*
// Ethernet Address
typedef struct {
	u_int8_t octet[ETHER_ADDR_LEN];
} EthernetAddress_t;

// ---------------------------------------------------------------------------
// Bridge Entry
// ---------------------------------------------------------------------------
// define bridge table entry used to do Ethernet bridging (16 bytes/entry)
typedef struct KFT_bridgeEntry {
	u_long filterID;			// data link (port) packet arrived on
	u_int32_t lastTime;			// last time we saw or used this address (tv_sec)
	EthernetAddress_t ea;		// hardware MAC address
	u_int8_t count;				// count port conflicts
	u_int8_t flags;
} KFT_bridgeEntry_t;
#define kBridgeFlagLocal			0x01
#define kBridgeFlagDelete			0x40
#define kBridgeFlagUpdate 			0x80

struct	ipk_bridgeUpdate {
	int32_t	length;		// length of message
    int16_t	type;		// message type
    int8_t	version;	// version
	int8_t	flags;		// flag bits
	KFT_bridgeEntry_t bridgeUpdate[1];	// some number of bridge updates
};
typedef struct ipk_bridgeUpdate ipk_bridgeUpdate_t;
*/

extern attach_t PROJECT_attach[kMaxAttach+1];

#define HASH_SIZE 8192	/* must be a power of 2 */
#define HASH_FN(addr)   (	\
	ntohs( ((short *)addr)[1] ^ ((short *)addr)[2] ) & (HASH_SIZE - 1))

#define EA_MATCH(a,b) (!memcmp(a, b, 6) )
#define EA_FROM_IFP(ifp)	((struct arpcom *)ifp)->ac_enaddr


void KFT_bridgeStart();
void KFT_bridgeStop();
KFT_bridgeEntry_t* KFT_bridgeFind(EthernetAddress_t* ea);
KFT_bridgeEntry_t* KFT_bridgeAdd(EthernetAddress_t*  ea);
KFT_bridgeEntry_t* KFT_bridgeAddPacket(KFT_packetData_t* packet);
int KFT_bridgeDelete(KFT_bridgeEntry_t* entry);
int KFT_bridgeAge();

