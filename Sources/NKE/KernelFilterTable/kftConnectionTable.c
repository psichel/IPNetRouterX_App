//
// kftConnection.c
// IPNetSentryX
//
// Created by Peter Sichel on Tue Jun 10 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Connection Table and support functions
//
// lastTime is stored as a u_int32_t corresponding to an NSTimeInterval (seconds) since 1970.
#if IPK_NKE
#define DEBUG_IPK 0
#else
#define DEBUG_IPK 0
#endif

#if DEBUG_IPK
#include <sys/syslog.h>
#endif

#include "IPTypes.h"
#include PS_TNKE_INCLUDE
#include "kftConnectionTable.h"
#include "kftFragmentTable.h"
#ifdef IPNetRouter
	#include "kftNatTable.h"
#endif
#include "kft.h"
#include "kftSupport.h"
#include "IPKSupport.h"
#include "FilterTypes.h"
#include "avl.h"
#include <sys/time.h>
#include <net/ethernet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netinet/tcp_seq.h>	// sequence number compare macros SEQ_LT, SEQ_LEQ, SEQ_GT, SEQ_GEQ(a,b)
#include <sys/socket.h>
#include <sys/mbuf.h>
#include <net/if.h>
#include <net/if_types.h>
#include <string.h>

#if IPK_NKE
#include <sys/systm.h>
#include <machine/spl.h>
#include <sys/param.h>
#include <libkern/OSAtomic.h>
#include <net/dlil.h>
// define malloc for kernel versus application use
#include <sys/malloc.h>
#if TIGER
	#define my_malloc(a)	_MALLOC(a, M_TEMP, M_NOWAIT)
	#define my_free(a)	FREE(a, M_TEMP)
#else
	#define my_malloc(a)	_MALLOC(a, M_IPFW, M_NOWAIT)
	#define my_free(a)	FREE(a, M_IPFW)
#endif
#else
#include "stdlib.h"
#define my_malloc(a)	malloc(a)
#define my_free(a)	free(a)
#endif

// IterArg passed to iterate function along with each node in tree
struct KFT_connectionIterArg {
 struct timeval now_tv;
 u_int32_t currentTime;
 u_int32_t lastTime;					// oldest lastTime
 int32_t ageOutNum;
 int16_t failoverRequest1;
 int16_t failoverRequest2;
 int16_t fromTimer;
 int16_t tdEntryCount;
 KFT_connectionEntry_t *entry;	// oldest entry
};
typedef struct KFT_connectionIterArg KFT_connectionIterArg_t;

// Global storage
#include "kftGlobal.h"		// PROJECT_doRateLimit

// Module wide storage
// allocate Kernel Connection Table
#define KFT_connectionTableSize 2000
static avl_tree *kft_connectionTree = NULL;
static avl_tree *kft_callbackTree = NULL;
static u_int32_t callbackKeyUnique;
static int32_t timerPending;
// free list
static SLIST_HEAD(listhead, KFT_connectionEntry) connection_freeList = { NULL };
static int32_t connection_freeCount = 0;
static int32_t connection_freeCountMax = 128;
static int32_t connection_memAllocated = 0;
static int32_t connection_memAllocFailed = 0;
static int32_t connection_memReleased = 0;
// delete list (to be deleted after iterating)
static SLIST_HEAD(listhead2, KFT_connectionEntry) connection_deleteList = { NULL };



#define kConnectionUpdateBufferSize 2000
static unsigned char connectionUpdateBuffer[kConnectionUpdateBufferSize];
static unsigned char trafficUpdateBuffer[kConnectionUpdateBufferSize];

#define WINDOW_MOVES_PER_SECOND 10

// forward internal function declarations
KFT_connectionEntry_t* KFT_connectionMalloc();
int KFT_connectionFree(void * key);
void KFT_connectionFreeAll();

// callback tree
void KFT_callbackSetMoveTimeForDirection(KFT_connectionEntry_t* cEntry, struct timeval *tvp, int8_t direction);
int KFT_callbackAddEntry(KFT_connectionEntry_t* cEntry, int8_t direction);
int KFT_callbackRemoveEntry(KFT_connectionEntry_t* cEntry);
int KFT_callbackSetTimeout(int msec);
void KFT_callbackUntimeout();
static void KFT_callbackTimeout(void *cookie);
// loging
int KFT_connectionLogEvent(KFT_connectionEntry_t* cEntry, char* inString);
#if !IPK_NKE
void testMessageFromClient(ipk_message_t* message);
int PROJECT_modifyReadyPacket(KFT_packetData_t* packet);
#endif

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionStart()
// ---------------------------------------------------------------------------------
//	init connection table
//  Called from IPNetSentry_NKE_start() or SO_KFT_RESET which are thread protected
void KFT_connectionStart()
{
	// release old trees if any
		// must release callback tree first since connectionTree releases nodes
	if (kft_callbackTree) free_avl_tree(kft_callbackTree, KFT_callbackFree);
	if (kft_connectionTree) free_avl_tree(kft_connectionTree, KFT_connectionFree);
	kft_callbackTree = NULL;
	kft_connectionTree = NULL;
	// allocate new avl trees
	kft_connectionTree = new_avl_tree(KFT_connectionCompare, NULL);
	kft_callbackTree = new_avl_tree(KFT_callbackCompare, NULL);
	callbackKeyUnique = 0;
	timerPending = 0;
	KFT_connectionFreeAll();	// releaase freeList
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_connectionStart\n");
	#endif
	{   // initialize connection update buffer
		ipk_connectionUpdate_t* message;
		message = (ipk_connectionUpdate_t*)&connectionUpdateBuffer[0];
		message->length = 8;	// offset to first entry
		message->type = kConnectionUpdate;
		message->version = 0;
		message->flags = 0;
	}
	{   // initialize traffic update buffer
		ipk_trafficUpdate_t* message;
		message = (ipk_trafficUpdate_t*)&trafficUpdateBuffer[0];
		message->length = 8;	// offset to first entry
		message->type = kTrafficUpdate;
		message->version = 0;
		message->flags = 0;
	}
	// start subordinate fragmentTable
	KFT_fragmentStart();
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionStop()
// ---------------------------------------------------------------------------------
//	release connection table
//  Called from IPNetSentry_NKE_stop()
void KFT_connectionStop()
{
	// cancel pending timer if any
	KFT_callbackUntimeout();
	// release old trees if any
		// must release callback tree first since connectionTree releases nodes
	if (kft_callbackTree) free_avl_tree(kft_callbackTree, KFT_callbackFree);
	if (kft_connectionTree) free_avl_tree(kft_connectionTree, KFT_connectionFree);
	kft_callbackTree = NULL;
	kft_connectionTree = NULL;
	// freeList
	KFT_connectionFreeAll();
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_connectionStop\n");
	#endif
	KFT_fragmentStop();
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionAdd()
// ---------------------------------------------------------------------------------
// add packet info to connection table
// caller must look for existing entry to avoid duplicates
// return a pointer to the new entry as packet->connectionEntry
// return:  0 success, -1 unable to complete request
int KFT_connectionAdd(KFT_packetData_t* packet)
{
	int returnValue = -1;
	int result;
	KFT_connectionEntry_t *cEntry = NULL;
	
	if (packet && kft_connectionTree) {
		// check if there is room
		if (KFT_connectionCount() > KFT_connectionTableSize) {
			KFT_connectionAge(0);	// make more if needed
		}
		// add entry to connection table
		cEntry = KFT_connectionMalloc();		
		if (cEntry) {
			returnValue = 0;
			bzero(cEntry, sizeof(KFT_connectionEntry_t));
			// lastTime
			struct timeval now_tv;
			#if IPK_NKE
			microtime(&now_tv);
			#else
			gettimeofday(&now_tv, NULL);
			#endif
			cEntry->lastTime = now_tv.tv_sec;	// ignore fractional seconds
			cEntry->firstTime = now_tv.tv_sec;
			// endpoint info
			ip_header_t* ipHeader;
			tcp_header_t* tcpHeader;
			int protocol;
			ipHeader = (ip_header_t*)packet->datagram;
			tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
			protocol = ipHeader->protocol;
			// assign based on packet direction
			if (packet->direction == kDirectionOutbound) {
				// remote peer
				cEntry->remote.address = ipHeader->dstAddress;
				cEntry->remote.protocol = protocol;
				cEntry->remote.pad = 0;
				// local
				cEntry->local.address = ipHeader->srcAddress;
				cEntry->local.protocol = protocol;
				cEntry->local.pad = 0;
				// port
				if ((protocol == IPPROTO_TCP) || (protocol == IPPROTO_UDP)) {
					cEntry->remote.port = tcpHeader->dstPort;
					cEntry->local.port = tcpHeader->srcPort;
				}
				else if (protocol == IPPROTO_ICMP) {
					icmp_header_t* icmpHeader;
					icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
					cEntry->icmpType = icmpHeader->type;
					cEntry->icmpCode = icmpHeader->code;
					// keep a separate entry for each ICMP service type
					cEntry->remote.port = (icmpHeader->type << 8) | icmpHeader->code;
				}
				// capture frame header info for rate limiting and source aware routing
				cEntry->txAttachIndex = packet->myAttach->attachIndex;
				if (packet->ifHeaderLen <= kFHMaxLen) {
					// outbound
					u_int8_t* ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
					cEntry->txfhlen = packet->ifHeaderLen;
					memcpy(cEntry->txfh, ha, cEntry->txfhlen);
				}
					// check if sending on an external interface
				if (packet->myAttach->kftInterfaceEntry.externalOn) cEntry->flags &= ~kConnectionFlagPassiveOpen;
			}
			else {	// inbound
				// remote peer
				cEntry->remote.address = ipHeader->srcAddress;
				cEntry->remote.protocol = protocol;
				cEntry->remote.pad = 0;
				// local
				cEntry->local.address = ipHeader->dstAddress;
				cEntry->local.protocol = protocol;
				cEntry->local.pad = 0;
				// port
				if ((protocol == IPPROTO_TCP) || (protocol == IPPROTO_UDP)) {
					cEntry->remote.port = tcpHeader->srcPort;
					cEntry->local.port = tcpHeader->dstPort;
				}
				else if (protocol == IPPROTO_ICMP) {
					icmp_header_t* icmpHeader;
					icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
					cEntry->icmpType = icmpHeader->type;
					cEntry->icmpCode = icmpHeader->code;
					// keep a separate entry for each ICMP service type
					cEntry->remote.port = (icmpHeader->type << 8) | icmpHeader->code;
				}
				// capture frame header info for rate limiting and source aware routing
				cEntry->rxAttachIndex = packet->myAttach->attachIndex;
				cEntry->rxLastTime = now_tv.tv_sec;
				if (packet->ifHeaderLen <= kFHMaxLen) {
					// inbound
					u_int8_t* ha = (u_int8_t*)*packet->frame_ptr;
					cEntry->rxfhlen = packet->ifHeaderLen;
					memcpy(cEntry->rxfh, ha, cEntry->rxfhlen);
				}
					// check if receiving on an external interface
				if (packet->myAttach->kftInterfaceEntry.externalOn) cEntry->flags |= kConnectionFlagPassiveOpen;
			}
			// add to tree
			returnValue = insert_by_key(kft_connectionTree, (void *)cEntry);
			if (returnValue != 0) {		// insert failed, out of memory
				KFT_connectionFree(cEntry);			// release new entry so we don't leak it
			}
			else {
				// include found entry with packet
				packet->connectionEntry = cEntry;
				// handle fragment info as needed
				{
					u_int16_t fragmentOffset;
					fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;
					// if first of multiple fragments, add info to fragment table
					if ((fragmentOffset == 0) && (ipHeader->fragmentOffset & IP_MF)) {
						result = KFT_fragmentAdd(packet);
						if (result != 0) KFT_logEvent(packet, -kReasonOutOfMemory, kActionNotCompleted);
					}
				}
			}
		}   // cEntry
	}   // if (packet && kft_connectionTree) {
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionInclude()
// ---------------------------------------------------------------------------------
// Search for packet in connection table
// return a pointer to the found entry (if any) as packet->connectionEntry
// return value: 0 found; -1 not found
int KFT_connectionInclude(KFT_packetData_t* packet)
{
	int returnValue = -1;	// not found
	KFT_connectionEntry_t *foundEntry = NULL;

	if (packet && kft_connectionTree) {
		ip_header_t* ipHeader;
		tcp_header_t* tcpHeader;
		KFT_connectionEntry_t compareEntry;
		u_int16_t fragmentOffset;
		
		ipHeader = (ip_header_t*)packet->datagram;
		tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
		fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;
		// look for local endpoint match based on direction
		if (packet->direction == kDirectionOutbound) {
			compareEntry.local.address	= ipHeader->srcAddress;
			compareEntry.local.protocol = ipHeader->protocol;
			compareEntry.local.pad = 0;
			// remote peer
			compareEntry.remote.address		= ipHeader->dstAddress;
			compareEntry.remote.protocol 	= ipHeader->protocol;
			compareEntry.remote.pad = 0;
			compareEntry.local.port	= 0;
			compareEntry.remote.port = 0;
			if ((ipHeader->protocol == IPPROTO_TCP) || (ipHeader->protocol == IPPROTO_UDP)) {
				if (fragmentOffset == 0) {
					compareEntry.local.port		= tcpHeader->srcPort;
					compareEntry.remote.port	= tcpHeader->dstPort;
				}
				else {
					// try to get port information from ip fragment table
					int result;
					KFT_fragmentEntry_t *foundFEntry = NULL;
					KFT_fragmentEntry_t cEntry;
					cEntry.fragment.srcAddress = ipHeader->srcAddress;
					cEntry.fragment.identification = ipHeader->identification;			
					result = KFT_fragmentFindEntry(&cEntry, &foundFEntry);
					if (result == 0) {
						compareEntry.local.port		= foundFEntry->srcPort;
						compareEntry.remote.port	= foundFEntry->dstPort;
					}
				}
			}
			else if (ipHeader->protocol == IPPROTO_ICMP) {
				icmp_header_t* icmpHeader;
				icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
				compareEntry.remote.port = (icmpHeader->type << 8) | icmpHeader->code;
			}
			returnValue = get_item_by_key(kft_connectionTree, (void *)&compareEntry, (void **)&foundEntry);
		}
		else {
			compareEntry.local.address		= ipHeader->dstAddress;
			compareEntry.local.protocol 	= ipHeader->protocol;
			compareEntry.local.pad = 0;
			// remote peer
			compareEntry.remote.address	 = ipHeader->srcAddress;
			compareEntry.remote.protocol = ipHeader->protocol;
			compareEntry.remote.pad = 0;
			compareEntry.local.port		= 0;
			compareEntry.remote.port	= 0;
			if ((ipHeader->protocol == IPPROTO_TCP) || (ipHeader->protocol == IPPROTO_UDP)) {
				if (fragmentOffset == 0) {
					compareEntry.local.port		= tcpHeader->dstPort;
					compareEntry.remote.port	= tcpHeader->srcPort;
				}
				else {
					// try to get port information from ip fragment table
					int result;
					KFT_fragmentEntry_t *foundFEntry = NULL;
					KFT_fragmentEntry_t cEntry;
					cEntry.fragment.srcAddress = ipHeader->srcAddress;
					cEntry.fragment.identification = ipHeader->identification;			
					result = KFT_fragmentFindEntry(&cEntry, &foundFEntry);
					if (result == 0) {
						compareEntry.local.port		= foundFEntry->dstPort;
						compareEntry.remote.port	= foundFEntry->srcPort;
					}
				}
			}
			else if (ipHeader->protocol == IPPROTO_ICMP) {
				icmp_header_t* icmpHeader;
				icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
				compareEntry.remote.port = (icmpHeader->type << 8) | icmpHeader->code;
			}
			returnValue = get_item_by_key(kft_connectionTree, (void *)&compareEntry, (void **)&foundEntry);
		}
		if (returnValue == 0) {
			// get current time
			struct timeval now_tv;
			#if IPK_NKE
			microtime(&now_tv);
			#else
			gettimeofday(&now_tv, NULL);
			#endif
			// reset entry last time
			foundEntry->lastTime = now_tv.tv_sec;
			if (packet->direction == kDirectionInbound) foundEntry->rxLastTime = now_tv.tv_sec;
			// return found entry in packet data
			packet->connectionEntry = foundEntry;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionState()
// ---------------------------------------------------------------------------------
// update connection state for entry based on packet and do Rate Limit processing
// input: packet->connectionEntry
int KFT_connectionState(KFT_packetData_t* packet)
{
	int returnValue = 0;
	int result;
	ip_header_t* ipHeader;
	KFT_connectionEntry_t* cEntry;
	KFT_filterEntry_t* filterEntry;
	// my and peer information
	KFT_connectionInfo_t*	myInfo;
	KFT_connectionInfo_t*	peerInfo;
	int32_t					ackIndex;
	
	do {
		cEntry = packet->connectionEntry;
		if (!cEntry) break;
		// capture frame header info for rate limiting and alternate routing
		if ((!cEntry->rxAttachIndex) && (packet->direction == kDirectionInbound)) {
			cEntry->rxAttachIndex = packet->myAttach->attachIndex;
			if (packet->ifHeaderLen <= kFHMaxLen) {
				// inbound
				u_int8_t* ha = (u_int8_t*)*packet->frame_ptr;
				cEntry->rxfhlen = packet->ifHeaderLen;
				memcpy(cEntry->rxfh, ha, cEntry->rxfhlen);
			}
		}
		if ((!cEntry->txfhlen) && (packet->direction == kDirectionOutbound) && (packet->ifHeaderLen)) {
			cEntry->txAttachIndex = packet->myAttach->attachIndex;
			if (packet->ifHeaderLen <= kFHMaxLen) {
				// outbound
				u_int8_t* ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
				cEntry->txfhlen = packet->ifHeaderLen;
				memcpy(cEntry->txfh, ha, cEntry->txfhlen);
			}
		}
		// traffic stats for connection
		int dataCount =  mbuf_pkthdr_len(*packet->mbuf_ptr) - packet->ipOffset;
		// - packet->ipHeaderLen - packet->transportHeaderLen;
		if (dataCount < 0) dataCount = 0;
		// my and peer information
		if (packet->direction == kDirectionInbound) {
			myInfo = &cEntry->rInfo;
			peerInfo = &cEntry->sInfo;
			cEntry->dataIn.count += dataCount;
		}
		else {
			myInfo = &cEntry->sInfo;
			peerInfo = &cEntry->rInfo;
			cEntry->dataOut.count += dataCount;
		}
		// -- rate limit stats for connection --
		ipHeader = (ip_header_t*)packet->datagram;
		// get time stamp
		struct timeval now_tv;
		#if IPK_NKE
			microtime(&now_tv);
		#else
			gettimeofday(&now_tv, NULL);
		#endif
		// calc segment length
		int segmentLength;
		segmentLength = ipHeader->totalLength - packet->ipHeaderLen - packet->transportHeaderLen;
		#if DEBUG_RATE_LIMITING_1
			if (packet->direction == kDirectionInbound)
				KFT_logText("\nKFT_connectionState --> INBOUND ", &segmentLength);
			else
				KFT_logText("\nKFT_connectionState OUTBOUND --> ", &segmentLength);
		#endif
		// update targetBytes based on rateLimitRule if any
			// receive side
		cEntry->rInfo.targetBytes = 0;
		if (cEntry->rInfo.rateLimitRule) {				
			filterEntry = KFT_filterEntryForIndex(cEntry->rInfo.rateLimitRule);
			if (filterEntry && (filterEntry->filterAction == kActionRateLimitIn)) {
				PROJECT_doRateLimit = 1;	// packet matched a rate limit rule
				// get rate limit
				int limit = filterEntry->rateLimit;
				// if last rule, reduce by reserve
				if (cEntry->rInfo.rateLimitRule == PROJECT_rReserveInfo.lastRule) {
					int i, index, reserve;
					KFT_filterEntry_t* reserveEntry;
					for (i=0; i<kMaxReserve; i++) {
						index = PROJECT_rReserveInfo.reserve[i];
						if (index == 0) break;	// no more reserve rules
						reserveEntry = KFT_filterEntryForIndex(index);
						// check how much of reserve limit was used
						// if more than 1/2, reserve = limit, else reserve = amount used
						int intervalBits = reserveEntry->intervalBytes * CONVERT_BPS;
						if (intervalBits >= reserveEntry->rateLimit/2) reserve = reserveEntry->rateLimit;
						else reserve = intervalBits;
						if (limit > reserve) limit -= reserve;
					}
				}
				// convert bps to Bps
				limit = limit/CONVERT_BPS;
				// adjust for number of active connections this interval
				int count = filterEntry->activeCountAdjusted;
				if (count) limit = limit/count;					
				// sanity check, limit must be at least one segment
				if (limit < 1460) limit = 1460;
				// save limit for future reference
				cEntry->rInfo.targetBytes = limit;
				// record interval traffic
				if (packet->direction == kDirectionInbound) {
					filterEntry->intervalBytes += ipHeader->totalLength;
				}
			}	// if (filterEntry && (filterEntry->filterAction == kActionRateLimitIn)) {
		}	// if (cEntry->rInfo.rateLimitRule) {
		
			// send side
		cEntry->sInfo.targetBytes = 0;
		if (cEntry->sInfo.rateLimitRule) {
			filterEntry = KFT_filterEntryForIndex(cEntry->sInfo.rateLimitRule);
			if (filterEntry && (filterEntry->filterAction == kActionRateLimitOut)) {
				PROJECT_doRateLimit = 1;	// packet matched a rate limit rule
				// get rate limit
				int limit = filterEntry->rateLimit;
				// if last rule, reduce by reserve
				if (cEntry->sInfo.rateLimitRule == PROJECT_sReserveInfo.lastRule) {
					int i, index, reserve;
					KFT_filterEntry_t* reserveEntry;
					for (i=0; i<kMaxReserve; i++) {
						index = PROJECT_sReserveInfo.reserve[i];
						if (index == 0) break;	// no more reserve rules
						reserveEntry = KFT_filterEntryForIndex(index);
						// check how much of reserve limit was used
						// if more than 1/2, reserve = limit, else reserve = amount used
						int intervalBits = reserveEntry->intervalBytes * CONVERT_BPS;
						if (intervalBits >= reserveEntry->rateLimit/2) reserve = reserveEntry->rateLimit;
						else reserve = intervalBits;
						if (limit > reserve) limit -= reserve;
					}
				}
				// convert bps to Bps
				limit = limit/CONVERT_BPS;
				// adjust for number of active connections this interval
				int count = filterEntry->activeCountAdjusted;
				if (count) limit = limit/count;					
				// sanity check, limit must be at least one segment
				if (limit < 1460) limit = 1460;
				// save limit for future reference
				cEntry->sInfo.targetBytes = limit;
				// record interval traffic
				if (packet->direction == kDirectionOutbound) {
					filterEntry->intervalBytes += ipHeader->totalLength;
				}
			}	// if (filterEntry && (filterEntry->filterAction == kActionRateLimitOut)) {
		}	// if (cEntry->sInfo.rateLimitRule) {
		
		// gather TCP state and rate limit info
		if (ipHeader->protocol == IPPROTO_TCP) {
			u_int32_t seqNext;
			tcp_header_t* tcpHeader;
			tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
			// SYN
			if (tcpHeader->code & kCodeSYN) {
				#if DEBUG_RATE_LIMITING_2
					if (packet->direction == kDirectionInbound)
						KFT_logText("KFT_connectionState SYN -->in ", NULL);
					else KFT_logText("KFT_connectionState SYN out--> ", NULL);
				#endif
				segmentLength++;
				if (packet->direction == kDirectionOutbound) cEntry->dupSynCount++;	// dead gateway?
				KFT_connectionSyn(packet);  // connection options
				// remember ISN to help in debugging
				myInfo->isn = tcpHeader->seqNumber;
				// initialize peer prevAckNum to my ISN (everything before ISN has been acked)
				// clear prevAckWin
				peerInfo->prevAckNum = myInfo->isn;
				peerInfo->prevAckWin = 0;
				// initialize seqNext to ISN + 1 (for SYN)
				myInfo->seqNext = tcpHeader->seqNumber+1;
				// reset target window so it is recomputed
				myInfo->targetWindow = 0;
			}
			else {
				cEntry->flags |= kConnectionFlagNonSyn;
				if (packet->direction == kDirectionOutbound) cEntry->dupSynCount = 0;	// reset for testing
				// if no ISN, jump in where we are
				if (myInfo->isn == 0) {
					#if DEBUG_RATE_LIMITING_2
						if (packet->direction == kDirectionInbound)
							KFT_logText("KFT_connectionState JUMP init -->in ", NULL);
						else KFT_logText("KFT_connectionState JUMP init out--> ", NULL);
					#endif
					// no previous packet seen in my direction
					// init myInfo
					myInfo->isn = tcpHeader->seqNumber;
					myInfo->seqNext = tcpHeader->seqNumber + segmentLength;
					if (tcpHeader->code & kCodeACK) {
						myInfo->prevAckNum = tcpHeader->ackNumber;
						myInfo->prevAckWin = tcpHeader->windowSize;		// window scale unknown
						myInfo->prevRWin = tcpHeader->windowSize;
					}
					// initialize peer prevAckNum to my ISN (everything before ISN has been acked)
					if (peerInfo->prevAckNum == 0) peerInfo->prevAckNum = myInfo->isn;
					// reset target window so it is recomputed
					myInfo->targetWindow = 0;
				}
			}
			// FIN
			if (tcpHeader->code & kCodeFIN) {
				segmentLength++;
				if (packet->direction == kDirectionInbound) {
					cEntry->flags |= kConnectionFlagFINPeer;
					cEntry->seqFINPeer = tcpHeader->seqNumber;
				}
				else {
					cEntry->flags |= kConnectionFlagFINLocal;
					cEntry->seqFINLocal = tcpHeader->seqNumber;
				}
			}
			// ACK
			if (tcpHeader->code & kCodeACK) {
				if (packet->direction == kDirectionInbound) {
					// FIN ACK (local has sent FIN and peer is acking it)
					if (cEntry->flags & kConnectionFlagFINLocal) {
						if ( SEQ_GT(tcpHeader->ackNumber,cEntry->seqFINLocal) )
							cEntry->flags |= kConnectionFlagFINAckPeer;
					}
				}
				else {
					// FIN ACK (peer has sent FIN and local is acking it)
					if (cEntry->flags & kConnectionFlagFINPeer) {
						if ( SEQ_GT(tcpHeader->ackNumber,cEntry->seqFINPeer) )
							cEntry->flags |= kConnectionFlagFINAckLocal;
					}
				}
			}
			
			// if this connection is not subject to rate limiting, we're done
			if ((peerInfo->rateLimitRule == 0) && (myInfo->rateLimitRule == 0)) break;
			
			// begin rate limit processing
			// ---------------------------
			// seqNext
			seqNext = tcpHeader->seqNumber + segmentLength;
			// record segment we are receiving
			// Is it a later segment than any we have seen before?
			if ( SEQ_GT(seqNext,myInfo->seqNext) ) {
				// update seqNext
				myInfo->seqNext = seqNext;
			}
			// ACK
			if (tcpHeader->code & kCodeACK) {
				// -- if peer is not rate limited, no need to withhold windowLimit --
				if (peerInfo->rateLimitRule == 0) break;	
					
				// Get target window we want to advertise
				// save with connection info so we only adjust once per second
					// try 10 window moves per second as a first pass
				if (myInfo->targetWindow == 0) {
					// find minWindow
					int32_t minWindow = peerInfo->mss;
					if (!minWindow) minWindow = 1460;
					// Use outbound bandwidth to set inbound window advertisement
					// Try 10 window moves per second as first guess.
					myInfo->targetWindow = peerInfo->targetBytes / WINDOW_MOVES_PER_SECOND;
						#if DEBUG_RATE_LIMITING_1
							KFT_logText("KFT_connectionState calculated target ", &myInfo->targetWindow);
						#endif
					// don't advertise less than MSS
					if (myInfo->targetWindow < minWindow) myInfo->targetWindow = minWindow;
				}
				int32_t targetWindow = myInfo->targetWindow;

				// get actual windowSize from Ack segment
					// window field in a SYN segment is not scaled
				int32_t myWindow;
				if (tcpHeader->code & kCodeSYN) myWindow = tcpHeader->windowSize;
				else myWindow = tcpHeader->windowSize << myInfo->scale;
				#if DEBUG_RATE_LIMITING_2
					if (packet->direction == kDirectionInbound) {
						if (peerInfo->isn) {
							ackIndex = (int)(tcpHeader->ackNumber - peerInfo->isn);
							KFT_logText("  I.B. ackIndex: ", &ackIndex);
						}
						KFT_logText("  I.B. windowSize: ", &myWindow);
					}
				#endif
				#if DEBUG_RATE_LIMITING_2
					if (packet->direction == kDirectionOutbound) {
						if (peerInfo->isn) {
							ackIndex = (int)(tcpHeader->ackNumber - peerInfo->isn);
							KFT_logText("  O.B. ackIndex: ", &ackIndex);
						}
						KFT_logText("  O.B. windowSize: ", &myWindow);
					}
				#endif

				// -- Decide how much to move the windowLimit
				//    based on target window, previously received, and previous move time.
				// Notice the receive window has a windowStart and a windowLimit.
				// Either or both can move!
				// The amount we ACK moves the window start.
				// The advertised window determines the windowLimit.
				//
				// ACKs are never actually withheld since we want to give
				//   TCP plenty of accurate round trip estimates.
				// What we need to control is when and how much the windowLimit moves.
				u_int32_t prevWindowLimit = myInfo->prevAckNum + myInfo->prevAckWin;
				int32_t ackDelta = 0;
				int32_t windowDelta = 0;
				
				// If previous moveWindow time has not expired?
				if ( timerisset(&myInfo->moveWindow_tv) &&
					 timerlt(&now_tv, &myInfo->moveWindow_tv)  ) {
					 // moveWindow time has not expired
						// do not move window
						// add to callback tree to move window at the right time
					// calculate target window to advertise
						// such that prevWindowLimit does not move
					targetWindow = (int)(prevWindowLimit - tcpHeader->ackNumber);
					if (targetWindow < 0) {
						// Notice the windowLimit has moved beyond previous value
						// most likely because the window Scale factor is wrong
						if (myInfo->uncountedMove == 0) myInfo->scale += 1;
						myInfo->uncountedMove += -targetWindow;
						#if DEBUG_RATE_LIMITING_2
							KFT_logText("KFT_connectionState - consistency check, target window: ", &targetWindow);
						#endif
						targetWindow = 0;
					}
					// update myInfo based on ACK we're sending
					if ( SEQ_GT(tcpHeader->ackNumber, myInfo->prevAckNum) ) {
						myInfo->prevAckNum = tcpHeader->ackNumber;
						myInfo->prevAckWin = targetWindow;
						myInfo->prevRWin = myWindow;
					}
					
					#if DEBUG_RATE_LIMITING_2
						KFT_logText("----  Delay moveWindow, windowSize ", &targetWindow);
						u_int32_t windowLimit = myInfo->prevAckNum + myInfo->prevAckWin;
						//int useableWindow = (int)(windowLimit - peerInfo->seqNext);
						if (peerInfo->isn) {
							u_int32_t windowLimitIndex = windowLimit - peerInfo->isn;
							if (packet->direction == kDirectionInbound)
								KFT_logText("---------------------- O.B. windowLimit ", &windowLimitIndex);
							else
								KFT_logText("---------------------- I.B. windowLimit ", &windowLimitIndex);
						}
					#endif
					// if already in callback tree for peer direction
					if (peerInfo->callbackPending) {
						// if move window time is before previous entry
						if ( timerlt(&myInfo->moveWindow_tv, &cEntry->callbackKey_tv) ) {
							// reset callback time and direction as needed
							result = KFT_callbackAddEntry(cEntry, packet->direction);
							if (result != 0) KFT_logText("KFT_connectionState - rate control interrupted, out of memory", NULL);
						}
						else myInfo->callbackPending = 1;
					}
					else {
						// if not already in callback tree for my direction
						if (myInfo->callbackPending == 0) {
							// add entry, callback direction is the direction of the ACK that is pending
							result = KFT_callbackAddEntry(cEntry, packet->direction);
							if (result != 0) KFT_logText("KFT_connectionState - rate control interrupted, out of memory", NULL);
						}
					}
				}	// previous move window time has not expired
				else {
					// -- Try to move window with this segment --
					// if connection entry is on callback tree for this direction,
					// remove since it expired and we'll be moving the window accordingly
					if ((myInfo->callbackPending) && (cEntry->callbackDirection == packet->direction)) {
						KFT_callbackRemoveEntry(cEntry);
						myInfo->callbackPending = 0;	// no longer pending
						#if DEBUG_RATE_LIMITING_2
							KFT_logText("KFT_connectionState cancel callback ", NULL);
						#endif
						// add back in peer direction if needed
						if (peerInfo->callbackPending) {
							result = KFT_callbackAddEntry(cEntry, (1-packet->direction));
							if (result != 0) KFT_logText("KFT_connectionState - rate control interrupted, out of memory", NULL);
						}
					}
					myInfo->callbackPending = 0;	// no longer pending

					// Always ACK whatever we got,
					// determine windowSize to advertise with this ACK
					if (myInfo->prevAckNum != 0) {
						// have previous ACK info
						// calculate how much are we moving the windowStart by?
						ackDelta = (int)(tcpHeader->ackNumber - myInfo->prevAckNum);
						ackIndex = (int)(tcpHeader->ackNumber - peerInfo->isn);
						
						// determine window to advertise based on targetWindow and prevWindowLimit
							// windowLimit >= prevWindowLimit to avoid window shrink
						if ( SEQ_LT(tcpHeader->ackNumber, prevWindowLimit) ) {
							int minWindow = (int)(prevWindowLimit - tcpHeader->ackNumber);
							if (targetWindow < minWindow) targetWindow = minWindow;
						}
							// if actual rwin received is less than target, adjust accordingly
						if (myWindow < targetWindow) targetWindow = myWindow;
						
						// update myInfo based on ACK we're sending
						if ( SEQ_GT(tcpHeader->ackNumber, myInfo->prevAckNum) ) {
							myInfo->prevAckNum = tcpHeader->ackNumber;
							myInfo->prevAckWin = targetWindow;
							myInfo->prevRWin = myWindow;
						}						
					}
					else {
						// if no previous ACK information, just use calculated target
						myInfo->prevAckNum = tcpHeader->ackNumber;
						myInfo->prevAckWin = targetWindow;
						myInfo->prevRWin = myWindow;
					}
					// calculate how much we are moving the windowLimit
					u_int32_t windowLimit = myInfo->prevAckNum + myInfo->prevAckWin; 
					windowDelta = (int)(windowLimit - prevWindowLimit);
					#if DEBUG_RATE_LIMITING_2
						KFT_logText("KFT_connectionState moving windowStart by: ", &ackDelta);
						KFT_logText("KFT_connectionState moving windowLimit by: ", &windowDelta);
						KFT_logText("KFT_connectionState - windowSize ", &targetWindow);
						//int useableWindow = (int)(windowLimit - peerInfo->seqNext);
						if (peerInfo->isn) {
							u_int32_t windowLimitIndex = windowLimit - peerInfo->isn;
							if (packet->direction == kDirectionInbound)
								KFT_logText("---------------------- O.B. windowLimit ", &windowLimitIndex);
							else
								KFT_logText("---------------------- I.B. windowLimit ", &windowLimitIndex);
						}
					#endif
				}	// Try to move window

				// if windowLimit moved
					// Limit transfer rate for subsequent data by calculating new move window time
					// timeInterval = transferAmount/rate
					// subsequent transferAmount is the advertised window
					// prev transfer amount is ackDelta since last windowLimit move - use previous amount to get actual rate
					// use send rate for receive side ACKs
				//double timeDelta = (double)ackDelta/(double)peerInfo->targetBytes;
				if (windowDelta > 2) {	// skip tiny SYN packets
					int32_t transferAmount;
					struct timeval delta_tv;
					// calculate transfer amount
					transferAmount = targetWindow + myInfo->uncountedMove;
					myInfo->uncountedMove = 0;
					if (myInfo->prevWindowStart) transferAmount = (int)(myInfo->prevAckNum - myInfo->prevWindowStart);
					myInfo->prevWindowStart = myInfo->prevAckNum;
					// calculate interval
					timerinterval(transferAmount, peerInfo->targetBytes, &delta_tv);
						// if move time is > 500ms, set to 500ms.
					if (timerms(&delta_tv) > 500) {
						delta_tv.tv_sec = 0;
						delta_tv.tv_usec = 500 * 1000;
						#if DEBUG_RATE_LIMITING_1
							KFT_logText("KFT_connectionState - set delta ms 500", NULL);
						#endif
					}
						// if move time is < 2 ms, set to 2 ms
						// if we could have ACKed more, we would have
					if (timerms(&delta_tv) < 2) {
						#if DEBUG_RATE_LIMITING_1
							KFT_logText("KFT_connectionState - set delta ms 2", NULL);
						#endif
						delta_tv.tv_sec = 0;
						delta_tv.tv_usec = 2 * 1000;
					}
					#if DEBUG_RATE_LIMITING_2
						int delta = timerms(&delta_tv);
						KFT_logText("KFT_connectionState - moveWindow_tv delta ms : ", &delta);
					#endif
					//myInfo->moveWindow_tv = ts + timeDelta;
					struct timeval when;
					timeradd(&now_tv, &delta_tv, &when);
					KFT_callbackSetMoveTimeForDirection(cEntry, &when, packet->direction);
				}	// if (ackDelta)
				
				// Don't add this connection to callback tree since ACK was allowed through.
				// The new moveWindowTime will determine whether to withhold subsequent ACKs.

				// adjust advertised window in packet
				if (targetWindow != myWindow) {
					u_int16_t old, new;
					int status;
					status = PROJECT_modifyReadyPacket(packet);
					tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
					old = tcpHeader->windowSize;
						// window field in a SYN segment is not scaled
					if (tcpHeader->code & kCodeSYN) tcpHeader->windowSize = targetWindow;
					else tcpHeader->windowSize = targetWindow >> myInfo->scale;
					new = tcpHeader->windowSize;
					if (status == 0) tcpHeader->checksum = hAdjustIpSum(tcpHeader->checksum, old, new);
				}
				// -- process callback tree to handle any connections that are ready and reschedule
				KFT_callbackAction();
				#if DEBUG_RATE_LIMITING_1
					ackIndex = (int)(myInfo->prevAckNum - peerInfo->isn);
					KFT_logText("KFT_connectionState allow ackIndex: ", &ackIndex);
				#endif
			}   // if (tcpHeader->code & kCodeACK) {
		}	//if (ipHeader->protocol == IPPROTO_TCP) {
		
		// gather UDP info
		else if (ipHeader->protocol == IPPROTO_UDP) {
			udp_header_t* udpHeader;
			udpHeader = (udp_header_t*)&packet->datagram[packet->ipHeaderLen];
			// if outbound via external interface and no response
			if ((packet->direction == kDirectionOutbound) &&
				(packet->myAttach->kftInterfaceEntry.externalOn) &&
				(cEntry->dataIn.count == 0) &&
				(cEntry->dataOut.count > dataCount)) {
				// to port 53 (DNS)
				if (udpHeader->dstPort == 53) {
					// notice DNS sends subsequent request from a different source port
					// repeating each request only once
					if (!cEntry->dupSynCount) cEntry->dupSynCount = 3;
					else cEntry->dupSynCount++;	// dead gateway?
				}
				// if expanding to other UDP services, do not redirect subnet broadcasts
			}
		}	// else if (ipHeader->protocol == IPPROTO_UDP) {
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionSyn()
// ---------------------------------------------------------------------------------
// update connection state for TCP SYN segment (examine TCP connection options)
// input: packet->connectionEntry
// called from KFT_connectionState() which checks input params
void KFT_connectionSyn(KFT_packetData_t* packet)
{
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	u_int8_t*	dp;
	int8_t		optionStart;
	u_int8_t	optionKind;
	int8_t		optionLen;
	u_int16_t	mss = 0;
	u_int16_t	clamp;
	u_int8_t	scale = 255;
	
	int status;
	status = PROJECT_modifyReadyPacket(packet);
	ipHeader = (ip_header_t*)packet->datagram;
	tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];

	dp = (u_int8_t*)tcpHeader;
	optionStart = 20;
	while (optionStart < packet->transportHeaderLen) {
		optionKind = dp[optionStart];
		switch (optionKind) {
			case kTCPOptionEnd:
				optionStart = packet->transportHeaderLen;	// done
				break;
			case kTCPOptionNop:
				optionStart += 1;
				break;
			case kTCPOptionMSS:
				optionLen = dp[optionStart+1];
				if (optionLen == 4) {
					mss = *(u_int16_t*)&dp[optionStart+2];
					mss = ntohs(mss);
					// perform MSS clamping if needed
					clamp = ifnet_mtu(packet->ifnet_ref) - 40;
					if ((clamp < mss) && (clamp > 400)) {
						// change option value and update tcp checksum
						if (status == 0) tcpHeader->checksum = hAdjustIpSum(tcpHeader->checksum, mss, clamp);
						clamp = htons(clamp);
						memcpy(&dp[optionStart+2], &clamp, 2);
					}
				}
				optionStart += optionLen;				
				break;
			case kTCPOptionScale:
				optionLen = dp[optionStart+1];
				if (optionLen == 3) {
					scale = dp[optionStart+2];
					if (packet->direction == kDirectionOutbound) {
						packet->connectionEntry->sInfo.scale = scale;
						#if DEBUG_RATE_LIMITING_2
							int temp = scale;
							KFT_logText("KFT_connectionSyn Send window scale: ", &temp);
						#endif
					}
					else {
						packet->connectionEntry->rInfo.scale = scale;
						#if DEBUG_RATE_LIMITING_2
							int temp = scale;
							KFT_logText("KFT_connectionSyn Receive window scale: ", &temp);
						#endif
					}
				}
				optionStart += optionLen;				
				break;
			default:
				optionLen = dp[optionStart+1];
				optionStart += optionLen;
				if (optionLen == 0) optionStart = packet->transportHeaderLen;	// defensive
				break;
		}	// end switch (optionKind)
	}
	// save MSS info for corresponding direction
	if (packet->direction == kDirectionOutbound) packet->connectionEntry->sInfo.mss = mss;
	else packet->connectionEntry->rInfo.mss = mss;
	// if no scale option reset scale to 0
	if (scale == 255) {
		packet->connectionEntry->sInfo.scale = 0;
		packet->connectionEntry->rInfo.scale = 0;
		#if DEBUG_RATE_LIMITING_2
			KFT_logText("KFT_connectionSyn clear window scale: ", NULL);
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	¥ KFT_sourceAwareActiveOpen
// ---------------------------------------------------------------------------------
// Look for cEntry with same remote address and passive open,
// if found, copy source aware route info
void KFT_sourceAwareActiveOpen(KFT_connectionEntry_t* cEntry)
{
	avl_node *cNode, *pNode, *sNode;
	KFT_connectionEntry_t *tEntry;
	u_int32_t remoteAddress = cEntry->remote.address;
	// find node
	unsigned long index;
	cNode = get_index_by_key(kft_connectionTree, (void *)cEntry, &index);
	if (cNode == NULL) return;
	// examine our neighbors
	pNode = get_predecessor(cNode);
	sNode = get_successor(cNode);	
	do {
		if (pNode != NULL) {
			tEntry = (KFT_connectionEntry_t *)pNode->key;
			pNode = get_predecessor(pNode);
			if ((tEntry != NULL) &&
				(tEntry->remote.address == remoteAddress) &&
				(tEntry->flags & kConnectionFlagPassiveOpen)) {
				// copy source aware routing info
				cEntry->rxAttachIndex = tEntry->rxAttachIndex;
				cEntry->rxfhlen = tEntry->rxfhlen;
				memcpy(cEntry->rxfh, tEntry->rxfh, cEntry->rxfhlen);
				// we're done
				break;
			}
		}
		if (sNode != NULL) {
			tEntry = (KFT_connectionEntry_t *)sNode->key;
			sNode = get_successor(sNode);
			if ((tEntry != NULL) &&
				(tEntry->remote.address == remoteAddress) &&
				(tEntry->flags & kConnectionFlagPassiveOpen)) {
				// copy source aware routing info
				cEntry->rxAttachIndex = tEntry->rxAttachIndex;
				cEntry->rxfhlen = tEntry->rxfhlen;
				memcpy(cEntry->rxfh, tEntry->rxfh, cEntry->rxfhlen);
				// we're done
				break;
			}
		}
	} while (pNode || sNode);
}

#pragma mark - rate limit callback tree -

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackSetMoveTimeForDirection
// ---------------------------------------------------------------------------------
// abstract setting the move window time so it can't conflict with previous callback entry
void KFT_callbackSetMoveTimeForDirection(KFT_connectionEntry_t* cEntry, struct timeval *tvp, int8_t direction)
{
	int result;
	KFT_connectionInfo_t* myInfo;
	KFT_connectionInfo_t* peerInfo;
	if (direction == kDirectionInbound) {
		myInfo = &cEntry->rInfo;
		peerInfo = &cEntry->sInfo;
	}
	else {
		myInfo = &cEntry->sInfo;
		peerInfo = &cEntry->rInfo;
	}
	// if connection entry is on callback tree for this direction,
	// remove it before setting moveWindowTime
	if (myInfo->callbackPending && (cEntry->callbackDirection == direction)) {
		KFT_callbackRemoveEntry(cEntry);
		myInfo->callbackPending = 0;	// no longer pending
		// add back in peer direction if needed
		if (peerInfo->callbackPending) {
			result = KFT_callbackAddEntry(cEntry, (1-direction));
			if (result != 0) KFT_logText("KFT_callbackSetMoveTimeForDirection - rate control interrupted, out of memory", NULL);
		}
	}
	timermove(&myInfo->moveWindow_tv, tvp);
}


// ---------------------------------------------------------------------------------
//	¥ KFT_callbackAddEntry
// ---------------------------------------------------------------------------------
// add entry to callback tree for direction
// - If cEntry is already on the list for this direction, we're done.
//   If we changed the moveWindowTime for this direction, entry would not be on list.
// - remove previous entry if any
// - set callbackKey from entry and callbackDirection based on direction parameter
// This ensures callbackKey is consistent with moveWindowTime for direction
// return: 0=success, -1 out of memory or other error
int KFT_callbackAddEntry(KFT_connectionEntry_t* cEntry, int8_t direction)
{
	int returnValue = -1;
	KFT_connectionInfo_t* myInfo;
	KFT_connectionInfo_t* peerInfo;
	do {
		// get myInfo
		if (direction == kDirectionInbound) {
			myInfo = &cEntry->rInfo;
			peerInfo = &cEntry->sInfo;
		}
		else {
			myInfo = &cEntry->sInfo;
			peerInfo = &cEntry->rInfo;
		}
		// already on list for peer direction?
		if (peerInfo->callbackPending) {
			// remove it
			KFT_callbackRemoveEntry(cEntry);
			// do not reset peer callbackPending
		}
		// set callbackKey and callbackDirection
		timermove(&cEntry->callbackKey_tv,&myInfo->moveWindow_tv);
		cEntry->callbackDirection = direction;
		// set unique ID in case time values match
		if (cEntry->callbackKeyUnique == 0) {
			callbackKeyUnique++;
			if (callbackKeyUnique == 0) callbackKeyUnique++;
			cEntry->callbackKeyUnique = callbackKeyUnique;
		}
		if (kft_callbackTree) returnValue = insert_by_key(kft_callbackTree, (void *)cEntry);
		if (returnValue == 0) {
			// success, entry added to list
			// set callbackPending
			myInfo->callbackPending = 1;
			#if 0	// DEBUG_RATE_LIMITING_1
				int dir = direction;
				KFT_logText("KFT_callbackAddEntry direction ", &dir);
			#endif
		}
	} while (0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackRemoveEntry
// ---------------------------------------------------------------------------------
int KFT_callbackRemoveEntry(KFT_connectionEntry_t* cEntry)
{
	int returnValue = 0;

	if (kft_callbackTree) returnValue = remove_by_key(kft_callbackTree, (void *)cEntry, KFT_callbackFree);
	// clear callbackPending from caller if entry has timed out
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackCount()
// ---------------------------------------------------------------------------------
int KFT_callbackCount()
{
	if (kft_callbackTree) return kft_callbackTree->length;
	else return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackSetTimeout
// ---------------------------------------------------------------------------------
// schedule time out if needed, return true if time out pending
int  KFT_callbackSetTimeout(int msec)
{
	// cancel pending timeout if any
	KFT_callbackUntimeout();
	// at least 2 ms
	if (msec < 2) msec = 2;
	// no more than 1 sec
	if (msec > 999) msec = 999;
	#if TIGER
		struct timespec ts;
		ts.tv_sec = 0;
		ts.tv_nsec = msec * 1000000;
		#if IPK_NKE
			bsd_timeout(KFT_callbackTimeout, (void *)0, &ts);
		#else
			void* ptr;
			ptr = KFT_callbackTimeout;	// avoid not used warning
		#endif
	#else
		#if IPK_NKE
			extern int hz;	// number of clock ticks that occur in one second
			int ticks = hz*msec/1000;
			timeout(KFT_callbackTimeout, (void *)0, ticks);
		#else
			void* ptr;
			ptr = KFT_callbackTimeout;	// avoid not used warning
		#endif
	#endif
	timerPending = 1;

	return timerPending;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackUntimeout
// ---------------------------------------------------------------------------------
void KFT_callbackUntimeout()
{
#if IPK_NKE
	if (timerPending) {
		#if TIGER
			bsd_untimeout(KFT_callbackTimeout, (void *)0);
		#else
			untimeout(KFT_callbackTimeout, (void *)0);
		#endif
		timerPending = 0;
	}
#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackTimeout
// ---------------------------------------------------------------------------------
// deferred ACK has timed out
static void KFT_callbackTimeout(void *cookie)
{
#if IPK_NKE
		PROJECT_lock();
#endif
		// timer is no longer pending
		timerPending = 0;
		#if DEBUG_RATE_LIMITING_1
			KFT_logText("KFT_callbackTimeout", NULL);
		#endif
		// is firewall disabled?
		if ((PROJECT_timerRefCount == 0) && ( KFT_callbackCount() )) {
			// clear the callback table and don't reschedule
			if (kft_callbackTree) free_avl_tree(kft_callbackTree, KFT_callbackFree);
			kft_callbackTree = NULL;
			// allocate new table
			kft_callbackTree = new_avl_tree(KFT_callbackCompare, NULL);
		}
		else {
			KFT_callbackAction();
		}
#if IPK_NKE
		PROJECT_unlock();
#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackAction
// ---------------------------------------------------------------------------------
// examine callbackTree to process any deferred ACKs that are ready
// Called from KFT_callbackTimeout when deferred ACK has timed out
// or from KFT_connectionState when any ACK segment is processed
//   or added to tree and needs to be scheduled.
// Return the last connection entry we processed for testing
KFT_connectionEntry_t* KFT_callbackAction()
{
	KFT_connectionEntry_t* cEntry = NULL;
	KFT_connectionInfo_t*	myInfo;
	KFT_connectionInfo_t*	peerInfo;
	int8_t direction;
	int i, limit;
	int result;
	
	// get time stamp
	struct timeval now_tv;
	#if IPK_NKE
		microtime(&now_tv);
	#else
		gettimeofday(&now_tv, NULL);
	#endif

	limit = KFT_callbackCount();	// defensive to ensure we get out
	limit = limit * 2;				// might need to process in each direction
	for (i=0; i<limit; i++) {		
		// get first entry from list
		result = get_item_by_index(kft_callbackTree, 0, (void **)&cEntry);
		// list is empty, exit loop
		if (result != 0) break;
		// if moveWindow_tv has not expired, exit loop
		if (timerlt(&now_tv, &cEntry->callbackKey_tv)) break;
		// Entry has timed out
		// get my and peer info
			// callback direction is the direction of the ACK that is pending
			// we ACK segments from the peer list.
		direction = cEntry->callbackDirection;
		if (direction == kDirectionInbound) {
			myInfo = &cEntry->rInfo;
			peerInfo = &cEntry->sInfo;
		}
		else {
			myInfo = &cEntry->sInfo;
			peerInfo = &cEntry->rInfo;
		}
		// remove entry from list
		KFT_callbackRemoveEntry(cEntry);
		myInfo->callbackPending = 0;	// no longer pending
		// check connection moveWindow_tv (defensive)
		if ( !timereq(&myInfo->moveWindow_tv, &cEntry->callbackKey_tv) ) {
			KFT_logText("\nKFT_callbackAction consistency check, key does not match moveWindow_tv ", NULL);
		}
		
		// move peer window by sending ACK in callback direction
		KFT_callbackMoveWindow(cEntry, direction);
		
		// Don't put back on list since we always ACK whatever we have.
		// The new moveWindowTime will determine whether to withhold subsequent window moves.

		if (peerInfo->callbackPending) {
			// has peer moveWindow time expired?
			if (timerlt(&now_tv, &peerInfo->moveWindow_tv)) {
				// no, add back in peer direction
				result = KFT_callbackAddEntry(cEntry, (1-direction));
				if (result != 0) KFT_logText("KFT_callbackAction - rate control interrupted, out of memory", NULL);
			}
			else {
				// yes, process moveWindow callback
				KFT_callbackMoveWindow(cEntry, (1-direction));
				peerInfo->callbackPending = 0;	// no longer pending
			}
		}
	}	// for (i=0; i<limit; i++) {
	
	// get first entry from list
	result = get_item_by_index(kft_callbackTree, 0, (void **)&cEntry);
	// list is not empty
	if (result == 0) {
		// reschedule timer for first remaining entry
		struct timeval delta_tv;
		timersub(&cEntry->callbackKey_tv, &now_tv, &delta_tv);
		int msec = timerms(&delta_tv);
		if (msec < 0) {
			KFT_logText("KFT_callbackAction consistency check, next callback already expired ", &msec);
		}
		// if more than 5 callbacks pending
		if (KFT_callbackCount() >= 5) {
			// set timer for at least 20 ms from now
			if (msec < 20) msec = 20;
		}
		// set timeout, will cancel previous if any
		KFT_callbackSetTimeout(msec);
		#if DEBUG_RATE_LIMITING_1
			KFT_logText("KFT_callbackAction schedule callback ms: ", &msec);
		#endif
	}
	#if DEBUG_RATE_LIMITING_1
	else {
		KFT_logText("KFT_callbackAction callback not rescheduled ", NULL);
	}
	#endif
	
	return cEntry;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackMoveWindow()
// ---------------------------------------------------------------------------------
// Send ACK in direction specified to move peer window
int KFT_callbackMoveWindow(KFT_connectionEntry_t* cEntry, int8_t direction)
{
	int returnValue = 0;
	// my and peer information
	KFT_connectionInfo_t*	myInfo;
	KFT_connectionInfo_t*	peerInfo;
	
	do {		
		// make sure interface is still attached
		#if TIGER
			if (PROJECT_attach[cEntry->rxAttachIndex].ifFilterRef == 0) break;
		#else
			if (PROJECT_attach[cEntry->rxAttachIndex].filterID == 0) break;
		#endif
		// get my and peer information
		if (direction == kDirectionInbound) {
			myInfo = &cEntry->rInfo;
			peerInfo = &cEntry->sInfo;
		}
		else {
			myInfo = &cEntry->sInfo;
			peerInfo = &cEntry->rInfo;
		}
		
		// calculate targetWindow to advertise
		// save with connection info so we only adjust once per second
			// try 10 window moves per second as a first pass
		if (myInfo->targetWindow == 0) {
			// find minWindow
			int32_t minWindow = peerInfo->mss;
			if (!minWindow) minWindow = 1460;
			// Use outbound bandwidth to set inbound window advertisement
			// Try 10 window moves per second as first guess.
			myInfo->targetWindow = peerInfo->targetBytes / WINDOW_MOVES_PER_SECOND;
				#if DEBUG_RATE_LIMITING_1
					KFT_logText("KFT_callbackMoveWindow calculated target ", &myInfo->targetWindow);
				#endif
			// don't advertise less than MSS
			if (myInfo->targetWindow < minWindow) myInfo->targetWindow = minWindow;
		}
		int32_t targetWindow = myInfo->targetWindow;

		// Decide how much to move the window
		// based on target window and segments received from peer
		// Notice the receive window has a windowStart and a windowLimit.
		// Either or both can move!
		// The amount we ACK moves the window start.
		// The advertised window determines the windowLimit
		//
		// ACKs are never actually withheld since we want to give
		//   TCP plenty of accurate round trip estimates.
		// What we need to control is when and how much the windowLimit moves.
		u_int32_t prevWindowLimit = myInfo->prevAckNum + myInfo->prevAckWin;
			
		// Since ACKs are never withheld, we're acking the same segment
		// we did previously but changing the windowSize.
		// The windowStart does not move.
		// In this particular case, if we are moving the windowLimit,
		// we don't want it to move again until the corresponding interval
		// has elapsed.
		
		// determine window to advertise based on targetWindow and prevWindowLimit
			// windowLimit >= prevWindowLimit to avoid window shrink
		if ( SEQ_LT(myInfo->prevAckNum, prevWindowLimit) ) {
			int minWindow = (int)(prevWindowLimit - myInfo->prevAckNum);
			if (targetWindow < minWindow) targetWindow = minWindow;
		}
			// if actual rwin received is less than target, adjust accordingly
		if (myInfo->prevRWin < targetWindow) targetWindow = myInfo->prevRWin;

		#if DEBUG_RATE_LIMITING_1
			KFT_logText("KFT_callbackMoveWindow - peer rate: ", &peerInfo->targetBytes);
			KFT_logText("KFT_callbackMoveWindow - advertised window: ", &targetWindow);
		#endif
		
		// record the window we advertise with this ACK
		myInfo->prevAckWin = targetWindow;

		// calculate how much we are moving the windowLimit
		u_int32_t windowLimit = myInfo->prevAckNum + myInfo->prevAckWin; 
		int windowDelta = (int)(windowLimit - prevWindowLimit);
		#if DEBUG_RATE_LIMITING_2
			if (direction == kDirectionInbound) {
				KFT_logText("KFT_callbackMoveWindow moving O.B. windowLimit by: ", &windowDelta);
				int32_t ackIndex = myInfo->prevAckNum - peerInfo->isn;
				KFT_logText("  I.B. ackIndex ", &ackIndex);
				KFT_logText("  I.B. windowSize ", &targetWindow);
				u_int32_t windowLimitIndex = windowLimit - peerInfo->isn;
				KFT_logText("---------------------- O.B. windowLimit ", &windowLimitIndex);
			}
			else {
				KFT_logText("KFT_callbackMoveWindow moving I.B. windowLimit by: ", &windowDelta);
				int32_t ackIndex = myInfo->prevAckNum - peerInfo->isn;
				KFT_logText("  O.B. ackIndex ", &ackIndex);
				KFT_logText("  O.B. windowSize ", &targetWindow);
				u_int32_t windowLimitIndex = windowLimit - peerInfo->isn;
				KFT_logText("---------------------- I.B. windowLimit ", &windowLimitIndex);
			}
		#endif
		
		// if windowLimit moved
			// Limit transfer rate for subsequent data by calculating new move window time
			// timeInterval = transferAmount/rate
			// subsequent transferAmount is the advertised window (prev amount would be ackDelta)
			// use send rate for receive side ACKs
		if (windowDelta > 0) {
			int32_t transferAmount;
			struct timeval delta_tv;
			// calculate transfer amount
			transferAmount = targetWindow + myInfo->uncountedMove;
			myInfo->uncountedMove = 0;
			if (myInfo->prevWindowStart) transferAmount = (int)(myInfo->prevAckNum - myInfo->prevWindowStart);
			myInfo->prevWindowStart = myInfo->prevAckNum;
			// calculate interval
			timerinterval(transferAmount, peerInfo->targetBytes, &delta_tv);
				// if move time is > 500ms, set to 500ms.
			if (timerms(&delta_tv) > 500) {
				delta_tv.tv_sec = 0;
				delta_tv.tv_usec = 500 * 1000;
			}
				// if move time is < 2 ms, set to 2 ms
				// if we could have ACKed more, we would have
			if (timerms(&delta_tv) < 2) {
				delta_tv.tv_sec = 0;
				delta_tv.tv_usec = 2 * 1000;
			}
			#if DEBUG_RATE_LIMITING_2
				int delta = timerms(&delta_tv);
				KFT_logText("KFT_callbackMoveWindow - moveWindow_tv delta ms : ", &delta);
			#endif
			// get time stamp
			struct timeval now_tv;
			#if IPK_NKE
				microtime(&now_tv);
			#else
				gettimeofday(&now_tv, NULL);
			#endif
			//myInfo->moveWindow_tv = ts + timeDelta;
			struct timeval when;
			timeradd(&now_tv, &delta_tv, &when);
			KFT_callbackSetMoveTimeForDirection(cEntry, &when, direction);

			// send Ack
			KFT_callbackSendACK(cEntry, direction);
		}
		#if DEBUG_RATE_LIMITING_2
		else {
			KFT_logText("KFT_callbackMoveWindow - window limit did not move. ", NULL);
		}
		#endif
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackSendACK()
// ---------------------------------------------------------------------------------
// Send TCP ACK segment for connection
int KFT_callbackSendACK(KFT_connectionEntry_t* cEntry, int8_t direction)
{
	int returnValue = 0;
	u_int8_t rejectBuffer[80];
	int ipStart;	// start of IP datagram in reject buffer
	attach_t* myAttach;
	u_char interfaceType = 0;
	u_char headerLength = 0;
	KFT_connectionInfo_t*	myInfo;

	if (!cEntry->rxAttachIndex) return -1;
	myAttach = &PROJECT_attach[cEntry->rxAttachIndex];
	// hardware info
	if (myAttach->ifnet_ref) {	// defensive
		interfaceType = ifnet_type(myAttach->ifnet_ref);
		headerLength = ifnet_hdrlen(myAttach->ifnet_ref);
	}
	// get my information
	if (direction == kDirectionInbound) {
		myInfo = &cEntry->rInfo;
	}
	else {
		myInfo = &cEntry->sInfo;
	}

	// build TCP ACK response
#if IPK_NKE
	mbuf_t mbuf_ref;
#endif
	ip_header_t* ipHeader2;
	tcp_header_t* tcpHeader2;
	u_int8_t* dp;
	tcp_pseudo_t tcpPseudo;
	int totalLength;

	// build IP header from connection info
	ipStart = headerLength;   // leave room for interface header
	ipHeader2 = (ip_header_t*)&rejectBuffer[ipStart];
	ipHeader2->hlen = 0x45;
	ipHeader2->tos = 0;
	totalLength = 40;
	ipHeader2->totalLength = totalLength;
	ipHeader2->identification = 17;
	ipHeader2->fragmentOffset = IP_DF;	// 0 with Don't fragment flag
	ipHeader2->ttl = 64;
	ipHeader2->protocol = IPPROTO_TCP;
	ipHeader2->checksum = 0;
	if (direction == kDirectionInbound) {
		ipHeader2->srcAddress = cEntry->remote.address;
		ipHeader2->dstAddress = cEntry->local.address;
	}
	else {	// outbound
		ipHeader2->srcAddress = cEntry->local.address;
		ipHeader2->dstAddress = cEntry->remote.address;
	}

	// build TCP header from connection info
	tcpHeader2 = (tcp_header_t*)&rejectBuffer[ipStart+20];
	if (direction == kDirectionInbound) {
		tcpHeader2->srcPort = cEntry->remote.port;
		tcpHeader2->dstPort = cEntry->local.port;
		tcpHeader2->seqNumber = cEntry->rInfo.seqNext;
	}
	else {	// outbound
		tcpHeader2->srcPort = cEntry->local.port;
		tcpHeader2->dstPort = cEntry->remote.port;
		tcpHeader2->seqNumber = cEntry->sInfo.seqNext;
	}	
	tcpHeader2->ackNumber = myInfo->prevAckNum;
	tcpHeader2->hlen = 0x50;
	tcpHeader2->code = kCodeACK;
	int scale;
	if (direction == kDirectionInbound) scale = cEntry->rInfo.scale;
	else  scale = cEntry->sInfo.scale;
	tcpHeader2->windowSize = myInfo->prevAckWin >> scale;
	tcpHeader2->checksum = 0;
	tcpHeader2->urgentPointer = 0;
	// ------------------
	// byte swap boundary
	// ------------------
	KFT_htonDgram((u_int8_t*)ipHeader2, kOptionNone);
	
	// tcp pseudo header for checksum calculation
	tcpPseudo.srcAddress = ipHeader2->srcAddress;
	tcpPseudo.dstAddress = ipHeader2->dstAddress;
	tcpPseudo.zero = 0;
	tcpPseudo.protocol = IPPROTO_TCP;
	tcpPseudo.length = htons(20);
	
	// compute checksums
	u_int16_t ipChecksum = IpSum((u_int16_t*)&rejectBuffer[ipStart], (u_int16_t*)&rejectBuffer[ipStart+20]);
	ipHeader2->checksum = htons(ipChecksum);
		// pseudo header
	dp = (u_int8_t*)&tcpPseudo;
	u_int16_t tcpChecksum = IpSum((u_int16_t*)&dp[0], (u_int16_t*)&dp[12]);
		// pad segment to even 16-bit length (if needed)
	int tcpChecksumLength = 20;
	if (0 % 2) {
		rejectBuffer[ipStart + 40 + 0] = 0;
		tcpChecksumLength += 1;
	}
		// add TCP segment checksum
	tcpChecksum = AddToSum(tcpChecksum, (u_int16_t*)&rejectBuffer[ipStart+20],
		(u_int16_t*)&rejectBuffer[ipStart+20+tcpChecksumLength]);
	tcpHeader2->checksum = htons(tcpChecksum);

#if IPK_NKE
	if (myAttach->ifnet_ref) {
		// build mbuf chain and send it
		char *frame_header = NULL;
		// inject Ack as input
		if (direction == kDirectionInbound) {
			// try to recover frame_ptr
			if (cEntry->rxfhlen) {
				memcpy(&rejectBuffer[0], cEntry->rxfh, cEntry->rxfhlen);
			}
			#if TIGER
				//errno_t status = mbuf_getpacket(MBUF_DONTWAIT, &mbuf_ref);	// use a cluster
				errno_t status = mbuf_allocpacket(MBUF_DONTWAIT, totalLength, NULL, &mbuf_ref);
				if (status == 0) {
					// try to put frame_header in mbuf leading space
					if (mbuf_leadingspace(mbuf_ref) >= headerLength) {
						frame_header = mbuf_datastart(mbuf_ref);
						memcpy(frame_header, &rejectBuffer[0], ipStart);
						memcpy(mbuf_data(mbuf_ref), &rejectBuffer[ipStart], totalLength);
						mbuf_setlen(mbuf_ref, totalLength);
					}
					else {
						frame_header = mbuf_data(mbuf_ref);
						memcpy(mbuf_data(mbuf_ref), &rejectBuffer[0], (int)totalLength+ipStart);
						//memcpy(mbuf_data(mbuf_ref), &rejectBuffer[ipStart], (int)totalLength);
						//mbuf_setlen(mbuf_ref, totalLength);
						mbuf_setdata(mbuf_ref, &frame_header[headerLength], totalLength);
					}
					// set packet length
					mbuf_pkthdr_setlen(mbuf_ref, totalLength);
					// set frame header in mbuf
					mbuf_pkthdr_setheader(mbuf_ref, frame_header);
					// set receive if
					mbuf_pkthdr_setrcvif(mbuf_ref, myAttach->ifnet_ref);
				}
				else mbuf_ref = NULL;
			#else
				mbuf_ref = m_devget(&rejectBuffer[0], totalLength+ipStart, 0, myAttach->ifnet_ref, NULL);
				if (mbuf_ref) {
					frame_header = mbuf_ref->m_data;
					mbuf_ref->m_data = &frame_header[headerLength];
					mbuf_ref->m_len = totalLength;
					mbuf_ref->m_pkthdr.len = totalLength;
				}
			#endif
			if (mbuf_ref) {			
				int result;
	// --------------
	// <<< Packet Out
	// --------------
				// tag mbuf so we don't try to process it again
				if (PROJECT_mtag(mbuf_ref, TAG_IN) == 0) {
					result = PROJECT_inject_input(mbuf_ref, 0, myAttach->attachIndex, myAttach->ifnet_ref, frame_header, kNetworkByteOrder);
					#if 0
						PROJECT_unlock();	// release lock during inject
						#if TIGER
							result = ifnet_input(myAttach->ifnet_ref, mbuf_ref, NULL);
						#else
							result = dlil_inject_if_input(mbuf_ref, frame_header, myAttach->filterID);
						#endif
						PROJECT_lock();
					#endif
				}
				else mbuf_freem(mbuf_ref);
				mbuf_ref = NULL;	// mbuf was consumed
			}
		}
		else {
			// inject ack as output
			// setup frame header
			if (cEntry->txfhlen) {
				memcpy(&rejectBuffer[0], cEntry->txfh, cEntry->txfhlen);
			}
			#if TIGER
				errno_t status = mbuf_getpacket(MBUF_DONTWAIT, &mbuf_ref);
				if (status == 0) {
					frame_header = mbuf_data(mbuf_ref);
					memcpy(mbuf_data(mbuf_ref), &rejectBuffer[0], (int)totalLength+ipStart);
					mbuf_setlen(mbuf_ref, totalLength+ipStart);
					mbuf_pkthdr_setlen(mbuf_ref, totalLength+ipStart);
					// set frame header in mbuf
					mbuf_pkthdr_setheader(mbuf_ref, frame_header);
				}
				else mbuf_ref = NULL;
			#else
				mbuf_ref = m_devget(&rejectBuffer[0], totalLength+ipStart, 0, myAttach->ifnet_ref, NULL);
			#endif
			// inject packet
			if (mbuf_ref) {			
				int result;
	// --------------
	// <<< Packet Out
	// --------------
				// tag mbuf so we don't try to process it again
				if (PROJECT_mtag(mbuf_ref, TAG_OUT) == 0) {
					result = PROJECT_inject_output(mbuf_ref, ipStart, myAttach->attachIndex, myAttach->ifnet_ref, kHostByteOrder);
					#if 0
						PROJECT_unlock();	// release lock during inject
						#if TIGER
							result = ifnet_output_raw(myAttach->ifnet_ref, AF_INET, mbuf_ref);
						#else
							result = dlil_inject_if_output(mbuf_ref, myAttach->filterID);
						#endif
						PROJECT_lock();
					#endif
				}
				else mbuf_freem(mbuf_ref);
				mbuf_ref = NULL;	// mbuf was consumed
			}
		}
	}	// if (myAttach->ifnet_ref) {
#endif
	return returnValue;
}

#pragma mark -- age --
// ---------------------------------------------------------------------------------
//	¥ KFT_connectionAge()
// ---------------------------------------------------------------------------------
// Age entries in connection table
// Called from ipk_timeout or KFT_connectionAdd which is thread protected.
// Send traffic report if trafficDiscovery enabled
// Return number of entries aged out
// Pass in if called from timer for periodic traffic reports
int KFT_connectionAge(int fromTimer)
{
	int returnValue = 0;
	KFT_connectionIterArg_t arg;
	int i;

	if (kft_connectionTree) {
		// get current time
		struct timeval now_tv;
		#if IPK_NKE
		microtime(&now_tv);
		#else
		gettimeofday(&now_tv, NULL);
		#endif
		timermove(&arg.now_tv, &now_tv);
		arg.currentTime = now_tv.tv_sec;
		arg.lastTime = now_tv.tv_sec;
		arg.entry = NULL;
		arg.ageOutNum = 0;
		arg.failoverRequest1 = 0;
		arg.failoverRequest2 = 0;
		arg.fromTimer = fromTimer;
		arg.tdEntryCount = 0;
		
		if (arg.fromTimer) {
			// update stats for attached interfaces
			for (i=1; i<=kMaxAttach; i++) {
				if (PROJECT_attach[i].ifnet_ref == NULL) continue;
				// copy current value
				PROJECT_attach[i].sendStamp = PROJECT_attach[i].sendCount;
				PROJECT_attach[i].receiveStamp = PROJECT_attach[i].receiveCount;
				// reset counter
				PROJECT_attach[i].sendCount = 0;
				PROJECT_attach[i].receiveCount = 0;
				// failover stats
				PROJECT_attach[i].activeConnections = 0;
				PROJECT_attach[i].failedConnections = 0;

				if (PROJECT_flags & kFlag_trafficDiscovery) {
					// send attachInfo if any
					if (PROJECT_attach[i].sendStamp || PROJECT_attach[i].receiveStamp) {
						KFT_trafficEntry_t tEntry;
						bzero(&tEntry,sizeof(KFT_trafficEntry_t));
						tEntry.attachInfo = 1;
						tEntry.dataIn.delta = PROJECT_attach[i].receiveStamp;
						tEntry.dataOut.delta = PROJECT_attach[i].sendStamp;
						// trafficDiscoveryTime, bsdName
						tEntry.trafficDiscoveryTime = arg.currentTime;
						memcpy(tEntry.bsdName, PROJECT_attach[i].kftInterfaceEntry.bsdName, kBSDNameLength);
						// append report
						KFT_trafficReport(&tEntry, &arg);
						arg.tdEntryCount++;
					}
				}
			}	// for (i=1; i<=kMaxAttach; i++) {
		}	// if (arg.fromTimer) {
		// iterate over table
		iterate_inorder(kft_connectionTree, KFT_connectionEntryAge, &arg);
		returnValue = arg.ageOutNum;
		// remove entries from delete list
		KFT_connectionEntry_t* entry;
		while ((entry = SLIST_FIRST(&connection_deleteList)) != NULL) {
			SLIST_REMOVE_HEAD(&connection_deleteList, entries);
			KFT_connectionEntryRemove(entry);
		}
		// if "table is full", release the oldest entry
		if (KFT_connectionCount() > KFT_connectionTableSize) {
			if (arg.entry) {
				KFT_connectionEntryRemove(arg.entry);
				returnValue += 1;
			}
		}
		// update UI
		if (arg.fromTimer && arg.tdEntryCount) KFT_trafficSendUpdates(kFlag_end);
		KFT_connectionSendUpdates();
		KFT_routeUpdate();
	}
	// age entries in subordinate ip fragment table if any
	KFT_fragmentAge();
#if DEBUG_RATE_LIMITING_1
	int count = KFT_connectionCount();
	KFT_logText("KFT_connectionAge count ", &count);
	KFT_logText("KFT_connectionAge removed ", &returnValue);
#endif
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionEntryAge()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Called periodically for each entry in the connection table to age it.
// Check age against limits and age out by adding to free list.
// Remember oldest entry we've seen so far.
int KFT_connectionEntryAge(void * key, void * iter_arg)
{
	int returnValue = 0;
	KFT_connectionEntry_t* cEntry;
	KFT_connectionIterArg_t* arg;
	long age;
	long limit;

	cEntry = (KFT_connectionEntry_t *)key;
	arg = (KFT_connectionIterArg_t *)iter_arg;
	// check age of this entry
	age = arg->currentTime - cEntry->lastTime;
	// calculate age limit based on entry
	switch (cEntry->local.protocol) {
		case IPPROTO_TCP:
			if ((cEntry->flags & kConnectionFlagFINAckLocal) && (cEntry->flags & kConnectionFlagFINAckPeer)) {
				// FIN ACK both ways, connection is fully closed
				limit = 1;
			}
			else if (!(cEntry->flags & kConnectionFlagFINLocal) &&
				!(cEntry->flags & kConnectionFlagFINPeer)) {
				// TCP and not half closed
				if (!(cEntry->flags & kConnectionFlagNonSyn)) {
					// we haven't seen a non Syn
					limit = 120;	// 2 minutes (since last retry)
				}
				else {
					limit = 86400;	// one day
					if (KFT_connectionCount() > 100)	limit = 1800;	// 30 minutes
				}
			}
			else {
				// TCP half or full close
				limit = 120;	// 2 minutes
			}
			break;
		case IPPROTO_UDP:
			if (cEntry->local.port == 500) limit = 1800;
			else if ((cEntry->remote.port == 53) || (cEntry->local.port == 53))
				limit = 20;  // DNS querry (20 sec since last retry)
			else limit = 120;	// 2 minutes
			break;
		case IPPROTO_ICMP:
			limit = 60;		// 1 minute
			break;
		case IPPROTO_GRE:
		case IPPROTO_ESP:	// IPSec
			limit = 1800;	// 30 minutes
			break;
		default:
			limit = 60;		// 1 minute (since last retry)
			break;
	}
	
	// age out?
	if (age > limit) {
		// remove it
		//if (arg->ageOutNum < arg->ageOutMax) arg->ageOutList[arg->ageOutNum++] = cEntry;
		SLIST_INSERT_HEAD(&connection_deleteList, cEntry, entries);
		arg->ageOutNum++;
	}
	else {
		// did not age out
		// update traffic stats
		cEntry->dataIn.delta = cEntry->dataIn.count - cEntry->dataIn.previous;
		cEntry->dataIn.previous = cEntry->dataIn.count;
		cEntry->dataOut.delta = cEntry->dataOut.count - cEntry->dataOut.previous;
		cEntry->dataOut.previous = cEntry->dataOut.count;
		// count active connections for rate limit rule if any
		if (cEntry->rInfo.rateLimitRule) {
			KFT_filterEntry_t* filterEntry = KFT_filterEntryForIndex(cEntry->rInfo.rateLimitRule);
			if (filterEntry && (filterEntry->filterAction == kActionRateLimitIn)) {
				if ((arg->currentTime - filterEntry->lastTime) <= 1) {
					// get previous count and limit to decide whether connection is active
					if (filterEntry->activeCountAdjusted > 0) {
						// adjust for number of active connections this interval
						int connectionLimit = (filterEntry->rateLimit / CONVERT_BPS) / filterEntry->activeCountAdjusted;
						// test if active
						if (cEntry->dataIn.delta > connectionLimit/4) filterEntry->activeCount++;
					}
					else if (cEntry->dataIn.delta > 1000) filterEntry->activeCount++;
				}	// recently updated
			}	// found rateLimitRule
		}
		if (cEntry->sInfo.rateLimitRule) {
			KFT_filterEntry_t* filterEntry = KFT_filterEntryForIndex(cEntry->sInfo.rateLimitRule);
			if (filterEntry && (filterEntry->filterAction == kActionRateLimitOut)) {
				if ((arg->currentTime - filterEntry->lastTime) <= 1) {
					// get previous count and limit to decide whether connection is active
					if (filterEntry->activeCountAdjusted > 0) {
						// adjust for number of active connections this interval
						int connectionLimit = (filterEntry->rateLimit / CONVERT_BPS) / filterEntry->activeCountAdjusted;
						// test if active
						if (cEntry->dataOut.delta > connectionLimit/4) filterEntry->activeCount++;
					}
					else if (cEntry->dataOut.delta > 1000) filterEntry->activeCount++;
				}	// recently updated
			}	// found rateLimitRule
		}
		// reset targetWindow
		cEntry->rInfo.targetWindow = 0;
		cEntry->sInfo.targetWindow = 0;
		// update failover stats
		if (cEntry->rxAttachIndex && cEntry->viaGateway) {
			int failoverAge = arg->currentTime - cEntry->rxLastTime;
			if (failoverAge < 60) PROJECT_attach[cEntry->rxAttachIndex].activeConnections += 1;
		}
		if (cEntry->attachFailed) {
			int failoverAge = arg->currentTime - cEntry->firstTime;
			if (failoverAge < 60) PROJECT_attach[cEntry->attachFailed].failedConnections += 1;
		}
		// remember oldest we've seen so far
		if (cEntry->lastTime < arg->lastTime) {
			arg->lastTime = cEntry->lastTime;
			arg->entry = cEntry;
		}
		// do trafficDiscovery if requested
		if ((PROJECT_flags & kFlag_trafficDiscovery) && arg->fromTimer) {
			// has this cEntry been updated? (age = 0, 1)
			if (age < 2) {
				KFT_cTrafficReport(key, iter_arg);
				arg->tdEntryCount++;
			}
		}
		// do report once every 10 minutes for connections older than 10 minutes
		if ((arg->currentTime - cEntry->firstTime > 600) && (arg->currentTime - cEntry->connectionLogTime > 600)) {
			cEntry->connectionLogTime = arg->currentTime;
			KFT_connectionEntryReport(key, iter_arg);
		}
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_connectionEntryRemove()
// ---------------------------------------------------------------------------------
// Report entry is going away and then delete it
int KFT_connectionEntryRemove(KFT_connectionEntry_t* entry)
{
	int returnValue;
	if (!entry) return -1;
	// report this entry since we're about to remove it
	entry->flags = kConnectionFlagDelete;
	KFT_connectionEntryReport(entry, NULL);
	// remove connection from rate limit rule if any (handled by filterUpdate)
		
	// remove entry from tree
	returnValue = KFT_connectionDelete(entry);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionDelete()
// ---------------------------------------------------------------------------------
// Delete actual connection entry (does not search for a matching entry)
int KFT_connectionDelete(KFT_connectionEntry_t* cEntry)
{
	int returnValue = 0;
	// report this cEntry since we're about to remove it
	cEntry->flags |= kConnectionFlagDelete;
	KFT_connectionEntryReport(cEntry, NULL);			
	
	// remove from AVL tree(s)
	if (cEntry->rInfo.callbackPending || cEntry->sInfo.callbackPending)
		returnValue = KFT_callbackRemoveEntry(cEntry);
	if (kft_connectionTree) returnValue = remove_by_key(kft_connectionTree, (void *)cEntry, KFT_connectionFree);
	return returnValue;
}

#pragma mark -- report --
// ---------------------------------------------------------------------------------
//	¥ KFT_connectionReport()
// ---------------------------------------------------------------------------------
// Report entries in connection table
int KFT_connectionReport()
{
	int returnValue = 0;
 
	if (kft_connectionTree) {
		// iterate over table
		iterate_inorder(kft_connectionTree, KFT_connectionEntryReport, NULL);
		// update UI
		KFT_connectionSendUpdates();
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionEntryReport()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Report connection entry to UI
int KFT_connectionEntryReport(void * key, void * iter_arg)
{
	int returnValue = 0;
	int length, howMany;
	int sizeLimit;
	// connection update message
	ipk_connectionUpdate_t* message;
	message = (ipk_connectionUpdate_t*)&connectionUpdateBuffer[0];
	length = message->length;
	howMany = (length-8)/sizeof(KFT_connectionEntry_t);
	// calculate size limit that still leaves room for another entry
	sizeLimit = kConnectionUpdateBufferSize - sizeof(KFT_connectionEntry_t);

	// add to update message
	memcpy(&message->connectionUpdate[howMany], key, sizeof(KFT_connectionEntry_t));
	message->connectionUpdate[howMany].flags |= kConnectionFlagUpdate;
	message->length += sizeof(KFT_connectionEntry_t);
	// if message buffer is full, send it
	if (message->length >= sizeLimit) KFT_connectionSendUpdates();
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionSendUpdates()
// ---------------------------------------------------------------------------------
// send any pending connection updates
void KFT_connectionSendUpdates()
{
	// connection update message
	ipk_connectionUpdate_t* message;
	message = (ipk_connectionUpdate_t*)&connectionUpdateBuffer[0];
	// are there any updates to send?
	if (message->length > 8) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskServer);
		message->length = 8;	// ofset to first entry
		message->flags = 0;
	}
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionCount()
// ---------------------------------------------------------------------------------
int KFT_connectionCount()
{
	if (kft_connectionTree) return kft_connectionTree->length;
	else return 0;
}


#define kLogEventSize 1024

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionLogEvent()
// ---------------------------------------------------------------------------------
// log TCP rate limiting events for debugging
int KFT_connectionLogEvent(KFT_connectionEntry_t* cEntry, char* inString)
{
	int returnValue = 0;
	// report debugging info
	unsigned char text[kLogEventSize];	// message buffer
	PSData inBuf;	
	// initialize buffer descriptor
	inBuf.bytes = &text[0];
	inBuf.length = sizeof(ipk_message_t);
	inBuf.bufferLength = kLogEventSize;
	inBuf.offset = sizeof(ipk_message_t);	// leave room for message length, type
	// build log text
		// local endpoint
	appendCString(&inBuf, "\n");
	appendIP(&inBuf, cEntry->local.address);
	appendCString(&inBuf, ":");
	appendInt(&inBuf, (int)cEntry->local.port);
		// remote endpoint
	appendCString(&inBuf, "->");
	appendIP(&inBuf, cEntry->remote.address);
	appendCString(&inBuf, ":");
	appendInt(&inBuf, (int)cEntry->remote.port);
		// event
	appendCString(&inBuf, "  ");
	returnValue = appendCString(&inBuf, inString);
	
	KFT_logData(&inBuf);
	return returnValue;
}

#pragma mark -- Traffic Discovery --

// ---------------------------------------------------------------------------------
//	¥ KFT_trafficReport()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Report traffic entry to UI
int KFT_trafficReport(void * key, void * iter_arg)
{
	int returnValue = 0;
	int length, howMany;
	int sizeLimit;
	// traffic update message
	ipk_trafficUpdate_t* message;
	message = (ipk_trafficUpdate_t*)&trafficUpdateBuffer[0];
	length = message->length;
	howMany = (length-8)/sizeof(KFT_trafficEntry_t);
	// calculate size limit that still leaves room for another entry
	sizeLimit = kConnectionUpdateBufferSize - sizeof(KFT_trafficEntry_t);

	// add to update message
	memcpy(&message->trafficUpdate[howMany], key, sizeof(KFT_trafficEntry_t));
	message->trafficUpdate[howMany].flags |= kConnectionFlagUpdate;
	message->length += sizeof(KFT_trafficEntry_t);
	// if message buffer is full, send it
	if (message->length >= sizeLimit) KFT_trafficSendUpdates(kFlag_none);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_cTrafficReport()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Report traffic entry to UI from passed in cEntry
int KFT_cTrafficReport(void * key, void * iter_arg)
{
	int returnValue = 0;
	int length, howMany;
	int sizeLimit;
	u_int8_t attachIndex;
	// traffic update message
	ipk_trafficUpdate_t* message;
	message = (ipk_trafficUpdate_t*)&trafficUpdateBuffer[0];
	length = message->length;
	howMany = (length-8)/sizeof(KFT_trafficEntry_t);
	// calculate size limit that still leaves room for another entry
	sizeLimit = kConnectionUpdateBufferSize - sizeof(KFT_trafficEntry_t);

	// add to update message
	//memcpy(&message->trafficUpdate[howMany], key, sizeof(KFT_trafficEntry_t));
	{
		KFT_trafficEntry_t* tEntry = &message->trafficUpdate[howMany];
		KFT_connectionEntry_t* cEntry = (KFT_connectionEntry_t*)key;
		KFT_connectionIterArg_t* arg = (KFT_connectionIterArg_t *)iter_arg;
		// init
		bzero(tEntry,sizeof(KFT_trafficEntry_t));
		// remote, local, dataIn, dataOut
		memcpy(tEntry, &cEntry->remote, (2*sizeof(KFT_connectionEndpoint_t) + 2*sizeof(KFT_stat_t)) );
		// trafficDiscoveryTime, bsdName
		tEntry->trafficDiscoveryTime = arg->currentTime;
		attachIndex = cEntry->rxAttachIndex;
		if (!attachIndex) attachIndex = cEntry->txAttachIndex;
		memcpy(tEntry->bsdName,
			PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName, kBSDNameLength);
		// icmp
		if (cEntry->remote.protocol == IPPROTO_ICMP) {
			tEntry->icmpType = cEntry->icmpType;
			tEntry->icmpCode = cEntry->icmpCode;
		}
	}
	message->trafficUpdate[howMany].flags |= kConnectionFlagUpdate;
	message->length += sizeof(KFT_trafficEntry_t);
	// if message buffer is full, send it
	if (message->length >= sizeLimit) KFT_trafficSendUpdates(kFlag_none);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_trafficSendUpdates()
// ---------------------------------------------------------------------------------
// send any traffic updates with flags
void KFT_trafficSendUpdates(int8_t flags)
{
	// traffic update message
	ipk_trafficUpdate_t* message;
	message = (ipk_trafficUpdate_t*)&trafficUpdateBuffer[0];
	message->flags |= flags;
	// send message to each active controller
	KFT_sendMessage((ipk_message_t*)message, kMessageMaskTrafficDiscovery);
	message->length = 8;	// ofset to first entry
	message->flags = 0;
}


#pragma mark --- AVL_TREE_SUPPORT_
// ---------------------------------------------------------------------------------
//	¥ KFT_connectionMemStat()
// ---------------------------------------------------------------------------------
KFT_memStat_t* KFT_connectionMemStat(KFT_memStat_t* record) {
	KFT_memStat_t* next = record;
	next->type = kMemStat_connection;
	next->freeCount = connection_freeCount;
	next->tableCount = KFT_connectionCount();
	next->allocated = connection_memAllocated;
	next->released = connection_memReleased;
	next->allocFailed = connection_memAllocFailed;
	next->leaked = next->allocated - next->released - next->tableCount - next->freeCount;
	next++;
	// callback tree
	bzero(next, sizeof(KFT_memStat_t));
	next->type = kMemStat_callback;
	next->tableCount = KFT_callbackCount();
	next++;
	return next;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionMalloc()
// ---------------------------------------------------------------------------------
KFT_connectionEntry_t* KFT_connectionMalloc() {
	KFT_connectionEntry_t* entry;
	// try to get one from our freeList
	if ((entry = SLIST_FIRST(&connection_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&connection_freeList, entries);
		connection_freeCount -= 1;
	}
	else {
		entry = (KFT_connectionEntry_t *)my_malloc(sizeof(KFT_connectionEntry_t));
		if (entry) connection_memAllocated += 1;
		else connection_memAllocFailed += 1;
	}
	return entry;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int KFT_connectionFree (void * key) {
	KFT_connectionEntry_t* entry = (KFT_connectionEntry_t*)key;
	if (connection_freeCount < connection_freeCountMax) {
		SLIST_INSERT_HEAD(&connection_freeList, entry, entries);
		connection_freeCount += 1;
	}
	else {
		my_free(key);
		connection_memReleased += 1;
	}
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_connectionFreeAll()
// ---------------------------------------------------------------------------------
void KFT_connectionFreeAll() {
	KFT_connectionEntry_t* entry;
	while ((entry = SLIST_FIRST(&connection_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&connection_freeList, entries);
		my_free((void*)entry);
		connection_memReleased += 1;
	}
	connection_freeCount = 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int KFT_callbackFree (void * key) {
	return 0;
}



// ---------------------------------------------------------------------------------
//	¥ KFT_connectionCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// "ta" and "tb" refer to KFT_connectionEndpoint_t structures
// for TCP connections we compare both the local and remote endpoints
// to insure uniquenes
int KFT_connectionCompare (void * compare_arg, void * a, void * b)
{
	KFT_connectionEndpoint_t* ta;
	KFT_connectionEndpoint_t* tb;
		// local EP
	ta = &((KFT_connectionEntry_t *)a)->local;
	tb = &((KFT_connectionEntry_t *)b)->local;
	// port
	if (ta->port < tb->port) return -1;
	if (ta->port > tb->port) return +1;
	// protocol
	if (ta->protocol < tb->protocol) return -1;
	if (ta->protocol > tb->protocol) return +1;
	// address
	if (ta->address < tb->address) return -1;
	if (ta->address > tb->address) return +1;	
		// remote EP
	ta = &((KFT_connectionEntry_t *)a)->remote;
	tb = &((KFT_connectionEntry_t *)b)->remote;
	// port
	if (ta->port < tb->port) return -1;
	if (ta->port > tb->port) return +1;
	// protocol
	if (ta->protocol < tb->protocol) return -1;
	if (ta->protocol > tb->protocol) return +1;
	// address
	if (ta->address < tb->address) return -1;
	if (ta->address > tb->address) return +1;
		// all are equal
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_callbackCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// Two part key consisting of calbackKeyTime and callbackKeyUnique
int KFT_callbackCompare (void * compare_arg, void * a, void * b)
{
	KFT_connectionEntry_t *ta = (KFT_connectionEntry_t *)a;
	KFT_connectionEntry_t *tb = (KFT_connectionEntry_t *)b;
	
	if (timerlt(&ta->callbackKey_tv, &tb->callbackKey_tv)) return -1;
	if (timergt(&ta->callbackKey_tv, &tb->callbackKey_tv)) return +1;
	if (ta->callbackKeyUnique < tb->callbackKeyUnique) return -1;
	if (ta->callbackKeyUnique > tb->callbackKeyUnique) return +1;
	return 0;
}

