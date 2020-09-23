// IPSupport.h
// IP support functions and definitions
// Copyright 1996-2001 Sustainable Softworks
// All Rights Reserved.

#import <Cocoa/Cocoa.h>
#import "unp.h"
#import "kftSupport.h"

#define NMIPAddressClassA		8
#define NMIPAddressClassB		16
#define NMIPAddressClassC		24
#define NMIPAddressMulticast	4
#define NMIPAddressReserved		5
#define NMIPAddressLoopback		6
#define NMIPAddressBroadcast	7


// function declarations
SInt32		GetIPAddressClass( SInt32 theIPAddress, NSMutableString* classString );
int			isIPAddress(NSString* inString, u_int32_t *outAddress4, in6_addr_t *outAddress6);
NSString*	prefixForMaskStr(NSString* maskStr);
NSString*   stringForIP(u_int32_t inValue);
NSString*	stringForIP6(in6_addr_t *inValue, int option);
NSString*	bitStringForIP6(in6_addr_t *inValue, int bitStart, int bitEnd, int options);
u_int32_t   ipForString(NSString* inString);
NSString*	ipOnlyString(NSString* inString);
u_int32_t	ipSegmentFromBuf(char *cbuf, int *offset, int *outLen);
u_int32_t	ipSegment1FromBuf(char *cbuf, int *offset, int *outLen);
u_int32_t	ipSegment6FromBuf(char *cbuf, int *offset, int *outLen);
NSString*   stringForNetNumber(u_int32_t inAddress, u_int32_t inMask);
u_int32_t   netNumberForString(NSString* inString, u_int32_t* outAddress, u_int32_t* outMask);
// convert address and port to dataRef to sockaddr_in or sockaddr_in6
int addressForData(NSData* dataRef, u_int32_t* address, in6_addr_t* address6, u_int16_t* port);
NSData* dataForAddress(u_int32_t address, u_int16_t port);
NSData* dataForAddress6(in6_addr_t* address6, u_int16_t port);

#define stringForInt(inValue) [NSString stringWithFormat:@"%d",inValue]
#define stringForHexInt32(inValue) [NSString stringWithFormat:@"%08X",inValue]
NSString*   addPercentEscapes(NSData* inData);
NSData*		removePercentEscapes(NSString* inString);
UInt8		FindRightBit(UInt32 inData, UInt8 inStart);
UInt8		FindLeftBit(UInt32 inData, UInt8 inStart);

int readFileHandle(NSFileHandle *fileHandle, NSData **dataP);
