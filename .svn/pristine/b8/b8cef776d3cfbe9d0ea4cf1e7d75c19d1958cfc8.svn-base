//
// kftTrigger.c
// IPNetSentryX
//
// Created by Peter Sichel on Fri Mar 21 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Trigger Table and support functions
//
// Notice we define a trigger table entry to contain the IP address, type,
// last time it was triggered, and duration.  Each entry is stored in
// an AVL Tree ordered by address and type.
// Showing the last time an entry was matched is easily interpreted
// by the user and requires the least amount of updating.  Only new matches
// need be updated in the display listing.
// 
// Searching the table for a matching entry is extremely fast,
// but aging the table requires we examine each entry to compare
// the last time and duration against the current time.
// This could be optimized by keeping a list of entries about
// expire, but for now we assume the table is usually small.
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
#include "kft.h"
#include "kftTrigger.h"
#include "IPKSupport.h"
#include "avl.h"
#include <sys/time.h>
#include <sys/queue.h>
#include <mach/boolean.h>
#include <string.h>

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
#include <sys/errno.h>
#define my_malloc(a)	malloc(a)
#define my_free(a)	free(a)
#endif

// IterArg passed to iterate function along with each node in tree
struct KFT_triggerIterArg {
 u_int32_t currentTime;
 u_int32_t lastTime;				// oldest lastTime
 u_int32_t limit;
 u_int32_t flags;
 long ageOutNum;
 KFT_triggerEntry_t *entry;	// oldest entry
};
typedef struct KFT_triggerIterArg KFT_triggerIterArg_t;

// Global storage
#include "kftGlobal.h"

// Module wide storage
// allocate Kernel Trigger Table
#define KFT_triggerTableSize 4000
static int kft_triggerTableSize = KFT_triggerTableSize;
static avl_tree *kft_triggerTree = NULL;
// free list
static SLIST_HEAD(listhead, KFT_triggerEntry) trigger_freeList = { NULL };
static int trigger_freeCount = 0;
static int trigger_freeCountMax = 256;
static int trigger_memAllocated = 0;
static int trigger_memAllocFailed = 0;
static int trigger_memReleased = 0;
// delete list (to be deleted after iterating)
static SLIST_HEAD(listhead2, KFT_triggerEntry) trigger_deleteList = { NULL };

static int kft_triggerDuration = 3;		// 1 hour
static u_int32_t kft_triggerLastUpdateTime = 0;

#define kTriggerUpdateBufferSize 2000
static unsigned char updateBuffer[kTriggerUpdateBufferSize];	 // must fit within a 2048 byte cluster


// forward internal function declarations
// support
int KFT_triggerSeconds(int value);
// age table
int KFT_triggerEntryAge(void * key, void * iter_arg);
	// AVL tree support
KFT_triggerEntry_t* KFT_triggerMalloc();
int KFT_triggerFree (void * key);
void KFT_triggerFreeAll();
#if !IPK_NKE
void testMessageFromClient(ipk_message_t* message);
#endif


// ---------------------------------------------------------------------------------
//	¥ KFT_triggerStart()
// ---------------------------------------------------------------------------------
//	init trigger table
//  Called from IPNetSentry_NKE_start() or SO_KFT_RESET which are thread protected
void KFT_triggerStart()
{
	KFT_triggerReset();
	KFT_triggerFreeAll();	// release freeList
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_triggerStart\n");
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerStop()
// ---------------------------------------------------------------------------------
//	release trigger table
//  Called from IPNetSentry_NKE_stop()
void KFT_triggerStop()
{
	// release old trees if any
	if (kft_triggerTree) free_avl_tree(kft_triggerTree, KFT_triggerFree);
	kft_triggerTree = NULL;
	// freeList
	KFT_triggerFreeAll();
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_triggerStop\n");
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerReset()
// ---------------------------------------------------------------------------------
//	reset trigger table
void KFT_triggerReset()
{
	// release old tree if any
	if (kft_triggerTree) free_avl_tree(kft_triggerTree, KFT_triggerFree);
	kft_triggerTree = NULL;
	// allocate new avl trees
	kft_triggerTree = new_avl_tree (KFT_triggerCompare, NULL);
	{   // initialize update buffer
		ipk_triggerUpdate_t* message;
		message = (ipk_triggerUpdate_t*)&updateBuffer[0];
		message->length = 8;	// offset to first entry
		message->type = kTriggerUpdate;
		message->version = 0;
		message->flags = 0;
	}
}


#pragma mark -- packet filter API --
// ---------------------------------------------------------------------------------
//	¥ KFT_triggerPacket()
// ---------------------------------------------------------------------------------
// add packet info to trigger table
// return: 0 success, ENOENT/ENOMEM unable to complete operation
int KFT_triggerPacket(KFT_packetData_t* packet, u_int32_t type)
{
	int returnValue = ENOENT;
	if (packet && kft_triggerTree) do {
		// look for existing entry
		ip_header_t* ipHeader;
		ipHeader = (ip_header_t*)packet->datagram;
		KFT_triggerEntry_t compareEntry;
		KFT_triggerEntry_t* entry = NULL;
		u_int8_t newEntry = 0;
		compareEntry.address = ipHeader->srcAddress;
		compareEntry.type = type;
		returnValue = get_item_by_key(kft_triggerTree, (void *)&compareEntry, (void **)&entry);
		if (returnValue != 0) {
			// need to create a new entry
			// check if there is room
			if (KFT_triggerCount() > kft_triggerTableSize) {
				KFT_triggerAge();
			}
			// allocate new entry
			entry = KFT_triggerMalloc();
			if (!entry) {
				returnValue = ENOMEM;	// out of memory
				break;
			}
			newEntry = 1;
			bzero(entry, sizeof(KFT_triggerEntry_t));
			// matchCount
			entry->match.count += 1;
		}	
		// load new or found entry
		{	// lastTime
			struct timeval tv;
			#if IPK_NKE
			getmicrotime(&tv);
			#else
			gettimeofday(&tv, NULL);
			#endif
			entry->lastTime = tv.tv_sec;	// ignore fractional seconds
		}
		// address
		entry->address = ipHeader->srcAddress;
		// type
		entry->type = type;
		// duration
		entry->duration = kft_triggerDuration;
		// triggered by (PString)
		if (packet->kftEntry) {
				// node number
			entry->triggeredBy[0] = packet->kftEntry->nodeNumber[0];
			memcpy(&entry->triggeredBy[1], &packet->kftEntry->nodeNumber[1], packet->kftEntry->nodeNumber[0]);
				// try to append node name if any
			int len, offset;
			len = packet->kftEntry->nodeName[0];
			if (len) {
				offset = entry->triggeredBy[0] + 1;
				if (offset < kTriggeredBySize) {
					entry->triggeredBy[offset++] = ' ';	// add a space
					entry->triggeredBy[0]++;
				}
				if ((offset + len) >= kTriggeredBySize) len = kTriggeredBySize - offset - 1;
				memcpy(&entry->triggeredBy[offset], &packet->kftEntry->nodeName[1], len);
				entry->triggeredBy[0] += len;
			}
		}
		else {
			entry->triggeredBy[0] = 6;
			memcpy(&entry->triggeredBy[1], "rule 0", 6);
		}
		// if new entry
		if (newEntry) {
			// add to tree
			returnValue = insert_by_key(kft_triggerTree, (void *)entry);
			if (returnValue != 0) {		// insert failed, out of memory
				KFT_triggerFree(entry);		// release entry so it doesn't leak
				returnValue = ENOMEM;
				break;
			}
			// send update for newly created entries right away
			entry->flags = kTriggerFlagUpdate;
			KFT_triggerEntryReport(entry, NULL);
			KFT_triggerSendUpdates();
		}
		#if DEBUG_IPK
			log(LOG_WARNING, "KFT_triggerAdd\n");
		#endif
	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerInclude()
// ---------------------------------------------------------------------------------
// Search for packet source IP address in trigger table
// return 0=found, -1=not found
int KFT_triggerInclude(KFT_packetData_t* packet, u_int32_t type)
{
	int returnValue = -1;	// not found
	if (packet && kft_triggerTree) {
		ip_header_t* ipHeader;
		tcp_header_t* tcpHeader;
		ipHeader = (ip_header_t*)packet->datagram;
		tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
		// special case ignore http from test server (209.68.51.199:80)
		if ((ipHeader->srcAddress == 0xD14433C7) && (tcpHeader->srcPort == 80)) return -1;
		KFT_triggerEntry_t compareEntry;
		KFT_triggerEntry_t *foundEntry = NULL;
		compareEntry.address = ipHeader->srcAddress;
		compareEntry.type = type;
		returnValue = get_item_by_key(kft_triggerTree, (void *)&compareEntry, (void **)&foundEntry);
		if (returnValue == 0) { // found it
			// get current time
			struct timeval tv;
			#if IPK_NKE
			getmicrotime(&tv);
			#else
			gettimeofday(&tv, NULL);
			#endif
			foundEntry->lastTime = tv.tv_sec;
			// increment matchCount
			foundEntry->match.count++;
			// return found entry in packet data
			packet->triggerEntry = foundEntry;
		}
	}
	return returnValue;
}

#pragma mark -- age table --
// ---------------------------------------------------------------------------------
//	¥ KFT_triggerAge()
// ---------------------------------------------------------------------------------
// Age entries in trigger table
// Called from ipk_timeout which is thread protected.
// return number of entries aged out
int KFT_triggerAge()
{
	return KFT_triggerAgeWithLimit(0);
}
// if limit is nonzero, use this limit for testing
int KFT_triggerAgeWithLimit(u_int32_t limit)
{
	int returnValue = 0;
	KFT_triggerIterArg_t arg;

	if (kft_triggerTree) {
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
		arg.limit = limit;
		// iterate over table
		iterate_inorder(kft_triggerTree, KFT_triggerEntryAge, &arg);
		returnValue = arg.ageOutNum;
		// remove entries from delete list
		KFT_triggerEntry_t* entry;
		while ((entry = SLIST_FIRST(&trigger_deleteList)) != NULL) {
			SLIST_REMOVE_HEAD(&trigger_deleteList, entries);
			KFT_triggerEntryRemove(entry);
		}
		// if "table is full", release the oldest entry
		if (KFT_triggerCount() > kft_triggerTableSize) {
			if (arg.entry) {
				KFT_triggerEntryRemove(arg.entry);
				returnValue += 1;
			}
		}
		// remember last update time
		kft_triggerLastUpdateTime = tv.tv_sec;
		// update UI
		KFT_triggerSendUpdates();
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerEntryAge()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Called periodically for each entry in the trigger table to age it.
// Check age against limits and age out by adding to list.
// Remember oldest entry we've seen so far.
int KFT_triggerEntryAge(void * key, void * iter_arg)
{
	int returnValue = 0;
	KFT_triggerEntry_t* entry;
	KFT_triggerIterArg_t* arg;
	u_int32_t age;
	u_int32_t limit;

	do {
		entry = (KFT_triggerEntry_t *)key;
		arg = (KFT_triggerIterArg_t *)iter_arg;
		// if entry duration is limited
		if (entry->duration) {
			// check age of this entry
			age = arg->currentTime - entry->lastTime;
			limit = arg->limit;
			if (limit == 0) limit = KFT_triggerSeconds(entry->duration);
			// age out?
			if (age >= limit) {
				// remove it
				//if (arg->ageOutNum < arg->ageOutMax) arg->ageOutList[arg->ageOutNum++] = entry;
				SLIST_INSERT_HEAD(&trigger_deleteList, entry, entries);
				arg->ageOutNum++;
				break;
			}
			// remember oldest we've seen so far
			if (entry->lastTime < arg->lastTime) {
				arg->lastTime = entry->lastTime;
				arg->entry = entry;
			}
		}
		// if entry is newer than last update, send to UI
		if (entry->lastTime > kft_triggerLastUpdateTime) {
			entry->flags = kTriggerFlagUpdate;
			KFT_triggerEntryReport(entry, NULL);
		}
	} while (false);
	return returnValue;
}

#pragma mark -- support --
// ---------------------------------------------------------------------------------
//	¥ KFT_triggerEntryRemove()
// ---------------------------------------------------------------------------------
// Report entry is going away and delete it
int KFT_triggerEntryRemove(KFT_triggerEntry_t* entry)
{
	int returnValue;
	if (!entry) return -1;
	// report this entry since we're about to remove it
	entry->flags = kTriggerFlagDelete;
	KFT_triggerEntryReport(entry, NULL);
	// remove entry from tree
	returnValue = KFT_triggerDelete(entry);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerSearchDelete()
// ---------------------------------------------------------------------------------
// Look for matching entry and delete found entry if any
// return 0 if found and deleted
int KFT_triggerSearchDelete(KFT_triggerEntry_t* entry)
{
	int returnValue = ENOENT;
	KFT_triggerEntry_t* foundEntry = NULL;
	
	if (kft_triggerTree) {
		// look for matching entry and delete it
		returnValue = get_item_by_key(kft_triggerTree, (void *)entry, (void **)&foundEntry);
		if (returnValue == 0) KFT_triggerDelete(foundEntry);
		else returnValue = ENOENT;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerDelete()
// ---------------------------------------------------------------------------------
// Delete actual trigger entry (does not search for a matching entry)
int KFT_triggerDelete(KFT_triggerEntry_t* entry)
{
	int returnValue = 0;	
	// remove it
	if (kft_triggerTree) returnValue = remove_by_key(kft_triggerTree, (void *)entry, KFT_triggerFree);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerSearchAdd()
// ---------------------------------------------------------------------------------
// Add matching entry to trigger table
// Search for match, update in place if found, otherwise allocate a new entry and add it.
// return:  0 success, ENOENT/ENOMEM out of memory or other error
int KFT_triggerSearchAdd(KFT_triggerEntry_t* entry)
{
	int returnValue = ENOENT;
	KFT_triggerEntry_t* foundEntry = NULL;
	
	if (kft_triggerTree) {
		// look for matching entry
		returnValue = get_item_by_key(kft_triggerTree, (void *)entry, (void **)&foundEntry);
		if (returnValue == 0) {
			// update found entry in place
			memcpy(foundEntry, entry, sizeof(KFT_triggerEntry_t));
		}
		else {
			// allocate new entry
			foundEntry = KFT_triggerMalloc();
			if (!foundEntry) returnValue = ENOMEM;	// out of memory
			else {
				memcpy(foundEntry, entry, sizeof(KFT_triggerEntry_t));
				// add it
				returnValue = KFT_triggerAdd(foundEntry);
				if (returnValue != 0) {		// insert failed, out of memory
					KFT_triggerFree(foundEntry);	// release new entry so it doesn't leak
					//KFT_logText("\nKFT_triggerSearchAdd - trigger not added, out of memory ", &returnValue);
				}
			}
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerAdd()
// ---------------------------------------------------------------------------------
// Add actual entry to trigger table (does not check for duplicates)
// return:  0 success, ENOENT/ENOMEM unable to complete operation
int KFT_triggerAdd(KFT_triggerEntry_t* entry)
{
	int returnValue = ENOENT;
	
	if (kft_triggerTree) {
		// add to tree
		returnValue = insert_by_key(kft_triggerTree, (void *)entry);
		if (returnValue != 0) returnValue = ENOMEM;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerEntryReport()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Report trigger entry to UI
int KFT_triggerEntryReport(void * key, void * iter_arg)
{
	int returnValue = 0;
	int length, howMany;
	int sizeLimit;
	// trigger update message
	ipk_triggerUpdate_t* message;
	message = (ipk_triggerUpdate_t*)&updateBuffer[0];
	length = message->length;
	howMany = (length-8)/sizeof(KFT_triggerEntry_t);
	// calculate size limit that still leaves room for another entry
	sizeLimit = kTriggerUpdateBufferSize - sizeof(KFT_triggerEntry_t);

	// add to update message
	memcpy(&message->triggerUpdate[howMany], key, sizeof(KFT_triggerEntry_t));
	if (iter_arg) message->triggerUpdate[howMany].flags = *((u_int8_t*)iter_arg);
	message->length += sizeof(KFT_triggerEntry_t);
	// if message buffer is full, send it
	if (message->length >= sizeLimit) KFT_triggerSendUpdates();
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerSendUpdates()
// ---------------------------------------------------------------------------------
// send any pending trigger updates
void KFT_triggerSendUpdates()
{
	// trigger update message
	ipk_triggerUpdate_t* message;
	message = (ipk_triggerUpdate_t*)&updateBuffer[0];
	// are there any updates to send?
	if (message->length > 8) {
		// send message to each active controller
		KFT_sendMessage((ipk_message_t*)message, kMessageMaskGUI);
		message->length = 8;	// reset offset to first entry
		message->flags = 0;
	}
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerSeconds
// ---------------------------------------------------------------------------------
// convert menu index to seconds
int KFT_triggerSeconds(int value)
{
	u_int32_t returnValue = 0;
	switch (value) {
		case 0:		// unlimited
			returnValue = 0;
			break;
		case 1:		// 1 minute
			returnValue = 60;
			break;
		case 2:		// 10 minutes
			returnValue = 600;
			break;
		case 3:		// 1 hour
			returnValue = 3600;
			break;
		case 4:		// 10 hours
			returnValue = 36000;
			break;
		case 5:		// 1 day
			returnValue = 86400;
			break;
		case 6:		// 10 days
			returnValue = 864000;
			break;
	}
	return returnValue;
}


#pragma mark -- client API --
// ---------------------------------------------------------------------------------
//	¥ KFT_setTriggerDuration()
// ---------------------------------------------------------------------------------
// set default trigger duration and return current value.
int KFT_setTriggerDuration(int value)
{
	if ((0 <= value) && (value <= kTriggerDurationMax)) kft_triggerDuration = value;
	return kft_triggerDuration;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerRemoveByKey()
// ---------------------------------------------------------------------------------
// remove corresponding entries, return number of entries removed
int KFT_triggerRemoveByKey(KFT_triggerKey_t value[], int howMany)
{
	int returnValue = 0;
	int result;
	int i;
	KFT_triggerEntry_t compareEntry;

	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_triggerRemoveByKey remove %d entries\n", howMany);
	#endif

	if (kft_triggerTree) {
		for (i=0; i<howMany; i++) {
			compareEntry.address = value[i].address;
			compareEntry.type = value[i].type;
			// look for entry in tree
			result = KFT_triggerSearchDelete(&compareEntry);
			// if we found it
			if (result == 0) {
				returnValue += 1;	// return how many removed
			}
			else {
				KFT_logText("KFT_triggerRemoveByKey: entry not found", NULL);
			}
		}
	}
	#if DEBUG_IPK
		log(LOG_WARNING, "KFT_triggerRemoveByKey removed %d entries\n", j);
	#endif
	
	// are there any more updates to send?
//	KFT_triggerSendUpdates();	// move to caller
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_triggerCount()
// ---------------------------------------------------------------------------------
int KFT_triggerCount()
{
	if (kft_triggerTree) return kft_triggerTree->length;
	else return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerUpload()
// ---------------------------------------------------------------------------------
// return number of entries found
int KFT_triggerUpload()
{
	int returnValue = 0;
	u_int8_t flags = kTriggerFlagUpdate;
 
	if (kft_triggerTree) {
		// iterate over table
		iterate_inorder(kft_triggerTree, KFT_triggerEntryReport, &flags);
		// update UI
		KFT_triggerSendUpdates();
		returnValue = kft_triggerTree->length;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerReceiveMessage()
// ---------------------------------------------------------------------------------
int KFT_triggerReceiveMessage(ipk_message_t* message)
{
	int returnValue = 0;
	ipk_triggerUpdate_t* updateMessage;
	int j, length, howMany;
	KFT_triggerEntry_t* triggerEntry;

	// update for current message
	updateMessage = (ipk_triggerUpdate_t *)message;
	length = updateMessage->length;
	howMany = (length-8)/sizeof(KFT_triggerEntry_t);
	for (j=0; j<howMany; j++) {
		triggerEntry = &updateMessage->triggerUpdate[j];
		// check flags for requested action
		if (triggerEntry->flags & kTriggerFlagDelete) {
			returnValue = KFT_triggerSearchDelete(triggerEntry);
		}
		else if (triggerEntry->flags & kTriggerFlagUpdate) {
			returnValue = KFT_triggerSearchAdd(triggerEntry);
			if (returnValue != 0) {
				//KFT_logText("\nKFT_triggerReceiveMessage - trigger not added, out of memory ", &status);
				break;
			}
		}
		else if (triggerEntry->flags & (kTriggerFlagTagAll | kTriggerFlagRemoveTagged)) {
			// apply flags
			KFT_triggerIterArg_t arg;
			if (kft_triggerTree) {
				arg.flags = triggerEntry->flags;
				// iterate over table
				iterate_inorder(kft_triggerTree, KFT_triggerEntryApply, &arg);
				// remove entries from delete list
				KFT_triggerEntry_t* entry;
				while ((entry = SLIST_FIRST(&trigger_deleteList)) != NULL) {
					SLIST_REMOVE_HEAD(&trigger_deleteList, entries);
					KFT_triggerEntryRemove(entry);
				}
			}
		}
	}
	// check if we need to expand table size
	if (kft_triggerTree->length > kft_triggerTableSize) kft_triggerTableSize = kft_triggerTree->length + 500;
	// done
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerEntryApply()
// ---------------------------------------------------------------------------------
// avl_iter_fun_type
// Called for each entry in the trigger table to tag and/or delete based on flags.
int KFT_triggerEntryApply(void * key, void * iter_arg)
{
	int returnValue = 0;
	KFT_triggerEntry_t* entry;
	KFT_triggerIterArg_t* arg;

	entry = (KFT_triggerEntry_t *)key;
	arg = (KFT_triggerIterArg_t *)iter_arg;
	if (arg->flags & kTriggerFlagTagAll) entry->flags |= kTriggerFlagTagAll;
	if ((arg->flags & kTriggerFlagRemoveTagged) && (entry->flags & kTriggerFlagTagAll)) {
		// remove it
		SLIST_INSERT_HEAD(&trigger_deleteList, entry, entries);
	}
	return returnValue;
}

#pragma mark --- AVL_TREE_SUPPORT ---
// ---------------------------------------------------------------------------------
//	¥ KFT_triggerMemStat()
// ---------------------------------------------------------------------------------
KFT_memStat_t* KFT_triggerMemStat(KFT_memStat_t* record) {
	KFT_memStat_t* next = record;
	next->type = kMemStat_trigger;
	next->freeCount = trigger_freeCount;
	next->tableCount = KFT_triggerCount();
	next->allocated = trigger_memAllocated;
	next->released = trigger_memReleased;
	next->allocFailed = trigger_memAllocFailed;
	next->leaked = next->allocated - next->released - next->tableCount - next->freeCount;
	next++;
	return next;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerMalloc()
// ---------------------------------------------------------------------------------
KFT_triggerEntry_t* KFT_triggerMalloc() {
	KFT_triggerEntry_t* entry;
	// try to get one from our freeList
	if ((entry = SLIST_FIRST(&trigger_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&trigger_freeList, entries);
		trigger_freeCount -= 1;
	}
	else {
		entry = (KFT_triggerEntry_t *)my_malloc(sizeof(KFT_triggerEntry_t));
		if (entry) trigger_memAllocated += 1;
		else trigger_memAllocFailed += 1;
	}
	return entry;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int KFT_triggerFree (void * key) {
	KFT_triggerEntry_t* entry = (KFT_triggerEntry_t*)key;
	if (trigger_freeCount < trigger_freeCountMax) {
		SLIST_INSERT_HEAD(&trigger_freeList, entry, entries);
		trigger_freeCount += 1;
	}
	else {
		my_free(key);
		trigger_memReleased += 1;
	}
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerFreeAll()
// ---------------------------------------------------------------------------------
void KFT_triggerFreeAll() {
	KFT_triggerEntry_t* entry;
	while ((entry = SLIST_FIRST(&trigger_freeList)) != NULL) {
		SLIST_REMOVE_HEAD(&trigger_freeList, entries);
		my_free((void*)entry);
		trigger_memReleased += 1;
	}
	trigger_freeCount = 0;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
// compare address and type
// a is from packet, b is from table.  Allow range in table.
int KFT_triggerCompare (void * compare_arg, void * a, void * b)
{
#if 1
	KFT_triggerEntry_t *ta = (KFT_triggerEntry_t *)a;
	KFT_triggerEntry_t *tb = (KFT_triggerEntry_t *)b;
	
	if (ta->address < tb->address) return -1;
	if (ta->address > (tb->address + tb->endOffset)) return +1;
	if (ta->type < tb->type) return -1;
	if (ta->type > tb->type) return +1;
	return 0;
#else	
	int result = memcmp(a, b, 8);
	if ( result < 0 ) {
		return -1;
	} else if ( result > 0 ) {
		return +1;
	} else {
		return 0;
	}
#endif
}


