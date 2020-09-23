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

// define trigger table entry used to maintain triggered addresses
struct KFT_triggerEntry {
	in_addr_t address;
	long age;
};
typedef struct KFT_triggerEntry KFT_triggerEntry_t;

void KFT_triggerInit();
int KFT_triggerAdd(KFT_packetData_t* packet);
int KFT_triggerInclude(KFT_packetData_t* packet);
int KFT_triggerAge(int limit);
int KFT_triggerCount();