//
//  NatEntry.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import PS_TNKE_INCLUDE

@interface NatEntry : NSObject <NSCopying, NSCoding> {
	u_int32_t apparentAddress;
	u_int32_t actualAddress;
	u_int32_t remoteAddress;
	u_int16_t apparentPort;
	u_int16_t actualPort;
	u_int16_t remotePort;
	u_int32_t lastTime;
	u_int16_t flags;
	u_int16_t endOffset;
	u_int8_t protocol;
	// table display
	NSString* interfaceStr;
	NSString* apparentEndpoint;
	NSString* actualEndpoint;
	NSString* remoteEndpoint;
	NSString* protocolStr;
	NSString* lastTimeStr;
	NSString* flagsStr;
}
// dictionary
- (NSMutableDictionary *)nodeDictionary;
- (void)setNodeDictionary:(NSDictionary *)value;
+ (NatEntry *)entryFromDictionary:(NSDictionary *)entryDictionary;
// compare
- (NSComparisonResult)compare:(NatEntry *)value;
- (NSString *)description;

// accessors
	// apparentEndpoint
- (u_int32_t)apparentAddress;
- (void)setApparentAddress:(u_int32_t)value;
- (u_int16_t)apparentPort;
- (void)setApparentPort:(u_int16_t)value;
- (NSString *)apparentEndpoint;
- (void)setApparentEndpoint:(NSString *)value;
	// actualEndpoint
- (u_int32_t)actualAddress;
- (void)setActualAddress:(u_int32_t)value;
- (u_int16_t)actualPort;
- (void)setActualPort:(u_int16_t)value;
- (NSString *)actualEndpoint;
- (void)setActualEndpoint:(NSString *)value;
	// remoteEndpoint
- (u_int32_t)remoteAddress;
- (void)setRemoteAddress:(u_int32_t)value;
- (u_int16_t)remotePort;
- (void)setRemotePort:(u_int16_t)value;
- (NSString *)remoteEndpoint;
- (void)setRemoteEndpoint:(NSString *)value;
	// protocol
- (u_int8_t)protocol;
- (void)setProtocol:(u_int8_t)value;
- (NSString *)protocolStr;
- (void)setProtocolStr:(NSString *)value;
	// lastTime
- (u_int32_t)lastTime;
- (void)setLastTime:(u_int32_t)value;
- (NSString *)lastTimeStr;
- (void)setLastTimeStr:(NSString *)value;
	// flags
- (u_int16_t)flags;
- (void)setFlags:(u_int16_t)value;
- (NSString *)flagsStr;
- (void)setFlagsStr:(NSString *)value;
	// interface
- (NSString *)interfaceStr;
- (void)setInterfaceStr:(NSString *)value;
	// endOffset
- (u_int16_t)endOffset;
- (void)setEndOffset:(u_int16_t)value;

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

int natObjectToData(NatEntry* entry, KFT_natEntry_t* outData);
NatEntry* natObjectFromData(KFT_natEntry_t* inData);

#define PM_apparentAddress		@"apparentAddress"
#define PM_apparentPort			@"apparentPort"
#define PM_actualAddress		@"actualAddress"
#define PM_actualPort			@"actualPort"

#define PM_lastTime				@"lastTime"
#define PM_flags				@"flags"
#define PM_endOffset			@"endOffset"
#define PM_protocol				@"protocol"
#define PM_interfaceStr			@"interfaceStr"

