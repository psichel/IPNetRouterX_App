//
// kftTrigger.h
// IPNetSentryX
//
// Created by Peter Sichel on Fri Mar 21 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Trigger Table and support functions
//
#include <sys/types.h>

// KFT_triggerEntry defined in IPNetSentry_NKE.h
/*
// ---------------------------------------------------------------------------------
// upstream message for trigger update
// ---------------------------------------------------------------------------------
// define trigger table entry used to maintain triggered addresses
struct KFT_triggerEntry {
	u_int32_t address;  // address and type are used together as an 8-byte key
	u_int32_t type;		// 32-bit hash of type name
	u_int32_t lastTime;
	u_int8_t duration;	
	u_int8_t flags;
	u_int8_t pad0;
	u_int8_t pad1;
	KFT_stat_t match;
	u_int8_t nodeNumber[16];
};
typedef struct KFT_triggerEntry KFT_triggerEntry_t;
#define kTriggerTypeTrigger 0
#define kTriggerTypeAddress 1
#define kTriggerTypeAuthorize 2
#define kTriggerTypeInvalid 3
#define kTriggerFlagDelete 1
#define kTriggerFlagUpdate 2
#define kTriggerDurationMax 6

struct	ipk_triggerUpdate {
	int32_t	length;		// length of message
    int16_t	type;		// message type
    int8_t	version;	// version
	int8_t	flags;		// flag bits
	KFT_triggerEntry_t triggerUpdate[1];	// some number of trigger updates
};
typedef struct ipk_triggerUpdate ipk_triggerUpdate_t;
*/

void KFT_triggerStart();
void KFT_triggerStop();
void KFT_triggerReset();
// packet filter API
int KFT_triggerPacket(KFT_packetData_t* packet, u_int32_t type);
int KFT_triggerInclude(KFT_packetData_t* packet, u_int32_t type);
// age table
int KFT_triggerAge();
int KFT_triggerAgeWithLimit(u_int32_t limit);
// support
int KFT_triggerEntryRemove(KFT_triggerEntry_t* entry);
int KFT_triggerSearchDelete(KFT_triggerEntry_t* entry);
int KFT_triggerDelete(KFT_triggerEntry_t* entry);
int KFT_triggerSearchAdd(KFT_triggerEntry_t* entry);
int KFT_triggerAdd(KFT_triggerEntry_t* entry);
int KFT_triggerEntryReport(void * key, void * iter_arg);
void KFT_triggerSendUpdates();
// client API
int KFT_setTriggerDuration(int value);
int KFT_triggerRemoveByKey(KFT_triggerKey_t value[], int howMany);
int KFT_triggerCount();
int KFT_triggerUpload();
int KFT_triggerReceiveMessage(ipk_message_t* message);
int KFT_triggerEntryApply(void * key, void * iter_arg);
// avl support
KFT_memStat_t* KFT_triggerMemStat(KFT_memStat_t* record);
int KFT_triggerCompare (void * compare_arg, void * a, void * b);
