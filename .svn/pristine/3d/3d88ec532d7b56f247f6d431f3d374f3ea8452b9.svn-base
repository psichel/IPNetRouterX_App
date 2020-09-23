//
// kftFragment.c
// IPNetRouterX
//
// Created by Peter Sichel on Fri Aug 15 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Fragment Table and support functions
//
// lastTime is stored as a u_int32_t corresponding to an NSTimeInterval since 1970.
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
#include "kftFragmentTable.h"
#include "kft.h"
#include "kftSupport.h"
#include "FilterTypes.h"
#include "avl.h"
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
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
typedef struct KFT_fragmentIterArg {
 u_int32_t currentTime;
 u_int32_t lastTime;					// oldest lastTime
 int32_t ageOutNum;
 KFT_fragmentEntry_t *entry;	// oldest entry
} KFT_fragmentIterArg_t;


// Global storage
//#include "kctGlobal.h"

// Module wide storage
// allocate Kernel Fragment Table
#define KFT_fragmentTableSize 2000
static avl_tree *kft_fragmentTree = NULL;
// free list
static SLIST_HEAD(listhead, KFT_fragmentEntry) fragment_freeList = { NULL };
static int fragment_freeCount = 0;
static int fragment_freeCountMax = 32;
static int fragment_memAllocated = 0;
static int fragment_memAllocFailed = 0;
static int fragment_memReleased = 0;
// delete list (to be deleted after iterating)
static SLIST_HEAD(listhead2, KFT_fragmentEntry) fragment_deleteList = { NULL };

// forward internal function declarations
KFT_fragmentEntry_t* KFT_fragmentMalloc();
int KFT_fragmentFree(void * key);
void KFT_fragmentFreeAll();
#if !IPK_NKE
void testMessageFromClient(ipk_message_t* message);
#endif


// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentStart()
// ---------------------------------------------------------------------------------
//	init fragment table
//  Called from IPNetRouter_NKE_start() or SO_KFT_RESET which are thread protected
void KFT_fragmentStart()
{
	// release old trees if any
	if (kft_fragmentTree) free_avl_tree(kft_fragmentTree, KFT_fragmentFree);
	kft_fragmentTree = NULL;
	// allocate new avl trees
	kft_fragmentTree = new_avl_tree (KFT_fragmentCompare, NULL);
	KFT_fragmentFreeAll();	// releaase freeList
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_fragmentStart\n");
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentStop()
// ---------------------------------------------------------------------------------
//	release fragment table
//  Called from IPNetRouter_NKE_stop()
void KFT_fragmentStop()
{
	// release old trees if any
	if (kft_fragmentTree) free_avl_tree(kft_fragmentTree, KFT_fragmentFree);
	kft_fragmentTree = NULL;
	// freeList
	KFT_fragmentFreeAll();
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_fragmentStop\n");
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentAdd()
// ---------------------------------------------------------------------------------
// add packet info to fragment table
// checks for existing entry to avoid duplicates
// return:  0 success, -1 unable to complete request
int KFT_fragmentAdd(KFT_packetData_t* packet)
{
	int returnValue = -1;
	KFT_fragmentEntry_t *entry = NULL;
	KFT_fragmentEntry_t *foundEntry = NULL;
	KFT_fragmentEntry_t compareEntry;
	u_int8_t newEntry = 0;
	
	if (packet && kft_fragmentTree) do {
		// get access to endpoint info
		ip_header_t* ipHeader;
		tcp_header_t* tcpHeader;
		ipHeader = (ip_header_t*)packet->datagram;
		tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
		// check if entry already exists
		compareEntry.fragment.srcAddress = ipHeader->srcAddress;
		compareEntry.fragment.identification = ipHeader->identification;
		returnValue = KFT_fragmentFindEntry(&compareEntry, &foundEntry);
		if (returnValue == 0) entry = foundEntry;
		else {
			// check if there is room
			if (KFT_fragmentCount() > KFT_fragmentTableSize) {
				KFT_fragmentAge();	// make more if needed
			}
			// add entry to fragment table
			entry = KFT_fragmentMalloc();
			if (!entry) {
				returnValue = -1;	// out of memory
				break;
			}
			newEntry = 1;
		}
		// load entry info
		bzero(entry, sizeof(KFT_fragmentEntry_t));
		// lastTime
		struct timeval tv;
		#if IPK_NKE
		getmicrotime(&tv);
		#else
		gettimeofday(&tv, NULL);
		#endif
		entry->lastTime = tv.tv_sec;	// ignore fractional seconds
		// load entry
		entry->fragment.srcAddress = ipHeader->srcAddress;
		entry->fragment.identification = ipHeader->identification;
		entry->srcPort = tcpHeader->srcPort;
		entry->dstPort = tcpHeader->dstPort;
		// if new entry
		if (newEntry) {
			// add to tree
			returnValue = insert_by_key(kft_fragmentTree, (void *)entry);
			if (returnValue != 0) { // insert failed, out of memory
				KFT_fragmentFree(entry);		// release new entry so we don't leak it
			}
		}
	} while (0);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentFindEntry()
// ---------------------------------------------------------------------------------
// Search for entry in fragment table
// return 0=success, foundEntry points to the entry we found
//		 -1=not found or other error
int KFT_fragmentFindEntry(KFT_fragmentEntry_t* compareEntry, KFT_fragmentEntry_t** foundEntry)
{
	if ((*foundEntry != NULL) || !kft_fragmentTree) return -1;
	return get_item_by_key(kft_fragmentTree, (void *)compareEntry, (void **)foundEntry);
}
/*
		KFT_fragmentEntry_t *foundEntry = NULL;
		KFT_fragmentEntry_t compareEntry;
		ip_header_t* ipHeader;
		tcp_header_t* tcpHeader;
		
		ipHeader = (ip_header_t*)packet->datagram;
		tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
		compareEntry.fragment.srcAddress = ipHeader->srcAddress;
		compareEntry.fragment.idenfication = ipHeader->identification;

		returnValue = KFT_fragmentFindEntry(&compareEntry, &foundEntry);
*/


// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentAge()
// ---------------------------------------------------------------------------------
// Age entries in fragment table
// Called from ipk_timeout which is thread protected.
// Return how many were aged out
int KFT_fragmentAge()
{
	int returnValue = 0;
	KFT_fragmentIterArg_t arg;
 
	if (kft_fragmentTree) {
		// get current time
		struct timeval tv;
		#if IPK_NKE
		getmicrotime(&tv);
		#else
		gettimeofday(&tv, NULL);
		#endif
		arg.currentTime = tv.tv_sec;
		arg.lastTime = tv.tv_sec;
		arg.ageOutNum = 0;
		arg.entry = NULL;
		// iterate over table
		iterate_inorder(kft_fragmentTree, KFT_fragmentEntryAge, &arg);
		returnValue = arg.ageOutNum;
		// remove entries from delete list
		KFT_fragmentEntry_t* entry;
		while ((entry = SLIST_FIRST(&fragment_deleteList)) != NULL) {
			SLIST_REMOVE_HEAD(&fragment_deleteList, entries);
			KFT_fragmentEntryRemove(entry);
		}
		// if "table is full", release the oldest entry
		if (KFT_fragmentCount() > KFT_fragmentTableSize) {
			if (arg.entry) {
				KFT_fragmentEntryRemove(arg.entry);
				returnValue += 1;
			}
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentEntryAge()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Called periodically for each entry in the fragment table to age it.
// Check age against limits and age out by adding to free list.
// Remember oldest entry we've seen so far.
int KFT_fragmentEntryAge(void * key, void * iter_arg)
{
	int returnValue = 0;
	KFT_fragmentEntry_t* entry;
	KFT_fragmentIterArg_t* arg;
	long age;
	
	entry = (KFT_fragmentEntry_t *)key;
	arg = (KFT_fragmentIterArg_t *)iter_arg;
	// check age of this entry
	age = arg->currentTime - entry->lastTime;
	// age out?
	if (age > 120) {	// 2 minutes
		// remove it
		//if (arg->ageOutNum < arg->ageOutMax) arg->ageOutList[arg->ageOutNum++] = entry;
		SLIST_INSERT_HEAD(&fragment_deleteList, entry, entries);
		arg->ageOutNum++;
	}
	else {
		// remember oldest we've seen so far
		if (entry->lastTime < arg->lastTime) {
			arg->lastTime = entry->lastTime;
			arg->entry = entry;
		}
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentEntryRemove()
// ---------------------------------------------------------------------------------
// Report entry is going away (if useful) and delete it.
int KFT_fragmentEntryRemove(KFT_fragmentEntry_t* entry)
{
	int returnValue = 0;
	if (!entry) return -1;
	// remove entry from tree
	if (kft_fragmentTree) returnValue = remove_by_key(kft_fragmentTree, (void *)entry, KFT_fragmentFree);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentCount()
// ---------------------------------------------------------------------------------
int KFT_fragmentCount()
{
	if (kft_fragmentTree) return kft_fragmentTree->length;
	else return 0;
}


#pragma mark --- AVL_TREE_SUPPORT ---
// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentMemStat()
// ---------------------------------------------------------------------------------
KFT_memStat_t* KFT_fragmentMemStat(KFT_memStat_t* record) {
	KFT_memStat_t* next = record;
	next->type = kMemStat_fragment;
	next->freeCount = fragment_freeCount;
	next->tableCount = KFT_fragmentCount();
	next->allocated = fragment_memAllocated;
	next->released = fragment_memReleased;
	next->allocFailed = fragment_memAllocFailed;
	next->leaked = next->allocated - next->released - next->tableCount - next->freeCount;
	next++;
	return next;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentMalloc()
// ---------------------------------------------------------------------------------
KFT_fragmentEntry_t* KFT_fragmentMalloc() {
	KFT_fragmentEntry_t* entry;
	// try to get one from our freeList
	if ((entry = SLIST_FIRST(&fragment_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&fragment_freeList, entries);
		fragment_freeCount -= 1;
	}
	else {
		entry = (KFT_fragmentEntry_t *)my_malloc(sizeof(KFT_fragmentEntry_t));
		if (entry) fragment_memAllocated += 1;
		else fragment_memAllocFailed += 1;
	}
	return entry;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int KFT_fragmentFree (void * key) {
	KFT_fragmentEntry_t* entry = (KFT_fragmentEntry_t*)key;
	if (fragment_freeCount < fragment_freeCountMax) {
		SLIST_INSERT_HEAD(&fragment_freeList, entry, entries);
		fragment_freeCount += 1;
	}
	else {
		my_free(key);
		fragment_memReleased += 1;
	}
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentFreeAll()
// ---------------------------------------------------------------------------------
void KFT_fragmentFreeAll() {
	KFT_fragmentEntry_t* entry;
	while ((entry = SLIST_FIRST(&fragment_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&fragment_freeList, entries);
		my_free((void*)entry);
		fragment_memReleased += 1;
	}
	fragment_freeCount = 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_fragmentCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// "ta" and "tb" refer to KFT_fragmentId_t structures
int KFT_fragmentCompare (void * compare_arg, void * a, void * b)
{
#if 1
	KFT_fragmentId_t *ta = (KFT_fragmentId_t *)a;
	KFT_fragmentId_t *tb = (KFT_fragmentId_t *)b;
	if (ta->identification < tb->identification) return -1;
	if (ta->identification > tb->identification) return +1;
	if (ta->srcAddress < tb->srcAddress) return -1;
	if (ta->srcAddress > tb->srcAddress) return +1;
	return 0;
#else
	u_int64_t* ta;
	u_int64_t* tb;
	ta = (u_int64_t*)&((KFT_fragmentEntry_t *)a)->fragment;		// Big Endian
	tb = (u_int64_t*)&((KFT_fragmentEntry_t *)b)->fragment;		// Big Endian
	if ( *ta < *tb ) {
		return -1;
	} else if ( *ta > *tb ) {
		return +1;
	} else {
		return 0;
	}
#endif
}

