//
// kftDelay.c
// IPNetSentryX
//
// Created by Peter Sichel on Fri Mar 21 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Delay Table and support functions
//

#define DEBUG_IPK 0

#if DEBUG_IPK
#include <sys/syslog.h>
#endif

#include "IPTypes.h"
#include PS_TNKE_INCLUDE
#include "kft.h"
#include "kftDelay.h"
#include "FilterTypes.h"


#if !IPK_NKE
#include <sys/time.h>
//#define NULL 0
#define EJUSTRETURN -2
#endif

#include <sys/types.h>
#include <libkern/OSTypes.h>
#if IPK_NKE
//#include <sys/param.h>
#include <sys/systm.h>
#include <sys/socket.h>
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
#include <net/dlil.h>
//#include <netinet/in.h>		// Needed for (*&^%$#@ arpcom in if_arp.h
//#include <net/ethernet.h>
//#include <net/if_arp.h>
#include <machine/spl.h>
//#include <kern/thread.h>
#include <libkern/OSAtomic.h>
#endif

// Module wide storage
// allocate delay table
#define KFT_delayTableSize 64
static KFT_delayEntry_t kft_delayTable[KFT_delayTableSize];
static int kft_delayNextEntry;
static int kft_delayTimerPending;
// periodic processing
static int delay_packetPending;
static int delay_periodicalPending;

// Global storage
#include "kftGlobal.h"

void KFT_delayPeriodical();
#if IPK_NKE
// timer callback
void KFT_delayTimeout(void *cookie);
#endif

// ---------------------------------------------------------------------------------
//	¥ KFT_delayInit()
// ---------------------------------------------------------------------------------
//	init delay table
//	Called from IPNetSentry_NKE_start wich is thread protected
void KFT_delayInit()
{
	bzero(kft_delayTable, sizeof(KFT_delayEntry_t)*KFT_delayTableSize);
	kft_delayNextEntry = 0;
	kft_delayTimerPending = 0;
	delay_packetPending = 0;
	delay_periodicalPending = 0;
}

void KFT_delayTerminate()
{
	// make sure delay table is empty
	KFT_delayAge(0);
	#if IPK_NKE
	if (kft_delayTimerPending) {
		#if TIGER
		bsd_untimeout(KFT_delayTimeout, (void *)0);
		#else
		untimeout(KFT_delayTimeout, (void *)0);
		#endif
	}
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ KFT_delayAdd()
// ---------------------------------------------------------------------------------
// add packet info to delay table
int KFT_delayAdd(KFT_packetData_t* packet)
{
	int returnValue = 0;
	int result;
#if !TIGER
	// note packet is pending so we can defer timer updates
	result = OSAddAtomic(1, (SInt32*)&delay_packetPending);
#endif
	if (packet) {
		if (packet->direction == kDirectionInbound) {
			// hold to dlil_inject_if_input() 
			// check for room in table
			if (kft_delayNextEntry < KFT_delayTableSize) {
				// add entry to delay table
				kft_delayTable[kft_delayNextEntry].mbuf_ref = *packet->mbuf_ptr;
				if (*packet->frame_ptr && packet->ifHeaderLen) {	// defensive
					// copy frame header
					memcpy(kft_delayTable[kft_delayNextEntry].frame_header, *packet->frame_ptr, packet->ifHeaderLen);
				}
				else bzero(kft_delayTable[kft_delayNextEntry].frame_header, kFrameHeaderSize);
				kft_delayTable[kft_delayNextEntry].attachIndex = packet->myAttach->attachIndex;
				kft_delayTable[kft_delayNextEntry].age = 0;
				kft_delayNextEntry += 1;
#if !IPK_NKE
				result = kft_delayNextEntry;
				KFT_logText("\nDelay packet, next entry: ", &result);
#endif
				result = OSAddAtomic(1, (SInt32*)&kft_delayTimerPending);
				if (result == 0) {	// timer is not running
					// start timer
					#if IPK_NKE
					KFT_delayPeriodical();
					#endif
					#if DEBUG_IPK
						log(LOG_WARNING, "KFT_delayAdd: start timer\n");
					#endif
				}
				returnValue = EJUSTRETURN;
			}
			else KFT_logEvent(packet, -kReasonDelayTableFull, kActionPass);
		}
	}
#if !TIGER
	// note packet is no longer pending so we can perform any deferred timer updates
	result = OSAddAtomic(-1, (SInt32*)&delay_packetPending);
	if (result == 1) {	// value before decrement
		if (delay_periodicalPending) {
			delay_periodicalPending = 0;
			KFT_delayPeriodical();
		}
	}
#endif
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_delayAge()
// ---------------------------------------------------------------------------------
// Age entries in delay table
// Try to compact the table
// Make room for one more if needed
// Called from KFT_delayTimeout which is thread protected.
int KFT_delayAge(int limit)
{
	int returnValue = 0;
	int i;
	int nextOpen;

	for (i=0; i<kft_delayNextEntry; i++) {
		if (kft_delayTable[i].mbuf_ref != NULL) {
			kft_delayTable[i].age += 1;
			if (kft_delayTable[i].age > limit) {
				// try to re-inject saved packet
	// --------------
	// <<< Packet Out
	// --------------
#if IPK_NKE
				#if TIGER
					mbuf_pkthdr_setheader(kft_delayTable[i].mbuf_ref, kft_delayTable[i].frame_header);
				#endif
				PROJECT_inject_input(kft_delayTable[i].mbuf_ref, 0, kft_delayTable[i].attachIndex, PROJECT_attach[kft_delayTable[i].attachIndex].ifnet_ref, kft_delayTable[i].frame_header, kHostByteOrder);
				#if 0
					PROJECT_unlock();	// release lock during inject
					#if TIGER
						ifnet_input(PROJECT_attach[kft_delayTable[i].attachIndex].ifnet_ref, kft_delayTable[i].mbuf_ref, NULL);
					#else
						dlil_inject_if_input(kft_delayTable[i].mbuf_ref, kft_delayTable[i].frame_header, PROJECT_attach[kft_delayTable[i].attachIndex].filterID);
					#endif
					PROJECT_lock();
				#endif
#else
				KFT_logText("\nInject packet from delay entry: ", &i);
#endif
				kft_delayTable[i].mbuf_ref = NULL;	// mbuf was consumed
			}	// if (kft_delayTable[i].age > limit)
		}	// if (kft_delayTable[i].mbuf_ref != NULL)
	}
	// try to compact table
	nextOpen = -1;
	for (i=0; i<kft_delayNextEntry; i++) {
		// is there an open entry
		if (nextOpen < 0) {
            if (kft_delayTable[i].mbuf_ref == NULL) nextOpen = i;	// remember it
		}
		else {
			// is this entry in use?
			if (kft_delayTable[i].mbuf_ref != NULL) {
				// move it
				kft_delayTable[nextOpen].mbuf_ref 				= kft_delayTable[i].mbuf_ref;
				memcpy(kft_delayTable[nextOpen].frame_header, kft_delayTable[i].frame_header, kFrameHeaderSize);
				kft_delayTable[nextOpen].attachIndex 		= kft_delayTable[i].attachIndex;
				kft_delayTable[nextOpen].age 			= kft_delayTable[i].age;
				nextOpen += 1;
			}
		}
	}
	if (nextOpen >= 0) {
		kft_delayNextEntry = nextOpen;
		#if !IPK_NKE
		i = kft_delayNextEntry;
		KFT_logText("\nDelay table compacted kft_delayNextEntry: ", &i);
		#endif
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_delayPeriodical()
// ---------------------------------------------------------------------------------
// called by 500 ms timer when delay table is active
// (from KFT_delayTimeout which is splnet)
void KFT_delayPeriodical()
{
#if IPK_NKE
	#if !TIGER
		extern int hz;	// number of clock ticks that occur in one second
	#endif
#endif
	// is firewall disabled?
	if (PROJECT_timerRefCount == 0) {
		// yes, make sure delay table is empty
		KFT_delayAge(0);
		kft_delayTimerPending = 0;
		#if DEBUG_IPK
        log(LOG_WARNING, "KFT_delayTimeout: stop timer\n");
		#endif
	}
	else {
		// firewall enabled, age table
		KFT_delayAge(1);
		// reschedule ourself as needed
			// timeout(void (*func)(), void *cookie, int ticks);
		if (kft_delayNextEntry > 0) {
#if IPK_NKE
			#if TIGER
			struct timespec ts;	
			ts.tv_sec = 0;		// half second interval
			ts.tv_nsec = 500000000;
			bsd_timeout(KFT_delayTimeout, (void *)0, &ts);
			#else
			timeout(KFT_delayTimeout, (void *)0, hz/2);
			#endif
#endif
			kft_delayTimerPending = 1;
		}
		else {
			kft_delayTimerPending = 0;
			#if DEBUG_IPK
			log(LOG_WARNING, "KFT_delayTimeout: stop timer\n");
			#endif
		}
	}
}

#pragma mark -- mutex lock --
#if IPK_NKE
// ---------------------------------------------------------------------------------
//	¥ KFT_delayTimeout
// ---------------------------------------------------------------------------------
//	half second timer used with packet delay table
//	reschedules itself to be called if delay table is not empty and Firewall is on
void KFT_delayTimeout(void *cookie)
{
	PROJECT_lock();

	if (!delay_packetPending) KFT_delayPeriodical();
	else OSAddAtomic(1, (SInt32*)&delay_periodicalPending);

	PROJECT_unlock();
}
#endif
