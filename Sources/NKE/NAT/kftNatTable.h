//
// kftNatTable.h
// IPNetRouterX
//
// Created by Peter Sichel on Tues Jun 10 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Nat Table and support functions
//
#include <sys/types.h>
#include "ipkTypes.h"

/* ipkTypes.h and IPNetRouter_TNKE.h
// ---------------------------------------------------------------------------
// NAT Entry
// ---------------------------------------------------------------------------
// define NAT table
typedef struct KFT_natEntry {
	KFT_connectionEndpoint_t apparent;
	KFT_connectionEndpoint_t actual;
	KFT_connectionEndpoint_t remote;
	KFT_connectionEndpoint_t proxy;
	u_int32_t	lastTime;			// NSTimeInterval seconds since 1970
	u_int32_t	expireTime;			// for NAT-PMP entries with a fixed life
	u_int16_t	flags;
	u_int8_t	inactive;
	u_int8_t	pad;
	char 		bsdName[kBSDNameLength];	// corresponding interface name (CString)
	// NAPT
	u_int16_t	endOffset;			// offset to last port in port range
	u_int32_t   seqFINLocal;		// seq# to check for last ACK
	u_int32_t   seqFINPeer;
//	u_int16_t	identification;		// from IP header
//	u_int16_t	fragmentOffset;
//	u_int32_t	seqInitial;			// used to offset seq and ack #'s
//	int16_t		seqOffset;			//   for content masquerading
//	u_int32_t	seqInitial2;		// used to offset seq and ack #'s
//	int16_t		seqOffset2;			//   for content masquerading
//	int16_t		seqOffsetPrev;
} KFT_natEntry_t;

// Values for NAT entry Flags
#define kNatFlagFINLocal		1		// Seen TCP FIN from local host
#define kNatFlagFINPeer			2		// Seen TCP FIN from peer
#define kNatFlagFINAckLocal		4		// Seen TCP FIN Ack from local host
#define kNatFlagFINAckPeer		8		// Seen TCP FIN Ack from peer

#define kNatFlagNatPMP			0x20	// This is a NAT-PMP entry that expires
#define kNatFlagProxy			0x40	// Transparent proxy entry
#define kNatFlagNonSyn			0x80	// Sent more than a Syn
#define kNatFlagDelete			0x0100
#define kNatFlagUpdate 			0x0200
#define kNatFlagRemoveAll		0x0400

struct	ipk_natUpdate {
	int32_t	length;		// length of message
    int16_t	type;		// message type
    int8_t	version;	// version
	int8_t	flags;		// flag bits
	KFT_natEntry_t natUpdate[1];	// some number of nat updates
};
typedef struct ipk_natUpdate ipk_natUpdate_t;
*/

void KFT_natStart();
void KFT_natStop();
int KFT_natFindApparentForActual(KFT_packetData_t* packet, KFT_natEntry_t* compareEntry, KFT_natEntry_t** foundEntry);
int KFT_natFindActualForApparent(KFT_packetData_t* packet, KFT_natEntry_t* compareEntry, KFT_natEntry_t** foundEntry);
int KFT_natPacket(KFT_packetData_t* packet);
KFT_natEntry_t* KFT_natAddCopy(KFT_natEntry_t* entry);
int KFT_natSearchDelete(KFT_natEntry_t* entry);
int KFT_natDelete(KFT_natEntry_t* entry);
// age
void KFT_natSecond();
int KFT_natAge();
int KFT_natEntryAge(void * key, void * iter_arg);
int KFT_natEntryRemove(KFT_natEntry_t* entry);
// report
int KFT_natUpload();
int KFT_natEntryReport(void * key, void * iter_arg);
void KFT_natSendUpdates();
int KFT_natCount();
int KFT_natCountActual();
// request
int KFT_natReceiveMessage(ipk_message_t* message);
// avl support
KFT_memStat_t* KFT_natMemStat(KFT_memStat_t* record);
int KFT_natApparentCompare (void * compare_arg, void * a, void * b);
int KFT_natActualCompare (void * compare_arg, void * a, void * b);

