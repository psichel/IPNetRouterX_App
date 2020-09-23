//
//  IPHost.m
//  IPNetMonitorX
//
//  Created by psichel on Tue Jun 26 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate an Internet Host Address

#import "IPHost.h"
#import "IPValue.h"
#import "IPSupport.h"
#import "unp.h"
#import <netdb.h>
#import <string.h>

@implementation IPHost
//--Setup--
- (id)init {
    return [self initWithName:nil];
}

- (id)initWithName:(NSString *)value {
    if (self = [super init]) {
        mName = [value retain];
        // IPv4 or IPv6 socket (defaults to IPv4)
        bzero(&mSocketAddress, sizeof(struct sockaddr_in6));
        mSocketAddress.sa_len = sizeof(struct sockaddr_in);
        mSocketAddress.sa_family = AF_INET;
    }
    return self;
}
- (void)dealloc {
    [mName release];
    [super dealloc];
}

- (void)setName:(NSString *)value
{
    [value retain];
    [mName release];
    mName = value;
}

- (void)setPort:(UInt16)port {
	if (mSocketAddress.sa_family == AF_INET) {
		struct sockaddr_in* so = (struct sockaddr_in*)&mSocketAddress;
		so->sin_port = htons(port);
	}
	else if (mSocketAddress.sa_family == AF_INET6) {
		struct sockaddr_in6* so = (struct sockaddr_in6*)&mSocketAddress;
		so->sin6_port = htons(port);
	}
}
- (void)setHAddress:(u_int32_t)address
// passed in host byte order
{
	struct sockaddr_in* so = (struct sockaddr_in*)&mSocketAddress;
	u_int32_t value;
	value = htonl(address);
	so->sin_family = AF_INET;
	memcpy(&so->sin_addr, &value, 4);
}
- (BOOL)setNAddress:(u_int8_t *)address size:(int)len
// passed in network byte order
{
    BOOL result=NO;
    if (len == 4) {
        struct sockaddr_in* so = (struct sockaddr_in*)&mSocketAddress;
		memcpy(&so->sin_addr, address, len);
		so->sin_family = AF_INET;
        result = YES;
    }
    else if (len == 16) {
        struct sockaddr_in6* so = (struct sockaddr_in6*)&mSocketAddress;
		memcpy(&so->sin6_addr, address, len);
		so->sin6_family = AF_INET6;
        result = YES;
    }
    return result;
}
- (BOOL)setSocketAddress:(sockaddr_t *)socketAddress size:(int)len
// test address length for IPv6
{
    BOOL result=NO;
    if (len <= 32) {
        memcpy(&mSocketAddress, socketAddress, len);
        result = YES;
    }
    return result;   
}


#pragma mark -- DNS --
    // DNR lookup name from address
- (BOOL)addressToName {
    int returnValue=NO;
    NSHost* host;
    host = [NSHost hostWithAddress:[self addressString]];
    [self setName:[host name]];
    // include :<port> is TBD
    if ((host != nil) && (mName != nil)) returnValue = YES;
    return returnValue;
}
    // DNR lookup address from name
- (BOOL)nameToAddress {
    BOOL returnValue = NO;
    NSRange range;
    NSString* str;
	u_int32_t address;
	in6_addr_t address6;
	int addressFamily;

    // get :<port> if present
    range = [mName rangeOfString:@":" options:NSBackwardsSearch];
	if (range.length != 0) {
		// check for ] indicating an IPv6 address
		NSRange range2;
		str = [mName substringToIndex:range.location];
		range2 = [str rangeOfString:@"]" options:NSBackwardsSearch];
		if (range2.length) {
			// found ], extract :port from IPv6 address
			str = [mName substringFromIndex:range.location+1];
			[self setPort:[str intValue]];
			[self setName:[mName substringToIndex:range.location]];
		}
		else {
			// check for 2nd : indicating an IPv6 address without []
			range2 = [str rangeOfString:@":" options:NSBackwardsSearch];
			if (range2.length == 0) {
				str = [mName substringFromIndex:range.location+1];
				[self setPort:[str intValue]];
				[self setName:[mName substringToIndex:range.location]];
			}
		}
	}        
    // see if it's a dotted quad
	addressFamily = isIPAddress(mName, &address, &address6);
	if (addressFamily == AF_INET) {
		//memcpy(&mSocketAddress.sin_addr, &address, 4);
		[self setHAddress:address];
		returnValue = YES;
	}
	else if (addressFamily == AF_INET6) {
		//memcpy(&mSocketAddress.sin_addr, &address, 4);
		[self setNAddress:(u_int8_t *)&address6 size:16];
		returnValue = YES;
	}
	else {
        // attempt DNS lookup
        NSHost* host;
        host = [NSHost hostWithName:mName];
		addressFamily = isIPAddress([host address], &address, &address6);
		if (addressFamily == AF_INET) {
			//memcpy(&mSocketAddress.sin_addr, &address, 4);
			[self setHAddress:address];
			returnValue = YES;
		}
		else if (addressFamily == AF_INET6) {
			//memcpy(&mSocketAddress.sin_addr, &address, 4);
			[self setNAddress:(u_int8_t *)&address6 size:16];
			returnValue = YES;
		}
    }
    return returnValue;
}

#pragma mark -- get info --
- (int)addressFamily
{
	return mSocketAddress.sa_family;
}

- (sockaddr_t *)socketAddress {
    return (sockaddr_t *)&mSocketAddress;
}
- (int)socketAddressLen {
    size_t len=0;
    if (mSocketAddress.sa_family == AF_INET) len = sizeof(struct sockaddr_in);
	else if (mSocketAddress.sa_family == AF_INET6) len = sizeof(struct sockaddr_in6);
    return len;
}
- (NSString *)name {
    return (NSString *)mName;
}

- (NSString *)addressString
{
    NSString* returnValue = nil;
	if (mSocketAddress.sa_family == AF_INET) {
		struct sockaddr_in* so = (struct sockaddr_in*)&mSocketAddress;
		u_int32_t value = *(UInt32*)&so->sin_addr;
		returnValue = stringForIP(ntohl(value));
	}
	else if (mSocketAddress.sa_family == AF_INET6) {
		struct sockaddr_in6* so = (struct sockaddr_in6*)&mSocketAddress;
		returnValue = stringForIP6(&so->sin6_addr, kOptionDefault);
	}
    return returnValue;
}

- (UInt32)v4Address
{
	u_int32_t value = 0;
	if (mSocketAddress.sa_family == AF_INET) {
		struct sockaddr_in* so = (struct sockaddr_in*)&mSocketAddress;
		value = *(u_int32_t*)&so->sin_addr;
	}
	return ntohl(value);
}

- (BOOL)getV6Address:(in6_addr_t *)address6
{
	BOOL returnValue = NO;
	if (mSocketAddress.sa_family == AF_INET6) {
		struct sockaddr_in6* so = (struct sockaddr_in6*)&mSocketAddress;
		memcpy(address6, &so->sin6_addr, 16);
		returnValue = YES;
	}
	return returnValue;
}

- (UInt16)port
{
	u_int16_t value = 0;
	if (mSocketAddress.sa_family == AF_INET) {
		struct sockaddr_in* so = (struct sockaddr_in*)&mSocketAddress;
		value = so->sin_port;
	}
	else if (mSocketAddress.sa_family == AF_INET6) {
		struct sockaddr_in6* so = (struct sockaddr_in6*)&mSocketAddress;
		value = so->sin6_port;
	}
	return ntohs(value);
}

- (BOOL)isEqualTo:(id)inHost
{
    int result;
    sockaddr_t* addr1;
    sockaddr_t* addr2;
    int len;
    addr1 = [self socketAddress];
    addr2 = [inHost socketAddress];
    len = [self socketAddressLen];
    result = memcmp(addr1, addr2, len); // zero if strings are equal
    return (result == 0);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@:%d",[self name],[self addressString],[self port]];
}

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];
    [coder encodeObject:mName];
    [coder encodeValueOfObjCType:@encode(sockaddr_in_t) at:&mSocketAddress];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    //self = [super initWithCoder:coder];
    self = [super init];
    mName = 	[[coder decodeObject] retain];
    [coder decodeValueOfObjCType:@encode(sockaddr_in_t) at:&mSocketAddress];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    IPHost *copy;
    copy = [[IPHost allocWithZone:zone] initWithName:mName];
    [copy setSocketAddress:[self socketAddress] size:[self socketAddressLen]];
    return copy;
}
@end
