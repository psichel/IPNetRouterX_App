//
//  NatEntry.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import "NatEntry.h"
#import "IPSupport.h"
#import "PSServiceDictionary.h"
//#import <sys/socket.h>		// basic socket definitions
//#import <sys/time.h>		// timeval{} for select
#import <netinet/in.h>		// sockaddr_in{} and other Internet defs
#import <arpa/inet.h>


@implementation NatEntry

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		apparentAddress = 0;
		apparentPort = 0;
		actualAddress = 0;
		actualPort = 0;
		protocol = 0;
		lastTime = 0;
		flags = 0;
		endOffset = 0;
		// display
		apparentEndpoint = nil;
		actualEndpoint = nil;
		protocolStr = nil;
		lastTimeStr = nil;
		interfaceStr = nil;
		flagsStr = nil;
    }
    return self;
}
// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	[interfaceStr release];			interfaceStr = nil;
	[apparentEndpoint release];		apparentEndpoint = nil;
	[actualEndpoint release];		actualEndpoint = nil;
	[protocolStr release];			protocolStr = nil;
	[lastTimeStr release];			lastTimeStr = nil;
	[flagsStr release];				flagsStr = nil;
    [super dealloc];
}

// Access node dictionary
// ---------------------------------------------------------------------------------
//	¥ nodeDictionary
// ---------------------------------------------------------------------------------
- (NSMutableDictionary *)nodeDictionary
{
	NSMutableDictionary* nd = [NSMutableDictionary dictionaryWithCapacity:10];
	[nd setObject:[NSNumber numberWithInt:apparentPort] forKey:PM_apparentPort];
	[nd setObject:[NSNumber numberWithInt:actualPort] forKey:PM_actualPort];
	[nd setObject:stringForIP(apparentAddress) forKey:PM_apparentAddress];
	[nd setObject:stringForIP(actualAddress) forKey:PM_actualAddress];
	
	[nd setObject:[NSDate dateWithTimeIntervalSince1970:lastTime] forKey:PM_lastTime];
	[nd setObject:[NSNumber numberWithInt:flags] forKey:PM_flags];
	[nd setObject:[NSNumber numberWithInt:endOffset] forKey:PM_endOffset];
	[nd setObject:[NSNumber numberWithInt:protocol] forKey:PM_protocol];
	[nd setObject:interfaceStr forKey:PM_interfaceStr];
	return nd;
}
// ---------------------------------------------------------------------------------
//	¥ setNodeDictionary
// ---------------------------------------------------------------------------------
- (void)setNodeDictionary:(NSDictionary *)value
{
	apparentPort = [[value objectForKey:PM_apparentPort] intValue];
	actualPort = [[value objectForKey:PM_actualPort] intValue];
	apparentAddress = ipForString([value objectForKey:PM_apparentAddress]);
	actualAddress = ipForString([value objectForKey:PM_actualAddress]);
	
	lastTime = [[value objectForKey:PM_lastTime] timeIntervalSince1970];
	flags = [[value objectForKey:PM_flags] intValue];
	endOffset = [[value objectForKey:PM_endOffset] intValue];
	protocol = [[value objectForKey:PM_protocol] intValue];
	[self setInterfaceStr:[value objectForKey:PM_interfaceStr]];
}

// ---------------------------------------------------------------------------------
//	¥ entryFromDictionary
// ---------------------------------------------------------------------------------
+ (NatEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	NatEntry* entry;
	entry = [[[NatEntry alloc] init] autorelease];
	[entry setNodeDictionary:entryDictionary];
	return entry;
}

// ---------------------------------------------------------------------------------
//	¥ compare:
// ---------------------------------------------------------------------------------
// order by apparent endpoint
- (NSComparisonResult)compare:(NatEntry *)value
{
	u_int16_t startPortA = apparentPort;
	u_int16_t endPortA = startPortA + endOffset;
	u_int16_t startPortB = [value apparentPort];
	u_int16_t endPortB = startPortB + [value endOffset];
	// port (could be a port range)	
	if (endPortA < startPortB) return -1;
	if (endPortB < startPortA) return +1;
	// protocol
	u_int8_t protocolB = [value protocol];
	if (protocol < protocolB) return -1;
	if (protocol > protocolB) return +1;
	// address
	u_int32_t addressB = [value apparentAddress];
	if (apparentAddress < addressB) return -1;
	if (apparentAddress > addressB) return +1;
	// all match
	return 0;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ %@ apparent %@ actual %@ %@ flags %@",
		[self interfaceStr],
		[self protocolStr],
		[self apparentEndpoint],
		[self actualEndpoint],
		[self lastTimeStr],
		[self flagsStr]
	];
}


#pragma mark --- Accessors ---
	// apparentEndpoint
- (u_int32_t)apparentAddress { return apparentAddress; }
- (void)setApparentAddress:(u_int32_t)value {
	apparentAddress = value;
	NSString* str;
	if (apparentPort) {
		NSString* name = [[PSServiceDictionary sharedInstance] serviceNameForPort:apparentPort protocol:protocol];
		if (name) str = [NSString stringWithFormat:@"%d (%@)",apparentPort,name];
		else str = [NSString stringWithFormat:@"%d",apparentPort];		
	}
	else str = @"*";
	[self setApparentEndpoint:[NSString stringWithFormat:@"%@:%@",stringForIP(apparentAddress),str]];
}
- (u_int16_t)apparentPort { return apparentPort; }
- (void)setApparentPort:(u_int16_t)value {
	apparentPort = value;
}
- (NSString *)apparentEndpoint { return apparentEndpoint; }
- (void)setApparentEndpoint:(NSString *)value {
	[value retain];
	[apparentEndpoint release];
	apparentEndpoint = value;
}

	// actualEndpoint
- (u_int32_t)actualAddress { return actualAddress; }
- (void)setActualAddress:(u_int32_t)value {
	actualAddress = value;
	NSString* str;
	if (actualPort) {
		NSString* name = [[PSServiceDictionary sharedInstance] serviceNameForPort:actualPort protocol:protocol];
		if (name) str = [NSString stringWithFormat:@"%d (%@)",actualPort,name];
		else str = [NSString stringWithFormat:@"%d",actualPort];		
	}
	else str = @"*";
	[self setActualEndpoint:[NSString stringWithFormat:@"%@:%@",stringForIP(actualAddress), str]];
}
- (u_int16_t)actualPort { return actualPort; }
- (void)setActualPort:(u_int16_t)value {
	actualPort = value;
}
- (NSString *)actualEndpoint { return actualEndpoint; }
- (void)setActualEndpoint:(NSString *)value {
	[value retain];
	[actualEndpoint release];
	actualEndpoint = value;
}

	// remoteEndpoint
- (u_int32_t)remoteAddress { return remoteAddress; }
- (void)setRemoteAddress:(u_int32_t)value {
	remoteAddress = value;
	NSString* str;
	if (remotePort) {
		NSString* name = [[PSServiceDictionary sharedInstance] serviceNameForPort:remotePort protocol:protocol];
		if (name) str = [NSString stringWithFormat:@"%d (%@)",remotePort,name];
		else str = [NSString stringWithFormat:@"%d",remotePort];		
	}
	else str = @"*";
	[self setRemoteEndpoint:[NSString stringWithFormat:@"%@:%@",stringForIP(remoteAddress), str]];
}
- (u_int16_t)remotePort { return remotePort; }
- (void)setRemotePort:(u_int16_t)value {
	remotePort = value;
}
- (NSString *)remoteEndpoint { return remoteEndpoint; }
- (void)setRemoteEndpoint:(NSString *)value {
	[value retain];
	[remoteEndpoint release];
	remoteEndpoint = value;
}

	// protocol
- (u_int8_t)protocol { return protocol; }
- (void)setProtocol:(u_int8_t)value {
	protocol = value;
	if (value == IPPROTO_TCP) [self setProtocolStr:@"TCP"];
	else if (value == IPPROTO_UDP) [self setProtocolStr:@"UDP"];
	else if (value == IPPROTO_ICMP) [self setProtocolStr:@"ICMP"];
	else if (value == IPPROTO_GRE) [self setProtocolStr:@"GRE"];
	else [self setProtocolStr:[NSString stringWithFormat:@"%d",protocol]];
}
- (NSString *)protocolStr { return protocolStr; }
- (void)setProtocolStr:(NSString *)value {
	[value retain];
	[protocolStr release];
	protocolStr = value;
}
	// lastTime
- (u_int32_t)lastTime { return lastTime; }
- (void)setLastTime:(u_int32_t)value {
	lastTime = value;
	NSCalendarDate* cd = [NSDate dateWithTimeIntervalSince1970:lastTime];
	[self setLastTimeStr:[cd descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil]];
}
- (NSString *)lastTimeStr { return lastTimeStr; }
- (void)setLastTimeStr:(NSString *)value {
	[value retain];
	[lastTimeStr release];
	lastTimeStr = value;
}
	// flags
- (u_int16_t)flags { return flags; }
- (void)setFlags:(u_int16_t)value {
	flags = value;
	NSString* str = @"";
	if (flags & kNatFlagNonSyn) str = [str stringByAppendingFormat:@"NonSyn "];
	if (flags & kNatFlagFINLocal) str = [str stringByAppendingFormat:@"FinLocal "];
	if (flags & kNatFlagFINAckPeer) str = [str stringByAppendingFormat:@"FinAckPeer "];
	if (flags & kNatFlagFINPeer) str = [str stringByAppendingFormat:@"FinPeer "];
	if (flags & kNatFlagFINAckLocal) str = [str stringByAppendingFormat:@"FinAckLocal "];
	if (flags & kNatFlagProxy) str = [str stringByAppendingFormat:@"Proxy "];
	[self setFlagsStr:str];
}
- (NSString *)flagsStr { return flagsStr; }
- (void)setFlagsStr:(NSString *)value {
	[value retain];
	[flagsStr release];
	flagsStr = value;
}

	// interface
- (NSString *)interfaceStr { return interfaceStr; }
- (void)setInterfaceStr:(NSString *)value {
	[value retain];
	[interfaceStr release];
	interfaceStr = value;
}
	// endOffset
- (u_int16_t)endOffset { return endOffset; }
- (void)setEndOffset:(u_int16_t)value {
	endOffset = value;
}


#pragma mark --- Coding and Copying ---
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeValueOfObjCType:@encode(u_int32_t) at:&apparentAddress];
    [coder encodeValueOfObjCType:@encode(u_int32_t) at:&actualAddress];
	[coder encodeValueOfObjCType:@encode(u_int32_t) at:&remoteAddress];
    [coder encodeValueOfObjCType:@encode(u_int16_t) at:&apparentPort];
    [coder encodeValueOfObjCType:@encode(u_int16_t) at:&actualPort];
	[coder encodeValueOfObjCType:@encode(u_int16_t) at:&remotePort];
	
	[coder encodeValueOfObjCType:@encode(u_int32_t) at:&lastTime];
	[coder encodeValueOfObjCType:@encode(u_int16_t) at:&flags];
	[coder encodeValueOfObjCType:@encode(u_int16_t) at:&endOffset];
	[coder encodeValueOfObjCType:@encode(u_int8_t) at:&protocol];

	[coder encodeObject:interfaceStr];
	[coder encodeObject:apparentEndpoint];
	[coder encodeObject:actualEndpoint];
	[coder encodeObject:remoteEndpoint];
	[coder encodeObject:protocolStr];
	[coder encodeObject:lastTimeStr];
	[coder encodeObject:flagsStr];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];

    [coder decodeValueOfObjCType:@encode(u_int32_t) at:&apparentAddress];
    [coder decodeValueOfObjCType:@encode(u_int32_t) at:&actualAddress];
	[coder decodeValueOfObjCType:@encode(u_int32_t) at:&remoteAddress];
    [coder decodeValueOfObjCType:@encode(u_int16_t) at:&apparentPort];
    [coder decodeValueOfObjCType:@encode(u_int16_t) at:&actualPort];
	[coder decodeValueOfObjCType:@encode(u_int16_t) at:&remotePort];
	
	[coder decodeValueOfObjCType:@encode(u_int32_t) at:&lastTime];
	[coder decodeValueOfObjCType:@encode(u_int16_t) at:&flags];
	[coder decodeValueOfObjCType:@encode(u_int16_t) at:&endOffset];
	[coder decodeValueOfObjCType:@encode(u_int8_t) at:&protocol];
	
    interfaceStr = [[coder decodeObject] retain];
	apparentEndpoint = [[coder decodeObject] retain];
	actualEndpoint = [[coder decodeObject] retain];
	remoteEndpoint = [[coder decodeObject] retain];
	protocolStr = [[coder decodeObject] retain];
	lastTimeStr = [[coder decodeObject] retain];
	flagsStr = [[coder decodeObject] retain];

    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    NatEntry *copy;
    copy = [[NatEntry allocWithZone:zone] init];
	// copy protocol and ports first to update display components	
	[copy setLastTime:lastTime];
	[copy setFlags:flags];
	[copy setEndOffset:endOffset];
	[copy setProtocol:protocol];

	[copy setApparentPort:apparentPort];
	[copy setActualPort:actualPort];
	[copy setActualPort:remotePort];
    [copy setApparentAddress:apparentAddress];
	[copy setActualAddress:actualAddress];
	[copy setActualAddress:remoteAddress];
    return copy;
}
@end


#pragma mark --- CONVERSION ---
// convert between data and object form
int natObjectToData(NatEntry* entry, KFT_natEntry_t* outData)
{
	int returnValue = -1;	// no entry
	
	if (entry) {
		// initialize result
		bzero(outData, sizeof(KFT_natEntry_t));		
		outData->lastTime = [entry lastTime];
		outData->flags = [entry flags];
		outData->endOffset = [entry endOffset];
		outData->apparent.protocol = [entry protocol];
		outData->actual.protocol = [entry protocol];
		outData->remote.protocol = [entry protocol];

		outData->apparent.port = [entry apparentPort];
		outData->actual.port = [entry actualPort];
		outData->remote.port = [entry remotePort];
		outData->apparent.address = [entry apparentAddress];
		outData->actual.address = [entry actualAddress];
		outData->remote.address = [entry remoteAddress];
		
		[[entry interfaceStr] getCString:outData->bsdName maxLength:kBSDNameLength encoding:NSUTF8StringEncoding];
		returnValue = 0;
	}
	return returnValue;
}

NatEntry* natObjectFromData(KFT_natEntry_t* inData)
{
	NatEntry* entry = [[[NatEntry alloc] init] autorelease];
	// set protocol and ports first to update display components
	[entry setLastTime:inData->lastTime];
	[entry setFlags:inData->flags];
	[entry setEndOffset:inData->endOffset];
	[entry setProtocol:inData->apparent.protocol];
	[entry setInterfaceStr:[NSString stringWithCString:inData->bsdName encoding:NSUTF8StringEncoding]];
	
	[entry setApparentPort:inData->apparent.port];
	[entry setActualPort:inData->actual.port];
	[entry setRemotePort:inData->remote.port];
    [entry setApparentAddress:inData->apparent.address];
	[entry setActualAddress:inData->actual.address];
	[entry setRemoteAddress:inData->remote.address];
	
	return entry;
}

