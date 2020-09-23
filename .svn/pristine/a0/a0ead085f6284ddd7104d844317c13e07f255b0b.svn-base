//
//  kftGlobal.c
//  IPNetSentryX
//
//  Created by Peter Sichel on Fri Feb 7 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// IPNetSentry NKE shared global storage
#import <types.h>

// max size of drop Response
#define KFT_dropResponseMax 1000

// drop Connection response
u_int8_t PROJECT_dropResponseBuffer[KFT_dropResponseMax];
int PROJECT_dropResponseLength;
// time of day info
sopt_timeParam_t PROJECT_timeOfDay;
// timer Ref Count (firewall enabled)
int32_t PROJECT_timerRefCount;
    // ipk_timeout reschedules itself when PROJECT_timerRefCount>0
int PROJECT_doRateLimit;			// packet matched a rate limit rule
