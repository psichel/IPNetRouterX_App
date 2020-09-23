//
// kftNatTable.c
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
// We use a separate table for "static" versus "dynamic" NAT entries
// for greater flexibility and efficiency.
// - search static table first
// - don't age static entries
// - can search static only for local NAT
// - replace dynamic entries only

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
#include "kftNatTable.h"
#include "kftPortMapTable.h"
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

// IterArg passed to iterate function along with each node in tree
struct KFT_natIterArg {
 u_int32_t currentTime;
 u_int32_t lastTime;					// oldest lastTime
 int32_t ageOutNum;
 KFT_natEntry_t *entry;	// oldest entry
};
typedef struct KFT_natIterArg KFT_natIterArg_t;

// Global storage
//#include "kftGlobal.h"

// Module wide storage
// -------------------
// allocate Kernel Nat Table
#define KFT_natTableSize 2000

static avl_tree *kft_natApparentTree = NULL;
static avl_tree *kft_natActualTree = NULL;
static u_int32_t sssoe = 0;		// seconds since start of epoc
// free list
static SLIST_HEAD(listhead, KFT_natEntry) nat_freeList = { NULL };
static int nat_freeCount = 0;
static int nat_freeCountMax = 128;
static int nat_memAllocated = 0;
static int nat_memAllocFailed = 0;
static int nat_memReleased = 0;
// delete list (to be deleted after iterating)
static SLIST_HEAD(listhead2, KFT_natEntry) nat_deleteList = { NULL };

#define kNatUpdateBufferSize 2000
static unsigned char updateBuffer[kNatUpdateBufferSize];

// NAT parameters are stored in attach instance as kftInterfaceEntry (see ipkTypes.h)

// forward internal function declarations
KFT_natEntry_t* KFT_natMalloc();
int KFT_natApparentFree (void * key);
int KFT_natActualFree (void * key);
void KFT_natFreeAll();
#if !IPK_NKE
void testMessageFromClient(ipk_message_t* message);
#endif


// ---------------------------------------------------------------------------------
//	¥ KFT_natStart()
// ---------------------------------------------------------------------------------
//	init nat table
//  Called from IPNetRouter_NKE_start() or SO_KFT_RESET which are thread protected
void KFT_natStart()
{
	// release old trees if any
	if (kft_natApparentTree) free_avl_tree(kft_natApparentTree, KFT_natApparentFree);
	if (kft_natActualTree) free_avl_tree(kft_natActualTree, KFT_natActualFree);
	kft_natApparentTree = NULL;
	kft_natActualTree = NULL;
	sssoe = 0;
	// allocate new avl trees
	kft_natApparentTree = new_avl_tree (KFT_natApparentCompare, NULL);
	kft_natActualTree = new_avl_tree (KFT_natActualCompare, NULL);
	KFT_natFreeAll();	// release freeList
	{   // initialize update buffer
		ipk_natUpdate_t* message;
		message = (ipk_natUpdate_t*)&updateBuffer[0];
		message->length = 8;	// offset to first entry
		message->type = kNatUpdate;
		message->version = 0;
		message->flags = 0;
	}
	// static table
	KFT_portMapStart();
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_natStart\n");
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natStop()
// ---------------------------------------------------------------------------------
//	release nat table
//  Called from IPNetRouter_NKE_stop()
void KFT_natStop()
{
	// release old trees if any
	if (kft_natApparentTree) free_avl_tree(kft_natApparentTree, KFT_natApparentFree);
	if (kft_natActualTree) free_avl_tree(kft_natActualTree, KFT_natActualFree);
	kft_natApparentTree = NULL;
	kft_natActualTree = NULL;
	// freeList
	KFT_natFreeAll();
	// static table
	KFT_portMapStop();
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_natStop\n");
	#endif
}


// ---------------------------------------------------------------------------------
//	¥ KFT_natPacket()
// ---------------------------------------------------------------------------------
// add (outgoing) packet info to nat table
// caller must check for existing actual EP entry to avoid duplication ( KFT_natFindApparentForActual() )
// return a pointer to new entry as packet->natEntry
// return:  0 success, -1 unable to complete request
int KFT_natPacket(KFT_packetData_t* packet)
{
	int returnValue = -1;	// unable to complete request
	KFT_natEntry_t *entry = NULL;
	KFT_interfaceEntry_t* params;
	int i, limit;
	
	if (packet && kft_natApparentTree && kft_natActualTree) {
		// check if there is room
		if (KFT_natCount() > KFT_natTableSize) {
			KFT_natAge();	// make more if needed
		}
		// add entry to nat table
		entry = KFT_natMalloc();		
		if (entry) {
			returnValue = 0;
			bzero(entry, sizeof(KFT_natEntry_t));
			// lastTime
			struct timeval tv;
			#if IPK_NKE
			getmicrotime(&tv);
			#else
			gettimeofday(&tv, NULL);
			#endif
			entry->lastTime = tv.tv_sec;	// ignore fractional seconds
			// record which interface created nat entry
			memcpy(entry->bsdName, packet->myAttach->kftInterfaceEntry.bsdName, kBSDNameLength);
			// endpoint info
			ip_header_t* ipHeader;
			tcp_header_t* tcpHeader;
			ipHeader = (ip_header_t*)packet->datagram;
			tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
				// actual
			entry->actual.protocol 	= ipHeader->protocol;
			if ((ipHeader->protocol == IPPROTO_TCP) || (ipHeader->protocol == IPPROTO_UDP)) {
				entry->actual.port	= tcpHeader->srcPort;
				entry->remote.port	= tcpHeader->dstPort;
			}
			entry->actual.address	= ipHeader->srcAddress;
				// apparent
			params = &packet->myAttach->kftInterfaceEntry;
			entry->apparent.protocol = ipHeader->protocol;
			entry->apparent.port = entry->actual.port;
			entry->apparent.address = params->natNet.address;
			if (packet->localProxy && (packet->direction == kDirectionInbound)) {
				entry->apparent.address = 1;	// reflector for local transparent proxy
			}
				// remote
			entry->remote.protocol 	= ipHeader->protocol;
			//if ((ipHeader->protocol == IPPROTO_TCP) || (ipHeader->protocol == IPPROTO_UDP))
			//	entry->remote.port	= tcpHeader->dstPort;
			entry->remote.address	= ipHeader->dstAddress;
			// Check if apparent endpoint is already in use
			do {
				avl_node* node;
				unsigned long index;
				int result;
				KFT_natEntry_t *foundEntry;
				i = 0;	// initialize search variables
				limit = KFT_natCount() + 3;

				// look for corresponding node in kft_natApparentTree
				node = get_index_by_key(kft_natApparentTree, entry, &index);
				if (node == NULL) {	// not found
					// check portMap table as well
					foundEntry = NULL;
					result = KFT_natFindActualForApparent(packet, entry, &foundEntry);
					if (result) break;	// endpoint is available (not found)
				}
				else foundEntry = node->key;				
				// apparent endpoint is busy, if port == 0 (protocol ICMP or unknown),
				// replace corresponding entry if not static
				if (entry->apparent.port == 0) {
					KFT_natDelete(foundEntry);
					break;
				}
				// look for next available port				
				for (i=0; i<limit; i++) {	
					// determine next port after found entry
					entry->apparent.port = foundEntry->apparent.port + foundEntry->endOffset + 1;
					if (node) {
						node = get_successor(node);		// next in tree
						if (node) {
							foundEntry = node->key;
							result = KFT_natApparentCompare(NULL, entry, foundEntry);
							if (result < 0) node = NULL;	// node does not match endpoint
						}
					}
					else node = get_index_by_key(kft_natApparentTree, entry, &index);
					if (node == NULL) {	// not found
						// check portMap table as well
						foundEntry = NULL;
						result = KFT_natFindActualForApparent(packet, entry, &foundEntry);
						if (result) break;	// endpoint is available (not found)
					}
					else foundEntry = node->key;
				}
			} while (0);
			if (i < limit) {
				// add to both trees (0 = success)
				returnValue = insert_by_key(kft_natApparentTree, (void *)entry);
				if (returnValue != 0) {		// insert failed, out of memory
					KFT_natApparentFree(entry);			// release new entry so it doesn't leak
				}
				else {
					returnValue = insert_by_key(kft_natActualTree, (void *)entry);
					if (returnValue != 0) { // insert failed, out of memory
						// remove from kft_natApparentTree and release
						remove_by_key(kft_natApparentTree, (void *)entry, KFT_natApparentFree);
					}
					else {
						// include entry with packet
						packet->natEntry = entry;
						// update UI with new entry
						KFT_natEntryReport(entry, NULL);
						KFT_natSendUpdates();
						#if DEBUG_IPK
							log(LOG_WARNING, "KFT_natAdd\n");
						#endif
					}
				}
			}
			else {
				KFT_natApparentFree(entry);
				returnValue = -2;	// could not find an unused apparent endpoint
			}
		}   // if (entry)
	}   // if (packet && kft_natApparentTree && kft_natActualTree)
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natAddCopy()
// ---------------------------------------------------------------------------------
// Add entry to NAT table by making a copy of the entry passed in.
// Check for duplicates and replace if found.
// return:  ptr to new entry on success, nil = out of memory or other error
KFT_natEntry_t* KFT_natAddCopy(KFT_natEntry_t* entry)
{
	KFT_natEntry_t* natE = NULL;
	int status;
	
	do {
		if (!kft_natApparentTree || !kft_natActualTree) break;
		natE = KFT_natMalloc();	
		if (!natE) break;	// out of memory
			// copy data content to newly allocated entry
		memcpy(natE, entry, sizeof(KFT_natEntry_t));
			// look for duplicate entries and delete them before adding
		KFT_natSearchDelete(natE);	// calls mfree for matching tree entry
			// lastTime
		struct timeval tv;
		#if IPK_NKE
		getmicrotime(&tv);
		#else
		gettimeofday(&tv, NULL);
		#endif
		natE->lastTime = tv.tv_sec;	// ignore fractional seconds
		// add to both trees (0 = success)
		status = insert_by_key(kft_natApparentTree, (void *)natE);
		if (status != 0) { // insert failed, out of memory
			KFT_natApparentFree(natE);		// release new entry so it doesn't leak
			natE = NULL;
			break;
		}
		else {
			status = insert_by_key(kft_natActualTree, (void *)natE);
			if (status != 0) {		// insert failed, out of memory
				// remove from kft_natApparentTree and release
				remove_by_key(kft_natApparentTree, (void *)natE, KFT_natApparentFree);
				natE = NULL;
			}
		}
	} while (0);
	return natE;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natSearchDelete()
// ---------------------------------------------------------------------------------
// Look for matching entry and delete if any before inserting new entry
// return 0 if found and deleted
int KFT_natSearchDelete(KFT_natEntry_t* compareEntry)
{
	int returnValue = -1;
	KFT_natEntry_t* foundEntry;
	
	if (kft_natApparentTree && kft_natActualTree) {
			// look for duplicate entries and delete them before adding
		foundEntry = NULL;
		returnValue = get_item_by_key(kft_natActualTree, (void *)compareEntry, (void **)&foundEntry);
		if (returnValue == 0) KFT_natDelete(foundEntry);
		{
			// check other tree (defensive)
			int status;
			foundEntry = NULL;
			status = get_item_by_key(kft_natApparentTree, (void *)compareEntry, (void **)&foundEntry);
			if (status == 0) {
				KFT_natDelete(foundEntry);
				returnValue = 0;
			}
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natDelete()
// ---------------------------------------------------------------------------------
// Delete nat entry (does not search for a matching entry, so must be an actual tree entry)
int KFT_natDelete(KFT_natEntry_t* entry)
{
	int returnValue = 0;
	// nat update message
	unsigned char buffer[kUpdateBufferSize];
	ipk_natUpdate_t* message;
	message = (ipk_natUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kNatUpdate;
	message->version = 0;
	message->flags = 0;

	if (kft_natApparentTree && kft_natActualTree) {
		// add to update message
		memcpy(&message->natUpdate[0], entry, sizeof(KFT_natEntry_t));
		message->natUpdate[0].flags |= kNatFlagDelete;
		message->length += sizeof(KFT_natEntry_t);
		// remove it
		returnValue = remove_by_key(kft_natActualTree, (void *)entry, KFT_natActualFree);
		returnValue = remove_by_key(kft_natApparentTree, (void *)entry, KFT_natApparentFree);
	}
	// are there any updates to send?
	if (message->length > 8) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natFindApparentForActual()
// ---------------------------------------------------------------------------------
// Search for entry in nat table
// return 0=success, foundEntry points to the entry we found
//		 -1=not found or other error
// include packet to pass along any additional state as needed.
int KFT_natFindApparentForActual(KFT_packetData_t* packet, KFT_natEntry_t* compareEntry, KFT_natEntry_t** foundEntry)
{
	int returnValue;
	KFT_natEntry_t *myEntry = NULL;
	if ((*foundEntry != NULL) || !kft_natActualTree) return -1;
	// search static table first
	returnValue = KFT_portMapFindApparentForActual(packet, compareEntry, &myEntry);
	// skip inactive
	if ((returnValue == 0) && myEntry->inactive) returnValue = -1;
	if (returnValue != 0) {
		// if not found, search dynamic table
		returnValue = get_item_by_key(kft_natActualTree, (void *)compareEntry, (void **)&myEntry);
		if (returnValue == 0) {
			// verify apparent address found matches the interface we're using
			KFT_interfaceEntry_t* params = &packet->myAttach->kftInterfaceEntry;
			if ( myEntry->apparent.address != params->natNet.address) {
				// replace entry for this interface
				KFT_natDelete(myEntry);
				returnValue = KFT_natPacket(packet);
				myEntry = packet->natEntry;
			}
		}
	}
	// found entry
	if (returnValue == 0) {
		// update lastTime
		struct timeval tv;
		#if IPK_NKE
		getmicrotime(&tv);
		#else
		gettimeofday(&tv, NULL);
		#endif
		myEntry->lastTime = tv.tv_sec;	// ignore fractional seconds
		// update entry we found
		*foundEntry = myEntry;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natFindActualForApparent()
// ---------------------------------------------------------------------------------
int KFT_natFindActualForApparent(KFT_packetData_t* packet, KFT_natEntry_t* compareEntry, KFT_natEntry_t** foundEntry)
{
	int returnValue;
	if ((*foundEntry != NULL) || !kft_natApparentTree) return -1;
	// search static table first
	returnValue = KFT_portMapFindActualForApparent(packet, compareEntry, foundEntry);
	// skip inactive
	if ((returnValue == 0) && (*foundEntry)->inactive) returnValue = -1;
	// if not found, search dynamic table
	if (returnValue != 0)
		returnValue = get_item_by_key(kft_natApparentTree, (void *)compareEntry, (void **)foundEntry);
	// update lastTime
	if (returnValue == 0) {
		struct timeval tv;
		#if IPK_NKE
		getmicrotime(&tv);
		#else
		gettimeofday(&tv, NULL);
		#endif
		(*foundEntry)->lastTime = tv.tv_sec;	// ignore fractional seconds
	}
	return returnValue;
}


#pragma mark --- age ---
// ---------------------------------------------------------------------------------
//	¥ KFT_natSecond()
// ---------------------------------------------------------------------------------
// update Seconds Since Start of Epoc
// Called once per second from ipk_timeout which is thread protected.
void KFT_natSecond()
{
	sssoe += 1;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natAge()
// ---------------------------------------------------------------------------------
// Age entries in nat table
// Called from ipk_timeout which is thread protected.
// Return number of entries aged out
int KFT_natAge()
{
	int returnValue = 0;
	KFT_natIterArg_t arg;
 
	if (kft_natApparentTree) {
		// get current time
		struct timeval tv;
		#if IPK_NKE
		getmicrotime(&tv);
		#else
		gettimeofday(&tv, NULL);
		#endif
		arg.currentTime = tv.tv_sec;
		arg.lastTime = tv.tv_sec;
		arg.entry = NULL;
		arg.ageOutNum = 0;
		// iterate over table
		iterate_inorder(kft_natApparentTree, KFT_natEntryAge, &arg);
		returnValue = arg.ageOutNum;
		// remove entries from delete list
		KFT_natEntry_t* entry;
		while ((entry = SLIST_FIRST(&nat_deleteList)) != NULL) {
			SLIST_REMOVE_HEAD(&nat_deleteList, entries);
			KFT_natEntryRemove(entry);
		}
		// if "table is full", release the oldest entry
		if (KFT_natCount() > KFT_natTableSize) {
			if (arg.entry) {
				KFT_natEntryRemove(arg.entry);
				returnValue += 1;
			}
		}
		// update UI
		KFT_natSendUpdates();
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natEntryAge()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Called periodically for each entry in the nat table to age it.
// Check age against limits and age out by adding to free list.
// Remember oldest entry we've seen so far.
int KFT_natEntryAge(void * key, void * iter_arg)
{
	int returnValue = 0;
	KFT_natEntry_t* entry;
	KFT_natIterArg_t* arg;
	int32_t age;
	int32_t limit;

	entry = (KFT_natEntry_t *)key;
	arg = (KFT_natIterArg_t *)iter_arg;
	// check age of this entry
	age = arg->currentTime - entry->lastTime;
	// calculate age limit based on entry
	switch (entry->apparent.protocol) {
		case IPPROTO_TCP:
			if ((entry->flags & kNatFlagFINAckLocal) && (entry->flags & kNatFlagFINAckPeer)) {
				// FIN ACK both ways, connection is fully closed
				limit = 2;
			}
			else if (!(entry->flags & kNatFlagFINLocal) &&
				!(entry->flags & kNatFlagFINPeer)) {
				// TCP and not half closed
				if (!(entry->flags & kNatFlagNonSyn)) {					
					// we haven't seen a non Syn
					limit = 240;	// 4 minutes (since last retry)
				}
				else {
					int count = KFT_natCount();
					if (count < 100)		limit = 86400;	// 1 day
					else if (count < 500)	limit = 3600;	// 1 hour
					else					limit = 1800;	// 30 minutes
				}
			}
			else {
				// TCP half or full close
				limit = 120;	// 2 minutes
			}
			break;
		case IPPROTO_UDP:
			if (entry->actual.port == 500) limit = 1800;
			else if ((entry->remote.port == 53) || (entry->actual.port == 53))
				limit = 30;  // DNS querry (30 sec since last retry)
			else limit = 240;	// 4 minutes
			break;
		case IPPROTO_ICMP:
			limit = 60;		// 1 minute
			break;
		case IPPROTO_GRE:
		case IPPROTO_ESP:	// IPSec
			limit = 1800;	// 30 minutes
			break;
		default:
			limit = 240;	// 4 minutes (since last retry)
			break;
	}
	
	// age out?
	if (age >= limit) {
		// remove it
		//if (arg->ageOutNum < arg->ageOutMax) arg->ageOutList[arg->ageOutNum++] = entry;
		SLIST_INSERT_HEAD(&nat_deleteList, entry, entries);
		arg->ageOutNum++;
	}
	else {
		// remember oldest we've seen so far
		if (entry->lastTime < arg->lastTime) {
			arg->lastTime = entry->lastTime;
			arg->entry = entry;
		}
		// report entry if changed since last interval
		if (arg->currentTime - entry->lastTime < 11) {
			KFT_natEntryReport(key, iter_arg);
		}
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_natEntryRemove()
// ---------------------------------------------------------------------------------
// Report entry is going away and then delete it
int KFT_natEntryRemove(KFT_natEntry_t* entry)
{
	int returnValue;
	if (!entry) return -1;
	// report this entry since we're about to remove it
	entry->flags = kNatFlagDelete;
	KFT_natEntryReport(entry, NULL);
	// remove nat from rate limit rule if any (handled by filterUpdate)
		
	// remove entry from tree
	returnValue = KFT_natDelete(entry);
	return returnValue;
}

#pragma mark --- report ---
// ---------------------------------------------------------------------------------
//	¥ KFT_natUpload()
// ---------------------------------------------------------------------------------
// Report entries in nat table, return number of entries found
int KFT_natUpload()
{
	int returnValue = 0;
 
	if (kft_natApparentTree) {
		// iterate over table
		iterate_inorder(kft_natApparentTree, KFT_natEntryReport, NULL);
		// update UI
		KFT_natSendUpdates();
		returnValue = kft_natApparentTree->length;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natEntryReport()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Report nat entry to UI
int KFT_natEntryReport(void * key, void * iter_arg)
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
	sizeLimit = kNatUpdateBufferSize - sizeof(KFT_natEntry_t);

	// add to update message
	memcpy(&message->natUpdate[howMany], key, sizeof(KFT_natEntry_t));
	message->natUpdate[howMany].flags |= kNatFlagUpdate;
	message->length += sizeof(KFT_natEntry_t);
	// if message buffer is full, send it
	if (message->length >= sizeLimit) KFT_natSendUpdates();
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natSendUpdates()
// ---------------------------------------------------------------------------------
// send any pending nat updates
void KFT_natSendUpdates()
{
	// nat update message
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

// ---------------------------------------------------------------------------------
//	¥ KFT_natCount()
// ---------------------------------------------------------------------------------
int KFT_natCount()
{
	if (kft_natApparentTree) return kft_natApparentTree->length;
	else return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natCountActual()
// ---------------------------------------------------------------------------------
int KFT_natCountActual()
{
	if (kft_natActualTree) return kft_natActualTree->length;
	else return 0;
}

#pragma mark --- request ---
// ---------------------------------------------------------------------------------
//	¥ KFT_natReceiveMessage()
// ---------------------------------------------------------------------------------
int KFT_natReceiveMessage(ipk_message_t* message)
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
			KFT_natSearchDelete(natEntry);
		}
		else if (natEntry->flags == kNatFlagUpdate) {
			if (!KFT_natAddCopy(natEntry)) {
				KFT_logText("KFT_natReceiveMessage - entry not added, out of memory ", NULL);
			}
		}
	}
	return returnValue;
}


#pragma mark --- AVL_TREE_SUPPORT ---
// ---------------------------------------------------------------------------------
//	¥ KFT_natMemStat()
// ---------------------------------------------------------------------------------
KFT_memStat_t* KFT_natMemStat(KFT_memStat_t* record) {
	KFT_memStat_t* next = record;
	next->type = kMemStat_nat;
	next->freeCount = nat_freeCount;
	next->tableCount = KFT_natCount();
	next->allocated = nat_memAllocated;
	next->released = nat_memReleased;
	next->allocFailed = nat_memAllocFailed;
	next->leaked = next->allocated - next->released - next->tableCount - next->freeCount;
	next++;
	// port  map
	bzero(next, sizeof(KFT_memStat_t));
	next->type = kMemStat_portMap;
	next->tableCount = KFT_portMapCount();
	next++;
	return next;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natMalloc()
// ---------------------------------------------------------------------------------
KFT_natEntry_t* KFT_natMalloc() {
	KFT_natEntry_t* entry;
	// try to get one from our freeList
	if ((entry = SLIST_FIRST(&nat_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&nat_freeList, entries);
		nat_freeCount -= 1;
	}
	else {
		entry = (KFT_natEntry_t *)my_malloc(sizeof(KFT_natEntry_t));
		if (entry) nat_memAllocated += 1;
		else nat_memAllocFailed += 1;
	}
	return entry;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natApparentFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int KFT_natApparentFree (void * key) {
	KFT_natEntry_t* entry = (KFT_natEntry_t*)key;
	if (nat_freeCount < nat_freeCountMax) {
		SLIST_INSERT_HEAD(&nat_freeList, entry, entries);
		nat_freeCount += 1;
	}
	else {
		my_free(key);
		nat_memReleased += 1;
	}
	return 0;
}

// used as avl_free_key_fun_type
// free tree node without releasing corresponding key
int KFT_natActualFree (void * key) {
  return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natFreeAll()
// ---------------------------------------------------------------------------------
void KFT_natFreeAll() {
	KFT_natEntry_t* entry;
	while ((entry = SLIST_FIRST(&nat_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&nat_freeList, entries);
		my_free((void*)entry);
		nat_memReleased += 1;
	}
	nat_freeCount = 0;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_natApparentCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// "ta" and "tb" refer to KFT_connectionEndpoint_t structures
// "a" is from packet, "b" is from table.  Allow port range in table.
int KFT_natApparentCompare (void * compare_arg, void * a, void * b)
{
#if 1
	KFT_connectionEndpoint_t* ta;
	KFT_connectionEndpoint_t* tb;
		// apparent EP
	ta = &((KFT_natEntry_t *)a)->apparent;
	tb = &((KFT_natEntry_t *)b)->apparent;
	// port
	if (ta->port < tb->port) return -1;
		// port within range?
	u_int16_t endOffset = ((KFT_natEntry_t *)b)->endOffset;
	if (ta->port > (tb->port + endOffset)) return +1;
	// protocol
	if (ta->protocol < tb->protocol) return -1;
	if (ta->protocol > tb->protocol) return +1;
	// address
	if (ta->address < tb->address) return -1;
	if (ta->address > tb->address) return +1;
		// all are equal
	return 0;
#else
	u_int64_t ta;
	u_int64_t tb;
	KFT_connectionEndpoint_t* epB;
	ta = *(u_int64_t*)&((KFT_natEntry_t *)a)->apparent;		// Big Endian
	tb = *(u_int64_t*)&((KFT_natEntry_t *)b)->apparent;		// Big Endian
	if ( ta < tb ) return -1;
	if ( ta > tb ) {
		u_int16_t range = ((KFT_natEntry_t *)b)->endOffset;
		if (range == 0) return +1;
		else {
			epB = (KFT_connectionEndpoint_t*)&tb;
			epB->port += range;
			if ( ta > tb ) return +1;
			// port within range
		}
	}
	return 0;
#endif
}


// ---------------------------------------------------------------------------------
//	¥ KFT_natActualCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// "ta" and "tb" refer to KFT_natEndpoint_t structures
// "a" is from packet, "b" is from table.  Allow port range in table.
int KFT_natActualCompare (void * compare_arg, void * a, void * b)
{
#if 1
	KFT_connectionEndpoint_t* ta;
	KFT_connectionEndpoint_t* tb;
		// apparent EP
	ta = &((KFT_natEntry_t *)a)->actual;
	tb = &((KFT_natEntry_t *)b)->actual;
	// port
	if (ta->port < tb->port) return -1;
		// port within range?
	u_int16_t endOffset = ((KFT_natEntry_t *)b)->endOffset;
	if (ta->port > (tb->port + endOffset)) return +1;
	// protocol
	if (ta->protocol < tb->protocol) return -1;
	if (ta->protocol > tb->protocol) return +1;
	// address
	if (ta->address < tb->address) return -1;
	if (ta->address > tb->address) return +1;
		// all are equal
	return 0;
#else
	u_int64_t ta;
	u_int64_t tb;
	KFT_connectionEndpoint_t* epB;
	ta = *(u_int64_t*)&((KFT_natEntry_t *)a)->actual;		// Big Endian
	tb = *(u_int64_t*)&((KFT_natEntry_t *)b)->actual;		// Big Endian
	if ( ta < tb ) return -1;
	if ( ta > tb ) {
		u_int16_t range = ((KFT_natEntry_t *)b)->endOffset;
		if (range == 0) return +1;
		else {
			epB = (KFT_connectionEndpoint_t*)&tb;
			epB->port += range;
			if ( ta > tb ) return +1;
			// port within range
		}
	}
	return 0;
#endif
}
