//
// kftFragment.h
// IPNetRouterX
//
// Created by Peter Sichel on Fri Aug 15 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Fragment Table and support functions
//
// In order to associate subsequent IP fragments with their corresponding
// Connection or NAT table entires, we keep a table of fragment IDs and
// their corresonding srcPort and dstPort from the UDP/TCP header which
// is not otherwise available in subsequent fragments.
//
// Fragments from the same IP datagram are uniquely identified by their
// source IP address and the "identification" field in the IP header.
// When we detect a packet with fragmentOffset zero and IP_MF (more fragments
// flag), we create a corresponding fragment table entry.  As subsequent
// fragments arrive that do not include a UDP or TCP header, we look them
// up in the fragmentTable to find the protocol ports and then use the
// complete data flow endpoints to find the corresponding Connection
// or NAT table entries.
//
// Fragment table entries are aged out after two minutes which exceeds
// the maximum IP fragment re-assembly time and reasonable retransmission time.
//
// The fragment table is rarely used for typical internet traffic, but provides
// protocol completeness for the fragmented datagram case.  We accept
// the small limitation that the first fragment must have arrived
// in order for subsequent fragments to be recognized.  Theoretically
// there is no guarantee that the first fragment will arrive in order,
// but this is a rare exception of an already rare exception.  We accept
// the possibility of extra retransmissions to work around this
// limitation.  Eventually, a first fragment will arrive before possibly
// retransmitted subsequent fragments.  If not, the network has bigger
// problems than fragment reassembly.
//
#include <sys/types.h>
#include "ipkTypes.h"

// KFT_fragmentEntry defined in ipkTypes.h
/*
// ---------------------------------------------------------------------------
// Fragment Entry
// ---------------------------------------------------------------------------
// define IP Fragment table
typedef struct KFT_fragmentId {
	u_int16_t pad;
	u_int16_t identification;
	u_int32_t srcAddress;
} KFT_fragmentId_t;

typedef struct KFT_fragmentEntry {
	KFT_fragmentId_t fragment;
	u_int32_t	lastTime;			// NSTimeInterval since 1970 (in seconds)
	u_int16_t	srcPort;			// source and dest ports needed to lookup connection entry
	u_int16_t	dstPort;			// for subsequent fragments
} KFT_fragmentEntry_t;
*/

void KFT_fragmentStart();
void KFT_fragmentStop();
int KFT_fragmentAdd(KFT_packetData_t* packet);
int KFT_fragmentFindEntry(KFT_fragmentEntry_t* compareEntry, KFT_fragmentEntry_t** foundEntry);
int KFT_fragmentAge();
int KFT_fragmentEntryAge(void * key, void * iter_arg);
int KFT_fragmentEntryRemove(KFT_fragmentEntry_t* entry);
int KFT_fragmentDelete(KFT_fragmentEntry_t* entry);
int KFT_fragmentCount();
// avl support
KFT_memStat_t* KFT_fragmentMemStat(KFT_memStat_t* record);
int KFT_fragmentCompare (void * compare_arg, void * a, void * b);

