//
// kftPortMapTable.c
// IPNetRouterX
//
// Created by Peter Sichel on Tue Jun 10 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Nat Table and support functions
//
// We represent the NAT table as a set of translation entries indexed by
// two AVL trees to allow fast lookups by Apparent or Actual Endpoint.
// The result of such lookups are cached in a corresponding connection table
// entry so lookups are not necessary for subsequent packets within a connection
// flow.
//
// Since AVL tree search scales efficiently, we can use the same table
// to NAT multiple interfaces on separate data links.  Each data link
// (en0, en1, ppp0) defines a different apparent address when NAT
// and External are selected for that inerface.  No special configuration
// is required to handle one-way or telco return type systems except to
// enable NAT on the additional interface.
//
// If NAT and !External is selected, treat as the "Local NAT" case to
// access internal servers using their external public address.
//
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
#include "kftPortMapTable.h"
#include "kftNatTable.h"
#include "kft.h"
#include "kftSupport.h"
#include "FilterTypes.h"
#include "avl.h"
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netinet/tcp_seq.h>	// sequence number compare macros SEQ_LT, SEQ_LEQ, SEQ_GT, SEQ_GEQ(a,b)
#include <sys/socket.h>
#include <sys/mbuf.h>

#if IPK_NKE
#include <sys/systm.h>
#include <machine/spl.h>
#include <sys/param.h>
#include <libkern/OSAtomic.h>
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

// Global storage
#include "kftGlobal.h"

// Module wide storage
// -------------------
// allocate Kernel Nat Table
#define KFT_natTableSize 2000

static avl_tree *kft_portMapApparentTree = NULL;
static avl_tree *kft_portMapActualTree = NULL;
static int wildcard;

#define kPortMapUpdateBufferSize 2000
static unsigned char updateBuffer[kPortMapUpdateBufferSize];

// NAT parameters are stored in attach instance as kftInterfaceEntry (see ipkTypes.h)

// forward internal function declarations
int KFT_portMapApparentFree (void * key);
int KFT_portMapActualFree (void * key);
#if !IPK_NKE
void testMessageFromClient(ipk_message_t* message);
#endif


// ---------------------------------------------------------------------------------
//	¥ KFT_portMapStart()
// ---------------------------------------------------------------------------------
//	init nat table
//  Called from IPNetRouter_NKE_start() or SO_KFT_RESET which are thread protected
void KFT_portMapStart()
{
	// release old trees if any
	if (kft_portMapApparentTree) free_avl_tree(kft_portMapApparentTree, KFT_portMapApparentFree);
	if (kft_portMapActualTree) free_avl_tree(kft_portMapActualTree, KFT_portMapActualFree);
	kft_portMapApparentTree = NULL;
	kft_portMapActualTree = NULL;
	wildcard = 0;
	// allocate new avl trees
	kft_portMapApparentTree = new_avl_tree (KFT_portMapApparentCompare, NULL);
	kft_portMapActualTree = new_avl_tree (KFT_portMapActualCompare, NULL);
	{   // initialize update buffer
		ipk_natUpdate_t* message;
		message = (ipk_natUpdate_t*)&updateBuffer[0];
		message->length = 8;	// offset to first entry
		message->type = kPortMapUpdate;
		message->version = 0;
		message->flags = 0;
	}
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_natStart\n");
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapStop()
// ---------------------------------------------------------------------------------
//	release nat table
//  Called from IPNetRouter_NKE_stop()
void KFT_portMapStop()
{
	// release old trees if any
	if (kft_portMapApparentTree) free_avl_tree(kft_portMapApparentTree, KFT_portMapApparentFree);
	if (kft_portMapActualTree) free_avl_tree(kft_portMapActualTree, KFT_portMapActualFree);
	kft_portMapApparentTree = NULL;
	kft_portMapActualTree = NULL;
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_natStop\n");
	#endif
}


// ---------------------------------------------------------------------------------
//	¥ KFT_portMapFindApparentForActual()
// ---------------------------------------------------------------------------------
// Search for entry in nat table
// return 0=success, foundEntry points to the entry we found
//		 -1=not found or other error
int KFT_portMapFindApparentForActual(KFT_packetData_t* packet, KFT_natEntry_t* compareEntry, KFT_natEntry_t** foundEntry)
{
	int retval;
	if ((*foundEntry != NULL) || !kft_portMapActualTree) return -1;
	retval = get_item_by_key(kft_portMapActualTree, (void *)compareEntry, (void **)foundEntry);
	if ((retval == 0) && (PROJECT_flags & kFlag_portMapLogging))
		KFT_portMapLog(packet, *foundEntry, kMapLookup_apparent);
	return retval;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapFindActualForApparent()
// ---------------------------------------------------------------------------------
int KFT_portMapFindActualForApparent(KFT_packetData_t* packet, KFT_natEntry_t* compareEntry, KFT_natEntry_t** foundEntry)
{
	int retval;
	if ((*foundEntry != NULL) || !kft_portMapApparentTree) return -1;
	retval = get_item_by_key(kft_portMapApparentTree, (void *)compareEntry, (void **)foundEntry);
	if (wildcard && (retval != 0)) {
		// look for wildcard address 0
		u_int32_t hold = compareEntry->apparent.address;
		compareEntry->apparent.address = 0;
		retval = get_item_by_key(kft_portMapApparentTree, (void *)compareEntry, (void **)foundEntry);
		compareEntry->apparent.address = hold;
	}
	if ((retval == 0) && (PROJECT_flags & kFlag_portMapLogging))
		KFT_portMapLog(packet, *foundEntry, kMapLookup_actual);
	return retval;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapAddCopy()
// ---------------------------------------------------------------------------------
// Add static/permanent entry to NAT table.
// Check for duplicates and replace if found.
// return:  0 success, -1 out of memory or other error
KFT_natEntry_t* KFT_portMapAddCopy(KFT_natEntry_t* entry)
{
	KFT_natEntry_t* natE = NULL;
	int status;
	
	do {
		if (!kft_portMapApparentTree || !kft_portMapActualTree) break;
		natE = (KFT_natEntry_t *)my_malloc(sizeof(KFT_natEntry_t));		
		if (!natE) break;	// out of memory
			// copy data content to newly allocated entry
		memcpy(natE, entry, sizeof(KFT_natEntry_t));
			// look for duplicate entries and delete them before adding
		KFT_portMapSearchDelete(natE);	// calls mfree for entry
			// lastTime
		struct timeval tv;
		#if IPK_NKE
		getmicrotime(&tv);
		#else
		gettimeofday(&tv, NULL);
		#endif
		natE->lastTime = tv.tv_sec;	// ignore fractional seconds
			// wildcard?
		if (natE->apparent.address == 0) wildcard = 1;
		// add to both trees (0 = success)
		status = insert_by_key(kft_portMapApparentTree, (void *)natE);
		if (status != 0) { // insert failed, out of memory
			my_free(natE);		// release copied entry so it doesn't leak
			natE = NULL;
			break;
		}
		else {
			status = insert_by_key(kft_portMapActualTree, (void *)natE);
			if (status != 0) { // insert failed, out of memory
				// remove from kft_portMapApparentTree and release
				remove_by_key(kft_portMapApparentTree, (void *)natE, KFT_portMapApparentFree);
				natE = NULL;
			}
		}
	} while (0);
	return natE;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapSearchDelete()
// ---------------------------------------------------------------------------------
// Look for matching entry and delete if any before inserting new entry
// return 0 if found and deleted
int KFT_portMapSearchDelete(KFT_natEntry_t* compareEntry)
{
	int returnValue = -1;
	KFT_natEntry_t* foundEntry;
	
	if (kft_portMapApparentTree && kft_portMapActualTree) {
		// look for duplicate entries
		foundEntry = NULL;
		returnValue = get_item_by_key(kft_portMapActualTree, (void *)compareEntry, (void **)&foundEntry);
		if (returnValue == 0) KFT_portMapDelete(foundEntry);
		{
			// check other tree (defensive)
			int status;
			foundEntry = NULL;
			status = get_item_by_key(kft_portMapApparentTree, (void *)compareEntry, (void **)&foundEntry);
			if (status == 0) {
				KFT_portMapDelete(foundEntry);
				returnValue = 0;
			}
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapDelete()
// ---------------------------------------------------------------------------------
// Delete nat entry (does not search for a matching entry)
int KFT_portMapDelete(KFT_natEntry_t* entry)
{
	int returnValue = 0;
	// nat update message
	unsigned char buffer[kUpdateBufferSize];
	ipk_natUpdate_t* message;
	message = (ipk_natUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kPortMapUpdate;
	message->version = 0;
	message->flags = 0;

	if (kft_portMapActualTree && kft_portMapApparentTree) {
		// add to update message
		memcpy(&message->natUpdate[0], entry, sizeof(KFT_natEntry_t));
		message->natUpdate[0].flags |= kNatFlagDelete;
		message->length += sizeof(KFT_natEntry_t);
		// remove it
		returnValue = remove_by_key(kft_portMapActualTree, (void *)entry, KFT_portMapActualFree);
		returnValue = remove_by_key(kft_portMapApparentTree, (void *)entry, KFT_portMapApparentFree);
	}
	// are there any updates to send?
	if (message->length > 8) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapCount()
// ---------------------------------------------------------------------------------
int KFT_portMapCount()
{
	if (kft_portMapApparentTree) return kft_portMapApparentTree->length;
	else return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapCountActual()
// ---------------------------------------------------------------------------------
int KFT_portMapCountActual()
{
	if (kft_portMapActualTree) return kft_portMapActualTree->length;
	else return 0;
}


#pragma mark --- report ---
// ---------------------------------------------------------------------------------
//	¥ KFT_portMapUpload()
// ---------------------------------------------------------------------------------
// Report entries in portMap table, return number of entries found
int KFT_portMapUpload()
{
	int returnValue = 0;
 
	if (kft_portMapApparentTree) {
		// iterate over table
		iterate_inorder(kft_portMapApparentTree, KFT_portMapEntryReport, NULL);
		// update UI
		KFT_portMapSendUpdates();
		returnValue = kft_portMapApparentTree->length;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapEntryReport()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Report portMap entry to UI
int KFT_portMapEntryReport(void * key, void * iter_arg)
{
	int returnValue = 0;
	int length, howMany;
	int sizeLimit;
	// nat update message
	ipk_natUpdate_t* message;
	message = (ipk_natUpdate_t*)&updateBuffer[0];
	length = message->length;
	howMany = (length-8)/sizeof(KFT_natEntry_t);
	// calculate size limit that still leaves room for another entry
	sizeLimit = kPortMapUpdateBufferSize - sizeof(KFT_natEntry_t);

	// add to update message
	memcpy(&message->natUpdate[howMany], key, sizeof(KFT_natEntry_t));
	message->natUpdate[howMany].flags |= kNatFlagUpdate;
	message->length += sizeof(KFT_natEntry_t);
	// if message buffer is full, send it
	if (message->length >= sizeLimit) KFT_portMapSendUpdates();
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapSendUpdates()
// ---------------------------------------------------------------------------------
// send any pending portMap updates
void KFT_portMapSendUpdates()
{
	// portMap update message
	ipk_natUpdate_t* message;
	message = (ipk_natUpdate_t*)&updateBuffer[0];
	// are there any updates to send?
	if (message->length > 8) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
		message->length = 8;	// ofset to first entry
		message->flags = 0;
	}
}

#pragma mark --- logging ---
// ---------------------------------------------------------------------------------
//	¥ KFT_portMapLog()
// ---------------------------------------------------------------------------------
// Found a match in Port Mapping table, log what we are translating
// foundEntry is the port mapping entry we found
// "Port map en0 in/out src/dst endpoint addr:port->addr:port
void KFT_portMapLog(KFT_packetData_t* packet, KFT_natEntry_t* foundEntry, int mapLookup)
{
	// report debugging info
	unsigned char text[255];	// message buffer
	PSData inBuf;	
	int actualPort, apparentPort;
	// check that we have port map info to log
	if (!packet) return;
	if (!foundEntry) return;
	// initialize buffer descriptor
	inBuf.bytes = &text[0];
	inBuf.length = sizeof(ipk_message_t);
	inBuf.bufferLength = 255;
	inBuf.offset = sizeof(ipk_message_t);	// leave room for message length, type
	// build log text
	appendCString(&inBuf, "\nPort map ");
	appendCString(&inBuf, packet->myAttach->kftInterfaceEntry.bsdName);
	// packet direction
	if (packet->direction == kDirectionInbound) appendCString(&inBuf, " inbound ");
	else appendCString(&inBuf, " outbound ");
	// endpoint mapping
	actualPort = foundEntry->actual.port;
	apparentPort = foundEntry->apparent.port;
	// endpoint info from packet
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	ipHeader = (ip_header_t*)packet->datagram;
	tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
	if (actualPort == 0) {
		if (mapLookup == kMapLookup_apparent) actualPort = tcpHeader->srcPort;
		else actualPort = tcpHeader->dstPort;
		apparentPort = actualPort;
	}
	if (mapLookup == kMapLookup_apparent) {
		appendCString(&inBuf, " apparent src endpoint ");
		appendIP(&inBuf, foundEntry->actual.address);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, actualPort);
		appendCString(&inBuf, "->");
		appendIP(&inBuf, foundEntry->apparent.address);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, apparentPort);
			// dst
		appendCString(&inBuf, " dst ");
		appendIP(&inBuf, ipHeader->dstAddress);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, tcpHeader->dstPort);
	}
	else if (mapLookup == kMapLookup_actual) {
		appendCString(&inBuf, " actual dst endpoint ");
		appendIP(&inBuf, foundEntry->apparent.address);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, apparentPort);
		appendCString(&inBuf, "->");
		appendIP(&inBuf, foundEntry->actual.address);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, actualPort);
			// src
		appendCString(&inBuf, " src ");
		appendIP(&inBuf, ipHeader->srcAddress);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, tcpHeader->srcPort);
	}
	else if (mapLookup == kMapLookup_proxy) {
		appendCString(&inBuf, " proxy src endpoint ");
			// src from packet
		appendIP(&inBuf, ipHeader->srcAddress);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, tcpHeader->srcPort);
			// proxy from foundEntry
		appendCString(&inBuf, "->");
		appendIP(&inBuf, foundEntry->proxy.address);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, foundEntry->proxy.port);
			// dst
		appendCString(&inBuf, " dst ");
		appendIP(&inBuf, ipHeader->dstAddress);
		appendCString(&inBuf, ":");
		appendInt(&inBuf, tcpHeader->dstPort);
	}
	KFT_logData(&inBuf);
}

#pragma mark --- request ---
// ---------------------------------------------------------------------------------
//	¥ KFT_portMapReceiveMessage()
// ---------------------------------------------------------------------------------
int KFT_portMapReceiveMessage(ipk_message_t* message)
{
	int returnValue = 0;
	ipk_natUpdate_t* updateMessage;
	int j, length, howMany;
	KFT_natEntry_t* natEntry;

	// update for current message
	updateMessage = (ipk_natUpdate_t *)message;
	length = updateMessage->length;
	howMany = (length-8)/sizeof(KFT_natEntry_t);
	for (j=0; j<howMany; j++) {
		natEntry = &updateMessage->natUpdate[j];
		// check flags for requested action
		if (natEntry->flags == kNatFlagDelete) {
			KFT_portMapSearchDelete(natEntry);
		}
		else if (natEntry->flags == kNatFlagUpdate) {
			if ( !KFT_portMapAddCopy(natEntry) ) KFT_logText("KFT_portMapReceiveMessage - entry not added, out of memory ", NULL);
		}
		else if (natEntry->flags == kNatFlagRemoveAll) {
			KFT_portMapStart();
		}
	}
	return returnValue;
}


#pragma mark --- AVL_TREE_SUPPORT ---

// ---------------------------------------------------------------------------------
//	¥ KFT_portMapApparentFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int KFT_portMapApparentFree (void * key) {
  my_free(key);
  return 0;
}
// used as avl_free_key_fun_type
// free tree node without releasing corresponding key
int KFT_portMapActualFree (void * key) {
  return 0;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_portMapApparentCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// "epA" and "epB" refer to KFT_connectionEndpoint_t structures
// "a" is from packet, "b" is from table.  Allow port range in table.
//
// Allow wild cards in table (protocol = any, port = any).
// Notice to allow wildcards means we don't compare the corresponding field.
// Must resolve the fields we compare first to make sure the matching
// entry cannot be down a different branch.
int KFT_portMapApparentCompare (void * compare_arg, void * a, void * b)
{
	KFT_connectionEndpoint_t* epA;
	KFT_connectionEndpoint_t* epB;
	epA = (KFT_connectionEndpoint_t*)&((KFT_natEntry_t *)a)->apparent;
	epB = (KFT_connectionEndpoint_t*)&((KFT_natEntry_t *)b)->apparent;
	
	if (epA->address < epB->address) return -1;
	if (epA->address > epB->address) return +1;
	if (epB->port) {
		if (epA->port < epB->port) return -1;
			// port within range?
		u_int16_t endOffset = ((KFT_natEntry_t *)b)->endOffset;
		if (epA->port > (epB->port + endOffset)) return +1;
		// compare protocol only if port or range is specified
		if (epB->protocol) {
			if (epA->protocol < epB->protocol) return -1;
			if (epA->protocol > epB->protocol) return +1;
		}
	}
	return 0;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_portMapActualCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// "ta" and "tb" refer to KFT_connectionEndpoint_t structures
// "a" is from packet, "b" is from table.  Allow port range in table.
// Allow wild cards in table (protocol = any, port = any).
int KFT_portMapActualCompare (void * compare_arg, void * a, void * b)
{
	KFT_connectionEndpoint_t* epA;
	KFT_connectionEndpoint_t* epB;
	epA = (KFT_connectionEndpoint_t*)&((KFT_natEntry_t *)a)->actual;
	epB = (KFT_connectionEndpoint_t*)&((KFT_natEntry_t *)b)->actual;
	
	if (epA->address < epB->address) return -1;
	if (epA->address > epB->address) return +1;
	if (epB->port) {
		if (epA->port < epB->port) return -1;
			// port within range?
		u_int16_t endOffset = ((KFT_natEntry_t *)b)->endOffset;
		if (epA->port > (epB->port + endOffset)) return +1;
		// compare protocol only if port or range is specified
		if (epB->protocol) {
			if (epA->protocol < epB->protocol) return -1;
			if (epA->protocol > epB->protocol) return +1;
		}
	}
	return 0;
}
