//
//  InterfaceEntry.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import "InterfaceEntry.h"
#import "SystemConfiguration.h"
#import "IPSupport.h"
#import "ipkTypes.h"


@implementation InterfaceEntry

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

+ (InterfaceEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	InterfaceEntry* entry;
	entry = [[[InterfaceEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

- (NSString *)description
{
	return [nodeDictionary description];
}

// ---------------------------------------------------------------------------------
//	¥ objectSpecifier
// ---------------------------------------------------------------------------------
- (NSScriptObjectSpecifier *)objectSpecifier {
	NSScriptClassDescription *containerClassDesc = (NSScriptClassDescription *)
		[NSScriptClassDescription classDescriptionForClass:[InterfaceEntry class]];

	return [[[NSUniqueIDSpecifier alloc] 
		initWithContainerClassDescription:containerClassDesc
		containerSpecifier:nil key:@"interfaces"
		uniqueID:[self interfaceID]] autorelease];
}

#pragma mark --- Accessors ---

- (NSNumber *)filterOn { return [nodeDictionary objectForKey:IT_filterOn]; }
- (void)setFilterOn:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_filterOn];
    else [nodeDictionary removeObjectForKey:IT_filterOn];
}

- (NSNumber *)externalOn { return [nodeDictionary objectForKey:IT_externalOn]; }
- (void)setExternalOn:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_externalOn];
    else [nodeDictionary removeObjectForKey:IT_externalOn];
}

- (NSNumber *)natOn { return [nodeDictionary objectForKey:IT_natOn]; }
- (void)setNatOn:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_natOn];
    else [nodeDictionary removeObjectForKey:IT_natOn];
}

- (NSNumber *)bridgeOn { return [nodeDictionary objectForKey:IT_bridgeOn]; }
- (void)setBridgeOn:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_bridgeOn];
    else [nodeDictionary removeObjectForKey:IT_bridgeOn];
}

- (NSString *)bsdName { return bsdNameForInterfaceID([nodeDictionary objectForKey:IT_interfaceID]); }
- (NSString *)interfaceName { return [nodeDictionary objectForKey:IT_interfaceName]; }
- (void)setInterfaceName:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_interfaceName];
    else [nodeDictionary removeObjectForKey:IT_interfaceName];
}

- (NSString *)serviceID { return [nodeDictionary objectForKey:IT_serviceID]; }
- (void)setServiceID:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_serviceID];
    else [nodeDictionary removeObjectForKey:IT_serviceID];
}

- (NSString *)interfaceID { return [nodeDictionary objectForKey:IT_interfaceID]; }
- (void)setInterfaceID:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_interfaceID];
    else [nodeDictionary removeObjectForKey:IT_interfaceID];
	// replace interfaceID in title if needed
	if (![value isEqualTo:interfaceIDForTitle([self interfaceName])]) {
		NSMutableString* title;
		NSRange findRange;
		NSRange replaceRange;
		replaceRange.length = 0;
		replaceRange.location = 0;
		title = [NSMutableString stringWithString:[self interfaceName]];
		findRange = [title rangeOfString:@"("];
		if (findRange.length) replaceRange.location = findRange.location+1;
		findRange = [title rangeOfString:@")"];
		if (findRange.length) replaceRange.length = findRange.location - replaceRange.location;
		if (replaceRange.length) {
			[title replaceCharactersInRange:replaceRange withString:value];
		}
		[self setInterfaceName:[NSString stringWithString:title]];
	}
}

- (NSString *)ifNet { return [nodeDictionary objectForKey:IT_ifNet]; }
- (void)setIfNet:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_ifNet];
    else [nodeDictionary removeObjectForKey:IT_ifNet];
}

- (NSString *)natNet { return [nodeDictionary objectForKey:IT_natNet]; }
- (void)setNatNet:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_natNet];
    else [nodeDictionary removeObjectForKey:IT_natNet];
}

- (NSString *)singleNet { return [nodeDictionary objectForKey:IT_singleNet]; }
- (void)setSingleNet:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:IT_singleNet];
    else [nodeDictionary removeObjectForKey:IT_singleNet];
}

// Interface table implicit
//- (NSString *)excludeNet { return [nodeDictionary objectForKey:IT_excludeNet]; }
- (NSString *)excludeNet { return nil; }	// ***
- (void)setExcludeNet:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:IT_excludeNet];
    else [nodeDictionary removeObjectForKey:IT_excludeNet];
}

- (NSNumber *)exposedHostSelection { return [nodeDictionary objectForKey:IT_exposedHostSelection]; }
- (void)setExposedHostSelection:(NSNumber *)value
{
    if (value) [nodeDictionary setObject:value forKey:IT_exposedHostSelection];
    else [nodeDictionary removeObjectForKey:IT_exposedHostSelection];
}

- (NSString *)exposedHost { return [nodeDictionary objectForKey:IT_exposedHost]; }
- (void)setExposedHost:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:IT_exposedHost];
    else [nodeDictionary removeObjectForKey:IT_exposedHost];
}


#pragma mark --- CODING_AND_COPYING ---
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
    InterfaceEntry *copy;
    copy = [[InterfaceEntry allocWithZone:zone] init];
    [copy setNodeDictionary:nodeDictionary];
    return copy;
}
@end

#pragma mark --- CONVERSION ---
// convert between data and object form
int interfaceObjectToData(InterfaceEntry* interfaceE, KFT_interfaceEntry_t* outData)
{
	int returnValue = -1;	// no entry
	
	if (interfaceE) {
		bzero(outData, sizeof(KFT_interfaceEntry_t));
		// filterOn
		outData->filterOn = [[interfaceE filterOn] intValue];
		// externalOn
		outData->externalOn = [[interfaceE externalOn] intValue];
		// natOn
		outData->natOn = [[interfaceE natOn] intValue];		
		// bridgeOn
		outData->bridgeOn = [[interfaceE bridgeOn] intValue];		
		// bsdName
		[[interfaceE bsdName] getCString:outData->bsdName maxLength:kBSDNameLength encoding:NSUTF8StringEncoding];
		// serviceID
		[[interfaceE serviceID] getCString:outData->serviceID maxLength:kServiceIDNameLength encoding:NSUTF8StringEncoding];
		// ifNet
		netNumberForString([interfaceE ifNet], &outData->ifNet.address, &outData->ifNet.mask);
		// natNet
		netNumberForString([interfaceE natNet], &outData->natNet.address, &outData->natNet.mask);
		// singleNet
		netNumberForString([interfaceE singleNet], &outData->singleNet.address, &outData->singleNet.mask);
		// -- valid for NAT interfaces only
		if (outData->natOn) {
			// excludeNet
			netNumberForString([interfaceE excludeNet], &outData->excludeNet.address, &outData->excludeNet.mask);
			// exposedHost
			outData->exposedHost = ipForString([interfaceE exposedHost]);
			// exposedHostSelection
			outData->exposedHostSelection = [[interfaceE exposedHostSelection] intValue];
		}
		returnValue = 0;
	}
	return returnValue;
}

InterfaceEntry* interfaceObjectFromData(KFT_interfaceEntry_t* inData)
{
	InterfaceEntry* interfaceE = nil;
	
	interfaceE = [[[InterfaceEntry alloc] init] autorelease];

	// filterOn
	[interfaceE setFilterOn:[NSNumber numberWithInt:inData->filterOn]];
	// externalOn
	[interfaceE setExternalOn:[NSNumber numberWithInt:inData->externalOn]];
	// natOn
	[interfaceE setNatOn:[NSNumber numberWithInt:inData->natOn]];
	// bridgeOn
	[interfaceE setBridgeOn:[NSNumber numberWithInt:inData->bridgeOn]];
	// bsdName
	[interfaceE setInterfaceName:[NSString stringWithCString:inData->bsdName encoding:NSUTF8StringEncoding]];
	// serviceID
	[interfaceE setServiceID:[NSString stringWithCString:inData->serviceID encoding:NSUTF8StringEncoding]];
	// ifNet
	[interfaceE setIfNet:stringForNetNumber(inData->ifNet.address, inData->ifNet.mask)];
	// natNet
	[interfaceE setNatNet:stringForNetNumber(inData->natNet.address, inData->natNet.mask)];
	// singleNet
	[interfaceE setSingleNet:stringForNetNumber(inData->singleNet.address, inData->singleNet.mask)];
	// -- valid for NAT interfaces only
	if (inData->natOn) {
		// excludeNet
		if (inData->excludeNet.mask) {
			[interfaceE setExcludeNet:stringForNetNumber(inData->excludeNet.address, inData->excludeNet.mask)];
		}
		// exposedHost
		if (inData->exposedHost) {
			[interfaceE setExposedHost:stringForIP(inData->exposedHost)];
		}
		// exposedHostSelection
		[interfaceE setExposedHostSelection:[NSNumber numberWithInt:inData->exposedHostSelection]];
	}
	
	return interfaceE;
}
