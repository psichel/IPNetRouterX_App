//
// kftSupport.h
// IPNetSentryX
//
// Created by Peter Sichel on Mon Nov 25 2002.
// Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Filter Table support functions
//

#ifndef _H_kftSupport
#define _H_kftSupport
#pragma once

#include "ipkTypes.h"
#include <sys/types.h>

// structure used to pass arbitrary mutable data
typedef struct {
	u_int8_t* bytes;
	u_int32_t length;
	u_int32_t bufferLength;
	u_int32_t offset;		// offset to content of interest in data buffer
} PSData;

typedef struct  {
	u_int32_t location;
	u_int32_t length;
} PSRange;


typedef struct KFT_contentSpec {
	u_int8_t* dataPtr;	// pointer to match data (to allow using a separate buffer)
	u_int16_t searchOffset;
	u_int16_t searchLength;
	u_int8_t searchDelimiter;
	u_int8_t flags;
	u_int8_t length;
	u_int8_t data[1];
} KFT_contentSpec_t;
#define kContentFlag_relativePlus 1
#define kContentFlag_relativeMinus 2
#define kContentFlag_ignoreCase 4
#define kContentFlag_useDelimiter 8
#define kContent_searchLength 64

// display options (for hex digits and IPv6 addresses)
// default to compress (skip leading zeros) and lowercase
#define kOptionDefault 0
//#define kOptionCompress	0x01
#define kOptionExpand 0x02
#define kOptionUpper 0x04
//#define kOptionLower 0x08
#define kOptionHidePrefixLen 0x10

// =================================================================================
//	� text support
// =================================================================================
// Don't replace with macro definition since we use autoincrement
int isDigit(char c);
int isHexDigit(char c);
int isAlpha(char c);
int findByte(PSData* inBuf, u_int8_t inByte);
int findByteIgnoreCase(PSData* inBuf, u_int8_t inByte, int16_t delimiter);
int findByteInRange(PSData* inBuf, PSRange* range, u_int8_t inByte);
int skipWhiteSpace(PSData* inBuf);
void decodeContent(KFT_contentSpec_t* content);
int encodeContent(PSData* inBuf, KFT_contentSpec_t* content);
int findEndOfToken(PSData* inBuf);
int nextToken(PSData* inBuf, PSRange* range);
int tcpHeaderFlagValue(PSData* inBuf, PSRange* range);
int intParamValue(PSData* inBuf);
int64_t int64ParamValue(PSData* inBuf);
int intValue(PSData* inBuf, PSRange* range);
int intValueWithFraction(PSData* inBuf, PSRange* range);
int64_t int64Value(PSData* inBuf, PSRange* range);
int intHexValue(PSData* inBuf, PSRange* range);
int string2Num(u_int8_t* str, u_int8_t inMax, u_int8_t* outLen);
int64_t string2Num64(u_int8_t* str, u_int8_t inMax, u_int8_t* outLen);
int string2HexNum(u_int8_t* str, u_int8_t inMax, u_int8_t* outLen);
int skipByte(PSData* inBuf, PSRange* range, u_int8_t inByte);
int findInSegment(PSData* inBuf, u_int8_t* string, int16_t length, int16_t delimiter, u_int8_t ignoreCase);
int compareIgnoreCase(u_int8_t* str1, u_int8_t* str2, int length);
// � text output
int appendCString(PSData* inBuf, char* string);
int appendPString(PSData* inBuf, unsigned char* string);
int appendBytes(PSData* inBuf, unsigned char* string, int howMany);
int appendInt(PSData* inBuf, int value);
int appendInt64(PSData* inBuf, int64_t value);
int appendHexInt(PSData* inBuf, u_int32_t value, int howMany, int options);
int appendIP(PSData* inBuf, u_int32_t value);
int appendTabs(PSData* inBuf, int count);
u_int8_t findRightBit(u_int32_t inData, u_int8_t inStart);
int tcpHeaderFlagString(PSData* inBuf, int maskOn, int maskOff);
// byte swapping
#define kNetworkByteOrder 0
#define kHostByteOrder 1
#define kOptionNone 0
#define kOptionFinalize 1
void KFT_ntohPacket(KFT_packetData_t* packet, u_int8_t option);
void KFT_ntohDgram(u_int8_t* datagram, u_int8_t option);
void KFT_htonPacket(KFT_packetData_t* packet, u_int8_t option);
void KFT_htonDgram(u_int8_t* datagram, u_int8_t option);

// external function declarations
int	 memcmp(const void *dest, const void *source, unsigned long length);
//void *memcpy(void *dest, const void *source, unsigned long length);
void bzero(void *dest, unsigned long length);
unsigned long	 strlen(const char *);

// UNIX timeval and supporting macros
// timerclear(tvp)
// timerisset(tvp)
// timercmp(tvp, uvp, cmp)  tvp <cmp> uvp  (cmp is a comparison operator == or !=)
// timeradd(tvp, uvp vvp)	a + b = c
// timersub(tvp, uvp, vvp)	a - b = c  (c may be negative) .4 - .7 = -.3 represented as -1.7
#define	timermove(tvp, uvp) {									\
	memmove( (tvp), (uvp), sizeof(struct timeval) );			\
}

#define timerdivide(tvp, value, uvp) do {						\
	(uvp)->tv_usec = (tvp)->tv_usec / 8;						\
	(uvp)->tv_usec += (tvp)->tv_sec * 1000000 / 8 % 1000000;	\
	(uvp)->tv_sec = (tvp)->tv_sec / 8;							\
	if ((uvp)->tv_usec >= 1000000) {							\
		(uvp)->tv_sec++;										\
		(uvp)->tv-usec -= 1000000;								\
	}															\
} while (0)

#define timerinterval(bytes, rate, tvp) do {					\
	int64_t temp = (bytes) * 1000 / (rate);						\
	(tvp)->tv_sec  = temp / 1000;								\
	(tvp)->tv_usec = (temp * 1000) % 1000000;					\
} while (0)

#define timerms(tvp) ((tvp)->tv_sec*1000 + (tvp)->tv_usec/1000)

#define timergt(tvp, uvp)										\
	(tvp)->tv_sec > (uvp)->tv_sec ? 1 :							\
	( ((tvp)->tv_sec == (uvp)->tv_sec) && ((tvp)->tv_usec > (uvp)->tv_usec) )

#define timerlt(tvp, uvp)										\
	(tvp)->tv_sec < (uvp)->tv_sec ? 1 :							\
	( ((tvp)->tv_sec == (uvp)->tv_sec) && ((tvp)->tv_usec < (uvp)->tv_usec) )

#define timereq(tvp, uvp)										\
	( ((tvp)->tv_sec == (uvp)->tv_sec) && ((tvp)->tv_usec == (uvp)->tv_usec) )

#endif
