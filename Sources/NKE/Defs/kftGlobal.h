/*
 *  kftGlobal.h
 *  IPNetSentryX
 *
 *  Created by Peter Sichel on Fri Feb 7 2003.
 *  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
 *
 */
// IPNetSentry NKE shared global storage

// max size of drop Response
#define KFT_dropResponseMax 1000

// drop Connection response
extern u_int8_t PROJECT_dropResponseBuffer[KFT_dropResponseMax];
extern int PROJECT_dropResponseLength;
// time of day info
extern sopt_timeParam_t PROJECT_timeOfDay;
// flags
extern u_int32_t PROJECT_flags;
// timer Ref Count (firewall enabled)
extern int32_t PROJECT_timerRefCount;
    // ipk_timeout reschedules itself when PROJECT_timerRefCount>0
extern int PROJECT_doRateLimit;			// packet matched a rate limit rule
	// reserve bandwidth info
extern KFT_reserveInfo_t PROJECT_rReserveInfo;
extern KFT_reserveInfo_t PROJECT_sReserveInfo;
// ---------------------------------------------------------------------------
// Advanced Routing Table
// ---------------------------------------------------------------------------
extern KFT_routeEntry_t PROJECT_route[kMaxRoute+1];
extern int PROJECT_routeCount;
