//
//  PortMapEntry.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import "PortMapEntry.h"
#import "IPValue.h"
#import "PortRangeFormatter.h"
#import "IPSupport.h"
//#import <sys/socket.h>		// basic socket definitions
//#import <sys/time.h>		// timeval{} for select
#import <netinet/in.h>		// sockaddr_in{} and other Internet defs
#import <arpa/inet.h>


@implementation PortMapEntry

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
        nodeDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
		[nodeDictionary setObject:[NSNumber numberWithInt:1] forKey:PM_enabled];
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
	// default for enabled
	if (![nodeDictionary objectForKey:PM_enabled])
		[nodeDictionary setObject:[NSNumber numberWithInt:1] forKey:PM_enabled];
}

+ (PortMapEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	PortMapEntry* entry;
	entry = [[[PortMapEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

// ---------------------------------------------------------------------------------
//	¥ compareActual:
// ---------------------------------------------------------------------------------
- (NSComparisonResult)compareActual:(PortMapEntry *)value
{
	IPValue* ta = nil;
	IPValue* tb = nil;
	int pa, pb;
	u_int32_t ipA, ipB;
	PortRangeFormatter* prf;
	NSString* str;
	NSString* portStr;

	// port (could be a port range or zero for any)
	prf = [PortRangeFormatter sharedInstance];
	if ((portStr = [self actualPort])) {
		if (![prf getObjectValue:&ta forString:portStr errorDescription:&str]) {
			NSLog(@"%@",str);
			return -1;
		}
	}
	if ((portStr = [value actualPort])) {
		if (![prf getObjectValue:&tb forString:portStr errorDescription:&str]) {
			NSLog(@"%@",str);
			return +1;
		}
	}
	if (([ta startPort] != 0) && ([tb startPort] != 0)) {
		if (([ta startPort] < [tb startPort]) && ([ta endPort] < [tb startPort])) return -1;
		if (([tb startPort] < [ta startPort]) && ([tb endPort] < [ta startPort])) return +1;
	}
	// protocol (could be zero for any)
	pa = [[self protocol] intValue];
	pb = [[value protocol] intValue];
	if ((pa != 0) && (pb != 0)) {
		if (pa < pb) return -1;
		if (pa > pb) return +1;
	}
	// address
	ipA = ipForString([self actualAddress]);
	ipB = ipForString([value actualAddress]);
	if (ipA < ipB) return -1;
	else if (ipA > ipB) return +1;
	else return 0;
}

// ---------------------------------------------------------------------------------
//	¥ compareApparent:
// ---------------------------------------------------------------------------------
- (NSComparisonResult)compareApparent:(PortMapEntry *)value
{
	IPValue* ta = nil;
	IPValue* tb = nil;
	int pa, pb;
	u_int32_t ipA, ipB;
	PortRangeFormatter* prf;
	NSString* str;
	NSString* portStr;

	// address
	ipA = ipForString([self apparentAddress]);
	ipB = ipForString([value apparentAddress]);
	if (ipA < ipB) return -1;
	if (ipA > ipB) return +1;
	// port (could be a port range or zero for any)
	prf = [PortRangeFormatter sharedInstance];
	if ((portStr = [self apparentPort])) {
		if (![prf getObjectValue:&ta forString:portStr errorDescription:&str]) {
			NSLog(@"%@",str);
			return -1;
		}
	}
	if ((portStr = [value apparentPort])) {
		if (![prf getObjectValue:&tb forString:portStr errorDescription:&str]) {
			NSLog(@"%@",str);
			return +1;
		}
	}
	if (([ta startPort] != 0) && ([tb startPort] != 0)) {
		if (([ta startPort] < [tb startPort]) && ([ta endPort] < [tb startPort])) return -1;
		if (([tb startPort] < [ta startPort]) && ([tb endPort] < [ta startPort])) return +1;
	}
	// protocol (could be zero for any)
	pa = [[self protocol] intValue];
	pb = [[value protocol] intValue];
	if ((pa != 0) && (pb != 0)) {
		if (pa < pb) return -1;
		if (pa > pb) return +1;
	}
	return 0;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@:%@ %@:%@ %@",
		[nodeDictionary objectForKey:PM_apparentAddress],
		[nodeDictionary objectForKey:PM_apparentPort],
		[nodeDictionary objectForKey:PM_actualAddress],
		[nodeDictionary objectForKey:PM_actualPort],
		[nodeDictionary objectForKey:PM_protocol]
		];
}

// ---------------------------------------------------------------------------------
//	¥ objectSpecifier
// ---------------------------------------------------------------------------------
// Apparent Compare uses IP Address, port range, protocol
- (NSScriptObjectSpecifier *)objectSpecifier {
	NSScriptClassDescription *containerClassDesc = (NSScriptClassDescription *)
		[NSScriptClassDescription classDescriptionForClass:[NSApp class]];

	NSString* uniqueID = [NSString stringWithFormat:@"address=%@;port=%@;protocol=%@",
		[self apparentAddress],[self apparentPort],[self protocol]];
	return [[[NSUniqueIDSpecifier alloc] 
		initWithContainerClassDescription:containerClassDesc
		containerSpecifier:nil key:@"portMaps"
		uniqueID:uniqueID] autorelease];
}


#pragma mark --- Accessors ---
- (NSNumber *)enabled { return [nodeDictionary objectForKey:PM_enabled]; }
- (void)setEnabled:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_enabled];
    else [nodeDictionary removeObjectForKey:PM_enabled];
}

- (NSString *)dynamic { return [nodeDictionary objectForKey:PM_dynamic]; }
- (void)setDynamic:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_dynamic];
    else [nodeDictionary removeObjectForKey:PM_dynamic];
}

- (NSString *)apparentAddress { return [nodeDictionary objectForKey:PM_apparentAddress]; }
- (void)setApparentAddress:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_apparentAddress];
    else [nodeDictionary removeObjectForKey:PM_apparentAddress];
}

- (NSString *)apparentPort { return [nodeDictionary objectForKey:PM_apparentPort]; }
- (void)setApparentPort:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_apparentPort];
    else [nodeDictionary removeObjectForKey:PM_apparentPort];
}

- (NSString *)actualAddress { return [nodeDictionary objectForKey:PM_actualAddress]; }
- (void)setActualAddress:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_actualAddress];
    else [nodeDictionary removeObjectForKey:PM_actualAddress];
}

- (NSString *)actualPort { return [nodeDictionary objectForKey:PM_actualPort]; }
- (void)setActualPort:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_actualPort];
    else [nodeDictionary removeObjectForKey:PM_actualPort];
}

- (NSString *)protocol { return [nodeDictionary objectForKey:PM_protocol]; }
- (void)setProtocol:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_protocol];
    else [nodeDictionary removeObjectForKey:PM_protocol];
}

- (NSNumber *)localProxy { return [nodeDictionary objectForKey:PM_localProxy]; }
- (void)setLocalProxy:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_localProxy];
    else [nodeDictionary removeObjectForKey:PM_localProxy];
}

- (NSString *)comment { return [nodeDictionary objectForKey:PM_comment]; }
- (void)setComment:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:PM_comment];
    else [nodeDictionary removeObjectForKey:PM_comment];
}

#pragma mark -- coding and copying --
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
    PortMapEntry *copy;
    copy = [[PortMapEntry allocWithZone:zone] init];
    [copy setNodeDictionary:nodeDictionary];
    return copy;
}
@end

#pragma mark --- CONVERSION ---
// convert between data and object form
int portMapObjectToData(PortMapEntry* entry, KFT_natEntry_t* outData)
{
	int returnValue = -1;	// no entry
	IPValue* ipValue;
	PortRangeFormatter* prf;
	
	if (entry) {
		// initialize result
		bzero(outData, sizeof(KFT_natEntry_t));
		// on
		outData->inactive = 1 -  [[entry enabled] intValue];
		// dynamic (bsdName if any)
		if ([[entry dynamic] length]) [[entry dynamic] getCString:outData->bsdName maxLength:8 encoding:NSUTF8StringEncoding];
		else outData->bsdName[0] = 0;
		// apparent endpoint
			// port and range if any
		prf = [PortRangeFormatter sharedInstance];
		if ([prf getObjectValue:&ipValue forString:[entry apparentPort] errorDescription:nil]) {
			outData->apparent.port = [ipValue startPort];
			if ([ipValue endPort]) outData->endOffset = [ipValue endPort] - [ipValue startPort];
		}
			// protocol
		outData->apparent.pad = 0;
		outData->apparent.protocol = [[entry protocol] intValue];
			// ip address
		outData->apparent.address = ipForString([entry apparentAddress]);
		// actual endpoint
			// port
		outData->actual.port = outData->apparent.port;	// default to apparent
		if ([prf getObjectValue:&ipValue forString:[entry actualPort] errorDescription:nil]) {
			outData->actual.port = [ipValue startPort];
		}
			// protocol
		outData->actual.pad = 0;
		outData->actual.protocol = [[entry protocol] intValue];
			// ip address
		outData->actual.address = ipForString([entry actualAddress]);
		// localProxy
		outData->localProxy = [[entry localProxy] intValue];
		returnValue = 0;
	}
	return returnValue;
}

PortMapEntry* portMapObjectFromData(KFT_natEntry_t* inData)
{
	PortMapEntry* entry = nil;
	NSString* str;
	u_int32_t address;
	PortRangeFormatter* prf;
	IPValue* ipValue;
	
	entry = [[[PortMapEntry alloc] init] autorelease];
	prf = [[[PortRangeFormatter alloc]  init] autorelease];
	ipValue = [[[IPValue alloc] init] autorelease];
	// on
	[entry setEnabled:[NSNumber numberWithInt:1-inData->inactive]];
	// dynamic
	if (inData->bsdName[0]) [entry setDynamic:[NSString stringWithCString:inData->bsdName encoding:NSUTF8StringEncoding]];
	// apparent port
	[ipValue setStartPort:inData->apparent.port];
	if (inData->endOffset) [ipValue setEndPort:inData->apparent.port + inData->endOffset];
	[entry setApparentPort:[prf stringForObjectValue:ipValue]];
	// apparent address
	address = inData->apparent.address;
	str = [NSString stringWithFormat:@"%d.%d.%d.%d",
        (SInt32)(address >> 24 & 0xFF),
        (SInt32)(address >> 16 & 0xFF),
        (SInt32)(address >> 8 & 0xFF),
        (SInt32)(address & 0xFF)
    ];
	[entry setApparentAddress:str];	
	// actual port
	[ipValue setStartPort:inData->actual.port];
	if (inData->endOffset) [ipValue setEndPort:inData->actual.port + inData->endOffset];
	else [ipValue setEndPort:0];
	[entry setActualPort:[prf stringForObjectValue:ipValue]];
	// actual address
	address = inData->actual.address;
	str = [NSString stringWithFormat:@"%d.%d.%d.%d",
        (SInt32)(address >> 24 & 0xFF),
        (SInt32)(address >> 16 & 0xFF),
        (SInt32)(address >> 8 & 0xFF),
        (SInt32)(address & 0xFF)
    ];
	[entry setActualAddress:str];	
	// protocol
	switch (inData->apparent.protocol) {
		case IPPROTO_TCP:
			str = [NSString stringWithFormat:@"%d (TCP)",inData->apparent.protocol];
			break;
		case IPPROTO_UDP:
			str = [NSString stringWithFormat:@"%d (UDP)",inData->apparent.protocol];
			break;
		case IPPROTO_ICMP:
			str = [NSString stringWithFormat:@"%d (ICMP)",inData->apparent.protocol];
			break;
		default:
			str = [NSString stringWithFormat:@"%d",inData->apparent.protocol];
			break;
	}
	[entry setProtocol:str];
	// localProxy
	[entry setLocalProxy:[NSNumber numberWithInt:inData->localProxy]];
	return entry;
}

