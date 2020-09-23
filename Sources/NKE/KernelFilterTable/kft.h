//
// kft.h
// IPNetSentryX
//
// Created by Peter Sichel on Thu Nov 14 2002.
// Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Filter Table functions and storage
// This module is designed to be tested as client code and then incorporated
// as part of our NKE

#include <sys/types.h>
#include <libkern/OSTypes.h>
#include "kftSupport.h"
#include "ipkTypes.h"
#define KFT_filterTableSize 1000

// define MAC address table
struct KFT_hwAddressEntry {
	char hwAddress[6];
	char pad[2];
	long age;
};
typedef struct KFT_hwAddressEntry KFT_hwAddressEntry_t;

extern attach_t PROJECT_attach[kMaxAttach+1];
extern PSData kft_filterTableD;

// init support
void KFT_init();
void KFT_terminate();
void KFT_filterInit();
int KFT_filterCount();
KFT_filterEntry_t* KFT_filterEntryForIndex(int index);
void KFT_filterPeriodical();
// receive messages
int KFT_receiveMessage(ipk_message_t* message);
int KFT_interfaceReceiveMessage(ipk_message_t* message);
int KFT_interfaceProcessEntry(int attachIndex);
int KFT_routeReceiveMessage(ipk_message_t* message);
int KFT_filterUpload(PSData* outBuf);
int KFT_filterDownload(PSData* inBuf);
void KFT_reset();
// send messages
void KFT_sendMessage(ipk_message_t* message, u_int32_t messageMask);
int KFT_filterUpdate();
int KFT_interfaceUpload();
int KFT_routeUpdate();
int KFT_syncUpdate(double timeInterval);
// filter packet
int KFT_processPacket(KFT_packetData_t* packet);
int KFT_deletePacket(KFT_packetData_t* packet);
int KFT_respondRST(KFT_packetData_t* packet);
int KFT_respondACK(KFT_packetData_t* packet);
// bridging
int KFT_reversePacket(KFT_packetData_t* packet);
int KFT_lateralPut(KFT_packetData_t* packet, int attachIndex);
int KFT_doRedirect(KFT_packetData_t* packet);
int KFT_reflectPacket(KFT_packetData_t* packet);
// logging
void KFT_logEvent(KFT_packetData_t* packet, int index, u_int8_t action);
void KFT_logData(PSData* inBuf);
void KFT_logText(char* text, int* number);
void KFT_logText4(char* text1, char* text2, char* text3, char* text4);
void KFT_logHex(u_int8_t* dp, int howMany);
// support
int KFT_attachIndexForName(char *inName);
int KFT_emptyAttachIndex();

#if !IPK_NKE
SInt32	OSAddAtomic(SInt32 amount, SInt32 * address);
#endif

