//
//  IPHost.h
//  IPNetMonitorX
//
//  Created by psichel on Tue Jun 26 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate an Internet Host Address

#import "unp.h"
#import <Foundation/Foundation.h>
#import "IPSupport.h"

@interface IPHost : NSObject <NSCopying, NSCoding> {
    NSString	*mName;
    sockaddr_t	mSocketAddress;		// sockaddr_in_t or sockaddr_in6_t
	u_int8_t	buffer[16];
}
// setup
- (id)init;
- (void)dealloc;
- (id)initWithName:(NSString *)value;
- (void)setName:(NSString *)value;
- (void)setPort:(UInt16)port;
- (void)setHAddress:(u_int32_t)address;
- (BOOL)setNAddress:(u_int8_t *)address size:(int)len;
- (BOOL)setSocketAddress:(sockaddr_t *)socketAddress size:(int)len;
// DNS
    // DNR lookup name from address
- (BOOL)addressToName;
    // DNR lookup address from name
- (BOOL)nameToAddress;
// get info
- (int)addressFamily;
- (sockaddr_t *)socketAddress;
- (int)socketAddressLen;
- (NSString *)name;
- (NSString *)addressString;
- (UInt32)v4Address;
- (BOOL)getV6Address:(in6_addr_t *)address6;
- (UInt16)port;
- (BOOL)isEqualTo:(id)inHost;
- (NSString *)description;
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;

@end
