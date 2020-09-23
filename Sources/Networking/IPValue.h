//
//  IPValue.h
//  IPNetMonitorX
//
//  Created by psichel on Tue Jun 05 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IPSupport.h"
#import "IPValueFormatter.h"
#import "ipkTypes.h"

// IP value used for field input/output
// <empty>				; start=0
// xxx.xxx.xxx.xxx			; prefixLen=0 end=0
// xxx.xxx.xxx.xxx/pl			; prefixLen!=0
// xxx.xxx.xxx.xxx-yyy.yyy.yyy.yyy	; end!=0
typedef struct {
    in6_addr_t	start6;
	in6_addr_t  end6;
	in6_addr_t	mask6;
	u_int32_t	start;
    u_int32_t	end;
    u_int16_t	startPort;
    u_int16_t	endPort;
    u_int8_t	prefixLen;
	u_int8_t	type;		// AF_INET, AF_INET6
	u_int8_t	segments;
	u_int8_t	options;	// display options (kOptionExpand,...)
	char		bsdName[kBSDNameLength];		// C string
} IPValueT;

@interface IPValue : NSObject <NSCopying> {
    IPValueT mIPValue;
}
- (id)init;
// ipAddress
- (u_int32_t)ipAddress;
- (void)setIpAddress: 		(u_int32_t)inValue;
- (in6_addr_t *)ipAddress6;
- (void)setIpAddress6:(in6_addr_t *)inValue;
//  mask
- (in6_addr_t *)mask6;
- (void)setMask6:(in6_addr_t *)inValue;
- (BOOL)hasMask6;
- (int)compareWithMask6:(in6_addr_t *)inValue;

- (u_int32_t)mask;
- (void)setMask: 		(u_int32_t)inValue;

// address range
- (u_int32_t)endAddress;
- (void)setEndAddress:   	(u_int32_t)inValue;
- (in6_addr_t *)endAddress6;
- (void)setEndAddress6:(in6_addr_t *)inValue;
- (BOOL)hasEndAddress;

- (u_int32_t)startOfRange;
- (int32_t)endOffset;		// offset to last address of address range

// other info
- (u_int8_t)prefixLen;
- (void)setPrefixLen:	(u_int8_t)inValue;
- (u_int8_t)type;
- (void)setType:(u_int8_t)inValue;
- (u_int8_t)segments;
- (void)setSegments:(u_int8_t)inValue;
- (u_int8_t)options;
- (void)setOptions:(u_int8_t)inValue mask:(u_int8_t)mask;

// port or port range
- (u_int16_t)startPort;
- (void)setStartPort:	(int)inValue;

- (u_int16_t)endPort;
- (void)setEndPort:		(int)inValue;

- (NSString *)stringValue;
- (BOOL)setStringValue:(NSString *)inValue;
#if !BUILD_AS_HELPER_TOOL
- (NSString *)stringValueForProtocol:(int)protocol;
#endif

// interface name for IPv6 multicast %en0
- (NSString *)bsdName;
- (void)setBsdName:(NSString *)value;

// <NSCopying>
- (const void *)bytes;
- (unsigned)length;
- (NSString *)description;
- (id)copyWithZone:(NSZone *)zone;
@end
