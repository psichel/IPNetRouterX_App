//  DHCPTable.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Mon Nov 10 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for DHCP State tables

#import "DHCPTable.h"
#import "DHCPState.h"

//#import "DHCPServer.h"
#import "IPValue.h"
#import "IPSupport.h"
#import "PSServiceDictionary.h"
// newDefaultEntry
#import "InterfaceTable.h"
#import "SystemConfiguration.h"

// =================================================================================
//	¥ DHCPStatusTable
// =================================================================================
@implementation DHCPStatusTable

// ---------------------------------------------------------------------------------
//	¥ tableFromDictionary
// ---------------------------------------------------------------------------------
+ (DHCPStatusTable *)tableFromDictionary:(NSDictionary *)inDictionary {
	DHCPStatusTable* table;
	table = [[[DHCPStatusTable alloc] init] autorelease];
	[table loadDictionaryOfDictionaries:inDictionary forEntryClass:[DHCPStatusEntry class]];
	return table;
}

// ---------------------------------------------------------------------------------
//	¥ tableView:setObjectValue:forTableColumn:row:
// ---------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id entry;
//	NSString* columnID;
//	id oldValue;
	
	entry = [self objectAtIndex:row];
#if 0
	columnID = [tableColumn identifier];
	oldValue = [entry valueForKey:columnID];
	[[oldValue retain] autorelease];
	[entry setValue:object forKey:columnID];
	// note if value has changed
	if (oldValue) {
		if ([object isKindOfClass:[NSString class]]) {
			if ([(NSString *)object compare:oldValue] != NSOrderedSame)
				[delegate updateParameter:DS_statusEntry withObject:entry];
				[delegate changeDone];
		}
		else if ([object isKindOfClass:[NSNumber class]]) {
			//if ([(NSNumber *)object compare:oldValue] != NSOrderedSame) {
			if ([object intValue] != [oldValue intValue]) {
				[delegate updateParameter:DS_statusEntry withObject:entry];
				[delegate changeDone];
			}
		}
		else {
			[delegate updateParameter:DS_statusEntry withObject:entry];
			[delegate changeDone];
		}
	}
	else if (object) {
		[delegate updateParameter:DS_statusEntry withObject:entry];
		[delegate changeDone];
	}
#else
	[delegate updateParameter:DS_statusEntry withObject:entry];
#endif
}

@end


// =================================================================================
//	¥ DHCPStaticConfigTable
// =================================================================================
@implementation DHCPStaticConfigTable
// ---------------------------------------------------------------------------------
//	¥ tableFromDictionary
// ---------------------------------------------------------------------------------
+ (DHCPStaticConfigTable *)tableFromDictionary:(NSDictionary *)inDictionary {
	DHCPStaticConfigTable* table;
	table = [[[DHCPStaticConfigTable alloc] init] autorelease];
	[table loadDictionaryOfDictionaries:inDictionary forEntryClass:[DHCPStaticConfigEntry class]];
	return table;
}

// ---------------------------------------------------------------------------------
//	¥ newDefaultEntry:
// ---------------------------------------------------------------------------------
- (int)newDefaultEntry:(int)selectedRow
{
	DHCPStaticConfigEntry* staticConfigE;
	u_int32_t address;
	// allocate new entry
	staticConfigE = [[[DHCPStaticConfigEntry alloc] init] autorelease];
	// initialize any defaults
	{
		InterfaceEntry* interfaceE;
		if (selectedRow < 0) selectedRow = [self count] - 1;   // if none selected, use last row
		if (selectedRow >= 0) {
			// borrow from existing last entry
			DHCPStaticConfigEntry* tableE;
			tableE = [self objectAtIndex:selectedRow];
			[staticConfigE setNetworkInterface:[tableE networkInterface]];
			address = [tableE ipAddressInt];
			// look for next unused address
			do {
				address += 1;
			} while ([self objectForKeyInt:address]);
			[staticConfigE setIpAddressInt:address];
		}
		else {
			// create first entry in table
			interfaceE = [[InterfaceTable sharedInstance] entryForDhcp];
			[staticConfigE setNetworkInterface:[interfaceE ifNet]];
			address = ipForString([interfaceE ifNet]) + 1;
			[staticConfigE setIpAddressInt:address];
		}
	}
	// add to table
	[self setObject:staticConfigE forKeyInt:address];
	return [self indexOfObject:staticConfigE];
}

// ---------------------------------------------------------------------------------
//	¥ tableView:setObjectValue:forTableColumn:row:
// ---------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id entry;
	NSString* columnID;
	id oldValue;
	BOOL didChange = NO;
	
	entry = [self objectAtIndex:row];
	columnID = [tableColumn identifier];
	oldValue = [entry valueForKey:columnID];
	[[oldValue retain] autorelease];
	[entry setValue:object forKey:columnID];
	// note if value has changed
	if (oldValue) {
		if ([object isKindOfClass:[NSString class]]) {
			if ([(NSString *)object compare:oldValue] != NSOrderedSame) didChange = YES;
		}
		else if ([object isKindOfClass:[NSNumber class]]) {
			//if ([(NSNumber *)object compare:oldValue] != NSOrderedSame) didChange = YES;
			if ([object intValue] != [oldValue intValue]) didChange = YES;
		}
		else didChange = YES;
	}
	else if (object) didChange = YES;
	if (didChange) {
		[delegate changeDone];
		if (![columnID isEqualTo:DS_comment]) [delegate setApplyPending:[NSNumber numberWithInt:1]];
		if ([columnID isEqualTo:DS_ipAddress]) {
			// remove and re-add entry to update position in table
			[[entry retain] autorelease];
			[self removeObjectAtIndex:row];
			[self setObject:entry forKeyInt:[entry keyInt]];
			// refresh display
			[delegate updateParameter:DS_staticConfigEntry withObject:entry];
		}
	}
}
@end


// =================================================================================
//	¥ DHCPDynamicConfigTable
// =================================================================================
@implementation DHCPDynamicConfigTable
// ---------------------------------------------------------------------------------
//	¥ tableFromDictionary
// ---------------------------------------------------------------------------------
+ (DHCPDynamicConfigTable *)tableFromDictionary:(NSDictionary *)inDictionary {
	DHCPDynamicConfigTable* table;
	table = [[[DHCPDynamicConfigTable alloc] init] autorelease];
	[table loadDictionaryOfDictionaries:inDictionary forEntryClass:[DHCPDynamicConfigEntry class]];
	return table;
}

// ---------------------------------------------------------------------------------
//	¥ newDefaultEntry
// ---------------------------------------------------------------------------------
- (int)newDefaultEntry:(int)selectedRow
{
	DHCPDynamicConfigEntry* dynamicConfigE;		
	// allocate new entry
	dynamicConfigE = [[[DHCPDynamicConfigEntry alloc] init] autorelease];
	// initialize any defaults
	{
		u_int32_t address;
		u_int32_t mask;
		u_int32_t startAddress;
		u_int32_t endAddress;
		u_int8_t prefixLen;

		InterfaceEntry* interfaceE;
		interfaceE = [[InterfaceTable sharedInstance] entryForDhcp];
		[dynamicConfigE setNetworkInterface:[interfaceE ifNet]];

		if (selectedRow < 0) selectedRow = [self count] - 1;   // if none selected, use last row
		if (selectedRow >= 0) {
			// borrow from existing last entry
			DHCPDynamicConfigEntry* tableE;
			tableE = [self objectAtIndex:selectedRow];
			address = [tableE endingAddressInt];
			// look for next unused address
			do {
				address += 1;
			} while ([self objectForKeyInt:address]);
			[dynamicConfigE setStartingAddressInt:address];
			[dynamicConfigE setEndingAddressInt:address];		
		}
		else {
			// create first entry in table
			address = netNumberForString([interfaceE ifNet], nil, &mask);
			prefixLen = FindRightBit(mask, 32);
			startAddress = address + 32-prefixLen;
			[dynamicConfigE setStartingAddressInt:startAddress];
			endAddress = address + (0xFFFFFFFF & ~mask) -1;
			[dynamicConfigE setEndingAddressInt:endAddress];		
		}
	}
	// add to table
	[self setObject:dynamicConfigE forKeyInt:[dynamicConfigE keyInt]];
	return [self indexOfObject:dynamicConfigE];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id entry;
	NSString* columnID;
	id oldValue;
	BOOL didChange = NO;
	
	entry = [self objectAtIndex:row];
	columnID = [tableColumn identifier];
	oldValue = [entry valueForKey:columnID];
	[[oldValue retain] autorelease];
	[entry setValue:object forKey:columnID];
	// note if value has changed
	if (oldValue) {
		if ([object isKindOfClass:[NSString class]]) {
			if ([(NSString *)object compare:oldValue] != NSOrderedSame) {
				didChange = YES;
				if ([columnID isEqualToString:DS_networkInterface]) {
					// initialize matching address range
					u_int32_t net;
					u_int32_t mask;
					u_int8_t prefixLen;
					u_int32_t start, end;
					
					net = netNumberForString(object, nil, &mask);
					prefixLen = FindRightBit(mask, 32);
					start = net + 32-prefixLen;
					end = net | ~mask;
					if (prefixLen <= 30) end -= 1;
					// adjust table entry and position
					NSString* old = [entry startingAddress];
					NSString* new = stringForIP(start);
					[entry setStartingAddressInt:start];
					[entry setEndingAddressInt:end];
					[self setObject:entry forKey:new];
					[self removeObjectForKey:old];
				}
			}
		}
		else if ([object isKindOfClass:[NSNumber class]]) {
			//if ([(NSNumber *)object compare:oldValue] != NSOrderedSame) didChange = YES;
			if ([object intValue] != [oldValue intValue]) didChange = YES;
		}
		else didChange = YES;
	}
	else if (object) didChange = YES;
	if (didChange) {
		[delegate changeDone];
		if (![columnID isEqualTo:DS_comment]) [delegate setApplyPending:[NSNumber numberWithInt:1]];
		if ([columnID isEqualTo:DS_startingAddress]) {
			// remove and re-add entry to update position in table
			[[entry retain] autorelease];
			[self removeObjectAtIndex:row];
			[self setObject:entry forKeyInt:[entry keyInt]];
			// refresh display
			[delegate updateParameter:DS_dynamicConfigEntry withObject:entry];
		}
	}
}
@end


// =================================================================================
//	¥ DHCPLeaseOptionsTable
// =================================================================================
@implementation DHCPLeaseOptionsTable

// ---------------------------------------------------------------------------------
//	¥ tableFromDictionary
// ---------------------------------------------------------------------------------
+ (DHCPLeaseOptionsTable *)tableFromDictionary:(NSDictionary *)inDictionary {
	DHCPLeaseOptionsTable* table;
	table = [[[DHCPLeaseOptionsTable alloc] init] autorelease];
	[table loadDictionaryOfDictionaries:inDictionary forEntryClass:[DHCPLeaseOptionsEntry class]];
	return table;
}

// ---------------------------------------------------------------------------------
//	¥ newDefaultEntry
// ---------------------------------------------------------------------------------
- (int)newDefaultEntry:(int)selectedRow
{
	DHCPLeaseOptionsEntry* leaseOptionsE;
	// allocate new entry
	leaseOptionsE = [[[DHCPLeaseOptionsEntry alloc] init] autorelease];
	// initialize any defaults
	{
		InterfaceEntry* interfaceE;
		NSString* addressStr;
		NSArray* addressList;
		NSString* serviceID;
		// network interface
		interfaceE = [[InterfaceTable sharedInstance] entryForDhcp];
		// if already in use, pick another one
		addressStr = [interfaceE ifNet];
		if ([self objectForKey:addressStr]) {
			NSArray* interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
			int i, count;
			count = [interfaceArray count];
			for (i=0; i<count; i++) {
				interfaceE = [interfaceArray objectAtIndex:i];
				addressStr = [interfaceE ifNet];
				if (![self objectForKey:addressStr]) break;
			}
		}
		[leaseOptionsE setNetworkInterface:[interfaceE ifNet]];
		// dhcpOn
		[leaseOptionsE setDhcpOn:[NSNumber numberWithInt:1]];
		// look for primary interface (first active or NAT)
		serviceID = [[[InterfaceTable sharedInstance] entryForNat] serviceID];
		// routers (external->kSCPropNetIPv4Router, internal->me)
		// name servers (external->skSCPropNetDNSServerAddresses, internal->0.0.0.0)
		if ([[interfaceE externalOn] intValue]) {  // external			
			addressStr = [[SystemConfiguration sharedInstance]
				service:serviceID dataForDictionaryName:@"IPv4" key:@"Router"];
			[leaseOptionsE setRouter:addressStr];
			addressList = [[SystemConfiguration sharedInstance]
				service:serviceID dataForDictionaryName:@"DNS" key:@"ServerAddresses"];
			[leaseOptionsE setNameServers:[addressList componentsJoinedByString:@", "]];
		}
		else {  // internal
			u_int32_t address;
			address = ipForString([interfaceE ifNet]);
			[leaseOptionsE setRouter:stringForIP(address)];
			[leaseOptionsE setNameServers:@"0.0.0.0"];
		}
		
		// default/max lease time
		[leaseOptionsE setDefaultLeaseTime:[NSNumber numberWithInt:86400]]; // 24 hours
		[leaseOptionsE setMaxLeaseTime:[NSNumber numberWithInt:86400]]; // 24 hours
		
		// search domains (kSCPropNetDNSSearchDomains)
		{
			NSArray* nameList;
			NSString* str;
			nameList = [[SystemConfiguration sharedInstance]
				service:serviceID dataForDictionaryName:@"DNS" key:@"SearchDomains"];
			str = [nameList componentsJoinedByString:@","];
			[leaseOptionsE setSearchDomains:str];
		}
	}
	// add to table
	[self addObject:leaseOptionsE];
	return [self indexOfObject:leaseOptionsE];
}

// ---------------------------------------------------------------------------------
//	¥ tableView:setObjectValue:forTableColumn:row:
// ---------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id entry;
	NSString* columnID;
	id oldValue;
	BOOL didChange = NO;
	
	entry = [self objectAtIndex:row];
	columnID = [tableColumn identifier];
	oldValue = [entry valueForKey:columnID];
	[[oldValue retain] autorelease];
	[entry setValue:object forKey:columnID];
	// note if value has changed
	if (oldValue) {
		if ([object isKindOfClass:[NSString class]]) {
			if ([(NSString *)object compare:oldValue] != NSOrderedSame) didChange = YES;
		}
		else if ([object isKindOfClass:[NSNumber class]]) {
			//if ([(NSNumber *)object compare:oldValue] != NSOrderedSame)  didChange = YES;
			if ([object intValue] != [oldValue intValue]) didChange = YES;
		}
		else didChange = YES;
	}
	else if (object) didChange = YES;
	if (didChange) {
		[delegate changeDone];
		if (![columnID isEqualTo:DS_comment]) [delegate setApplyPending:[NSNumber numberWithInt:1]];
		if ([columnID isEqualTo:DS_networkInterface]) {
			// remove and re-add entry to update position in table
			if (object) [self setObject:entry forKey:object];
			if (oldValue) [self removeObjectForKey:oldValue];
			//[[entry retain] autorelease];
			//[self removeObjectAtIndex:row];		// PSArrayTable
			//[self setObject:entry forKeyInt:[entry keyInt]];
			// refresh display
			[delegate updateParameter:DS_leaseOptionsTable withObject:entry];
		}
	}
}

// ---------------------------------------------------------------------------------
//	¥ objectAtIndex
// ---------------------------------------------------------------------------------
- (id)objectAtIndex:(unsigned)index
{
	id returnValue = nil;
	NSString* key;
	if (!sortedKeys) {
		sortedKeys = [[tableDictionary allKeys] sortedArrayUsingFunction:ipSort context:NULL];
		[sortedKeys retain];
	}
	if ([sortedKeys count] > index) {
		key = [sortedKeys objectAtIndex:index];
		returnValue = [tableDictionary objectForKey:key];
	}
	return returnValue;
}
// ---------------------------------------------------------------------------------
//	¥ indexOfObject
// ---------------------------------------------------------------------------------
- (unsigned)indexOfObject:(id)anObject
{
	if (!sortedKeys) {
		sortedKeys = [[tableDictionary allKeys] sortedArrayUsingFunction:ipSort context:NULL];
		[sortedKeys retain];
	}
	return [sortedKeys indexOfObject:[anObject key]];
}
@end


// =================================================================================
//	¥ DHCPServerOptionsTable
// =================================================================================
@implementation DHCPServerOptionsTable
// ---------------------------------------------------------------------------------
//	¥ tableFromDictionary
// ---------------------------------------------------------------------------------
+ (DHCPServerOptionsTable *)tableFromDictionary:(NSDictionary *)inDictionary {
	DHCPServerOptionsTable* table;
	table = [[[DHCPServerOptionsTable alloc] init] autorelease];
	[table loadDictionaryOfDictionaries:inDictionary forEntryClass:[DHCPServerOptionsEntry class]];
	return table;
}

// ---------------------------------------------------------------------------------
//	¥ newDefaultEntry
// ---------------------------------------------------------------------------------
- (int)newDefaultEntry:(int)selectedRow
{
	DHCPServerOptionsEntry* serverOptionsE;
	// allocate new entry
	serverOptionsE = [[[DHCPServerOptionsEntry alloc] init] autorelease];
	// initialize any defaults
	{
		int i;
		NSString* str;
		[serverOptionsE setDhcpOptionText:@"option text"];
		[serverOptionsE setDhcpOptionType:[NSNumber numberWithInt:0]];
		if (selectedRow < 0) selectedRow = [self count] - 1;   // if none selected, use last row
		if (selectedRow >= 0) {
			// borrow from existing last entry
			DHCPServerOptionsEntry* tableE;
			tableE = [self objectAtIndex:selectedRow];
			i = [[tableE dhcpOptionNumber] intValue];
			// look for next unused option number
			do {
				i += 1;
				str = [NSString stringWithFormat:@"%d",i];
			} while ([self objectForKey:str]);
			[serverOptionsE setDhcpOptionNumber:str];
		}
		else {
			// create first entry in table
			[serverOptionsE setDhcpOptionNumber:@"0"];
		}
	}
	// add to table
	[self addObject:serverOptionsE];
	// refresh display
	return [self indexOfObject:serverOptionsE];
}

// ---------------------------------------------------------------------------------
//	¥ tableView:setObjectValue:forTableColumn:row:
// ---------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id entry;
	NSString* columnID;
	id oldValue;
	BOOL didChange = NO;
	
	entry = [self objectAtIndex:row];
	columnID = [tableColumn identifier];
	oldValue = [entry valueForKey:columnID];
	[[oldValue retain] autorelease];
	[entry setValue:object forKey:columnID];
	// note if value has changed
	if (oldValue) {
		if ([object isKindOfClass:[NSString class]]) {
			if ([(NSString *)object compare:oldValue] != NSOrderedSame) didChange = YES;
		}
		else if ([object isKindOfClass:[NSNumber class]]) {
			//if ([(NSNumber *)object compare:oldValue] != NSOrderedSame) didChange = YES;
			if ([object intValue] != [oldValue intValue]) didChange = YES;
		}
		else didChange = YES;
	}
	else if (object) didChange = YES;
	if (didChange) {
		[delegate changeDone];
		if (![columnID isEqualTo:DS_comment]) [delegate setApplyPending:[NSNumber numberWithInt:1]];
		if ([columnID isEqualTo:DS_dhcpOptionNumber]) {
			// remove and re-add entry to update position in table
			if (object) [self setObject:entry forKey:object];
			if (oldValue) [self removeObjectForKey:oldValue];
			//[[entry retain] autorelease];
			//[self removeObjectAtIndex:row];		// PSArrayTable
			//[self setObject:entry forKeyInt:[entry keyInt]];
			// refresh display
			[delegate updateParameter:DS_serverOptionsTable withObject:entry];
		}
		if ([columnID isEqualTo:DS_dhcpOptionType]) {
			NSString* str = [entry dhcpOptionText];
			u_int32_t outAddress;
			if (!isIPAddress(str, &outAddress, nil)) {
				// suggest an IP address
				InterfaceEntry* interfaceE = [[InterfaceTable sharedInstance] entryForDhcp];
				str = ipOnlyString([interfaceE ifNet]);
				[entry setDhcpOptionText:str];
			}
		}
	}
}

// ---------------------------------------------------------------------------------
//	¥ objectAtIndex
// ---------------------------------------------------------------------------------
- (id)objectAtIndex:(unsigned)index
{
	id returnValue = nil;
	NSString* key;
	if (!sortedKeys) {
		sortedKeys = [[tableDictionary allKeys] sortedArrayUsingFunction:intSort context:NULL];
		[sortedKeys retain];
	}
	if ([sortedKeys count] > index) {
		key = [sortedKeys objectAtIndex:index];
		returnValue = [tableDictionary objectForKey:key];
	}
	return returnValue;
}
// ---------------------------------------------------------------------------------
//	¥ indexOfObject
// ---------------------------------------------------------------------------------
- (unsigned)indexOfObject:(id)anObject
{
	if (!sortedKeys) {
		sortedKeys = [[tableDictionary allKeys] sortedArrayUsingFunction:intSort context:NULL];
		[sortedKeys retain];
	}
	return [sortedKeys indexOfObject:[anObject key]];
}
@end


// ---------------------------------------------------------------------------------
//	¥ ipSort
// ---------------------------------------------------------------------------------
NSInteger ipSort(id str1, id str2, void *context)
{
    u_int32_t v1 = ipForString(str1);
    u_int32_t v2 = ipForString(str2);
    if (v1 < v2)
        return NSOrderedAscending;
    else if (v1 > v2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}
/*
// use from PSServiceDictionary.h
// ---------------------------------------------------------------------------------
//	¥ intSort
// ---------------------------------------------------------------------------------
NSInteger intSort(id num1, id num2, void *context)
{
    int v1 = [num1 intValue];
    int v2 = [num2 intValue];
    if (v1 < v2)
        return NSOrderedAscending;
    else if (v1 > v2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}
*/
