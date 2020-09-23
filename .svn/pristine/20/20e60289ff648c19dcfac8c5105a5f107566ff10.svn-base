//
//  TriggerEntry.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import "TriggerEntry.h"
#import "IPKSupport.h"
#import "IPSupport.h"
#import <sys/socket.h>		// basic socket definitions
#import <sys/time.h>		// timeval{} for select
#import <netinet/in.h>		// sockaddr_in{} and other Internet defs
#import <arpa/inet.h>


@implementation TriggerEntry

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
        nodeDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
        if (!nodeDictionary) return nil;
    }
    return self;
}
// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
    [nodeDictionary release]; nodeDictionary = nil;
    [super dealloc];
}

// Access node dictionary
- (NSMutableDictionary *)nodeDictionary { return nodeDictionary; };
- (void)setNodeDictionary:(NSMutableDictionary *)value {
    [value retain];
    [nodeDictionary release];
    nodeDictionary = value;
}

+ (TriggerEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	TriggerEntry* entry;
	entry = [[[TriggerEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}


// ---------------------------------------------------------------------------------
//	¥ compare:
// ---------------------------------------------------------------------------------
- (NSComparisonResult)compare:(TriggerEntry *)value
{
	u_int32_t addressA, addressB;
	u_int32_t typeA, typeB;
	u_int32_t endOffset;
	
	addressA = ipForString([self ipAddress]);
	typeA = [[self type] intValue];

	addressB = ipForString([value ipAddress]);
	typeB = [[value type] intValue];
	endOffset = [[value endOffset] unsignedIntValue];
	
	if (addressA < addressB) return -1;
	if (addressA > (addressB + endOffset)) return +1;
	if (typeA < typeB) return -1;
	if (typeA > typeB) return +1;
	return 0;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"address:%@ duration:%@ expireDate:%@ endOffset:%@",
		[self addressString],
		[nodeDictionary objectForKey:TT_duration],
		[[nodeDictionary objectForKey:TT_lastTime] description],
		[self endOffset]
		];
}

// ---------------------------------------------------------------------------------
//	¥ objectSpecifier
// ---------------------------------------------------------------------------------
// Apparent Compare uses IP Address, port range, protocol
- (NSScriptObjectSpecifier *)objectSpecifier {
	NSScriptClassDescription *containerClassDesc = (NSScriptClassDescription *)
		[NSScriptClassDescription classDescriptionForClass:[NSApp class]];

	NSString* uniqueID = [NSString stringWithFormat:@"address=%@;endOffset=%d;type=%@;",
		[self ipAddress],[[self endOffset] intValue],[self typeString]];
	return [[[NSUniqueIDSpecifier alloc] 
		initWithContainerClassDescription:containerClassDesc
		containerSpecifier:nil key:@"triggers"
		uniqueID:uniqueID] autorelease];
}

#pragma mark --- Accessors ---

- (NSString *)ipAddress { return [nodeDictionary objectForKey:TT_ipAddress]; }
- (void)setIpAddress:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:TT_ipAddress];
    else [nodeDictionary removeObjectForKey:TT_ipAddress];
}

- (NSNumber *)type { return [nodeDictionary objectForKey:TT_type]; }
- (void)setType:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:TT_type];
	else [nodeDictionary removeObjectForKey:TT_type];
}
- (NSString *)typeString {
	NSString* returnValue = @"unknown";
	int type = [[self type] intValue];
	switch (type) {
		case kTriggerTypeTrigger: returnValue = kTriggerTypeTriggerStr; break;
		case kTriggerTypeAddress: returnValue = kTriggerTypeAddressStr; break;
		case kTriggerTypeAuthorize: returnValue = kTriggerTypeAuthorizeStr; break;
		case kTriggerTypeInvalid: returnValue = kTriggerTypeInvalidStr; break;
	}
	return returnValue;
}


// offset to end of address of range
- (NSNumber *)endOffset { return [nodeDictionary objectForKey:TT_endOffset]; }
- (void)setEndOffset:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:TT_endOffset];
	else [nodeDictionary removeObjectForKey:TT_endOffset];
}
// support address ranges
- (NSString *)addressString {
	u_int32_t endOffset = [[self endOffset] unsignedIntValue];
	if (endOffset == 0) return [self ipAddress];
	{
		int mask;
		int count = 0;
		mask = endOffset;
		while (mask & 1) {
			count++;
			mask >>= 1;
		}
		if (mask == 0) {
			return [NSString stringWithFormat:@"%@/%d",[self ipAddress],32-count];
		}
		else {
			u_int32_t address = ipForString([self ipAddress]);
			return [NSString stringWithFormat:@"%@-%@",[self ipAddress],stringForIP(address+endOffset)];
		}
	}
}
- (void)setAddressString:(NSString *)value {
	NSRange range;
	do {
		if ([value length] == 0) {
			[self setIpAddress:value];
			[self setEndOffset:nil];
			break;
		}
		range = [value rangeOfString:@"-"];		// A-B
		if (range.length) {
			NSString *startStr, *endStr;
			startStr = [value substringToIndex:range.location];
			endStr = [value substringFromIndex:range.location+range.length];
			u_int32_t start, end;
			start = ipForString(startStr);
			end = ipForString(endStr);
			[self setIpAddress:startStr];
			if (end >= start) [self setEndOffset:[NSNumber numberWithUnsignedInt:end-start]];
			break;
		}
		
		range = [value rangeOfString:@"/"];	// cidr notation?
		if (range.length) {
			NSString *startStr, *prefixLenStr;
			startStr = [value substringToIndex:range.location];
			prefixLenStr = [value substringFromIndex:range.location+range.length];
			u_int32_t prefixLen, mask, start, end;
			prefixLen = [prefixLenStr intValue];
			if (prefixLen <= 32) {
				mask = 0xFFFFFFFF << (32 - prefixLen);
				start = ipForString(startStr) & mask;
				[self setIpAddress:stringForIP(start)];
				end = start | ~mask;
				if (end >= start) [self setEndOffset:[NSNumber numberWithUnsignedInt:end-start]];
			}
			else {
				[self setIpAddress:startStr];
				[self setEndOffset:nil];			
			}
			break;
		}
		[self setIpAddress:value];
		[self setEndOffset:nil];
	} while (false);
}

- (NSString *)triggeredBy { return [nodeDictionary objectForKey:TT_triggeredBy]; }
- (void)setTriggeredBy:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:TT_triggeredBy];
    else [nodeDictionary removeObjectForKey:TT_triggeredBy];
}

- (NSNumber *)matchCount { return [nodeDictionary objectForKey:TT_matchCount]; }
- (void)setMatchCount:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:TT_matchCount];
    else [nodeDictionary removeObjectForKey:TT_matchCount];
}

- (NSDate *)lastTime { return [nodeDictionary objectForKey:TT_lastTime]; }
- (void)setLastTime:(NSDate *)value {
    if (value) [nodeDictionary setObject:value forKey:TT_lastTime];
    else [nodeDictionary removeObjectForKey:TT_lastTime];
}

// ---------------------------------------------------------------------------------
//	¥ setDuration:
// ---------------------------------------------------------------------------------
- (NSNumber *)duration { return [nodeDictionary objectForKey:TT_duration]; }
- (void)setDuration:(NSNumber *)value {
	// if setting has changed
	NSString* previous = [nodeDictionary objectForKey:TT_duration];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:TT_duration];
		else [nodeDictionary removeObjectForKey:TT_duration];
	}
}

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:nodeDictionary];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
	nodeDictionary = [[coder decodeObject] retain];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    TriggerEntry *copy;
    copy = [[TriggerEntry allocWithZone:zone] init];
    [copy setNodeDictionary:nodeDictionary];
    return copy;
}
@end


#pragma mark --- CONVERSION ---
// convert between data and object form
int triggerObjectToData(TriggerEntry* entry, KFT_triggerEntry_t* outData)
{
	int returnValue = -1;	// no entry
	
	if (entry && outData) {
		// initialize result
		bzero(outData, sizeof(KFT_triggerEntry_t));
		outData->address = ipForString([entry ipAddress]);
		outData->type = [[entry type] intValue];
		outData->endOffset = [[entry endOffset] unsignedIntValue];
		outData->lastTime = (u_int32_t)[[entry lastTime] timeIntervalSince1970];
		outData->duration = [[entry duration] intValue];
		outData->match.count = [[entry matchCount] intValue];
		NSData* text = [[entry triggeredBy] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
		[text getBytes:&outData->triggeredBy[1] length:kTriggeredBySize-1];
		outData->triggeredBy[0] = [text length];
		if (outData->triggeredBy[0] > kTriggeredBySize-1) outData->triggeredBy[0] = kTriggeredBySize-1;
		returnValue = 0;
	}
	return returnValue;
}

TriggerEntry* triggerObjectFromData(KFT_triggerEntry_t* inData)
{
	TriggerEntry* entry = [[[TriggerEntry alloc] init] autorelease];
	
	// build trigger entry from message
		// ipAddress
	[entry setIpAddress:stringForIP(inData->address)];
		// type
	[entry setType:[NSNumber numberWithInt:inData->type]];
		// endOffset
	[entry setEndOffset:[NSNumber numberWithUnsignedInt:inData->endOffset]];
		// last time
	[entry setLastTime:[NSDate dateWithTimeIntervalSince1970:
		inData->lastTime]];
		// duration
	[entry setDuration:[NSNumber numberWithInt:inData->duration]];
		// match count
	[entry setMatchCount:[NSNumber numberWithUnsignedLong:
		inData->match.count]];
		// triggered by
	NSString* str = [[[NSString alloc] initWithBytes:&inData->triggeredBy[1]
		length:inData->triggeredBy[0] encoding:NSUTF8StringEncoding] autorelease];
	[entry setTriggeredBy:str];
	return entry;
}

