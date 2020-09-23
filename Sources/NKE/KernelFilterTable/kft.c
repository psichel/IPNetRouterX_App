//  kft.c
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu Nov 14 2002.
//  Copyright (c) 2002-03 Sustainable Softworks, Inc. All rights reserved.
//
//  Kernel Filter Table functions and storage
//  This module is designed to be tested as client code and then incorporated
//  as part of our IPNetSentry_NKE
/*
List of functions that can fail with "out of memory" for inspection
KFT_triggerPacket		0=success
KFT_triggerSearchAdd	0=success
KFT_triggerAdd			0=success
KFT_connectionAdd		0=success
KFT_bridgeAdd			 0=failed
KFT_bridgeAddPacket		 0=failed
KFT_fragmentAdd			0=success
KFT_natPacket			0=success
KFT_natAddCopy			0=failed to allocate new entry
KFT_portMapAddCopy		0=failed to allocate new entry
KFT_callbackAddEntry	0=success
*/

#if IPK_NKE
#define DEBUG_IPK 0
#define TEST_BRIDGING 0
#include <libkern/libkern.h>
#else
#define DEBUG_IPK 0
#define TEST_BRIDGING 0
#include <stdio.h>
#endif

#if DEBUG_IPK
#include <sys/syslog.h>
#endif

#include "IPTypes.h"
#include PS_TNKE_INCLUDE
#include "kft.h"
#include "kftTrigger.h"
#include "kftDelay.h"
#include "kftConnectionTable.h"
#include "avl.h"
#include "kftFragmentTable.h"
#ifdef IPNetRouter
#include "kftNatProcess.h"
#include "kftNatTable.h"
#include "kftPortMapTable.h"
#endif
#include "kftBridgeTable.h"
#include "FilterTypes.h"
#include "IPKSupport.h"
//#include "kftPanther.h"

#if !IPK_NKE
#include <sys/time.h>
//#define NULL 0
#define EJUSTRETURN -2
#endif

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if_types.h>
#include <net/if.h>
#include <sys/mbuf.h>
#include <net/ethernet.h>
#include <sys/errno.h>
//#include <net/firewire.h>
#define	FIREWIRE_EUI64_LEN		8
#if IPK_NKE
#include <sys/param.h>
#include <sys/systm.h>
#include <sys/protosw.h>
#include <sys/socketvar.h>
#include <sys/fcntl.h>
#include <sys/malloc.h>
#include <sys/queue.h>
#include <sys/domain.h>
#include <net/route.h>

#include <net/if_dl.h>
#include <net/ndrv.h>
#include <net/kext_net.h>
#include <net/dlil.h>
#include <net/if_arp.h>
#include <machine/spl.h>
#include <kern/thread.h>
#include <libkern/OSAtomic.h>

int do_pullup(mbuf_t *mbuf_ptr, size_t inSizeNeeded, int direction);
	#if !TIGER
	extern struct mbuf *m_dup(struct mbuf *, int);
	#endif
#endif
#if !IPK_NKE
int PROJECT_modifyReadyPacket(KFT_packetData_t* packet);
#endif
void	*memcpy(void *, const void *, size_t);

#define kLogEventSize 1024

// Module wide storage
// allocate kernel filter tables
static KFT_filterEntry_t kft_filterTable[KFT_filterTableSize];
//static int kft_filterNextEntry;
#define kft_filterNextEntry kft_filterTableD.offset
PSData kft_filterTableD;			// filter table descriptor
// other module wide storage
static int kft_filterUpdateCount;	// used to control test interval for idle rules
static EthernetAddress_t broadcastAddress;
// periodic processing
static int kft_emptyMessageCount;
// external MTU for bridging
static int kft_externalMTU;

// Global storage
#include "kftGlobal.h"

// forward internal function declarations
int KFT_doNKEStack(KFT_packetData_t* packet);
int KFT_filterPacket(KFT_packetData_t* packet);
int KFT_matchEntryAtIndex(KFT_packetData_t* packet, int* ioIndex);
int KFT_matchContent(KFT_packetData_t* packet, KFT_contentSpec_t* content);
int indexOfParent(int index);
// bridging
int KFT_bridge(KFT_packetData_t* packet);
int KFT_bridgeOutput(KFT_packetData_t* packet, ifnet_t ifnet_ref, u_int8_t attachIndex,
	u_int8_t bridgeDirection, u_int8_t copy);
// route to
int KFT_resolveRouteTo(u_int32_t routeNextHop, u_int8_t* attachIndex, u_int8_t* direction);
int KFT_setRouteToAddress(KFT_filterEntry_t* entry, KFT_packetData_t* packet);
// filter actions
int KFT_tableAction(KFT_packetData_t* packet, int* ioIndex);
int KFT_filterAction(KFT_packetData_t* packet, int* ioIndex, u_int8_t action);
int KFT_leafChildAction(KFT_packetData_t* packet, int index, int skipLeaf);
int KFT_dropConnection(KFT_packetData_t* packet);
SInt64	myOSAddAtomic64(SInt32 amount, SInt64 *address);
// Count Updates
int KFT_memStatUpdate();

#if IPK_NKE
//int ik_findIFNet(char *inName, ifnet_t *ifnet_ref);
// timer callback
void KFT_delayTimeout(void *cookie);
#else
void testMessageFromClient(ipk_message_t* message);
#endif


#pragma mark --- INIT_SUPPORT ---
// ---------------------------------------------------------------------------------
//	¥ KFT_init()
// ---------------------------------------------------------------------------------
//	initialize filter tables
//	Called from IPNetSentry_NKE_start() which is already protected
void KFT_init()
{
	kft_filterUpdateCount = 0;
	PROJECT_doRateLimit = 0;
	kft_emptyMessageCount = 0;
	kft_externalMTU = 0;
	
	KFT_filterInit();
	KFT_triggerStart();
	KFT_delayInit();
	KFT_connectionStart();
#ifdef IPNetRouter
	KFT_natStart();
#endif
	broadcastAddress.octet[0] = 0xFF;
	broadcastAddress.octet[1] = 0xFF;
	broadcastAddress.octet[2] = 0xFF;
	broadcastAddress.octet[3] = 0xFF;
	broadcastAddress.octet[4] = 0xFF;
	broadcastAddress.octet[5] = 0xFF;
	KFT_bridgeStart();
}
void KFT_terminate()
{
	KFT_triggerStop();
	KFT_delayTerminate();
	KFT_connectionStop();
#ifdef IPNetRouter
	KFT_natStop();
#endif
	KFT_bridgeStop();
	avl_free_all();
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterInit()
// ---------------------------------------------------------------------------------
void KFT_filterInit()
{
	bzero(kft_filterTable, sizeof(KFT_filterEntry_t)*KFT_filterTableSize);
	kft_filterNextEntry = 0;
	// data descriptor for filter table
	kft_filterTableD.bytes = (u_int8_t *)kft_filterTable;
	kft_filterTableD.length = 0;
	kft_filterTableD.bufferLength = KFT_filterTableSize * sizeof(KFT_filterEntry_t);
	kft_filterTableD.offset = 0;  // use for table index of next entry
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterCount()
// ---------------------------------------------------------------------------------
// return number of entries in filter table
// Used prior to KFT_filterUpload to estimate buffer size
int KFT_filterCount()
{
	return kft_filterNextEntry;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterEntryForIndex()
// ---------------------------------------------------------------------------------
// Retrieve table entry for index
KFT_filterEntry_t* KFT_filterEntryForIndex(int index)
{
	if (index >= KFT_filterTableSize) return NULL;
	return &kft_filterTable[index];
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterPeriodical()
// ---------------------------------------------------------------------------------
// called by one second timer when firewall is enabled
// (from ipk_timeout which is splnet)
void KFT_filterPeriodical()
{
	int mod10 = kft_filterUpdateCount % 10;		// 10 second intervals

	// filter update every second
	KFT_filterUpdate();
	// age trigger table
	if (mod10 == 0) KFT_triggerAge();
	// age connection table if packet matched a rate limit rule, traffic discovery, or once every 10 seconds
	if (PROJECT_doRateLimit || (PROJECT_flags & kFlag_trafficDiscovery)) KFT_connectionAge(1);
	else if (mod10 == 1) KFT_connectionAge(1);
	PROJECT_doRateLimit = 0;
#ifdef IPNetRouter
	// age nat table
	KFT_natSecond();
	if (mod10 == 2)  KFT_natAge();
#endif
	// age bridge table
	if (mod10 == 3) KFT_bridgeAge();
	// update memory stats
	if (PROJECT_flags & kFlag_memStats) KFT_memStatUpdate();
}


#pragma mark --- RECEIVE_MESSAGES ---
// ---------------------------------------------------------------------------------
//	¥ KFT_receiveMessage()
// ---------------------------------------------------------------------------------
// dispatch ipk_message from client
int KFT_receiveMessage(ipk_message_t* message)
{
	int returnValue = 0;
	int type;
	switch(message->type) {
#ifdef IPNetRouter
		case kPortMapUpdate:
			returnValue = KFT_portMapReceiveMessage(message);
			break;
		case kNatUpdate:
			returnValue = KFT_natReceiveMessage(message);
			break;
#endif
		case kTriggerUpdate:
			returnValue = KFT_triggerReceiveMessage(message);
			break;
		case kInterfaceUpdate:
			returnValue = KFT_interfaceReceiveMessage(message);
			break;
		case kRouteUpdate:
			returnValue = KFT_routeReceiveMessage(message);
			break;
		default:
			type = message->type;
			KFT_logText("KFT_receiveMessage unknown message type ", &type);
			returnValue = 1;	// unknown message
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_interfaceReceiveMessage()
// ---------------------------------------------------------------------------------
int KFT_interfaceReceiveMessage(ipk_message_t* message)
{
	int returnValue = 0;
	ipk_interfaceUpdate_t* updateMessage;
	int j, length, howMany;
	KFT_interfaceEntry_t* interfaceE;
	u_int8_t attachIndex;

	// update for current message
	updateMessage = (ipk_interfaceUpdate_t *)message;
	length = updateMessage->length;
	howMany = (length-8)/sizeof(KFT_interfaceEntry_t);
	for (j=0; j<howMany; j++) {
		interfaceE = &updateMessage->interfaceUpdate[j];
		// look for existing DLIL attach instance
		attachIndex = KFT_attachIndexForName(interfaceE->bsdName);
		if (attachIndex) {
			// found existing DLIL attach, copy params in
			memcpy(&PROJECT_attach[attachIndex].kftInterfaceEntry, interfaceE, sizeof(KFT_interfaceEntry_t));
				// notice there could be more than one interface for
				// a single BSDname, so its important to copy only the NAT
				// interface or first one.
			returnValue = KFT_interfaceProcessEntry(attachIndex);
		}   // if (attachIndex) {
	}   // for (j=0; j<howMany; j++) {
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_interfaceProcessEntry()
// ---------------------------------------------------------------------------------
int KFT_interfaceProcessEntry(int attachIndex)
{
	int returnValue = 0;
	KFT_interfaceEntry_t* interfaceE;
	int myMTU;
	ifnet_t ifnet_ref = NULL;
	KFT_bridgeEntry_t* bridgeEntry;
	#if IPK_NKE
	errno_t status;
	#endif

	interfaceE = &PROJECT_attach[attachIndex].kftInterfaceEntry;
	//KFT_logText4("\nKFT_interfaceProcessEntry", interfaceE->bsdName,NULL, NULL);

	// get corresponding ifnet
	ifnet_ref = PROJECT_attach[attachIndex].ifnet_ref;
	if (ifnet_ref) {
		// get MTU of first external interface
		if (interfaceE->externalOn && (kft_externalMTU == 0)) {
			kft_externalMTU = ifnet_mtu(ifnet_ref);
		}
		// reduce MTU of bridged internal interfaces to match external interface if needed
		if (!interfaceE->externalOn && interfaceE->bridgeOn) {
			if ((kft_externalMTU >= 1450) && (kft_externalMTU < 1500)) {
				myMTU = ifnet_mtu(ifnet_ref);
				if (myMTU > kft_externalMTU) {
					// should use SIOCSIFDEVMTU instead [PAS] ***
					ifnet_set_mtu(ifnet_ref, kft_externalMTU);
				}
			}
		}
	}
	// set promiscuous mode for Ethernet bridging if enabled
	if (interfaceE->bridgeOn && !PROJECT_attach[attachIndex].promiscOn) {
		#if IPK_NKE
		if (ifnet_ref) {
			// enable promiscuous mode
			#if TIGER
				status = ifnet_set_promiscuous(ifnet_ref, 1);
			#else
				int s;
				s = splimp();
				status = ifpromisc(ifnet_ref, 1);
				splx(s);
			#endif
			// remember what we did
			PROJECT_attach[attachIndex].promiscOn = 1;
		}
		else {
			KFT_logText4("\nKFT_interfaceProcessEntry no ifnet_ref for bridged interface",
				PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName,NULL, NULL);
		}
		#endif
		{
			unsigned char buffer[kLogEventSize];	// message buffer
			PSData inBuf;
			// initialize buffer descriptor
			inBuf.bytes = &buffer[0];
			inBuf.length = sizeof(ipk_message_t);
			inBuf.bufferLength = kLogEventSize;
			inBuf.offset = sizeof(ipk_message_t);	// leave room for message length, type
			// append logging info
			appendCString(&inBuf, "\nKFT_interfaceReceiveMessage set promiscOn=1 for ");
			appendCString(&inBuf, PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName);
			appendCString(&inBuf, " ");
			appendHexInt(&inBuf, PROJECT_attach[attachIndex].ea.octet[0], 2, kOptionDefault);
			appendCString(&inBuf, ":");
			appendHexInt(&inBuf, PROJECT_attach[attachIndex].ea.octet[1], 2, kOptionDefault);
			appendCString(&inBuf, ":");
			appendHexInt(&inBuf, PROJECT_attach[attachIndex].ea.octet[2], 2, kOptionDefault);
			appendCString(&inBuf, ":");
			appendHexInt(&inBuf, PROJECT_attach[attachIndex].ea.octet[3], 2, kOptionDefault);
			appendCString(&inBuf, ":");
			appendHexInt(&inBuf, PROJECT_attach[attachIndex].ea.octet[4], 2, kOptionDefault);
			appendCString(&inBuf, ":");
			appendHexInt(&inBuf, PROJECT_attach[attachIndex].ea.octet[5], 2, kOptionDefault);
			// log it
			KFT_logData(&inBuf);
		}
	}
	if (!interfaceE->bridgeOn && PROJECT_attach[attachIndex].promiscOn) {
		#if IPK_NKE
		if (ifnet_ref) {
			// disable promiscuous mode
			#if TIGER
				status = ifnet_set_promiscuous(ifnet_ref, 0);
			#else
				int s, ret ;
				s = splimp();
				ret = ifpromisc(ifnet_ref, 0);
				splx(s);
			#endif
			// remember what we did
			PROJECT_attach[attachIndex].promiscOn = 0;
		}
		#endif
		KFT_logText4("\nKFT_interfaceProcessEntry set promiscOn=0 for",
			PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName,NULL, NULL);
	}
	// load bridge table with local Ethernet addresses
	bridgeEntry = NULL;
	if (ifnet_ref) {
		bridgeEntry = KFT_bridgeFind(&PROJECT_attach[attachIndex].ea);
	}
	// add entry if needed
	if (!bridgeEntry) {
		bridgeEntry = KFT_bridgeAdd(&PROJECT_attach[attachIndex].ea);
		// cannot fail since bridge table is hashed array
	}
	if (bridgeEntry) {
		// update hw address in case of collision
		memcpy(&bridgeEntry->ea, &PROJECT_attach[attachIndex].ea, ETHER_ADDR_LEN);
		bridgeEntry->attachIndex = attachIndex;
		bridgeEntry->flags = kBridgeFlagOutbound;
		#if TEST_BRIDGING
			printf("\nKFT_interfaceReceiveMessage %s local EA",
				PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName);
			printf(" %02x:%02x:%02x:%02x:%02x:%02x",
				PROJECT_attach[attachIndex].ea.octet[0],
				PROJECT_attach[attachIndex].ea.octet[1],
				PROJECT_attach[attachIndex].ea.octet[2],
				PROJECT_attach[attachIndex].ea.octet[3],
				PROJECT_attach[attachIndex].ea.octet[4],
				PROJECT_attach[attachIndex].ea.octet[5]);
		#endif
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_routeReceiveMessage()
// ---------------------------------------------------------------------------------
int KFT_routeReceiveMessage(ipk_message_t* message)
{
	int returnValue = 0;
	ipk_routeUpdate_t* updateMessage;
	int j, length, howMany;
	KFT_routeEntry_t* routeE;

	// update for current message
	updateMessage = (ipk_routeUpdate_t *)message;
	length = updateMessage->length;
	howMany = (length-8)/sizeof(KFT_routeEntry_t);
	for (j=0; j<howMany; j++) {
		routeE = &updateMessage->routeUpdate[j];
		memcpy(&PROJECT_route[j], routeE, sizeof(KFT_routeEntry_t));
	}   // for (j=0; j<howMany; j++) {
	// set table count
	PROJECT_routeCount = howMany;
	// check for upload request
	if (updateMessage->flags & kFlag_requestUpdate) KFT_routeUpdate();

	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterDownload()
// ---------------------------------------------------------------------------------
int KFT_filterDownload(PSData* inBuf)
{	
	int returnValue = 0;
	// reset externalMTU prior to attach interfaces
	kft_externalMTU = 0;
	// do conversion in client
	// copy buffer directly to filter table
	if (inBuf->length <= KFT_filterTableSize * sizeof(KFT_filterEntry_t)) {
		memcpy(kft_filterTable, inBuf->bytes, inBuf->length);
		kft_filterNextEntry = inBuf->length/sizeof(KFT_filterEntry_t);
		returnValue = kft_filterNextEntry;  // number of entries read in
	}
	// walk filter table to gather reserveInfo
	{
		int i;
		KFT_filterEntry_t* filterEntry;
		int rIndex = 0;
		int sIndex = 0;
		// initialize reserve info
		bzero(&PROJECT_rReserveInfo,sizeof(KFT_reserveInfo_t));
		bzero(&PROJECT_sReserveInfo,sizeof(KFT_reserveInfo_t));
		for (i=1; i<kft_filterNextEntry; i++) {
			filterEntry = &kft_filterTable[i];
			if (filterEntry->filterAction == kActionRateLimitIn) {
				if (rIndex < kMaxReserve) PROJECT_rReserveInfo.reserve[rIndex++] = i;
				PROJECT_rReserveInfo.lastRule = i;
			}
			else if (filterEntry->filterAction == kActionRateLimitOut) {
				if (sIndex < kMaxReserve) PROJECT_sReserveInfo.reserve[sIndex++] = i;
				PROJECT_sReserveInfo.lastRule = i;
			}
		}
		// remove last rule from reserve list
		if ((rIndex > 0) &&
			(PROJECT_rReserveInfo.reserve[rIndex-1] == PROJECT_rReserveInfo.lastRule))
				PROJECT_rReserveInfo.reserve[rIndex-1] = 0;
		if ((sIndex > 0) &&
			(PROJECT_sReserveInfo.reserve[sIndex-1] == PROJECT_sReserveInfo.lastRule))
				PROJECT_sReserveInfo.reserve[sIndex-1] = 0;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_reset()
// ---------------------------------------------------------------------------------
// reset selected state before downloading from client
void KFT_reset()
{
	kft_externalMTU = 0;
	KFT_delayInit();
	KFT_triggerReset();
	KFT_connectionStart();
#ifdef IPNetRouter
	KFT_natStart();
	KFT_portMapStart();
#endif
	KFT_bridgeStart();
	KFT_logText("\nKFT_reset", NULL);
}

#pragma mark --- SEND_MESSAGES ---
// ---------------------------------------------------------------------------------
//	¥ KFT_sendMessage()
// ---------------------------------------------------------------------------------
// send message as kernel or client test
void KFT_sendMessage(ipk_message_t* message, u_int32_t messageMask)
{
#if IPK_NKE
	PROJECT_sendMessageToAll(message, messageMask);
#else
	testMessageFromClient(message);
#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_memStatUpdate()
// ---------------------------------------------------------------------------------
// Notify controller with latest memory statistics
int KFT_memStatUpdate()
{
	int returnValue = 0;
	unsigned char buffer[kUpdateBufferSize];
	ipk_memStatUpdate_t *message;
	KFT_memStat_t *record, *next;
	int sizeLimit;

	// setup interface update message
	message = (ipk_memStatUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kMemStatUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(KFT_memStat_t);
	// report table stats
		// avl
	record = &message->memStatUpdate[0];
	next = KFT_avlMemStat(record);
	message->length += (char *)next - (char *)record;
		// trigger
	record = next;
	next = KFT_triggerMemStat(record);
	message->length += (char *)next - (char *)record;
		// connection
	record = next;
	next = KFT_connectionMemStat(record);
	message->length += (char *)next - (char *)record;
#ifdef IPNetRouter
		// nat
	record = next;
	next = KFT_natMemStat(record);
	message->length += (char *)next - (char *)record;
#endif
		// fragment
	record = next;
	next = KFT_fragmentMemStat(record);
	message->length += (char *)next - (char *)record;
	
	// are there any updates to send?
	if (message->length > 8) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
		#if 0
			log(LOG_WARNING, "KFT_memStatUpdate: %d\n", j);
		#endif
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterUpdate()
// ---------------------------------------------------------------------------------
//	Notify controller of any changed entries
// Should only be called from ipk_timeout which is thread protected.
int KFT_filterUpdate()
{
	int returnValue = 0;
	KFT_filterEntry_t* entry;
	unsigned char buffer[kUpdateBufferSize];	// buffer  300 entries * 20 bytes per
	ipk_filterUpdate_t* message;
	int sizeLimit;
	int i, j;
	u_int32_t recentTime;
	int checkIdle;
	
	// get current time
	struct timeval tv;
	#if IPK_NKE
	getmicrotime(&tv);
	#else
	gettimeofday(&tv, NULL);
	#endif
	recentTime = tv.tv_sec - 2;	// two seconds ago

	kft_filterUpdateCount += 1;
	checkIdle = kft_filterUpdateCount % 10;
	// setup filter update message
	message = (ipk_filterUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kFilterUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(ipk_countUpdate_t);
	j = 0;
	i = 1;		// skip root entry
	// walk filter table
	while (i<kft_filterNextEntry) {
		// get pointer to table entry
		entry = &kft_filterTable[i];
		// if entry not enabled
		if (!entry->enabled) {
			i += entry->nodeCount;	// skip disabled entries
			continue;
		}
		// recently updated entry?
		if (entry->lastTime > recentTime) {	// within last two seconds
			// rate limit processing
			if ((entry->filterAction == kActionRateLimitIn) || (entry->filterAction == kActionRateLimitOut)) {
				int32_t intervalBytesError;		// amount over(+) or under(-) target rate limit
				int32_t activeCountDelta = 0;	// amount to adjust based on intervalBytesError
				// calculate error during last interval (amount over(+) or under(-) target)
				intervalBytesError = entry->intervalBytes - (entry->rateLimit/CONVERT_BPS);
				entry->intervalBytes = 0;
				// calculate error adjustment
				if (entry->activeCountAdjusted > 0) {
					int roundedError;
					int connectionLimit = (entry->rateLimit / CONVERT_BPS) / entry->activeCountAdjusted;
					// any amount over is too much
					if (intervalBytesError > 0) roundedError = intervalBytesError + connectionLimit*3/4;	
					else roundedError = intervalBytesError - connectionLimit/4;
					if (connectionLimit) activeCountDelta = roundedError / connectionLimit;
				}
				else entry->activeCountAdjusted = entry->activeCount;
				// reset active data flow Count
				entry->activeCountAdjusted += activeCountDelta;
				if (entry->activeCountAdjusted <= 0) entry->activeCountAdjusted = entry->activeCount;
				entry->activeCount = 0;
			}
			// update stats for this entry
			entry->match.delta = entry->match.count - entry->match.previous;
			if (entry->match.delta < 0) entry->match.delta = 0; 
			entry->match.previous = entry->match.count;
			entry->byte.delta = entry->byte.count - entry->byte.previous;
			if (entry->byte.delta < 0) entry->byte.delta = 0;
			entry->byte.previous = entry->byte.count;
			// load update message
			message->countUpdate[j].index = i;
			message->countUpdate[j].match.count = entry->match.count;
			message->countUpdate[j].match.previous = entry->match.previous;
			message->countUpdate[j].match.delta = entry->match.delta;
			message->countUpdate[j].byte.count = entry->byte.count;
			message->countUpdate[j].byte.previous = entry->byte.previous;
			message->countUpdate[j].byte.delta = entry->byte.delta;
			message->countUpdate[j].lastTime = entry->lastTime;
			message->length += sizeof(ipk_countUpdate_t);			
			j += 1;
			// if message buffer is full, send it
			if (message->length >= sizeLimit) {
				KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
				message->length = 8;	// ofset to first entry
				message->flags = 0;
				j = 0;
				kft_emptyMessageCount = 0;
			}
		}
		else {	// not recently updated
			// skip children unless checking for idle time
			if (!checkIdle) {
				i += entry->nodeCount;	// skip innactive entries
				continue;
			}
		}
		// check idle time?
		if (checkIdle) {
			if ((entry->property == kFilterIdleSeconds) ||
				(entry->property == kFilterParentIdleSeconds)) {
				returnValue = KFT_leafChildAction(NULL, i, 0);
			}	// if (entry->property == kFilterParentIdleSeconds)
		}	// if (kft_filterUpdateCount % 10 == 0)
		i += 1;	// advance for next entry
	}
	
	// are there any updates to send?
	if ((j > 0) || (kft_emptyMessageCount == 0)) {
		if (j > 0) kft_emptyMessageCount = 0;	// allow one empty message after any data updates
		else kft_emptyMessageCount += 1;
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterUpload()
// ---------------------------------------------------------------------------------
int KFT_filterUpload(PSData* outBuf)
{
	int returnValue = 0;
	// do conversion in client
	// copy filter table directly to buffer
	int size = kft_filterNextEntry * sizeof(KFT_filterEntry_t);
	if (size <= outBuf->bufferLength) {
		memcpy(outBuf->bytes, kft_filterTable, size);
		outBuf->length = size;
	}
	else outBuf->length = 0;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_interfaceUpload()
// ---------------------------------------------------------------------------------
// send interface update message with current interface table
int KFT_interfaceUpload()
{
	int returnValue = 0;
	unsigned char buffer[kUpdateBufferSize];
	ipk_interfaceUpdate_t* message;
	int sizeLimit;
	int i, j;

	// setup interface update message
	message = (ipk_interfaceUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kInterfaceUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(KFT_interfaceEntry_t);
	j = 0;
	// walk attach instance table
	for (i=1; i<=kMaxAttach; i++) {
		// active attach entry (filterID indicates attached)?
		#if TIGER
		if ((PROJECT_attach[i].ifFilterRef != 0) || (PROJECT_attach[i].ipFilterRef != 0)) {
		#else
		if (PROJECT_attach[i].filterID != 0) {
		#endif
			// add to message
			memcpy(&message->interfaceUpdate[j], &PROJECT_attach[i].kftInterfaceEntry,
				sizeof(KFT_interfaceEntry_t));
			message->length += sizeof(KFT_interfaceEntry_t);
			j += 1;
			returnValue += 1;	// return how many we found
			// if message buffer is full, send it
			if (message->length >= sizeLimit) {
				KFT_sendMessage((ipk_message_t*)message, kMessageMaskServerGUI);
				message->length = 8;	// ofset to first entry
				message->flags = 0;
				j = 0;
			}
		#if TIGER
        }
		#else
		}
		#endif
	}
	// are there any updates to send?
	if (j > 0) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskServerGUI);
		#if 0
			log(LOG_WARNING, "KFT_interfaceUpload: %d\n", j);
		#endif
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_routeUpdate()
// ---------------------------------------------------------------------------------
// send route update messages with current route table entries, return how many we found
int KFT_routeUpdate()
{
	int returnValue = 0;
	unsigned char buffer[kUpdateBufferSize];
	ipk_routeUpdate_t* message;
	int sizeLimit;
	int i, j;
	KFT_routeEntry_t* routeE;

	// setup route update message
	message = (ipk_routeUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kRouteUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(KFT_routeEntry_t);
	j = 0;
	// walk route table
	for (i=0; i<PROJECT_routeCount; i++) {
		// get failover stats
		routeE = &PROJECT_route[i];
		if (!routeE->attachIndex) routeE->attachIndex = KFT_attachIndexForName(routeE->bsdName);
		routeE->activeConnections = PROJECT_attach[routeE->attachIndex].activeConnections;
		routeE->failedConnections = PROJECT_attach[routeE->attachIndex].failedConnections;
		// add to message
		memcpy(&message->routeUpdate[j], &PROJECT_route[i],
			sizeof(KFT_routeEntry_t));
		message->length += sizeof(KFT_routeEntry_t);
		j += 1;
		returnValue += 1;	// return how many we found
		// if message buffer is full, send it
		if (message->length >= sizeLimit) {
			KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
			message->length = 8;	// ofset to first entry
			message->flags = 0;
			j = 0;
		}
	}
	// are there any updates to send?
	if (j > 0) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
		#if 0
			log(LOG_WARNING, "KFT_routeUpdate: %d\n", j);
		#endif
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_syncUpdate()
// ---------------------------------------------------------------------------------
// send sync update message with timeInterval passed in to confirm processing complete
// up to this time.
int KFT_syncUpdate(double timeInterval)
{
	int returnValue = 0;
	unsigned char buffer[kUpdateBufferSize];
	ipk_syncUpdate_t* message;

	// setup route update message
	message = (ipk_syncUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kSyncUpdate;
	message->version = 0;
	message->flags = 0;
	// set timeInterval
	message->timeInterval = timeInterval;
	message->length += sizeof(timeInterval);
	// send it
	KFT_sendMessage((ipk_message_t*)message, kMessageMaskServer);
	return returnValue;
}

#pragma mark --- FILTER_PACKETS ---
// ---------------------------------------------------------------------------------
//	¥ KFT_processPacket()
// ---------------------------------------------------------------------------------
// process BSD packet against filter table calling KFT_filterAction for any matches
// packets are passed as an mbuf chain:
//	*packet->mbuf_ptr points to the first mbuf in the chain (flags = M_PKTHDR)
//  packet->ipOffset gives the offset to the start of IP datagram within the mbuf data
//  packet->direction 0=outbound, 1=inbound
//  packet->myAttach->kftInterfaceEntry.bsdName pointer to CString name for corresponding ifnet
//
// For Mac OS X Tiger:
//   *packet->mbuf_ptr is an mbuf_t
//   packet->ifnet_ref is an ifnet_t
// So we need to handle any such references differently
//
// Notice an mbuf may be linked to additional packets (m_nextpkt).
// We assume we're called once for each packet.  Our job is to examine
// the mbuf chain that forms a single IP datagram.
//
// We assume the caller has checked the link layer header for IP,
// but confirm this by ignoring anything that is not a valid IPv4 (IPv6?) dg.
//
// We can view the mbuf chain as a series of data segments of varying length.
// Protocol headers must fit within a single mbuf (call pullup if needed)
//
//	Output:
//		0 continue normal packet processing
//		EJUSTRETURN (-2) return immediately 
//			no further processing, but do not delete packet, we have consumed it.
//		other nonzero: delete packet (mbuf chain) and return immediately (error condition)
int KFT_processPacket(KFT_packetData_t* packet)
{
	int returnValue = 0;
    ip_header_t* ipHeader;
	u_int8_t	 protocol;
	// Begin per packet processing
	do {
        // if not IP
		if (packet->bridgeNonIP) {
			// perform Ethernet bridging if requested
			if (packet->myAttach->kftInterfaceEntry.bridgeOn) {
				returnValue = KFT_bridge(packet);
			}
			break;  // not IP, we're done
		}
		// pullup as needed to access packet headers
		// -----------------------------------------
		#if IPK_NKE
            // Verify we have a contiguous IP header.
            int sizeNeeded, sizeHave;
			sizeHave = mbuf_len(*packet->mbuf_ptr);
            sizeNeeded = packet->ipOffset + sizeof(ip_header_t);
			if (sizeNeeded > sizeHave) {
				if (returnValue = do_pullup(packet->mbuf_ptr, sizeNeeded, packet->direction)) break;
			}
		#endif
		packet->datagram = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
		packet->datagram = &packet->datagram[packet->ipOffset];
		ipHeader = (ip_header_t*)packet->datagram;
		protocol = ipHeader->protocol;
 		// check that we have a valid datagram
		// Non IPv4?
		if ((ipHeader->hlen & 0xF0) != 0x40) {
			// lo0 (loopback)?  Let it through silently so we don't break stuff by accident
			if (memcmp("lo0", packet->myAttach->kftInterfaceEntry.bsdName, 3) == 0) break;
			// IPv6?
			if ((ipHeader->hlen & 0xF0) == 0x60) {
				// Block IPv6?
				if (PROJECT_flags & kFlag_blockIPv6) {
					// delete packet, without logging
					returnValue = KFT_deletePacket(packet);
					break;
				}
				// let IPv6 through silently
				break;
			}
			// Not IPv4 or IPv6, log and then pass (probably harmless)
			KFT_logEvent(packet, -kReasonNotV4, kActionPass);
			break;
		}
		packet->ipHeaderLen = (ipHeader->hlen & 0x0F) << 2;	// in bytes
		if (packet->ipHeaderLen < 20) {
			KFT_logEvent(packet, -kReasonShortIPHeader, kActionDelete);
			returnValue = KFT_deletePacket(packet);
			break;			
		}
        // transport header length		
        packet->transportHeaderLen = 0;
        if (protocol == IPPROTO_TCP) packet->transportHeaderLen = 20;
        else if (protocol == IPPROTO_UDP) packet->transportHeaderLen = 8;
        else if (protocol == IPPROTO_ICMP) packet->transportHeaderLen = 8;
        #if IPK_NKE
            // Verify we have a contiguous transport header.
			sizeHave = mbuf_len(*packet->mbuf_ptr);
            sizeNeeded = packet->ipOffset + packet->ipHeaderLen + packet->transportHeaderLen;
			if (sizeNeeded > sizeHave) {
				if (returnValue = do_pullup(packet->mbuf_ptr, sizeNeeded, packet->direction)) break;
				packet->datagram = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
				packet->datagram = &packet->datagram[packet->ipOffset];
			}
        #endif
        if (protocol == IPPROTO_TCP) {
            tcp_header_t* tcpHeader;
            tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
            packet->transportHeaderLen = (tcpHeader->hlen & 0xF0) >> 2;	// in bytes
			if (packet->transportHeaderLen < 20) {
				//if (PROJECT_flags & kFlag_triggerOnInvalid) {
					ip_header_t* ipHeader = (ip_header_t*)packet->datagram;
					//NTOHL(ipHeader->srcAddress);
					ipHeader->srcAddress = ntohl(ipHeader->srcAddress);
					KFT_triggerPacket(packet, kTriggerTypeInvalid);
				//}
				KFT_logEvent(packet, -kReasonShortTCPHeader, kActionDelete);
				returnValue = KFT_deletePacket(packet);
				break;			
			}
			if (packet->transportHeaderLen > 20) {
			#if IPK_NKE
				// Verify we have a contiguous transport header including any TCP options.
				sizeHave = mbuf_len(*packet->mbuf_ptr);
				sizeNeeded = packet->ipOffset + packet->ipHeaderLen + packet->transportHeaderLen;
				if (sizeNeeded > sizeHave) {
					if (returnValue = do_pullup(packet->mbuf_ptr, sizeNeeded, packet->direction)) break;
					packet->datagram = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
					packet->datagram = &packet->datagram[packet->ipOffset];
				}
			#endif
			}
        }
		// save original attachIndex and direction
		packet->redirect.originalAttachIndex = packet->myAttach->attachIndex;
		packet->redirect.originalDirection = packet->direction;
		
		// process packet through NKE network stack
		returnValue = KFT_doNKEStack(packet);
		// if packet was deleted, we're done
		if (returnValue != 0) break;

	} while (0);	// end of per packet processing
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_doNKEStack()
// ---------------------------------------------------------------------------------
// process BSD packet through NKE network stack
	// For outbound, want to filter before NAT obscures Actual IP address,
	//  so layer filtering above NAT.
	// For inbound, want to filter before bridging to include firewall,
	//	so layer bridging above Filter.
	// Network Stack order is
		// IP
		// Bridge
		// Filter
		// NAT
		// enX
int KFT_doNKEStack(KFT_packetData_t* packet)
{
	int returnValue = 0;
    ip_header_t* ipHeader = (ip_header_t*)packet->datagram;
	KFT_connectionEntry_t *cEntry = NULL;
	int result;
		
	do {
		// Convert header fields to host byte order for processing
		KFT_ntohPacket(packet, kOptionNone);
		// alternate loopback address 0.0.0.127
		if (ipHeader->dstAddress == 127) {
			// Swap source and destination IP address so packet will appear to be from the reflector.
			ip_header_t* ipHeader;
			u_int32_t target;
			u_int32_t oldAddress;
			// swap source & dest
			result = PROJECT_modifyReadyPacket(packet);
			ipHeader = (ip_header_t*)packet->datagram;
				// update src
			target = ipHeader->dstAddress;
			oldAddress = ipHeader->srcAddress;
			ipHeader->srcAddress = target;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target);
				// update dst
			target = oldAddress;
			oldAddress = ipHeader->dstAddress;
			ipHeader->dstAddress = target;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target);
			// reflect packet
			returnValue = KFT_reflectPacket(packet);
			break;
		}
		
		// perform NAT for inbound if enabled on this interface
		#if IPNetRouter
		if (packet->myAttach->kftInterfaceEntry.natOn) {
			if (packet->direction == kDirectionInbound) returnValue = KFT_natIn(packet);
			// notice NAT can delete the packet if Exposed host is none (*packet->mbuf_ptr == NULL)
			// if packet was deleted, we're done
			if (returnValue != 0) break;
		}
		#endif
		
		// find previous connection entry (if any)
		// notice connections are between "actual" endpoints so NAT first for inbound
		result = KFT_connectionInclude(packet);
		cEntry = packet->connectionEntry;
		
		// get frame header info if we don't already have it
		if (cEntry) {
			if ((cEntry->rxfhlen == 0) && (packet->direction == kDirectionInbound)) {
				if (packet->ifHeaderLen && (packet->ifHeaderLen <= kFHMaxLen)) {
					// inbound
					u_int8_t* ha = (u_int8_t*)*packet->frame_ptr;
					cEntry->rxfhlen = packet->ifHeaderLen;
					memcpy(cEntry->rxfh, ha, cEntry->rxfhlen);
				}
			}
			else if ((cEntry->txfhlen == 0) && (packet->direction == kDirectionOutbound)) {
				if (packet->ifHeaderLen && (packet->ifHeaderLen <= kFHMaxLen)) {
					// outbound
					u_int8_t* ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
					cEntry->txfhlen = packet->ifHeaderLen;
					memcpy(cEntry->txfh, ha, cEntry->txfhlen);
				}
			}
		}
		
		// if IP filtering is enabled
		if (packet->myAttach->kftInterfaceEntry.filterOn) {
			returnValue = KFT_filterPacket(packet);
			// if packet was deleted, we're done
			if (returnValue != 0) break;
		}

		// add packet to connection table if no previous entry
		if (!cEntry) {
			result = KFT_connectionAdd(packet);
			cEntry = packet->connectionEntry;
			if (!cEntry) {
				KFT_logEvent(packet, -kReasonOutOfMemory, kActionNotCompleted);
				break;	// out of memory
			}
			else {
				// store any rate limit rule we saw during IP filtering with no connection entry
				cEntry->rInfo.rateLimitRule = packet->rateLimitInRule;
				cEntry->sInfo.rateLimitRule = packet->rateLimitOutRule;
			}
		}
		// if packet was deleted, we're done
		if (*packet->mbuf_ptr == NULL) {	// defensive
			returnValue = EJUSTRETURN;
			break;
		}
		// can assume we have a cEntry from here on

		// update packet state (filtering sees state before this packet)
		// includes rate limiting if enabled
		returnValue = KFT_connectionState(packet);
		// if packet was deleted, we're done
		if (returnValue != 0) break;
		
		// perform load balancing or failover if requested
		if ( ((PROJECT_flags & kFlag_loadBalance) || (PROJECT_flags & kFlag_failover))  &&
			(packet->direction == kDirectionOutbound) &&
			(packet->myAttach->kftInterfaceEntry.externalOn)) do {
			u_int32_t loadBalance;
			int index;
			KFT_routeEntry_t *routeE = NULL;
			
			// test if there is an alternate gateway
			if (PROJECT_routeCount <= 1) break;
			// test if packet has already been redirected by RouteTo or other mechanism
			if (packet->redirect.attachIndex != 0) break;
			// test if packet is for a next hop gateway (destination is not on directly attached network)
			u_int32_t attachedNet = packet->myAttach->kftInterfaceEntry.ifNet.address &
							packet->myAttach->kftInterfaceEntry.ifNet.mask;
			u_int32_t destNet = ipHeader->dstAddress & packet->myAttach->kftInterfaceEntry.ifNet.mask;
			if (destNet == attachedNet) break;			
			// skip broadcast & multicast
			if (ipHeader->dstAddress == INADDR_BROADCAST) break;
			if (IN_MULTICAST(ipHeader->dstAddress)) break;

			// mark cEntry as viaGateway (destination is not directly attached)
			cEntry->viaGateway = 1;
			if (PROJECT_flags & kFlag_loadBalance) {
				// select interface from available gateways based on local and remote endpoings
				loadBalance = cEntry->remote.address + cEntry->remote.port + cEntry->local.address + cEntry->local.port;
				index = loadBalance % PROJECT_routeCount;
				routeE = &PROJECT_route[index];
				if (!routeE->attachIndex) routeE->attachIndex = KFT_attachIndexForName(routeE->bsdName);
			}
			if (PROJECT_flags & kFlag_failover) {
				int attachIndex = packet->myAttach->attachIndex;
				int failover = 0;
				if ((PROJECT_attach[attachIndex].failedConnections) &&
					(PROJECT_attach[attachIndex].failedConnections >= PROJECT_attach[attachIndex].activeConnections)) failover = 1;
				if ((cEntry->dupSynCount >= 3) || failover) {
					// which gateway did we try?
					for (index=0; index<PROJECT_routeCount; index++) {
						routeE = &PROJECT_route[index];
						if (!routeE->attachIndex) routeE->attachIndex = KFT_attachIndexForName(routeE->bsdName);
						if (routeE->attachIndex == packet->myAttach->attachIndex) break;
					}
					if (index < PROJECT_routeCount) {
						// look for next available gateway
						int rotate = 0;
						if (cEntry->dupSynCount >= 3) rotate = cEntry->dupSynCount - 3;
						index = (index+1+rotate) % PROJECT_routeCount;
						routeE = &PROJECT_route[index];
						if (!routeE->attachIndex) routeE->attachIndex = KFT_attachIndexForName(routeE->bsdName);
						// failover stats
						if (cEntry->dupSynCount >= 3) cEntry->attachFailed = packet->myAttach->attachIndex;
					}
				}
			}
			// shift packet to corresponding data link
			// lookup attachIndex from bsdName if needed					
			if (routeE && routeE->attachIndex) {
				result = KFT_lateralPut(packet, routeE->attachIndex);
				// if data link has changed
				if (result == 0) {
					// Ethernet frame?
					if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
						// rewrite destination MAC address
						u_int8_t* ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
						memcpy(&ha[0], &routeE->gatewayHA[0], ETHER_ADDR_LEN);
					}
				}
			}	// if (routeE->attachIndex) {
		} while (0);	// if ((PROJECT_flags & kFlag_loadBalance) &&
		
		// perform source aware routing as needed (unless bridging)
		if ((PROJECT_flags & kFlag_sourceAwareRouting) && !packet->myAttach->kftInterfaceEntry.bridgeOn) {
			// external interface and outbound
			if ((packet->myAttach->kftInterfaceEntry.externalOn) &&
				(packet->direction == kDirectionOutbound)) {
				// source aware active open
				if (((cEntry->flags & kConnectionFlagNonSyn) == 0) &&
					((cEntry->flags & kConnectionFlagPassiveOpen) == 0)) {
					KFT_sourceAwareActiveOpen(cEntry);
				}
				// do connection packets arrive from a different interface and passive open
				if (cEntry->rxAttachIndex != packet->myAttach->attachIndex) {
					// make sure attachIndex is valid
					int attachIndex = cEntry->rxAttachIndex;
					if (attachIndex && PROJECT_attach[attachIndex].ifnet_ref) {
						// dont do source aware routing until we've seen an
						// inbound connection packet (rxAttachIndex > 0)
						// only do frame headers we have seen
						if ((packet->ifType == IFT_ETHER) && (cEntry->rxfhlen)) {
							KFT_lateralPut(packet, attachIndex);						
							// replace destination MAC address with received source MAC address
							u_int8_t* ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
							memcpy(&ha[0], &cEntry->rxfh[6], ETHER_ADDR_LEN);
						}
						// allow redirect processing to handle the rest
					}
				}
			}
		}
					
		// perform Bridging for outbound if enabled
			// Bridged packets skip NAT on the outbound side
		if ((packet->myAttach->kftInterfaceEntry.bridgeOn) &&
			(packet->direction == kDirectionOutbound)) {
			// restore network byte order before bridging
			KFT_htonPacket(packet, kOptionNone);
#if 0
			// finalize packet since it may be injected to another interface
			#if IPK_NKE
			if (packet->modifyReady == 0) {
				mbuf_t mbuf_ref;
				mbuf_ref = *(packet->mbuf_ptr);
				mbuf_outbound_finalize(mbuf_ref, AF_INET, packet->ipOffset);
				// might have done m_pullup
				packet->datagram = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
				packet->datagram = &packet->datagram[packet->ipOffset];
				// clear csum flags
				mbuf_inbound_modified(mbuf_ref);		// mbuf->m_pkthdr.csum_flags = 0;
				mbuf_clear_csum_requested(mbuf_ref);	// mbuf->m_pkthdr.csum_data = 0;
			}
			#endif
#endif
			// bridge
			returnValue = KFT_bridge(packet);
			if (returnValue != 0) break;	// if packet was deleted, we're done
			// Convert header fields to host byte order for processing
			KFT_ntohPacket(packet, kOptionNone);
		}			
		
		// perform NAT for outbound if enabled on this interface
		#ifdef IPNetRouter
		if (packet->myAttach->kftInterfaceEntry.natOn) {
			if (packet->direction == kDirectionOutbound) returnValue = KFT_natOut(packet);
			// if packet was deleted, we're done
			if (returnValue != 0) break;
		}
		#endif
		
		// perform Ethernet bridging for inbound if requested
			// we pass packets through our NAT firewall before bridging,
			// but do bridging before any routing
		if ((packet->myAttach->kftInterfaceEntry.bridgeOn) &&
			(packet->direction == kDirectionInbound)) {
			// restore network byte order before bridging
			KFT_htonPacket(packet, kOptionNone);
#if 0
			// finalize packet since it may be injected to another interface
			#if IPK_NKE
			if (packet->modifyReady == 0) {
				mbuf_t mbuf_ref;
				mbuf_ref = *(packet->mbuf_ptr);
				mbuf_inbound_modified(mbuf_ref);		// mbuf->m_pkthdr.csum_flags = 0;
				mbuf_clear_csum_requested(mbuf_ref);	// mbuf->m_pkthdr.csum_data = 0;			
			}
			#endif
#endif
			// bridge
			returnValue = KFT_bridge(packet);
			if (returnValue != 0) break;	// if packet was deleted, we're done
		}
		
		// Redirect packet per any advanced routing options if specified
		// Factoring notes:
		//	reverse - change packet direction (swap src/dst MAC)
		//  lateralPut - change data link
		//  doRedirect - inject as requested
		//  reflect - reverse followed by doRedirect
		returnValue = KFT_doRedirect(packet);
		//	*packet->mbuf_ptr = NULL;	// mbuf was consumed
		//	returnValue = EJUSTRETURN;  // terminate packet processing without releasing mbuf chain
		
	} while (0);	// byte swap boundary
	// Convert header fields back to network byte order before passing on
	KFT_htonPacket(packet, kOptionNone);
	
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_filterPacket()
// ---------------------------------------------------------------------------------
// process BSD packet against filter table calling KFT_filterAction for any matches
int KFT_filterPacket(KFT_packetData_t* packet)
{
	int returnValue = 0;
	KFT_connectionEntry_t *cEntry = packet->connectionEntry;
	int i;

	do {
		// perform IP filtering
		// --------------------
		// initialize for content matching
		mbuf_t mbuf_ref = *packet->mbuf_ptr;
		packet->segmentLen = mbuf_len(mbuf_ref) - packet->ipOffset;
		packet->matchOffset = 0;	// defensive
		packet->textLength = 0;		// defensive
		packet->leafAction = 0;		// defensive
		// check packet against each filter rule
		i = 1;
		while (i<kft_filterNextEntry) {
			returnValue = KFT_matchEntryAtIndex(packet, &i);
			if (returnValue != 0) break;
		}
		if (returnValue == -1) {
			// internal error, index out of range
			KFT_logEvent(packet, -kReasonConsistencyCheck, kActionPass);
			returnValue = 0;	// continue processing packet
		}
		// if packet was deleted, we're done
		if (returnValue != 0) break;
		if (*packet->mbuf_ptr == NULL) {
			returnValue = EJUSTRETURN;
			break;
		}
		
		// handle connections closed by firewall
		if (cEntry) {
			if (cEntry->flags & kConnectionFlagClosed) {
				cEntry->dropCount += 1;
				if (cEntry->dropCount <= 3) {
					if ((packet->direction == kDirectionOutbound) &&
						(cEntry->flags & kConnectionFlagFINPeer) &&
						(cEntry->flags & kConnectionFlagFINLocal)) {
						KFT_respondACK(packet);	// orderly close
						packet->dontLog = 1;	// already logged when kConnectionFlagClosed
					}
				}
				else if (cEntry->dropCount <= 10) KFT_respondRST(packet);
				// now delete it
				KFT_logEvent(packet, -kReasonConnectionState, kActionDelete);
				returnValue = KFT_deletePacket(packet);
				break;
			}
		}
	} while (0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_matchEntryAtIndex()
// ---------------------------------------------------------------------------------
// Test packet against filter entry.
// Output: ioIndex points to next entry to test 
// or kft_filterNextEntry for leaf action, stop testing this packet
//  0 normal completion, continue
// -1 index out of range
// Note packet may be NULL for timer invoked actions
int KFT_matchEntryAtIndex(KFT_packetData_t* packet, int* ioIndex)
{
	int returnValue = 0;
	u_int8_t* dp8;
	u_int16_t* dp16;
	u_int32_t* dp32;
	int64_t* dp64;
	KFT_filterEntry_t* entry;
	int index;
	int parentIndex;
	long compareResult = -1;	// default to not match

	do {
		index = *ioIndex;
		// check for entry within table
		if ((index < 0) || (index >= kft_filterNextEntry)) {
			*ioIndex = kft_filterNextEntry;		// make sure we stop
			returnValue = -1;
			break;
		}
		// get pointer to table entry
		entry = &kft_filterTable[index];
		// if entry is not enabled
		if (!entry->enabled) {
			*ioIndex += entry->nodeCount;	// skip it
			break;
		}
		// match corresponding property
		dp8 = &entry->propertyValue[0];
		dp16 = (u_int16_t*)dp8;
		dp32 = (u_int32_t*)dp8;
		dp64 = (int64_t*)dp8;

		if (entry->property < kFilter__2) {
			if (entry->property < kFilter__1) {
				// BLOCK_1
				switch(entry->property) {
					case kFilterAny:
						compareResult = 0;	// match any
						break;
					case kFilterNone:
						compareResult = -1;	// match none
						break;
					case kFilterDirection:
						if (!packet) break;
						compareResult = packet->direction - dp8[0];
						break;
					case kFilterInterface:
						if (!packet) break;
						// check for internal/external
						if (dp8[0] == 1) {
							if (dp8[1] == kInterfaceInternal) {
								compareResult = packet->myAttach->kftInterfaceEntry.externalOn;
							}
							else if (dp8[1] == kInterfaceExternal) {
								compareResult = 1-packet->myAttach->kftInterfaceEntry.externalOn;
							}
							break;
						}
						// compare interface name PString to CString
						compareResult = memcmp(&dp8[1], &packet->myAttach->kftInterfaceEntry.bsdName[0], dp8[0]);
//							KFT_logText4("\nRule interface:", &dp8[1], "Packet interface:",
//								&packet->myAttach->kftInterfaceEntry.bsdName[0]);
						break;
					case kFilterInclude:
						if (!packet) break;
						if (dp8[0] == kIncludeTrigger) compareResult = KFT_triggerInclude(packet, kTriggerTypeTrigger);
						else if (dp8[0] == kIncludeAddress) compareResult = KFT_triggerInclude(packet, kTriggerTypeAddress);
						else if (dp8[0] == kIncludeAuthorize) compareResult = KFT_triggerInclude(packet, kTriggerTypeAuthorize);
						else if (dp8[0] == kIncludeInvalid) compareResult = KFT_triggerInclude(packet, kTriggerTypeInvalid);
						else if (dp8[0] == kIncludeState) {
							//compareResult = KFT_connectionInclude(packet);
							compareResult = (packet->connectionEntry == 0);
						}
						break;
					case kFilterSourceMACAddress:
					{
						u_int8_t* ha;
						if (!packet) break;
						// Ethernet frame?
						if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
							if (packet->direction == kDirectionOutbound) {
								ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
							}
							else ha = (u_int8_t*)*packet->frame_ptr;
							compareResult = memcmp(&ha[6], &dp8[0], ETHER_ADDR_LEN);
						}
						break;
					}
					case kFilterDestMACAddress:
					{
						u_int8_t* ha;
						if (!packet) break;
						// Ethernet frame?
						if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
							if (packet->direction == kDirectionOutbound) {
								ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
							}
							else ha = (u_int8_t*)*packet->frame_ptr;
							compareResult = memcmp(&ha[0], &dp8[0], ETHER_ADDR_LEN);
						}
						break;
					}
				}	// switch(entry->property)
			}	// < kFilter__1
			else if (packet) {
				// BLOCK_2
				// setup access to IP header
				ip_header_t* ipHeader;
				icmp_header_t* icmpHeader;
				ipHeader = (ip_header_t*)packet->datagram;
				switch(entry->property) {
					case kFilterSourceNet: {
						int endOffset = dp32[1];
						if (endOffset == 0) {
							compareResult = (ipHeader->srcAddress - dp32[0]);
						}
						else {
							compareResult = (ipHeader->srcAddress - dp32[0]);
							if (compareResult > endOffset) compareResult -= endOffset;
							else if (compareResult > 0) compareResult = 0;
						}
						break;
					}
					case kFilterDestNet: {
						int endOffset = dp32[1];
						if (endOffset == 0) {
							compareResult = (ipHeader->dstAddress - dp32[0]);
						}
						else {
							compareResult = (ipHeader->dstAddress - dp32[0]);
							if (compareResult > endOffset) compareResult -= endOffset;
							else if (compareResult > 0) compareResult = 0;
						}
						break;
					}
					case kFilterProtocol:
						compareResult = (ipHeader->protocol - dp8[0]);
						break;		
					case kFilterIPFragmentOffset:
						compareResult = ( (ipHeader->fragmentOffset & 0x1FFF) - dp16[0] );
						break;		
					case kFilterIPOptions:
						// saved as null terminated list of integers
						// match if each specified option is present (or not present)
						{
							int i, offset;
							u_int8_t option;
							compareResult = 0;	// default for empty list of options
							i = 0;
							while ((option = dp8[i++])) {
								compareResult = -1;
								offset = 20;	// start of options in IP header
								while (offset < packet->ipHeaderLen) {
									if (packet->datagram[offset++] == 0) break;	// end of list
									if (packet->datagram[offset++] == 1) continue;	// NOP
									if (packet->datagram[offset] == option) {
										compareResult = 0;	// found it
										break;
									} 
									offset += packet->datagram[offset+1];	// skip option length
								}
								if ((compareResult != 0) && (entry->relation == kRelationEqual)) break;
								if ((compareResult == 0) && (entry->relation == kRelationNotEqual)) break;
							}
						}
						break;		
					case kFilterICMPType:
						// verify ICMP and get header
						compareResult = -1;
						if (ipHeader->protocol != IPPROTO_ICMP) break;
						icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
						// compare icmp type
						compareResult = icmpHeader->type - dp8[0];
						break;
					case kFilterICMPCode:
						// verify ICMP and get header
						compareResult = -1;
						if (ipHeader->protocol != IPPROTO_ICMP) break;
						icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
						// compare icmp code
						compareResult = icmpHeader->code - dp8[0];
						break;
				}	// switch(entry->property)
			}
		}	// < kFilter__2
		else {
			if (entry->property < kFilter__3) {
			  if (packet) {
				// BLOCK_3
				// setup access to IP headers
				ip_header_t* ipHeader;
				tcp_header_t* tcpHeader;
				u_int8_t tcpHeaderLen;
				ipHeader = (ip_header_t*)packet->datagram;
				switch(entry->property) {
					case kFilterTCPHeaderFlags:
						// saved as 8-bit ON mask and OFF mask
						compareResult = -1;
						if (ipHeader->protocol != IPPROTO_TCP) break;
						tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
						if ((tcpHeader->code & dp8[0]) != dp8[0]) break;	// all ON flags present?
						if ((tcpHeader->code & dp8[1]) != 0) break;			// all OFF flags absent?
						compareResult = 0;
						break;
					case kFilterTCPOptions:
						// saved as null terminated list of integers
						{
							int i, offset;
							u_int8_t option;
							// verify TCP and get header
							compareResult = -1;
							if (ipHeader->protocol != IPPROTO_TCP) break;
							tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
							tcpHeaderLen = (tcpHeader->hlen & 0xF0) >> 2;	// in bytes
							// match if each specified option is present (or not present)
							compareResult = 0;	// default for empty list of options
							i = 0;
							while ((option = dp8[i++])) {
								compareResult = -1;
								offset = packet->ipHeaderLen + 20;	// start of options in TCP header
								while (offset < packet->ipHeaderLen+tcpHeaderLen) {
									if (packet->datagram[offset++] == 0) break;	// end of list
									if (packet->datagram[offset++] == 1) continue;	// NOP
									if (packet->datagram[offset] == option) {
										compareResult = 0;	// found it
										break;
									} 
									offset += packet->datagram[offset+1];	// skip option length
								}
								if ((compareResult != 0) && (entry->relation == kRelationEqual)) break;
								if ((compareResult == 0) && (entry->relation == kRelationNotEqual)) break;
							}
						}
						break;		
					case kFilterSourcePort:
						// verify TCP or UDP and get header
						compareResult = -1;
						if ((ipHeader->protocol != IPPROTO_TCP) &&
							(ipHeader->protocol != IPPROTO_UDP)) break;
						tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
						// compare source port
						compareResult = tcpHeader->srcPort - dp16[0];
						// port range?
						if ((compareResult > 0) && dp16[1]) {
							compareResult = tcpHeader->srcPort - dp16[1];
							if (compareResult < 0) compareResult = 0;
						}
						break;
					case kFilterDestPort:
						// verify TCP or UDP and get header
						compareResult = -1;
						if ((ipHeader->protocol != IPPROTO_TCP) &&
							(ipHeader->protocol != IPPROTO_UDP)) break;
						tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
						// compare source port
						compareResult = tcpHeader->dstPort - dp16[0];
						// port range?
						if ((compareResult > 0) && dp16[1]) {
							compareResult = tcpHeader->dstPort - dp16[1];
							if (compareResult < 0) compareResult = 0;
						}
						break;
					case kFilterDataContent:
					{	
						KFT_contentSpec_t* content;
						content = (KFT_contentSpec_t *)&entry->propertyValue[0];
						// reset pointer since table was copied to NKE
						content->dataPtr = &content->data[0];
						if (entry->relation == kRelationIgnoreCase) content->flags |= kContentFlag_ignoreCase;
						else content->flags &= ~kContentFlag_ignoreCase;
						compareResult = KFT_matchContent(packet, content);
						// show what we found or searched but didn't find
						if (compareResult == 0) {
							packet->textOffset = packet->matchOffset;
							packet->textLength = content->length;
						}
						else {
							packet->textOffset = content->searchOffset;
							packet->textLength = 64;
						}
						break;
					}
					case kFilterURLKeyword:
					{	
						if (ipHeader->protocol != IPPROTO_TCP) break;
						// saved URL keyword as Pstring
						KFT_contentSpec_t content;
						// look for GET /key1/key2/key3
						content.searchOffset = 3;
						content.searchLength = 64;
						content.searchDelimiter = 13;
						content.flags = kContentFlag_ignoreCase + kContentFlag_useDelimiter;
						content.length = entry->propertyValue[0];
						content.dataPtr = &entry->propertyValue[1];
						compareResult = KFT_matchContent(packet, &content);
						if (compareResult == 0) {
							packet->textOffset = 4;
							packet->textLength = 64;
							break;	// found match
						}
						// look for "Host:"
						content.searchOffset = 64;
						content.searchLength = 255;
						//content.searchDelimiter = 0;
						content.flags = kContentFlag_ignoreCase;
						content.length = 5;
						content.dataPtr = (u_int8_t*)"Host:";
						compareResult = KFT_matchContent(packet, &content);
						if (compareResult != 0) break;	// no match
						else packet->textOffset = packet->matchOffset + 5;
						// look for keyword
						content.searchOffset = 5;
						content.searchLength = 128;
						content.searchDelimiter = 13;
						content.flags = kContentFlag_relativePlus + kContentFlag_ignoreCase + kContentFlag_useDelimiter;
						content.length = entry->propertyValue[0];
						content.dataPtr = &entry->propertyValue[1];
						compareResult = KFT_matchContent(packet, &content);
						if (compareResult != 0) break;	// no match
						packet->textLength = 64;
						break;
					}
				}	// switch(entry->property)
			  }	// if (packet)
			}	// < kFilter__3
			else {
				// BLOCK_4
				switch(entry->property) {
					case kFilterTimeOfDay:
					{
						// hh:mm or hh:mm-hh:mm  (FF for not a range)
						struct timeval tv;
						u_int32_t delta;
						int secondOfDay;
#if IPK_NKE
						getmicrotime(&tv);
#else
						gettimeofday(&tv, NULL);
#endif
						// update timeOfDay info
						delta = tv.tv_sec - PROJECT_timeOfDay.timeStamp;	// seconds
						if (delta > 10) {
							PROJECT_timeOfDay.timeStamp = tv.tv_sec;
							// seconds per day = 24 * 60 * 60 = 86400
							PROJECT_timeOfDay.day += delta / 86400;
							PROJECT_timeOfDay.secondOfDay += delta % 86400;
							if (PROJECT_timeOfDay.secondOfDay > 86400) {
								PROJECT_timeOfDay.day += PROJECT_timeOfDay.secondOfDay / 86400;
								PROJECT_timeOfDay.secondOfDay = PROJECT_timeOfDay.secondOfDay % 86400;
							}
						}
						// compare current time against rule
						secondOfDay = ((int)dp8[0] * 3600) + ((int)dp8[1] * 60);
						compareResult = PROJECT_timeOfDay.secondOfDay - secondOfDay;
						// test for range
						if ((compareResult > 0) && (dp8[2] != 0xFF)) {
							secondOfDay = ((int)dp8[2] * 3600) + ((int)dp8[3] * 60);
							compareResult = PROJECT_timeOfDay.secondOfDay - secondOfDay;
							if (compareResult < 0) compareResult = 0;
						}
						break;
					}
					case kFilterDayOfWeek:
					{
						// n or n-m  (FF for not a range)
						struct timeval tv;
						u_int32_t delta;
#if IPK_NKE
						getmicrotime(&tv);
#else
						gettimeofday(&tv, NULL);
#endif
						// update timeOfDay info
						delta = tv.tv_sec - PROJECT_timeOfDay.timeStamp;	// seconds
						if (delta > 10) {
							PROJECT_timeOfDay.timeStamp = tv.tv_sec;
							// seconds per day = 24 * 60 * 60 = 86400
							PROJECT_timeOfDay.day += delta / 86400;
							PROJECT_timeOfDay.secondOfDay += delta % 86400;
							if (PROJECT_timeOfDay.secondOfDay > 86400) {
								PROJECT_timeOfDay.day += PROJECT_timeOfDay.secondOfDay / 86400;
								PROJECT_timeOfDay.secondOfDay = PROJECT_timeOfDay.secondOfDay % 86400;
							}
						}
						// compare current day against rule
						compareResult = PROJECT_timeOfDay.day - dp8[0];
						// test for day range
						if ((compareResult > 0) && (dp8[1] != 0xFF)) {
							compareResult = PROJECT_timeOfDay.day - dp8[1];
							if (compareResult < 0) compareResult = 0;
						}
						break;
					}
					case kFilterDateAndTime:
						{
							// get current time
							struct timeval tv;
							#if IPK_NKE
							getmicrotime(&tv);
							#else
							gettimeofday(&tv, NULL);
							#endif
							compareResult = tv.tv_sec - dp32[0];
						}
						break;
					case kFilterIdleSeconds:
						if (!packet) {	// only match during filter update
							// get current time
							struct timeval tv;
							#if IPK_NKE
							getmicrotime(&tv);
							#else
							gettimeofday(&tv, NULL);
							#endif
							compareResult = (tv.tv_sec - kft_filterTable[index].lastTime) - dp32[0];
							if (entry->relation == kRelationEqual) {
								// we only test idle time every 10 seconds, so equal is approximate
								if ((-5 <= compareResult) && (compareResult <= 5)) compareResult = 0;
							}
						}
						break;
					case kFilterParentIdleSeconds:
						if (!packet) {	// only match during filter update
							// get current time
							struct timeval tv;
							#if IPK_NKE
							getmicrotime(&tv);
							#else
							gettimeofday(&tv, NULL);
							#endif
							parentIndex = indexOfParent(index);
							compareResult = (tv.tv_sec - kft_filterTable[parentIndex].lastTime) - dp32[0];
							if (entry->relation == kRelationEqual) {
								// we only test idle time every 10 seconds, so equal is approximate
								if ((-5 <= compareResult) && (compareResult <= 5)) compareResult = 0;
							}
						}
						break;
					case kFilterParentMatchCount:
						parentIndex = indexOfParent(index);
						// if (property == include) compare to include count
						if ((kft_filterTable[parentIndex].property == kFilterInclude) &&
							packet &&
							packet->triggerEntry) {
							compareResult = packet->triggerEntry->match.count - dp64[0];
						}
						else {
							compareResult = kft_filterTable[parentIndex].match.count - dp64[0];
						}
						break;
					case kFilterParentMatchRate:
						parentIndex = indexOfParent(index);
						compareResult = kft_filterTable[parentIndex].match.delta - dp64[0];
						break;
					case kFilterParentByteCount:
						parentIndex = indexOfParent(index);
						compareResult = kft_filterTable[parentIndex].byte.count - dp64[0];
						break;
				}	// switch(entry->property)
			}	// !< kFilter__3
		}	// !< kFilter__2
		// interpret compareResult based on relation
		if	(
				((entry->relation == kRelationEqual)			&& (compareResult == 0)) ||
				((entry->relation == kRelationNotEqual)			&& (compareResult != 0)) ||
				((entry->relation == kRelationGreaterOrEqual) 	&& (compareResult >= 0)) ||
				((entry->relation == kRelationLessOrEqual)		&& (compareResult <= 0)) ||
				((entry->relation == kRelationIgnoreCase)		&& (compareResult == 0))
			) {
			returnValue = KFT_tableAction(packet, ioIndex);
		}
		else *ioIndex += entry->nodeCount;
	} while (0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_matchContent()
// ---------------------------------------------------------------------------------
// Test packet for data content
// 16-bit search offset, 16-bit search length, 8-bit flags, pstring to match
// Output:
//  0 content match found
// -1 content match not found
int KFT_matchContent(KFT_packetData_t* packet, KFT_contentSpec_t* content)
{
	int compareResult = -1;	
	u_int8_t ignoreCase = content->flags & kContentFlag_ignoreCase;
	int16_t delimiter = -1;
	if (content->flags & kContentFlag_useDelimiter) delimiter = content->searchDelimiter;
	if (packet) do {
		mbuf_t mbuf_ref = *(packet->mbuf_ptr);
		PSData inBuf;
		// determine search starting and ending offset in datagram
		int contentOffset = packet->ipHeaderLen + packet->transportHeaderLen;
		int searchOffset = content->searchOffset;
		// adjust for relative offsets
		if (content->flags & kContentFlag_relativePlus) searchOffset = packet->matchOffset + searchOffset;
		else if (content->flags & kContentFlag_relativeMinus) searchOffset = packet->matchOffset - searchOffset;
		int searchStart = searchOffset + contentOffset;
		int searchEnd = searchStart + content->searchLength;
		// find data segments to search
		if (packet->segmentLen > searchStart) {
			inBuf.bytes = packet->datagram;
			inBuf.bufferLength = packet->segmentLen;
			inBuf.length = searchEnd;
			if (inBuf.length > inBuf.bufferLength) inBuf.length = inBuf.bufferLength;
			inBuf.offset = searchStart;
			compareResult = findInSegment(&inBuf, content->dataPtr, content->length, delimiter, ignoreCase);
			if (compareResult == 0) {
				packet->matchOffset = inBuf.offset - contentOffset;
				break;
			}
			else packet->matchOffset = 0;
		}
		// any more segments?
		int searchPos = packet->segmentLen;	// where we are in packet
		while ((mbuf_ref = mbuf_next(mbuf_ref))) {
			size_t len = mbuf_len(mbuf_ref);
			void* data = mbuf_data(mbuf_ref);
			if (searchPos >= searchEnd) break;
			if (searchStart > searchPos + len) {
				searchPos += len;
				continue;
			}
			inBuf.bytes = data;
			inBuf.bufferLength = len;
			inBuf.length = searchEnd - searchPos;
			if (inBuf.length > inBuf.bufferLength) inBuf.length = inBuf.bufferLength;
			inBuf.offset = 0;
			if (searchStart > searchPos) inBuf.offset = searchStart - searchPos;
			if (compareResult > 0) {
				// try to complete partial match
				int n = compareResult;
				if (ignoreCase)
					compareResult = compareIgnoreCase(inBuf.bytes, &content->dataPtr[n], content->length-n);
				else
					compareResult = memcmp(inBuf.bytes, &content->dataPtr[n], content->length-n);
				if (compareResult == 0) {
					packet->matchOffset = searchPos - n - contentOffset;
					break;
				}
				else packet->matchOffset = 0;
			}
			compareResult = findInSegment(&inBuf, content->dataPtr, content->length, delimiter, ignoreCase);
			if (compareResult == 0) {
				packet->matchOffset = inBuf.offset + searchPos - contentOffset;
				break;
			}
			else packet->matchOffset = 0;
			searchPos += mbuf_len(mbuf_ref);
		}
	} while (false);
	return compareResult;
}

// ---------------------------------------------------------------------------------
//	¥ indexOfParent()
// ---------------------------------------------------------------------------------
//	Find index of parent table entry
int indexOfParent(int index)
{
	int returnValue = 0;
//	int i;
//	for (i=index-1; i>0; i--) {
//		if ((i + kft_filterTable[i].nodeCount) > index) {
//			returnValue = i;
//			break;
//		}
//	}
	returnValue = kft_filterTable[index].parentIndex;
	return returnValue;
}

#if IPK_NKE
	#if TIGER
		// ---------------------------------------------------------------------------------
		//	¥ do_pullup()
		// ---------------------------------------------------------------------------------
		int do_pullup(mbuf_t *mbuf_ptr, size_t inSizeNeeded, int direction)
		{
			// remember original mbuf to determine if we got a new one
			mbuf_t m_orig = *mbuf_ptr;
			mbuf_t newM = *mbuf_ptr;
			errno_t status = 0;
			
			//if (newM->m_pkthdr.len < inSizeNeeded) {
			if (mbuf_pkthdr_len(newM) < inSizeNeeded) {
				#if DEBUG_IPK
					printf("do_pullup %8.8X, wanted %d bytes, only %d in packet!",
							newM, inSizeNeeded, mbuf_pkthdr_len(newM));
				#endif
				return ENOENT;
			}
			while ((mbuf_len(newM) < inSizeNeeded) && mbuf_next(newM)) {
				size_t total = mbuf_len(newM) + mbuf_len(mbuf_next(newM));
				size_t newSize = min(inSizeNeeded, total);
				status = mbuf_pullup(&newM, newSize);
				if (status != 0) {
					#if DEBUG_IPK
						printf("do_pullup(%8.8X, %d) - out of memory!", *mbuf_ptr, inSizeNeeded);
					#endif
					/* Packet has been destroyed. */
					*mbuf_ptr = newM;
					return status;
				}
				else {
					*mbuf_ptr = newM;
				}
			}
			// check if we have a new mbuf
			if (m_orig != *mbuf_ptr) {
				// new mbuf, retag it
				if (direction == kDirectionInbound) status = PROJECT_mtag(*mbuf_ptr, TAG_IN);
				else status = PROJECT_mtag(*mbuf_ptr, TAG_OUT);
			}
			return status;
		}
	#else
		// Jaguar/Panther
		// ---------------------------------------------------------------------------------
		//	¥ do_pullup()
		// ---------------------------------------------------------------------------------
		int do_pullup(mbuf_t *mbuf_ptr, size_t inSizeNeeded, int direction)
		{
			struct mbuf* newM = *mbuf_ptr;
			
			if (newM->m_pkthdr.len < inSizeNeeded) {
		#if DEBUG_IPK
				log(LOG_WARNING, "do_pullup %8.8X, wanted %d bytes, only %d in packet!",
						newM, inSizeNeeded, newM->m_pkthdr.len);
		#endif
				return ENOENT;
			}
			while ((newM->m_len < inSizeNeeded) && newM->m_next) {
				unsigned int total = 0;
				total = newM->m_len + (newM->m_next)->m_len;
				
				if ((newM = m_pullup(newM, min(inSizeNeeded, total))) == NULL) {
		#if DEBUG_IPK
					log(LOG_WARNING, "do_pullup(%8.8X, %d) - out of memory!", *mbuf_ptr, inSizeNeeded);
		#endif
					/* Packet has been destroyed. */
					*mbuf_ptr = newM;
					return ENOMEM;
				} else
					*mbuf_ptr = newM;
			}
			return 0;
		}
	#endif
#endif

#pragma mark --- BRIDGING ---
// ---------------------------------------------------------------------------------
//	¥ KFT_bridge()
// ---------------------------------------------------------------------------------
// perform Ethernet bridging
// returns: 0 continue normal packet processing, EJUSTRETURN packet was deleted, other UNIX error
//
// *** Intel Compatibility Note ***
// Because KFT_bridge may duplicate or copy packets with reference count shared clusters,
// it needs to be outside the byte swapping boundary.  Packets must be passed in Network Byte order.
int KFT_bridge(KFT_packetData_t* packet)
{
	int returnValue = 0;
	// defensive, test if packet was deleted
	if (*packet->mbuf_ptr == NULL) return EJUSTRETURN;
	// Bridge Ethernet packets only
	if (packet->ifType == IFT_ETHER) do {
		EthernetAddress_t srcAddress;
		EthernetAddress_t dstAddress;
		u_int8_t* ha;
		KFT_bridgeEntry_t* bridgeEntry;
		u_int32_t attachIndex;
		u_int8_t bridgeDirection;
		int i;
		
		if (packet->direction == kDirectionOutbound) {
			ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
		}
		else ha = (u_int8_t*)*packet->frame_ptr;
		#if TEST_BRIDGING
			printf("\nKFT_bridge receive packet on %s ",
				packet->myAttach->kftInterfaceEntry.bsdName);
			if (packet->direction == kDirectionOutbound) printf("outbound");
			else  printf("inbound");
			printf("\n-- dst %02x:%02x:%02x:%02x:%02x:%02x src %02x:%02x:%02x:%02x:%02x:%02x type %02x%02x",
				ha[0],ha[1],ha[2],ha[3],ha[4],ha[5],ha[6],ha[7],ha[8],ha[9],ha[10],ha[11],ha[12],ha[13]);			
		#endif		
		// get dst and src hardware address dst[6] src[6] type[2]
		memcpy(&dstAddress, &ha[0], ETHER_ADDR_LEN);
		memcpy(&srcAddress, &ha[6], ETHER_ADDR_LEN);
		// -- Listen and Learn --
		// check for source in bridge table and add if needed
		bridgeEntry = KFT_bridgeFind(&srcAddress);
		if (bridgeEntry) {
			if (bridgeEntry->flags & kBridgeFlagOutbound) bridgeDirection = kDirectionOutbound;
			else bridgeDirection = kDirectionInbound;
			// confirm that interface and direction matches previously recorded
			if ( (bridgeEntry->attachIndex != packet->myAttach->attachIndex) ||
				 (bridgeDirection != packet->direction) ) {
				#if TEST_BRIDGING
					printf("\nKFT_bridge port conflict from: %s",
						packet->myAttach->kftInterfaceEntry.bsdName);
					printf(" %02x:%02x:%02x:%02x:%02x:%02x",
						ha[6],ha[7],ha[8],ha[9],ha[10],ha[11]);
				#endif
				// port conflict
				if (bridgeDirection == kDirectionOutbound) {
					// packet sent from local interface arrived from a different interface or direction
					// loop detected, stop interface that sent this packet from bridge-forwarding packets
					PROJECT_attach[bridgeEntry->attachIndex].muteOn = 1;
					break;  // don't bridge this packet
				} else {
					// host has moved or possible loop
					if (bridgeEntry->conflictCount < 15) {
						bridgeEntry->conflictCount += 1;
					}
					if (bridgeEntry->conflictCount > 10) {
						// loop detected, stop this interface from bridge-forwarding packets
						packet->myAttach->muteOn = 1;
						break;  // don't bridge this packet
					}
					// update entry for new port and direction
					bridgeEntry->attachIndex = packet->myAttach->attachIndex;
					if (packet->direction == kDirectionOutbound) bridgeEntry->flags |= kBridgeFlagOutbound;
					else bridgeEntry->flags &= ~kBridgeFlagOutbound;
				}
			}
		}
		if (!bridgeEntry) {
			KFT_bridgeAddPacket(packet);	// cannot fail since bridge table is hashed array
			#if TEST_BRIDGING
				printf("\nKFT_bridge %s has seen",
					packet->myAttach->kftInterfaceEntry.bsdName);
				if (packet->direction == kDirectionOutbound) printf(" outbound from");
				else  printf(" inbound from");
				printf(" %02x:%02x:%02x:%02x:%02x:%02x",
					ha[6],ha[7],ha[8],ha[9],ha[10],ha[11]);
			#endif
		}
		// test if interface is muted
		if (packet->myAttach->muteOn) break;
		// -- Bridge Forward --
		// now look for destination in table
		bridgeEntry = KFT_bridgeFind(&dstAddress);
		if (!bridgeEntry) {
			// no entry found, forward to other bridge enabled interfaces
			for (i=1; i<=kMaxAttach; i++) {
				if (PROJECT_attach[i].kftInterfaceEntry.bridgeOn) {
					// skip the interface packet arrived on since we'll forward as part of normal processing
					if (i != packet->myAttach->attachIndex) {
						#if TEST_BRIDGING
							printf("\nKFT_bridge broadcast");
							printf(" outbound");
							printf(" to %s %02x:%02x:%02x:%02x:%02x:%02x",
								PROJECT_attach[i].kftInterfaceEntry.bsdName,
								ha[0],ha[1],ha[2],ha[3],ha[4],ha[5]);
							printf(" from %s %02x:%02x:%02x:%02x:%02x:%02x",
								packet->myAttach->kftInterfaceEntry.bsdName,
								ha[6],ha[7],ha[8],ha[9],ha[10],ha[11]);
						#endif
						// output packet to corresponding ports
						{
							ifnet_t ifnet_ref = PROJECT_attach[i].ifnet_ref;
							u_int8_t copy = 1;
							KFT_bridgeOutput(packet, ifnet_ref, i, kDirectionOutbound, copy);
							// Don't forward inbound to other ports since promiscuous will be ignored.
							// Exception is for broadcast since some protocols (like ARP & DHCP) are
							// sensitive to which interface packets arrive from.
							// Don't forward our own broadcasts (Tiger will complain).
							if (packet->direction == kDirectionInbound) {
								if ( EA_MATCH(&dstAddress, &broadcastAddress) ) {
									//ik_findIFNet(PROJECT_attach[i].kftInterfaceEntry.bsdName, &ifnet_ref);
									KFT_bridgeOutput(packet, ifnet_ref, i, kDirectionInbound, copy);
								}
							}
						}
					}   // if (i != packet->myAttach->attachIndex) {
					#if TEST_BRIDGING
					else {
						printf("\nKFT_bridge forward (broadcast)");
						if (packet->direction == kDirectionOutbound) printf(" outbound");
						printf(" to %s %02x:%02x:%02x:%02x:%02x:%02x",
							packet->myAttach->kftInterfaceEntry.bsdName,
							ha[0],ha[1],ha[2],ha[3],ha[4],ha[5]);
						printf(" from %s %02x:%02x:%02x:%02x:%02x:%02x",
							packet->myAttach->kftInterfaceEntry.bsdName,
							ha[6],ha[7],ha[8],ha[9],ha[10],ha[11]);
					}
					#endif
				}	//	if (PROJECT_attach[i].kftInterfaceEntry.bridgeOn) {
			}	//	for (i=1; i<=kMaxAttach; i++) {
		}
		else {
			// found a bridge entry
			if ((attachIndex = bridgeEntry->attachIndex)) { // make sure we have a valid attach index
				// flip direction to inject where we saw from
				if (bridgeEntry->flags & kBridgeFlagOutbound) bridgeDirection = kDirectionInbound;
				else bridgeDirection = kDirectionOutbound;
				
				// If destination port matches, no further action required
				// since we'll forward the packet as part of normal processing.
				if (attachIndex != packet->myAttach->attachIndex) {
					// bridge entry points to a different port, try to inject packet there
					// make sure filterID is still valid and bridging on that interface is enabled
					if (PROJECT_attach[attachIndex].kftInterfaceEntry.bridgeOn) {
						#if TEST_BRIDGING
							printf("\nKFT_bridge unicast");
							if (bridgeDirection == kDirectionOutbound) printf(" outbound");
							printf(" to %s %02x:%02x:%02x:%02x:%02x:%02x",
								PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName,
								ha[0],ha[1],ha[2],ha[3],ha[4],ha[5]);
							printf(" from %s %02x:%02x:%02x:%02x:%02x:%02x",
								packet->myAttach->kftInterfaceEntry.bsdName,
								ha[6],ha[7],ha[8],ha[9],ha[10],ha[11]);
						#endif
						// if flipping direction, re-tag packet for new direction
						if (packet->direction == kDirectionOutbound) {
							if (bridgeDirection != kDirectionOutbound) {
								returnValue = PROJECT_mtag(*packet->mbuf_ptr, TAG_IN);
								if (returnValue != 0) return returnValue;
							}
						}
						else {
							if (bridgeDirection == kDirectionOutbound) {
								returnValue = PROJECT_mtag(*packet->mbuf_ptr, TAG_OUT);
								if (returnValue != 0) return returnValue;
							}
						}
						// get ifnet_ref for corresponding interface
							// We have to be careful on Panther because interfaces can disappear.
							// This should cause corresponding interface to detach before we try to use
							// this ifnet pointer.
						ifnet_t ifnet_ref = PROJECT_attach[attachIndex].ifnet_ref;
						//ik_findIFNet(PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName, &ifnet_ref);
						u_int8_t copy = 0;
						// output packet to corresponding port
						returnValue = KFT_bridgeOutput(packet, ifnet_ref, attachIndex, bridgeDirection, copy);
						returnValue = EJUSTRETURN;
					}
				}   // if (attachIndex != packet->myAttach->attachIndex) {
				#if TEST_BRIDGING
				else {
					printf("\nKFT_bridge forward (unicast)");
					if (packet->direction == kDirectionOutbound) printf(" outbound");
					printf(" to %s %02x:%02x:%02x:%02x:%02x:%02x",
						packet->myAttach->kftInterfaceEntry.bsdName,
						ha[0],ha[1],ha[2],ha[3],ha[4],ha[5]);
					printf(" from %s %02x:%02x:%02x:%02x:%02x:%02x",
						packet->myAttach->kftInterfaceEntry.bsdName,
						ha[6],ha[7],ha[8],ha[9],ha[10],ha[11]);
				}
				#endif
			}
		}
	} while (false);	// if (packet->ifType == IFT_ETHER) do {
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_bridgeOutput()
// ---------------------------------------------------------------------------------
// send a copy of the packet to the corresonding port (interface and direction)
// ifnet_ref is the interface we are sending on used as receive from interface to pass up the stack
// Injecting an mbuf copy cannot be deferred.  Use a different path for deferred re-routing.
//
// *** Intel Compatibility Note ***
// Because KFT_bridgeOutput may duplicate or copy packets with reference count shared clusters,
// it needs to be outside the byte swapping boundary when copy is used.
// Packets must be passed in Network Byte order.
int KFT_bridgeOutput(KFT_packetData_t* packet, ifnet_t ifnet_ref, u_int8_t attachIndex,
	u_int8_t bridgeDirection, u_int8_t copy)
{
	int returnValue = 0;
#if IPK_NKE
	u_int8_t* dp;
	mbuf_t mbuf_ref;
	char* frame_header;
	int ipOffset = packet->ipOffset;
#endif	
	do {
		#if IPK_NKE
			mbuf_ref = *packet->mbuf_ptr;
			// copy the mbuf (if needed) so we don't consume it
			if (copy) {
				#if TIGER
					//returnValue = mbuf_copym(mbuf_ref, 0, MBUF_COPYALL, MBUF_DONTWAIT, &mbuf_ref);
					returnValue = mbuf_dup(mbuf_ref, MBUF_DONTWAIT, &mbuf_ref);
					if (returnValue != 0) break;
					// tag new mbuf so we don't try to process it again
					if (bridgeDirection == kDirectionOutbound) returnValue = PROJECT_mtag(mbuf_ref, TAG_OUT);
					else returnValue = PROJECT_mtag(mbuf_ref, TAG_IN);
					if (returnValue != 0) break;
				#else
					//mbuf_ref = m_copy(mbuf_ref, 0, M_COPYALL);
					mbuf_ref = m_dup(mbuf_ref, M_DONTWAIT);
					if (!mbuf_ref) break;  // m_copy failed
				#endif
			}
			else {
				// tell caller packet was consumed
				*packet->mbuf_ptr = NULL;
			}
			if (bridgeDirection == kDirectionOutbound) {
				// inject outbound
				if (packet->direction == kDirectionInbound) {
					// original packet was inbound
					// turn off hardware checksum flags for received packets being injected outbound
					#if TIGER
						mbuf_inbound_modified(mbuf_ref);		// mbuf->m_pkthdr.csum_flags = 0;
						mbuf_clear_csum_requested(mbuf_ref);	// mbuf->m_pkthdr.csum_data = 0;
					#else
						mbuf_ref->m_pkthdr.csum_data = 0;
						mbuf_ref->m_pkthdr.csum_flags = 0;
					#endif
					// make room for frame header in mbuf and copy it over
					frame_header = *packet->frame_ptr;
					#if TIGER
						returnValue = mbuf_prepend(&mbuf_ref, packet->ifHeaderLen, MBUF_DONTWAIT);
						if (returnValue != 0) break;
						dp = mbuf_data(mbuf_ref);
					#else
						M_PREPEND(mbuf_ref, packet->ifHeaderLen, M_DONTWAIT);
						if (!mbuf_ref) break;  // M_PREPEND failed
						dp = mtod(mbuf_ref, u_int8_t*);
					#endif
					bcopy(frame_header, dp, packet->ifHeaderLen);
					ipOffset += packet->ifHeaderLen;	// adjust ipOffset
				}
				// inject packet to corresponding interface
	// --------------
	// <<< Packet Out
	// --------------
				returnValue = PROJECT_inject_output(mbuf_ref, ipOffset, attachIndex, ifnet_ref, packet->swap);
					#if TEST_BRIDGING
						printf("\n  .. bridge inject outbound to %s%d from %s%d result %d",
							ifnet_name(ifnet_ref), ifnet_unit(ifnet_ref),
							ifnet_name(packet->ifnet_ref), ifnet_unit(packet->ifnet_ref),
							returnValue );
					#endif
				mbuf_ref = NULL;	// mbuf was consumed
			}
			else {
				// inject inbound
				#if TIGER
					// set corresponding recv_if
					returnValue = mbuf_pkthdr_setrcvif(mbuf_ref, ifnet_ref);
					// setup frame header
					if (packet->direction == kDirectionInbound) {
						// original packet was inbound
						// mark as modified since we changed rcvif?
							// mbuf_inbound_modified(mbuf_ref);
						// turn off M_PROMISC flag for received packets being redirected
						mbuf_setflags_mask(mbuf_ref, 0, MBUF_PROMISC);
						// fast path, just re-direct
						if (copy == 0) {
							mbuf_pkthdr_setheader(mbuf_ref, *packet->frame_ptr);
							// inject
	// --------------
	// <<< Packet Out
	// --------------
							returnValue = PROJECT_inject_input(mbuf_ref, ipOffset, attachIndex, ifnet_ref, NULL, packet->swap);
							mbuf_ref = NULL;	// mbuf was consumed
							#if TEST_BRIDGING
								printf("\n  .. fastpath bridge inject inbound to %s%d from %s%d result %d",
									ifnet_name(ifnet_ref), ifnet_unit(ifnet_ref),
									ifnet_name(packet->ifnet_ref), ifnet_unit(packet->ifnet_ref),
									returnValue );
							#endif
							break;
						}
						// prepend frame header
						returnValue = mbuf_prepend(&mbuf_ref, packet->ifHeaderLen, MBUF_DONTWAIT);
						if (returnValue != 0) break;
						dp = mbuf_data(mbuf_ref);
						bcopy(*packet->frame_ptr, dp, packet->ifHeaderLen);
						ipOffset += packet->ifHeaderLen;	// adjust ipOffset
					}
					// packet was outbound or includes frame header
					frame_header = mbuf_data(mbuf_ref);
					size_t len;
					void* data;
					len = mbuf_len(mbuf_ref) - packet->ifHeaderLen;
					data = mbuf_data(mbuf_ref) + packet->ifHeaderLen;
					mbuf_setdata(mbuf_ref, data, len);
					len = mbuf_pkthdr_len(mbuf_ref) - packet->ifHeaderLen;
					mbuf_pkthdr_setlen(mbuf_ref, len);
					mbuf_pkthdr_setheader(mbuf_ref, frame_header);
					ipOffset -= packet->ifHeaderLen;	// adjust ipOffset
					// inject
	// --------------
	// <<< Packet Out
	// --------------
					returnValue = PROJECT_inject_input(mbuf_ref, ipOffset, attachIndex, ifnet_ref, NULL, packet->swap);
					mbuf_ref = NULL;	// mbuf was consumed
					#if TEST_BRIDGING
						printf("\n  .. bridge inject inbound to %s%d from %s%d result %d",
							ifnet_name(ifnet_ref), ifnet_unit(ifnet_ref),
							ifnet_name(packet->ifnet_ref), ifnet_unit(packet->ifnet_ref),
							returnValue );
					#endif
				#else
					// set corresponding recv_if
					mbuf_ref->m_pkthdr.rcvif = ifnet_ref;
					// setup frame_header
					if (packet->direction == kDirectionInbound) {
						// original packet was inbound
						// fast path, just re-direct
						if (copy == 0) {
							// inject
							returnValue = PROJECT_inject_input(mbuf_ref, ipOffset, attachIndex, ifnet_ref, *packet->frame_ptr, packet->swap);
							mbuf_ref = NULL;	// mbuf was consumed
							break;
						}
						// prepend frame header
						M_PREPEND(mbuf_ref, packet->ifHeaderLen, M_DONTWAIT);
						if (!mbuf_ref) break;  // M_PREPEND failed
						dp = mtod(mbuf_ref, u_int8_t*);
						bcopy(*packet->frame_ptr, dp, packet->ifHeaderLen);
						ipOffset += packet->ifHeaderLen;	// adjust ipOffset
					}
					// packet was outbound or includes frame header
					frame_header = mbuf_ref->m_data;
					mbuf_ref->m_data += packet->ifHeaderLen;
					mbuf_ref->m_len -= packet->ifHeaderLen;			// length of data in this mbuf
					mbuf_ref->m_pkthdr.len -= packet->ifHeaderLen;		// total length of packet
					ipOffset -= packet->ifHeaderLen;	// adjust ipOffset
					// inject
					returnValue = PROJECT_inject_input(mbuf_ref, ipOffset, attachIndex, ifnet_ref, frame_header, packet->swap);
					mbuf_ref = NULL;	// mbuf was consumed
				#endif
			}
		#else
			int value = attachIndex;
			if (bridgeDirection == kDirectionInbound)
				KFT_logText("\nKFT_bridgeOutput inject packet inbound to attachIndex:", &value);
			else
				KFT_logText("\nKFT_bridgeOutput inject packet outbound to attachIndex:", &value);
		#endif	
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_reversePacket()
// ---------------------------------------------------------------------------------
// Reverse packet direction (inbound <=> outbound)
// Move frame header and swap src/dst MAC addresses
int KFT_reversePacket(KFT_packetData_t* packet)
{
	int returnValue = 0;
#if IPK_NKE
	u_int8_t* dp;
	mbuf_t mbuf_ref;
	char* frame_header;

	do {
		// Turn off hardware checksum flags for received packets being injected outbound.
		// Finalize outbound packets before injecting inbound.
		PROJECT_modifyReadyPacket(packet);
		// get mbuf pointer
		mbuf_ref = *packet->mbuf_ptr;
		// swap src and dst MAC address so packet won't be flagged as M_PROMISC when demux is called
		{
			// get pointer to hardware address
			u_int8_t* ha;
			if (packet->direction == kDirectionInbound) ha = (u_int8_t*)*packet->frame_ptr;
			else ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
			if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
				// swap Ethernet src, dst
				u_int8_t buf[8];
				memcpy(&buf[0], &ha[6], ETHER_ADDR_LEN);
				memcpy(&ha[6], &ha[0], ETHER_ADDR_LEN);
				memcpy(&ha[0], &buf[0], ETHER_ADDR_LEN);
			}	
		}
		if (packet->direction == kDirectionInbound) {
			// original packet was inbound (will be injected outbound)
			// make room for frame header in mbuf and copy it over
			frame_header = *packet->frame_ptr;
			#if TIGER
				returnValue = mbuf_prepend(packet->mbuf_ptr, packet->ifHeaderLen, MBUF_DONTWAIT);
				mbuf_ref = *packet->mbuf_ptr;
				if (returnValue != 0) break;
				dp = mbuf_data(mbuf_ref);
			#else
				M_PREPEND(*packet->mbuf_ptr, packet->ifHeaderLen, M_DONTWAIT);
				mbuf_ref = *packet->mbuf_ptr;
				if (!mbuf_ref) break;  // M_PREPEND failed
				dp = mtod(mbuf_ref, u_int8_t*);
			#endif
			bcopy(frame_header, dp, packet->ifHeaderLen);
			packet->ipOffset += packet->ifHeaderLen;	// adjust ipOffset
			// re-tag packet for new direction
			returnValue = PROJECT_mtag(*packet->mbuf_ptr, TAG_OUT);
			if (returnValue != 0) {
				mbuf_freem(*packet->mbuf_ptr);
				*packet->mbuf_ptr = NULL;	// mbuf was consumed
				packet->datagram = NULL;
				break;
			}
			// update packet to reflect new direction
			packet->direction = kDirectionOutbound;
		}
		else {
			// original packet was outbound (will be injected inbound)
			mbuf_ref = *packet->mbuf_ptr;
			#if TIGER
				// set corresponding recv_if
				returnValue = mbuf_pkthdr_setrcvif(mbuf_ref, packet->ifnet_ref);
				// setup frame header
				frame_header = mbuf_data(mbuf_ref);
				size_t len;
				void* data;
				len = mbuf_len(mbuf_ref) - packet->ifHeaderLen;
				data = mbuf_data(mbuf_ref) + packet->ifHeaderLen;
				mbuf_setdata(mbuf_ref, data, len);
				len = mbuf_pkthdr_len(mbuf_ref) - packet->ifHeaderLen;
				mbuf_pkthdr_setlen(mbuf_ref, len);
				mbuf_pkthdr_setheader(mbuf_ref, frame_header);
				packet->ipOffset -= packet->ifHeaderLen;	// adjust ipOffset
				// inject
//				returnValue = PROJECT_inject_input(mbuf_ref, ipOffset, attachIndex, ifnet_ref, NULL, packet->swap);
//				mbuf_ref = NULL;	// mbuf was consumed
			#else
				// set corresponding recv_if
				mbuf_ref->m_pkthdr.rcvif = packet->ifnet_ref;
				// setup frame_header
				// packet was outbound or includes frame header
				frame_header = mbuf_ref->m_data;
				mbuf_ref->m_data += packet->ifHeaderLen;
				mbuf_ref->m_len -= packet->ifHeaderLen;			// length of data in this mbuf
				mbuf_ref->m_pkthdr.len -= packet->ifHeaderLen;		// total length of packet
				packet->ipOffset -= packet->ifHeaderLen;	// adjust ipOffset
				// inject
//				returnValue = PROJECT_inject_input(mbuf_ref, ipOffset, attachIndex, ifnet_ref, frame_header, packet->swap);
//				mbuf_ref = NULL;	// mbuf was consumed
			#endif
			// re-tag packet for new direction
			returnValue = PROJECT_mtag(*packet->mbuf_ptr, TAG_IN);
			if (returnValue != 0) return returnValue;			
			// update packet to reflect new direction
			packet->direction = kDirectionInbound;
		}
	} while (0);
	// put back possibly modified pointers
	*packet->frame_ptr = frame_header;
#endif	
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_lateralPut()
// ---------------------------------------------------------------------------------
// Shift packet to a different data link
int KFT_lateralPut(KFT_packetData_t* packet, int attachIndex)
{
	int returnValue = EINVAL;
	do {
		// check if we're already on the requested link
		if (attachIndex == packet->myAttach->attachIndex) break;
		// verify that new attachIndex is valid
		if (!PROJECT_attach[attachIndex].ifnet_ref) break;
		// make sure packet has been finalized
		PROJECT_modifyReadyPacket(packet);
		// do lateral
		if (packet->direction == kDirectionInbound) {
			// inbound
			// turn off M_PROMISC flag for received packets being redirected
#if (IPK_NKE & TIGER)
			mbuf_t mbuf_ref = *packet->mbuf_ptr;
			mbuf_setflags_mask(mbuf_ref, 0, MBUF_PROMISC);
#endif
		}
		else {
			// outbound
			// update source MAC address to reflect new data link
			u_int8_t* ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
			if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
				memcpy(&ha[6], &PROJECT_attach[attachIndex].ea, ETHER_ADDR_LEN);
			}	
		}
		// remember new destination data link
		packet->redirect.attachIndex = attachIndex;
		// update packet to associate with this attach point
		packet->myAttach = (attach_t*)&PROJECT_attach[attachIndex];
		returnValue = 0;
	} while (0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_doRedirect()
// ---------------------------------------------------------------------------------
// Inject packet to corresponding link based on redirect info (if any)
int KFT_doRedirect(KFT_packetData_t* packet)
{
	int returnValue = 0;
	u_int8_t attachIndex = packet->redirect.attachIndex;
	if (!attachIndex) attachIndex = packet->redirect.originalAttachIndex;
	do {
		// check for valid redirect info
		if ((attachIndex <= 0) || (attachIndex > kMaxAttach)) break;
		if ((attachIndex != packet->redirect.originalAttachIndex) ||
			(packet->direction != packet->redirect.originalDirection)) {
#if IPK_NKE
			mbuf_t mbuf_ref = *packet->mbuf_ptr;
			int ipOffset = packet->ipOffset;
			ifnet_t ifnet_ref = PROJECT_attach[attachIndex].ifnet_ref;
				// --------------
				// <<< Packet Out
				// --------------
			if (packet->direction == kDirectionOutbound) {
				returnValue = PROJECT_inject_output(mbuf_ref, ipOffset, attachIndex, ifnet_ref, packet->swap);
				#if 0
					KFT_logText4("\nKFT_doRedirect inject packet outbound to:",
						PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName, NULL, NULL);
					if (returnValue) KFT_logText("\nKFT_doRedirect inject error: ", &returnValue);
				#endif
			}
			else {
				char* frame_header = *packet->frame_ptr;
				returnValue = PROJECT_inject_input(mbuf_ref, ipOffset, attachIndex, ifnet_ref, frame_header, packet->swap);
				#if 0
					KFT_logText4("\nKFT_doRedirect inject packet inbound to:",
						PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName, NULL, NULL);
					if (returnValue) KFT_logText("\nKFT_doRedirect inject error: ", &returnValue);
				#endif
			}
#else
			if (packet->direction == kDirectionOutbound) {
				KFT_logText4("\nKFT_doRedirect inject packet outbound to:",
					PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName, NULL, NULL);
			}
			else {
				KFT_logText4("\nKFT_doRedirect inject packet inbound to:",
					PROJECT_attach[attachIndex].kftInterfaceEntry.bsdName, NULL, NULL);
			}
#endif
			*packet->mbuf_ptr = NULL;	// mbuf was consumed
			returnValue = EJUSTRETURN;  // terminate packet processing without releasing mbuf chain
		}
	} while (0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_reflectPacket()
// ---------------------------------------------------------------------------------
// Turn packet around by injecting it back to the data link it came from.
//
// A "reflector" can be used as an alternate loopback address to force local packets
// through our NKE for NAT processing.  Notice we send outbound packets back up the
// stack and tag them so they are not processed by the NKE in the reverse direction.
// Any reverse processing should be done before invoking the reflector.
int KFT_reflectPacket(KFT_packetData_t* packet)
{
	int returnValue = 0;
	do {
		returnValue = KFT_reversePacket(packet);
		if (returnValue != 0) break;
		returnValue = KFT_doRedirect(packet);
	} while (false);
	return returnValue;
}


#pragma mark --- ROUTE_TO ---
// ---------------------------------------------------------------------------------
//	¥ KFT_resolveRouteTo()
// ---------------------------------------------------------------------------------
// Try to find corresponding attach index and direction for next hop IP address
int KFT_resolveRouteTo(u_int32_t routeNextHop, u_int8_t* attachIndex, u_int8_t* direction)
{
	int returnValue = -1;	// not found
	u_int8_t i;
	u_int32_t address, mask;
	for (i=1; i<kMaxAttach; i++) {
		address = PROJECT_attach[i].kftInterfaceEntry.ifNet.address;
		mask	= PROJECT_attach[i].kftInterfaceEntry.ifNet.mask;
		if ((routeNextHop & mask) == (address & mask)) {
			// found matching network
			*attachIndex = i;
			// if next hop is local IP interface
			if (routeNextHop == address) *direction = kDirectionInbound;
			else *direction = kDirectionOutbound;
			returnValue = 0;
			break;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_setRouteToAddress()
// ---------------------------------------------------------------------------------
// set hardware address in packet for routeTo filter action
int KFT_setRouteToAddress(KFT_filterEntry_t* entry, KFT_packetData_t* packet)
{
	int returnValue = 0;
	u_int8_t* ha;
	// have packet and hw address
	if (*packet->mbuf_ptr) {
		// get pointer to hardware address
		if (packet->direction == kDirectionInbound) ha = (u_int8_t*)*packet->frame_ptr;
		else ha = (u_int8_t*)mbuf_data(*packet->mbuf_ptr);
		// confirm header type
		if (packet->ifType == IFT_ETHER) {
			memcpy(ha, entry->routeHardwareAddress, ETHER_ADDR_LEN);
		}
		else if (packet->ifType == IFT_IEEE1394) {
			memcpy(ha, entry->routeHardwareAddress, FIREWIRE_EUI64_LEN);
		}
	}
	return returnValue;
}

#pragma mark --- FILTER_ACTIONS ---
// ---------------------------------------------------------------------------------
//	¥ KFT_tableAction()
// ---------------------------------------------------------------------------------
//	Perform table actions for KFT_processPacket()
//	Pass in both the packet and index of corresponding filter rule (used to perform action)
//  packet may be NULL for timer based actions
int KFT_tableAction(KFT_packetData_t* packet, int* ioIndex)
{
	int returnValue = 0;
	int result;
	mbuf_t mbuf_ref = NULL;
	KFT_filterEntry_t* entry;
	// get pointer to table entry
	entry = &kft_filterTable[*ioIndex];
	// bump counters for this rule
		// idleSeconds
	// get current time
	struct timeval tv;
	#if IPK_NKE
	getmicrotime(&tv);
	#else
	gettimeofday(&tv, NULL);
	#endif
	entry->lastTime = tv.tv_sec;
		// matchCount
	//entry->match.count += 1;
	myOSAddAtomic64(1, (SInt64*)&entry->match.count);
		// byteCount
	if (packet) {
		mbuf_ref = *(packet->mbuf_ptr);
		if (mbuf_ref) {	// in case mbuf was previously consumed
			int len = mbuf_pkthdr_len(mbuf_ref) - packet->ipOffset;
			//entry->byte.count += mbuf_ref->m_pkthdr.len;
			myOSAddAtomic64(len, (SInt64*)&entry->byte.count);
		}
		packet->kftEntry = entry;	// set matching entry
	}
	// handle table actions (Next, Skip)
	if (entry->filterAction == kActionLevelNext) *ioIndex += 1;
	else if (entry->filterAction == kActionLevelSkip) {
		// skip next in table
		*ioIndex += 1;	// point to next rule regardless of level
		if (*ioIndex < kft_filterNextEntry) {
			entry = &kft_filterTable[*ioIndex];
			*ioIndex += entry->nodeCount;	// skip it
		}
	}
	// "kActionGroup" is just a marker for KActionExitGroup
	else if (entry->filterAction == KActionExitGroup) {
		// walk tree backward to look for parent "Group"
		KFT_filterEntry_t* parentEntry;
		int parentIndex = indexOfParent(*ioIndex);
		while (parentIndex > 0) {
			parentEntry = &kft_filterTable[parentIndex];
			if (parentEntry->filterAction == kActionGroup) {
				*ioIndex = parentIndex + parentEntry->nodeCount;
				break;
			}
			// backup to next parent
			parentIndex = indexOfParent(parentIndex);
		}
	}
	// handle triggers
	else if (entry->filterAction == kActionTrigger) {
		// trigger
		result = KFT_triggerPacket(packet, kTriggerTypeTrigger);
		if (result != 0) KFT_logText("\nKFT_tableAction - trigger not added, out of memory ", &result);
		returnValue = KFT_filterAction(packet, ioIndex, kActionDelete);
	}
	else if (entry->filterAction == kActionAuthorize) {
		// keep source address
		result = KFT_triggerPacket(packet, kTriggerTypeAuthorize);
		if (result != 0) KFT_logText("\nKFT_tableAction - trigger not added, out of memory ", &result);
		// advance to next rule
		*ioIndex += 1;
	}
	else if (entry->filterAction == kActionKeepInvalid) {
		// keep source address
		result = KFT_triggerPacket(packet, kTriggerTypeInvalid);
		if (result != 0) KFT_logText("\nKFT_tableAction - trigger not added, out of memory ", &result);
		// advance to next rule
		*ioIndex += 1;
	}
	else if (entry->filterAction == kActionKeepAddress) {
		// keep source address
		result = KFT_triggerPacket(packet, kTriggerTypeAddress);
		if (result != 0) KFT_logText("\nKFT_tableAction - trigger not added, out of memory ", &result);
		// advance to next rule
		*ioIndex += 1;
	}
	else if (entry->filterAction == kActionDelay) {
		// delay
		*ioIndex = kft_filterNextEntry;	// done matching table
		returnValue = KFT_delayAdd(packet);
	}
	else if (entry->filterAction == kActionResetParent) {
		// reset parent matchCount
		int parentIndex = indexOfParent(*ioIndex);
		// if (property == include trigger) reset include count
		if ((kft_filterTable[parentIndex].property == kFilterInclude) &&
			//(kft_filterTable[parentIndex].propertyValue[0] == kIncludeAddress) &&
			packet &&
			packet->triggerEntry) {
			packet->triggerEntry->match.count = 0;
		}
		kft_filterTable[parentIndex].match.count = 0;
		// advance to next rule
		*ioIndex += 1;
	}
	// callback to perform filter actions
	else returnValue = KFT_filterAction(packet, ioIndex, entry->filterAction);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_filterAction()
// ---------------------------------------------------------------------------------
//	Callback used by KFT_processPacket()
//	Pass in both the packet and index of corresponding filter rule (used to perform action)
//	Note ioIndex must be a valid table index.
//  Set the packet->leafAction for logging and to skip any further leaf actions.
//	Return 0 to continue processing
int KFT_filterAction(KFT_packetData_t* packet, int* ioIndex, u_int8_t action)
{
	int returnValue = 0;	// continue packet processing
	int returnIndex;
	int myIndex;
	#if 0
		log(LOG_WARNING, "KFT_filterAction: %d\n", action);
	#endif
	// remember table entry
	myIndex = *ioIndex;
	returnIndex = myIndex + 1;		// advance to next for matching entry
	switch (action) {
		case kActionPass:
			returnIndex = kft_filterNextEntry;	// done matching table
			if (!packet) break;
			if (packet->leafAction) break;
			packet->leafAction = action;
			KFT_leafChildAction(packet, myIndex, 1);	// still do children if any
			break;
		case kActionDelete:
			returnIndex = kft_filterNextEntry;	// done matching table
			if (!packet) break;
			if (packet->leafAction) break;
			packet->leafAction = action;
			KFT_leafChildAction(packet, myIndex, 1);	// still do children if any
			KFT_logEvent(packet, myIndex, action);
			// delete packet
			returnValue = KFT_deletePacket(packet);
			break;
		case kActionReject:
			returnIndex = kft_filterNextEntry;	// done matching table
			if (!packet) break;
			if (packet->leafAction) break;		// don't recurse for terminating actions
			packet->leafAction = action;
			KFT_leafChildAction(packet, myIndex, 1);	// still do children if any
			KFT_logEvent(packet, myIndex, action);
			// delete packet
			returnValue = KFT_respondRST(packet);
			returnValue = KFT_deletePacket(packet);
			break;
		case kActionDropConnection:
		{
			returnIndex = kft_filterNextEntry;	// done matching table
			if (!packet) break;
			if (packet->leafAction) break;			
			packet->leafAction = action;
			KFT_leafChildAction(packet, myIndex, 1);	// still do children if any
			KFT_logEvent(packet, myIndex, action);
			// drop connection
			returnValue = KFT_dropConnection(packet);
			break;
		}
		case kActionRateLimitIn:
			if (!packet) break;
			packet->rateLimitInRule = myIndex;
			// find connection entry
			if (!packet->connectionEntry) break;
			// update rateLimitRule in connection entry
			packet->connectionEntry->rInfo.rateLimitRule = myIndex;
			break;
		case kActionRateLimitOut:
			if (!packet) break;
			packet->rateLimitOutRule = myIndex;
			// find connection entry
			if (!packet->connectionEntry) break;
			// update rateLimitRule in connection entry
			packet->connectionEntry->sInfo.rateLimitRule = myIndex;
			break;
		case kActionRouteTo:
		{
			// set destination HW address and redirect packet out corresponding port
			int result;
			u_int8_t attachIndex;
			u_int8_t direction;
			returnIndex = kft_filterNextEntry;	// done matching table
			if (!packet) break;
			KFT_filterEntry_t* entry = &kft_filterTable[myIndex];
			// since interfaces can come and go, lookup corresonding attach info
			result = KFT_resolveRouteTo(entry->routeNextHop, &attachIndex, &direction);
			if (result != 0) break;
			// only update Ethernet frames at this time
			if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {			
				// check that we have a target hardware address
				u_int32_t* dp = (u_int32_t*)entry->routeHardwareAddress;
				if (!dp[0]) break;
				// set hardware dest address
				KFT_setRouteToAddress(entry, packet);
			}
			// redirect to corresponding port
			result = KFT_lateralPut(packet, attachIndex);
			break;
		}
		// controller actions
		case kActionDontLog:
			// set flag to not log this packet if deleted etc.
			if (!packet) break;
//			KFT_logEvent(packet, myIndex, action);	// debug
			packet->dontLog = 1;
			break;
		case kActionAlert:
		case kActionEmail:
		case kActionURL:
		case kActionAppleScript:
			KFT_logEvent(packet, myIndex, action);
			// if this is a leaf action, don't log packet twice
			if (packet && packet->leafAction) packet->dontLog = 1;
			break;
		case kActionLog:
			KFT_logEvent(packet, myIndex, action);
			break;
	}	// switch (action)
	*ioIndex = returnIndex;
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_leafChildAction()
// ---------------------------------------------------------------------------------
//	Perform filter actions for a leaf node including children if any.
//	Pass in both the packet (if known) and index of leaf filter rule.
//  If (skipLeaf) skip the leaf node itself and just do any children.
//
//  As a leaf node, the packet disposition has been determined
//  or there is no packet so it will not be matched.
int KFT_leafChildAction(KFT_packetData_t* packet, int index, int skipLeaf)
{
	int returnValue = 0;
	int stopAt = index + kft_filterTable[index].nodeCount;
	int ioIndex = index;
	if (skipLeaf) ioIndex += 1;
	// steal code from KFT_matchEntryAtIndex to check these non packet rules
	while (ioIndex < stopAt) {
		returnValue = KFT_matchEntryAtIndex(packet, &ioIndex);
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_deletePacket()
// ---------------------------------------------------------------------------------
// delete packet from mbuf chain
// dlil is designed to call us with one packet at a time (mbuf_ref->m_nextpkt == NULL)
// so that it can run any interface filters on each packet.
int KFT_deletePacket(KFT_packetData_t* packet)
{
#if IPK_NKE
	if (*packet->mbuf_ptr) mbuf_freem( *packet->mbuf_ptr );		// release this one
#endif
	*packet->mbuf_ptr = NULL;	// mbuf was consumed
	packet->datagram = NULL;
	return EJUSTRETURN;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_dropConnection()
// ---------------------------------------------------------------------------------
// drop connection
// Drop connection differs from delete packet in that we try to clear the
// corresponding TCP connection entry.
//
// Outbound: respond to connection request with local image and RST packet,
//   send RST to peer.
// Inbound: turn on TCP RST flag in packet pass on to stack.
int KFT_dropConnection(KFT_packetData_t* packet)
{
	int returnValue = 0;
	errno_t result;
#if IPK_NKE
	mbuf_t mbuf_ref;
#endif
	result = PROJECT_modifyReadyPacket(packet);
	tcp_header_t* tcpHeader;
	tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];

	// if packet is outbound, try to respond using local image
	if (packet->direction == kDirectionOutbound) {
		// try to inject a response
		// use content previously set in kft_droppedResponseBuffer (if any)
		// offset guide:  link header [6], ip header [20], tcp header [40], data content [60]
		ip_header_t* ipHeader;
		ip_header_t* ipHeader2;
		tcp_header_t* tcpHeader2;
		u_int8_t* dp;
		tcp_pseudo_t tcpPseudo;
		int totalLength;

		#if 0
			log(LOG_WARNING, "Drop connection trying to insert response %d\n", PROJECT_dropResponseLength);
		#endif
		// copy our sent frame header if desired
		// build IP header
		ipHeader  = (ip_header_t*)packet->datagram;
		ipHeader2 = (ip_header_t*)&PROJECT_dropResponseBuffer[20];
		ipHeader2->hlen = 0x45;
		ipHeader2->tos = 0;
		totalLength = 40 + PROJECT_dropResponseLength;
		ipHeader2->totalLength = totalLength;
		ipHeader2->identification = 17;
		ipHeader2->fragmentOffset = 0;
		ipHeader2->ttl = 64;
		ipHeader2->protocol = IPPROTO_TCP;
		ipHeader2->checksum = 0;
		ipHeader2->srcAddress = ipHeader->dstAddress;
		ipHeader2->dstAddress = ipHeader->srcAddress;

		// build TCP header from sent packet using src port, dst port, and ack# as seq#
		tcpHeader2 = (tcp_header_t*)&PROJECT_dropResponseBuffer[40];
		tcpHeader2->srcPort = tcpHeader->dstPort;
		tcpHeader2->dstPort = tcpHeader->srcPort;
		tcpHeader2->seqNumber = tcpHeader->ackNumber;
		tcpHeader2->ackNumber = tcpHeader->seqNumber + ipHeader->totalLength
			- packet->ipHeaderLen - packet->transportHeaderLen;
		tcpHeader2->hlen = 0x50;
		tcpHeader2->code = kCodeACK + kCodePSH + kCodeFIN;
		tcpHeader2->windowSize = 4096;
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
		tcpPseudo.length = htons(20 + PROJECT_dropResponseLength);

		// compute checksums
		u_int16_t ipChecksum = IpSum((u_int16_t*)&PROJECT_dropResponseBuffer[20], (u_int16_t*)&PROJECT_dropResponseBuffer[40]);
		ipHeader2->checksum = htons(ipChecksum);
			// pseudo header
		dp = (u_int8_t*)&tcpPseudo;
		u_int16_t tcpChecksum = IpSum((u_int16_t*)&dp[0], (u_int16_t*)&dp[12]);
			// pad segment to even 16-bit length
		int tcpChecksumLength = 20 + PROJECT_dropResponseLength;
		if (tcpChecksumLength % 2) {
			PROJECT_dropResponseBuffer[60 + PROJECT_dropResponseLength] = 0;
			tcpChecksumLength += 1;
		}
			// add TCP segment checksum
		tcpChecksum = AddToSum(tcpChecksum, (u_int16_t*)&PROJECT_dropResponseBuffer[40],
			(u_int16_t*)&PROJECT_dropResponseBuffer[40+tcpChecksumLength]);
		tcpHeader2->checksum = htons(tcpChecksum);
#if IPK_NKE
		// try to recover frame_ptr
		char* frameP;
		int headerLength = packet->ifHeaderLen;
		frameP = mbuf_data(*packet->mbuf_ptr);
		if ((packet->ifType == IFT_ETHER) && (headerLength == ETHER_HDR_LEN)) {
			// copy Ethernet src, dst, and type
			memcpy(&PROJECT_dropResponseBuffer[6], &(frameP[6]), ETHER_ADDR_LEN);
			memcpy(&PROJECT_dropResponseBuffer[12], &(frameP[0]), ETHER_ADDR_LEN);
			memcpy(&PROJECT_dropResponseBuffer[18], &(frameP[12]), ETHER_TYPE_LEN);
			frameP = (char*)&PROJECT_dropResponseBuffer[6];
		}
		else {
			memcpy(&PROJECT_dropResponseBuffer[20-headerLength], frameP, headerLength);
			frameP = (char*)&PROJECT_dropResponseBuffer[20-headerLength];
		}
		// build mbuf chain and send it
		#if TIGER
			result = mbuf_getpacket(MBUF_DONTWAIT, &mbuf_ref);
			if (result == 0) {
				frameP = mbuf_data(mbuf_ref);
				memcpy(mbuf_data(mbuf_ref), &PROJECT_dropResponseBuffer[20-headerLength], (int)totalLength+headerLength);
				mbuf_setdata(mbuf_ref, &frameP[headerLength], totalLength);
				mbuf_pkthdr_setlen(mbuf_ref, totalLength);
				// set frame header in mbuf
				mbuf_pkthdr_setheader(mbuf_ref, frameP);
				// set receive if
				mbuf_pkthdr_setrcvif(mbuf_ref, packet->ifnet_ref);
			}
			else mbuf_ref = NULL;
		#else
			mbuf_ref = m_devget(&PROJECT_dropResponseBuffer[20-headerLength], (int)totalLength+headerLength, 0, packet->ifnet_ref, NULL);
			if (mbuf_ref) {
				frameP = mbuf_ref->m_data;
				mbuf_ref->m_data = &frameP[headerLength];
				mbuf_ref->m_len = totalLength;
				mbuf_ref->m_pkthdr.len = totalLength;
			}
		#endif
		if (mbuf_ref) {
	// --------------
	// <<< Packet Out
	// --------------
			// tag mbuf so we don't try to process it again
			if (PROJECT_mtag(mbuf_ref, TAG_IN) == 0) {
				result = PROJECT_inject_input(mbuf_ref, 0, packet->myAttach->attachIndex, packet->ifnet_ref, frameP, kNetworkByteOrder);
				#if 0
					PROJECT_unlock();	// release lock during inject
					#if TIGER
						result = ifnet_input(packet->ifnet_ref, mbuf_ref, NULL);
					#else
						result = dlil_inject_if_input(mbuf_ref, frameP, packet->myAttach->filterID);
					#endif
					PROJECT_lock();
				#endif
			}
			else mbuf_freem(mbuf_ref);
			#if 0
				log(LOG_WARNING, "dlil inject result: %d\n", result);			
			#endif
			mbuf_ref = NULL;	// mbuf was consumed
		}
		else {
			#if 0
				log(LOG_WARNING, "Drop connection m_devget failed\n");
			#endif
		}
		
		// after responding with local image, update connection state to mark as closed by firewall
		{
			if (packet->connectionEntry) {
				packet->connectionEntry->flags |= kConnectionFlagClosed + kConnectionFlagFINPeer;
			}
		}
		// process the original outbound packet
		returnValue = KFT_deletePacket(packet);
#else
		KFT_logText("\nInject packet", NULL);
#endif
	}			
	else {
		// packet is inbound
		// respond with reset
		KFT_respondRST(packet);
		// turn on TCP RST flag and pass it on (after updating TCP header checksum)
		u_int16_t	old, new;
		old = *(u_int16_t*)&tcpHeader->hlen;
		tcpHeader->code |= kCodeRST;
		new = *(u_int16_t*)&tcpHeader->hlen;
		if (result == 0) tcpHeader->checksum = hAdjustIpSum(tcpHeader->checksum, old, new);
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_respondRST()
// ---------------------------------------------------------------------------------
// respond to packet with TCP RESET segment
int KFT_respondRST(KFT_packetData_t* packet)
{
	int returnValue = 0;
#if IPK_NKE
	errno_t status;
	mbuf_t mbuf_ref;
#endif
	u_int8_t rejectBuffer[80];
	int ipStart;	// start of IP datagram in reject buffer
	tcp_header_t* tcpHeader;
	tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];

	// build TCP RESET response
	ip_header_t* ipHeader;
	ip_header_t* ipHeader2;
	tcp_header_t* tcpHeader2;
	u_int8_t* dp;
	tcp_pseudo_t tcpPseudo;
	int totalLength;

	// copy our sent header if desired
	// build IP header
	ipHeader  = (ip_header_t*)packet->datagram;
	ipStart = packet->ifHeaderLen;
	ipHeader2 = (ip_header_t*)&rejectBuffer[ipStart];
	ipHeader2->hlen = 0x45;
	ipHeader2->tos = 0;
	totalLength = 40;
	ipHeader2->totalLength = totalLength;
	ipHeader2->identification = 17;
	ipHeader2->fragmentOffset = 0;
	ipHeader2->ttl = 64;
	ipHeader2->protocol = IPPROTO_TCP;
	ipHeader2->checksum = 0;
	ipHeader2->srcAddress = ipHeader->dstAddress;
	ipHeader2->dstAddress = ipHeader->srcAddress;

	// build TCP header from sent packet using src port, dst port, and ack# as seq#
	tcpHeader2 = (tcp_header_t*)&rejectBuffer[ipStart+20];
	tcpHeader2->srcPort = tcpHeader->dstPort;
	tcpHeader2->dstPort = tcpHeader->srcPort;
	tcpHeader2->seqNumber = tcpHeader->ackNumber;
	tcpHeader2->ackNumber = tcpHeader->seqNumber + ipHeader->totalLength
		- packet->ipHeaderLen - packet->transportHeaderLen;
	if (tcpHeader->code & kCodeSYN) tcpHeader2->ackNumber += 1;
	if (tcpHeader->code & kCodeFIN) tcpHeader2->ackNumber += 1;
	tcpHeader2->hlen = 0x50;
	tcpHeader2->code = kCodeRST;
	tcpHeader2->windowSize = 4096;
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
	// build mbuf chain and send it
	if (packet->ifnet_ref) {	// defensive
		// if packet is outbound, inject response as input
		if (packet->direction == kDirectionOutbound) {
			// try to recover frame_ptr
			char *frameP;
			frameP = mbuf_data(*packet->mbuf_ptr);
			if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
				// copy Ethernet src, dst, and type
				memcpy(&rejectBuffer[0], &(frameP[6]), ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[6], &(frameP[0]), ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[12], &(frameP[12]), ETHER_TYPE_LEN);
				frameP = (char*)&rejectBuffer[0];
			}
			else {
				memcpy(&rejectBuffer[0], frameP, ipStart);
				frameP = (char*)&rejectBuffer[0];
			}
			#if TIGER
				status = mbuf_getpacket(MBUF_DONTWAIT, &mbuf_ref);
				if (status == 0) {
					frameP = mbuf_data(mbuf_ref);
					memcpy(mbuf_data(mbuf_ref), &rejectBuffer[0], (int)totalLength+ipStart);
					mbuf_setdata(mbuf_ref, &frameP[ipStart], totalLength);
					mbuf_pkthdr_setlen(mbuf_ref, totalLength);
					// set frame header in mbuf
					mbuf_pkthdr_setheader(mbuf_ref, frameP);
					// set receive if
					mbuf_pkthdr_setrcvif(mbuf_ref, packet->ifnet_ref);
				}
				else mbuf_ref = NULL;
			#else
				mbuf_ref = m_devget(&rejectBuffer[0], totalLength+ipStart, 0, packet->ifnet_ref, NULL);
				if (mbuf_ref) {
					frameP = mbuf_ref->m_data;
					mbuf_ref->m_data = &frameP[ipStart];
					mbuf_ref->m_len = totalLength;
					mbuf_ref->m_pkthdr.len = totalLength;
				}
			#endif
			if (mbuf_ref) {			
	// --------------
	// <<< Packet Out
	// --------------
				#if IPK_NKE
					// tag mbuf so we don't try to process it again
					if (PROJECT_mtag(mbuf_ref, TAG_IN) == 0) {
						status = PROJECT_inject_input(mbuf_ref, 0, packet->myAttach->attachIndex, packet->ifnet_ref, frameP, kNetworkByteOrder);
						#if 0
							PROJECT_unlock();	// release lock during inject
							#if TIGER
								status = ifnet_input(packet->ifnet_ref, mbuf_ref, NULL);
							#else
								status = dlil_inject_if_input(mbuf_ref, frameP, packet->myAttach->filterID);
							#endif
							PROJECT_lock();
						#endif
					}
					else mbuf_freem(mbuf_ref);
					#if 0
						log(LOG_WARNING, "dlil inject result: %d", result);
					#endif
				#else
					KFT_logText("\nInject packet", NULL);
				#endif
				mbuf_ref = NULL;	// mbuf was consumed
			}
			else {
				#if 0
					log(LOG_WARNING, "RespondRST m_devget failed\n");
				#endif
			}
		}
		else {
			// packet was inbound, try to inject response as output
			// setup frame header
			char *frameP;
			frameP = *packet->frame_ptr;
			if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
				// copy Ethernet src, dst, and type
				memcpy(&rejectBuffer[0], &frameP[6], ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[6], &frameP[0], ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[12], &frameP[12], ETHER_TYPE_LEN);
			}
			else {
				memcpy(&rejectBuffer[0], frameP, ipStart);
			}
			#if TIGER
				status = mbuf_getpacket(MBUF_DONTWAIT, &mbuf_ref);
				if (status == 0) {
					memcpy(mbuf_data(mbuf_ref), &rejectBuffer[0], (int)totalLength+ipStart);
					mbuf_setlen(mbuf_ref, totalLength+ipStart);
					mbuf_pkthdr_setlen(mbuf_ref, totalLength+ipStart);
				}
				else mbuf_ref = NULL;
			#else
				mbuf_ref = m_devget(&rejectBuffer[0], totalLength+ipStart, 0, packet->ifnet_ref, NULL);
			#endif
			// inject packet
			if (mbuf_ref) {			
	// --------------
	// <<< Packet Out
	// --------------
				#if IPK_NKE
					// tag mbuf so we don't try to process it again
					if (PROJECT_mtag(mbuf_ref, TAG_OUT) == 0) {
						status = PROJECT_inject_output(mbuf_ref, ipStart, packet->myAttach->attachIndex, packet->ifnet_ref, kHostByteOrder);
						#if 0
							PROJECT_unlock();	// release lock during inject
							#if TIGER
								status = ifnet_output_raw(packet->ifnet_ref, 0, mbuf_ref);
							#else
								status = dlil_inject_if_output(mbuf_ref, packet->myAttach->filterID);
							#endif
							PROJECT_lock();
						#endif
					}
					else mbuf_freem(mbuf_ref);
					#if 0
						log(LOG_WARNING, "dlil inject result: %d", result);
					#endif
				#else
					KFT_logText("\nInject packet", NULL);
				#endif
				mbuf_ref = NULL;	// mbuf was consumed
			}
			else {
				#if 0
					log(LOG_WARNING, "RespondRST m_devget failed");
				#endif
			}
		}
	}	// if (packet->ifnet_ref)
#endif
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_respondACK()
// ---------------------------------------------------------------------------------
// respond to packet with TCP ACK segment
int KFT_respondACK(KFT_packetData_t* packet)
{
	int returnValue = 0;
#if IPK_NKE
	errno_t status;
	mbuf_t mbuf_ref;
#endif
	u_int8_t rejectBuffer[80];
	int ipStart;	// start of IP datagram in reject buffer
	tcp_header_t* tcpHeader;
	tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];

	// build TCP ACK response
	ip_header_t* ipHeader;
	ip_header_t* ipHeader2;
	tcp_header_t* tcpHeader2;
	u_int8_t* dp;
	tcp_pseudo_t tcpPseudo;
	int totalLength;

	// copy our sent header if desired
	// build IP header
	ipHeader  = (ip_header_t*)packet->datagram;
	ipStart = packet->ifHeaderLen;
	ipHeader2 = (ip_header_t*)&rejectBuffer[ipStart];
	ipHeader2->hlen = 0x45;
	ipHeader2->tos = 0;
	totalLength = 40;
	ipHeader2->totalLength = totalLength;
	ipHeader2->identification = 17;
	ipHeader2->fragmentOffset = 0;
	ipHeader2->ttl = 64;
	ipHeader2->protocol = IPPROTO_TCP;
	ipHeader2->checksum = 0;
	ipHeader2->srcAddress = ipHeader->dstAddress;
	ipHeader2->dstAddress = ipHeader->srcAddress;

	// build TCP header from sent packet using src port, dst port, and ack# as seq#
	tcpHeader2 = (tcp_header_t*)&rejectBuffer[ipStart+20];
	tcpHeader2->srcPort = tcpHeader->dstPort;
	tcpHeader2->dstPort = tcpHeader->srcPort;
	tcpHeader2->seqNumber = tcpHeader->ackNumber;
	tcpHeader2->ackNumber = tcpHeader->seqNumber + ipHeader->totalLength
		- packet->ipHeaderLen - packet->transportHeaderLen;
	if (tcpHeader->code & kCodeSYN) tcpHeader2->ackNumber += 1;
	if (tcpHeader->code & kCodeFIN) tcpHeader2->ackNumber += 1;
	tcpHeader2->hlen = 0x50;
	tcpHeader2->code = kCodeACK;
	tcpHeader2->windowSize = 4096;
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
	// build mbuf chain and send it
	if (packet->ifnet_ref) {	// defensive
		// if packet is outbound, inject response as input
		if (packet->direction == kDirectionOutbound) {
			// try to recover frame_ptr
			char *frameP;
			frameP = mbuf_data(*packet->mbuf_ptr);
			if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
				// copy Ethernet src, dst, and type
				memcpy(&rejectBuffer[0], &(frameP[6]), ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[6], &(frameP[0]), ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[12], &(frameP[12]), ETHER_TYPE_LEN);
				frameP = (char*)&rejectBuffer[0];
			}
			else {
				memcpy(&rejectBuffer[0], frameP, ipStart);
				frameP = (char*)&rejectBuffer[0];
			}
			#if TIGER
				status = mbuf_getpacket(MBUF_DONTWAIT, &mbuf_ref);
				if (status == 0) {
					frameP = mbuf_data(mbuf_ref);
					memcpy(mbuf_data(mbuf_ref), &rejectBuffer[0], (int)totalLength+ipStart);
					mbuf_setdata(mbuf_ref, &frameP[ipStart], totalLength);
					mbuf_pkthdr_setlen(mbuf_ref, totalLength);
					// set frame header in mbuf
					mbuf_pkthdr_setheader(mbuf_ref, frameP);
					// set receive if
					mbuf_pkthdr_setrcvif(mbuf_ref, packet->ifnet_ref);
				}
				else mbuf_ref = NULL;
			#else
				mbuf_ref = m_devget(&rejectBuffer[0], totalLength+ipStart, 0, packet->ifnet_ref, NULL);
				if (mbuf_ref) {
					frameP = mbuf_ref->m_data;
					mbuf_ref->m_data = &frameP[ipStart];
					mbuf_ref->m_len = totalLength;
					mbuf_ref->m_pkthdr.len = totalLength;
				}
			#endif
			if (mbuf_ref) {			
	// --------------
	// <<< Packet Out
	// --------------
				#if IPK_NKE
					// tag new mbuf so we don't try to process it again
					if (PROJECT_mtag(mbuf_ref, TAG_IN) == 0) {
						status = PROJECT_inject_input(mbuf_ref, 0, packet->myAttach->attachIndex, packet->ifnet_ref, frameP, kNetworkByteOrder);
					}
					else mbuf_freem(mbuf_ref);
					#if 0
						log(LOG_WARNING, "dlil inject result: %d", result);
					#endif
				#else
					KFT_logText("\nInject packet", NULL);
				#endif
				mbuf_ref = NULL;	// mbuf was consumed
			}
			else {
				#if 0
					log(LOG_WARNING, "RespondACK m_devget failed");
				#endif
			}
		}
		else {
			// packet was inbound, try to inject response as output
			// setup frame header
			char *frameP;
			frameP = *packet->frame_ptr;
			if ((packet->ifType == IFT_ETHER) && (packet->ifHeaderLen == ETHER_HDR_LEN)) {
				// copy Ethernet src, dst, and type
				memcpy(&rejectBuffer[0], &frameP[6], ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[6], &frameP[0], ETHER_ADDR_LEN);
				memcpy(&rejectBuffer[12], &frameP[12], ETHER_TYPE_LEN);
			}
			else {
				memcpy(&rejectBuffer[0], frameP, ipStart);
			}
			#if TIGER
				status = mbuf_getpacket(MBUF_DONTWAIT, &mbuf_ref);
				if (status == 0) {
					memcpy(mbuf_data(mbuf_ref), &rejectBuffer[0], (int)totalLength+ipStart);
					mbuf_setlen(mbuf_ref, totalLength+ipStart);
					mbuf_pkthdr_setlen(mbuf_ref, totalLength+ipStart);
				}
				else mbuf_ref = NULL;
			#else
				mbuf_ref = m_devget(&rejectBuffer[0], totalLength+ipStart, 0, packet->ifnet_ref, NULL);
			#endif
			// inject packet
			if (mbuf_ref) {			
	// --------------
	// <<< Packet Out
	// --------------
				#if IPK_NKE
					// tag mbuf so we don't try to process it again
					if (PROJECT_mtag(mbuf_ref, TAG_OUT) == 0) {
						status = PROJECT_inject_output(mbuf_ref, ipStart, packet->myAttach->attachIndex, packet->ifnet_ref, kHostByteOrder);
					}
					else mbuf_freem(mbuf_ref);
					#if 0
						log(LOG_WARNING, "dlil inject result: %d", result);
					#endif
				#else
					KFT_logText("\nInject packet", NULL);
				#endif
				mbuf_ref = NULL;	// mbuf was consumed
			}
			else {
				#if 0
					log(LOG_WARNING, "RespondACK m_devget failed");
				#endif
			}
		}
	}	// if (packet->ifnet_ref)
#endif
	return returnValue;
}

#pragma mark --- LOGGING ---
// ---------------------------------------------------------------------------------
//	¥ KFT_logEvent()
// ---------------------------------------------------------------------------------
// Callback used by KFT_processPacket() to log a firewall event
// Build log message based on packet and event.  Assumes controller will prepend time stamp.
//
// Format as a NeXT style property list.
// Makes it easy to parse or re-arrange later
// dictionary -> { key = value; key = value; key = value }
// quoted value -> "some value"
//
// { 
//   action = "packet dropped";
//   rule = "x.x.x rule name";
//   interface = en0;
//   direction = inbound;
//   source = addr,port;
//   destination = addr,port;
//   protocol = TCP;
//   icmp type = n;
//   icmp code = n;
//   parameter = "some param"
// }
//
// Notice packet can be NULL to log a non-packet event.
// Notice index can be negative to log a "Rule 0" event (no filter entry);
void KFT_logEvent(KFT_packetData_t* packet, int index, u_int8_t action)
{
	KFT_filterEntry_t* entry = 0;
	ip_header_t* ipHeader;
	u_int8_t logAction;
	u_int8_t protocol = 0;
	unsigned char text[kLogEventSize];	// message buffer
	u_int8_t* dp8;
	PSData inBuf;
	
	do {
		if (packet && packet->dontLog) break;
		// get pointer to table entry
		if (index >= 0) entry = &kft_filterTable[index];
		// initialize buffer descriptor
		inBuf.bytes = &text[0];
		inBuf.length = sizeof(ipk_message_t);
		inBuf.bufferLength = kLogEventSize;
		inBuf.offset = sizeof(ipk_message_t);	// leave room for message length, type
	
		// begin log entry property list
		appendCString(&inBuf, "{");
		appendCString(&inBuf, " action = \"");
		logAction = action;
		if (packet && packet->leafAction) logAction = packet->leafAction;
		switch (logAction) {
			case kActionPass:
				appendCString(&inBuf, "packet passed");
				break;
			case kActionDelete:
				appendCString(&inBuf, "packet dropped");
				break;
			case kActionReject:
				appendCString(&inBuf, "reject, packet dropped");
				break;
			case kActionDropConnection:
				appendCString(&inBuf, "connection dropped");
				break;
			case kActionLog:
				appendCString(&inBuf, "packet logged");
				break;
			case kActionDontLog:	// for debugging
				appendCString(&inBuf, "dont log");
				break;
			case kActionAlert:
				appendCString(&inBuf, "Alert");
				break;
			case kActionEmail:
				appendCString(&inBuf, "Email notification");
				break;
			case kActionURL:
				appendCString(&inBuf, "URL notification");
				break;
			case kActionAppleScript:
				appendCString(&inBuf, "AppleScript");
				break;
			case kActionNotCompleted:
				appendCString(&inBuf, "processing not completed");
				break;
			default:
				appendCString(&inBuf, "unexpected event:");
				appendInt(&inBuf, logAction);
				break;
		}
		appendCString(&inBuf, "\";");
	
		if (action != logAction) {
			appendCString(&inBuf, " subAction = \"");
			logAction = action;
			switch (action) {
				case kActionPass:
					appendCString(&inBuf, "packet passed");
					break;
				case kActionDelete:
					appendCString(&inBuf, "packet dropped");
					break;
				case kActionReject:
					appendCString(&inBuf, "reject, packet dropped");
					break;
				case kActionDropConnection:
					appendCString(&inBuf, "connection dropped");
					break;
				case kActionLog:
					appendCString(&inBuf, "packet logged");
					break;
				case kActionAlert:
					appendCString(&inBuf, "Alert");
					break;
				case kActionEmail:
					appendCString(&inBuf, "Email notification");
					break;
				case kActionURL:
					appendCString(&inBuf, "URL notification");
					break;
				case kActionAppleScript:
					appendCString(&inBuf, "AppleScript");
					break;
				default:
					appendCString(&inBuf, "unexpected event:");
					appendInt(&inBuf, logAction);
					break;
			}
			appendCString(&inBuf, "\";");
		}
	
		// display rule and name if any
		appendCString(&inBuf, " rule = \"");
		if (index > 0) {
			if (entry) {
				appendPString(&inBuf, entry->nodeNumber);
				if (entry->nodeName[0]) {
					appendCString(&inBuf, " ");
					appendPString(&inBuf, entry->nodeName);
				}
			}
		}
		else {
			// rule 0 firewall events not associated with a user specified firewall rule
			appendCString(&inBuf, "rule = 0 ");
			switch (-index) {
				case kReasonConsistencyCheck:
					appendCString(&inBuf, "internal consistency check");
					break;
				case kReasonShortIPHeader:
					appendCString(&inBuf, "short IP header");
					break;
				case kReasonNotV4:
					appendCString(&inBuf, "not IP v4");
					break;
				case kReasonHeaderChecksum:
					appendCString(&inBuf, "IP header checksum");
					break;
				case kReasonShortTCPHeader:
					appendCString(&inBuf, "short TCP header");
					break;
				case kReasonICMPLength:
					appendCString(&inBuf, "ICMP length");
					break;
				case kReasonNATActionReject:
					appendCString(&inBuf, "NAT action");
					break;
				case kReasonSourceIPZero:
					appendCString(&inBuf, "source IP address zero");
					break;
				case kReasonDelayTableFull:
					appendCString(&inBuf, "delay table full");
					break;
				case kReasonConnectionState:
					appendCString(&inBuf, "connection closed by firewall");
					break;
				case kReasonOutOfMemory:
					appendCString(&inBuf, "out of memory");
					break;
				default:
					appendCString(&inBuf, "unexpected rule 0");
					break;
			}
		}
		appendCString(&inBuf, "\";");
		
		// include packet information
		if (packet) {		
			if (-index == kReasonNotV4) {
				u_int32_t* dp32;
				dp32 = (u_int32_t*)packet->datagram;
				appendCString(&inBuf, " parameter = \"");
				appendInt(&inBuf, (int)packet->ipOffset);
				appendCString(&inBuf, ":");
				appendHexInt(&inBuf, dp32[0], 8, kOptionDefault);
				appendCString(&inBuf, " ");
				appendHexInt(&inBuf, dp32[1], 8, kOptionDefault);
				appendCString(&inBuf, " ");
				appendHexInt(&inBuf, dp32[2], 8, kOptionDefault);
				appendCString(&inBuf, " ");
				appendHexInt(&inBuf, dp32[3], 8, kOptionDefault);
				appendCString(&inBuf, " ");
				appendHexInt(&inBuf, dp32[4], 8, kOptionDefault);
				appendCString(&inBuf, " ");
				appendHexInt(&inBuf, dp32[5], 8, kOptionDefault);
				appendCString(&inBuf, " ");
				appendHexInt(&inBuf, dp32[6], 8, kOptionDefault);
				appendCString(&inBuf, " ");
				appendHexInt(&inBuf, dp32[7], 8, kOptionDefault);
				appendCString(&inBuf, "\";");
			}
			else {
				// setup access to IP
				ipHeader = (ip_header_t*)packet->datagram;
				protocol = ipHeader->protocol;
			
				// source
				appendCString(&inBuf, " source = ");
				appendIP(&inBuf, ipHeader->srcAddress);
				if ((protocol == IPPROTO_TCP) ||
					(protocol == IPPROTO_UDP)) {
					tcp_header_t* tcpHeader;
					tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
					appendCString(&inBuf, ":");
					appendInt(&inBuf, (int)tcpHeader->srcPort);
				}
				appendCString(&inBuf, ";");
				
				// destination
				appendCString(&inBuf, " destination = ");
				appendIP(&inBuf, ipHeader->dstAddress);
				if ((protocol == IPPROTO_TCP) ||
					(protocol == IPPROTO_UDP)) {
					tcp_header_t* tcpHeader;
					tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
					appendCString(&inBuf, ":");
					appendInt(&inBuf, (int)tcpHeader->dstPort);
				}
				appendCString(&inBuf, ";");
		
				// protocol
				appendCString(&inBuf, " protocol = ");
				if (protocol == IPPROTO_TCP) appendCString(&inBuf, "TCP");
				else if (protocol == IPPROTO_UDP) appendCString(&inBuf, "UDP");
				else if (protocol == IPPROTO_ICMP) {
					icmp_header_t* icmpHeader;
					icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
					appendCString(&inBuf, "\"ICMP");
					appendCString(&inBuf, ":");
					appendInt(&inBuf, (int)icmpHeader->type);
					appendCString(&inBuf, ",");
					appendInt(&inBuf, (int)icmpHeader->code);
					appendCString(&inBuf, "\"");
				}
				else appendInt(&inBuf, (int)protocol);
				appendCString(&inBuf, ";");	

				// matched content if any
				if (packet->textLength) {
					if ((protocol == IPPROTO_TCP) ||
						(protocol == IPPROTO_UDP)) {
						int start;
						dp8 = &packet->datagram[packet->ipHeaderLen + packet->transportHeaderLen];
						start = packet->ipHeaderLen + packet->transportHeaderLen + packet->textOffset;
						if (start < packet->segmentLen) {
							if (packet->segmentLen - start < packet->textLength)
								packet->textLength = packet->segmentLen - start;
							appendCString(&inBuf, " matchContent = ");
							appendCString(&inBuf, "\"");
							appendBytes(&inBuf, &dp8[packet->textOffset], packet->textLength);
							appendCString(&inBuf, "\"");
							appendCString(&inBuf, ";");
						}
					}
				}

			}	// if !(-index == kReasonNotV4)

			// byteCount
			{
				int byteCount;
				byteCount =  mbuf_pkthdr_len(*packet->mbuf_ptr) - packet->ipOffset;
				appendCString(&inBuf, " byteCount = ");
				appendInt(&inBuf, byteCount);
				appendCString(&inBuf, ";");
			}

			// direction
			if (packet->direction) appendCString(&inBuf, " direction = in;");
			else appendCString(&inBuf, " direction = out;");
	
			// bsd interface
			appendCString(&inBuf, " interface = ");
			appendCString(&inBuf, packet->myAttach->kftInterfaceEntry.bsdName);
			appendCString(&inBuf, ";");
		}	// if (packet)
		// Parameter if any
		if ((index > 0) && (entry)) {
			if (entry->parameterStart) {
				appendCString(&inBuf, " parameter = \"");
				appendPString(&inBuf, &entry->propertyValue[entry->parameterStart]);
				appendCString(&inBuf, "\";");
			}
		}
		// end log entry property list
		appendCString(&inBuf, " }");
	
		// fill in message header and send it
		{
			ipk_filterLog_t* message;
			message = (ipk_filterLog_t *)inBuf.bytes;
			message->length = inBuf.offset;
			switch (action) {
				case kActionLog:
					message->type = kFilterLog;
					break;
				case kActionAlert:
					message->type = kFilterAlert;
					break;
				case kActionEmail:
					message->type = kFilterEmail;
					break;
				case kActionURL:
					message->type = kFilterURL;
					break;
				case kActionAppleScript:
					message->type = kFilterAppleScript;
					break;
				default:
					message->type = kFilterLog;
			}
			// send it to each active controller
			KFT_sendMessage((ipk_message_t*)message, kMessageMaskServer);
		}
	} while (false);
}


// ---------------------------------------------------------------------------------
//	¥ KFT_logData()
// ---------------------------------------------------------------------------------
// Log any text contained in a PSData.
// Text should be offset by sizeof(ipk_message_t) to leave room for message length and type
// Primarily used for debugging
void KFT_logData(PSData* inBuf)
{
	// fill in message header and send it
	ipk_filterLog_t* message;
	message = (ipk_filterLog_t *)inBuf->bytes;
	message->length = inBuf->offset;
	message->type = kFilterLog;
	// send it to each active controller
	KFT_sendMessage((ipk_message_t*)message, kMessageMaskServer);
}

// ---------------------------------------------------------------------------------
//	¥ KFT_logText()
// ---------------------------------------------------------------------------------
// Log a C string and a number if specified.  Either can be nil.
void KFT_logText(char* text, int* number)
{
	unsigned char buffer[kLogEventSize];	// message buffer
	PSData inBuf;

	// initialize buffer descriptor
	inBuf.bytes = &buffer[0];
	inBuf.length = sizeof(ipk_message_t);
	inBuf.bufferLength = kLogEventSize;
	inBuf.offset = sizeof(ipk_message_t);	// leave room for message length, type
	// append parameter info
	if (text) appendCString(&inBuf, text);
	if (number) appendInt(&inBuf, *number);
	// log it
	KFT_logData(&inBuf);
}

// ---------------------------------------------------------------------------------
//	¥ KFT_logText4()
// ---------------------------------------------------------------------------------
// Log up to 4 C strings, any can be nil, separate by 1 space
void KFT_logText4(char* text1, char* text2, char* text3, char* text4)
{
	unsigned char buffer[kLogEventSize];	// message buffer
	PSData inBuf;

	// initialize buffer descriptor
	inBuf.bytes = &buffer[0];
	inBuf.length = sizeof(ipk_message_t);
	inBuf.bufferLength = kLogEventSize;
	inBuf.offset = sizeof(ipk_message_t);	// leave room for message length, type
	// append parameter info
	if (text1) appendCString(&inBuf, text1);
	if (text2) { appendCString(&inBuf, " "); appendCString(&inBuf, text2); }
	if (text3) { appendCString(&inBuf, " "); appendCString(&inBuf, text2); }
	if (text4) { appendCString(&inBuf, " "); appendCString(&inBuf, text2); }
	// log it
	KFT_logData(&inBuf);
}

// ---------------------------------------------------------------------------------
//	¥ KFT_logHex()
// ---------------------------------------------------------------------------------
// Log some data as hex characters
void KFT_logHex(u_int8_t* dp, int howMany)
{
	unsigned char buffer[kLogEventSize];	// message buffer
	PSData inBuf;
	int i;

	// initialize buffer descriptor
	inBuf.bytes = &buffer[0];
	inBuf.length = sizeof(ipk_message_t);
	inBuf.bufferLength = kLogEventSize;
	inBuf.offset = sizeof(ipk_message_t);	// leave room for message length, type
	for (i=0; i<howMany; i++) {
		// append hex characters
		if (i) {
			if (i%32 == 0) appendCString(&inBuf, "\n");
			if (i%4 == 0) appendCString(&inBuf, " ");
		}
		appendHexInt(&inBuf, (int)dp[i], 2, kOptionDefault);
	}
	// log it
	KFT_logData(&inBuf);
}


#pragma mark --- SUPPORT ---
// ---------------------------------------------------------------------------------
//	¥ KFT_attachIndexForName
// ---------------------------------------------------------------------------------
//	Find attach instance with corresponding bsdName.
//	Return 0 for not found.
int KFT_attachIndexForName(char *inName)
{
    int returnValue = 0;	// no such entry ENOENT
    int i;
    int len;
    
    len = strlen(inName);
    for (i=1; i<=kMaxAttach; i++) {
        if ( memcmp(inName, &PROJECT_attach[i].kftInterfaceEntry.bsdName[0], len) == 0 ) {
            returnValue = i;
            break;
        }
    }
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_emptyAttachIndex
// ---------------------------------------------------------------------------------
//	Find an empty attach instance (available slot)
//	Return 0 for not found
int KFT_emptyAttachIndex()
{
    int returnValue = 0;	// all slots in use EBUSY
    int i;
    
    for (i=1; i<=kMaxAttach; i++) {
        #if TIGER
		if ((PROJECT_attach[i].ifFilterRef == 0) && (PROJECT_attach[i].ipFilterRef == 0)) {
		#else
		if (PROJECT_attach[i].filterID == 0) {
		#endif
            returnValue = i;
            break;
		#if TIGER
        }
		#else
		}
		#endif
    }
    return returnValue;
}


#if !IPK_NKE
SInt32	OSAddAtomic(SInt32 amount, SInt32 * address)
{
	SInt32 returnValue;
	returnValue = *address;
	*address = returnValue + amount;
	return returnValue;
}
#endif
SInt64	myOSAddAtomic64(SInt32 amount, SInt64 *address)
{
	SInt64 returnValue;
	returnValue = *address;
	*address = returnValue + amount;
	return returnValue;
}
