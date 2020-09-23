//
// kftDelay.h
// IPNetSentryX
//
// Created by Peter Sichel on Fri Mar 21 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Delay Table and support functions
//
#include <sys/types.h>
#include "ipkTypes.h"
#define kFrameHeaderSize 16

// define delay table entry
// used to hold and later re-inject promiscuous TCP Reset segments
struct KFT_delayEntry {
	mbuf_t mbuf_ref;
	char frame_header[kFrameHeaderSize];	// 16 bytes to hold the frame header
	u_int32_t attachIndex;
	int32_t age;
};
typedef struct KFT_delayEntry KFT_delayEntry_t;

void KFT_delayInit();
void KFT_delayTerminate();
int KFT_delayAdd(KFT_packetData_t* packet);
int KFT_delayAge(int limit);
