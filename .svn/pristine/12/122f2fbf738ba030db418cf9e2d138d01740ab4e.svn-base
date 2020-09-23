//
// kftTrigger.c
// IPNetSentryX
//
// Created by Peter Sichel on Fri Mar 21 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Trigger Table and support functions
//

#define IPK_DEBUG 0

#if IPK_DEBUG
#include <sys/syslog.h>
#endif

#include "kft.h"
#include "kftTrigger.h"
#include "IPTypes.h"

#if IPK_NKE
//#include <sys/param.h>
#include <sys/systm.h>
//#include <sys/socket.h>
//#include <sys/protosw.h>
//#include <sys/socketvar.h>
//#include <sys/fcntl.h>
//#include <sys/malloc.h>
//#include <sys/queue.h>
//#include <sys/domain.h>
//#include <sys/mbuf.h>
//#include <net/route.h>
//#include <net/if.h>
//#include <net/if_types.h>
//#include <net/if_dl.h>
//#include <net/ndrv.h>
//#include <net/kext_net.h>
//#include <net/dlil.h>
//#include <netinet/in.h>		// Needed for (*&^%$#@ arpcom in if_arp.h
//#include <net/ethernet.h>
//#include <net/if_arp.h>
#include <machine/spl.h>
//#include <kern/thread.h>
#endif

// Module wide storage
// allocate Kernel Trigger Table
#define KFT_triggerTableSize 500
static KFT_triggerEntry_t kft_triggerTable[KFT_triggerTableSize];
static int kft_triggerNextEntry;

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerInit()
// ---------------------------------------------------------------------------------
//	init trigger table
//  Called from IPNetSentry_NKE_start() or SO_KFT_RESET which are thread protected
void KFT_triggerInit()
{
	bzero(kft_triggerTable, sizeof(KFT_triggerEntry_t)*KFT_triggerTableSize);
	kft_triggerNextEntry = 0;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_triggerAdd()
// ---------------------------------------------------------------------------------
// add packet info to trigger table
int KFT_triggerAdd(KFT_packetData_t* packet)
{
	int returnValue = 0;
	if (packet) {
		ip_header_t* ipHeader;
		ipHeader = (ip_header_t*)packet->datagram;
		// check for room in table
		if (kft_triggerNextEntry >= KFT_triggerTableSize) {
			// try to make room
			KFT_triggerAge(3600);	// 1 hour
		}
		// add entry to trigger table
		kft_triggerTable[kft_triggerNextEntry].address = ipHeader->srcAddress;
		kft_triggerTable[kft_triggerNextEntry].age = 0;
		kft_triggerNextEntry += 1;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_triggerInclude()
// ---------------------------------------------------------------------------------
// Search for packet source IP address in trigger table
// We assume the trigger table is small, so use simple linear searching for now
int KFT_triggerInclude(KFT_packetData_t* packet)
{
	int returnValue = -1;	// not found
	if (packet) {
		ip_header_t* ipHeader;
		int i;
		ipHeader = (ip_header_t*)packet->datagram;
		for (i=0; i<kft_triggerNextEntry; i++) {
			if (ipHeader->srcAddress == kft_triggerTable[i].address) {
				kft_triggerTable[i].age = 0;	// reset age
				returnValue = 0;
				break;
			}
		}
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_triggerAge()
// ---------------------------------------------------------------------------------
// Age entries in trigger table
// Try to compact the table
// Make room for one more if needed
// Called from ipk_timeout which is thread protected.
int KFT_triggerAge(int limit)
{
	int returnValue = 0;
	int i;
	int nextOpen;
	int maxAge, maxIndex;

	nextOpen = -1;
	maxAge = -1;
	maxIndex = -1;
	for (i=0; i<kft_triggerNextEntry; i++) {
		kft_triggerTable[i].age += 1;
		if (kft_triggerTable[i].age > limit) kft_triggerTable[i].address = 0;	// clear this entry
		// remember max so far
		if (kft_triggerTable[i].age > maxAge) {
			maxAge = kft_triggerTable[i].age;
			maxIndex = i;
		}
		// try to compact table
		if (nextOpen < 0) {
			// is there an open entry
            if (kft_triggerTable[i].address == 0) nextOpen = i;	// remember it
		}
		else {
			// is this entry in use?
			if (kft_triggerTable[i].address != 0) {
				// move it
				kft_triggerTable[nextOpen].address = kft_triggerTable[i].address;
				kft_triggerTable[nextOpen].age = kft_triggerTable[i].age;
				nextOpen += 1;
			}
		}
	}
	if (nextOpen >= 0) kft_triggerNextEntry = nextOpen;
	// if table is full, clear the oldest entry
	if (kft_triggerNextEntry >= KFT_triggerTableSize) {
		kft_triggerTable[maxIndex].address = 0;
		kft_triggerTable[maxIndex].age = 0;
		// age table again to compact it
		KFT_triggerAge(limit);
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_triggerCount()
// ---------------------------------------------------------------------------------
int KFT_triggerCount()
{
	return kft_triggerNextEntry;
}
