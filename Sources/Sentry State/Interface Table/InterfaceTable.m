//  InterfaceTable.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 1 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for interface table

#import "InterfaceTable.h"
#import "SentryDefs.h"
#import "kftSupport.h"
#import "IPSupport.h"
#import "SystemConfiguration.h"
#import PS_TNKE_INCLUDE
#if !BUILD_AS_HELPER_TOOL
#import "SentryModel.h"
#import "SentryController.h"
#endif
#import "kft.h"
#if IPNetRouter
#import "DHCPEntry.h"
#endif

// Globals
NSString *InterfaceTableNotification = @"InterfaceTableNotification";

@implementation InterfaceTable

// ---------------------------------------------------------------------------------
//	¥ sharedInstance
// ---------------------------------------------------------------------------------
+ (InterfaceTable *) sharedInstance {
#if BUILD_AS_HELPER_TOOL
//#if 1
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[InterfaceTable alloc] init];
	}
	return sharedTask;
#else
	SentryModel *sentryModel = [SentryModel sharedInstance];
	InterfaceTable *interfaceTable = [sentryModel interfaceTable];
	if (!interfaceTable) {
		interfaceTable = [[[InterfaceTable alloc] init] autorelease];
		[[sentryModel sentryState] setInterfaceTable:interfaceTable];
	}
	return interfaceTable;
#endif
}

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
	if (self = [super init]) {
        // initialize our instance variables
		interfaceArray = nil;
		excludeNet = nil;
		exposedHostSelection = nil;
		exposedHost = nil;
    }
	[self updateFromSCF];
	// request to be notified when IPv4 configuration changes
	[[SystemConfiguration sharedInstance] addObserver:self withSelector:@selector(scfNotification:)];
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	// no longer want to be notified when IPv4 configuration changes
	[[SystemConfiguration sharedInstance] removeObserver:self];
    [interfaceArray release];	interfaceArray = nil;
	[excludeNet release];			excludeNet = nil;
	[exposedHostSelection release];	exposedHostSelection = nil;
	[exposedHost release];			exposedHost = nil;
    [super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:InterfaceTableNotification 
    object:self];
}

// ---------------------------------------------------------------------------------
//	¥ removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:InterfaceTableNotification
        object:nil];	// remove any previous InterfaceTableNotification
}

// ---------------------------------------------------------------------------------
//	¥ updateParameter
// ---------------------------------------------------------------------------------
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
    NSDictionary* myDictionary;
	myDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:anObject, name, nil];
	// notify listeners with dictionary
	[[NSNotificationCenter defaultCenter]
		postNotificationName:InterfaceTableNotification
		object:self
		userInfo:myDictionary];		
	[myDictionary release];
	return YES;
}

// ---------------------------------------------------------------------------------
//	¥ interfaceArray
// ---------------------------------------------------------------------------------
// Get or set underlying NSMutableArray object to examine or update interface list
- (NSMutableArray *)interfaceArray { return interfaceArray; }
- (void)setInterfaceArray:(NSMutableArray *)value {
	[value retain];
	[interfaceArray release];
	interfaceArray = value;
}

// ---------------------------------------------------------------------------------
//	¥ interfaceArrayOfDictionaries
// ---------------------------------------------------------------------------------
// Return as array of dictionaries for export as XML
- (NSArray *)interfaceArrayOfDictionaries {
	NSEnumerator* en;
	NSMutableArray* arrayOfDictionaries;
	InterfaceEntry* entry;
	
	arrayOfDictionaries = [NSMutableArray array];
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		[arrayOfDictionaries addObject:[entry nodeDictionary]];
	}
	return (NSArray *)arrayOfDictionaries;
}


// ---------------------------------------------------------------------------------
// ¥ updateFromSCF
// ---------------------------------------------------------------------------------
// Update interfaceTable using SCF (System Configuration Framework)
// Merge previous interface settings if any
- (void)updateFromSCF
{
	NSArray* prevArray;
	NSArray* titles;
	NSArray* serviceIDs;
	int i, count;
	NSString* title;
	NSString* serviceID;
	NSString* bsdName;
	NSString* netNumberStr;
	NSEnumerator* en;
	
	// get previously saved interface array if any
	prevArray = [self interfaceArray];

	// load interface array
		// allocate tempArray
	NSMutableArray* tempArray = [NSMutableArray arrayWithCapacity:64];
	// get list of interfaces
	titles = [[SystemConfiguration sharedInstance]
		interfaceTitlesAndServiceIDs:&serviceIDs];
	// for each interface
	count = [titles count];
	for (i=0; i<count; i++) {
		title = [titles objectAtIndex:i];
		serviceID = [serviceIDs objectAtIndex:i];
		InterfaceEntry* entry = nil;
		InterfaceEntry* prevEntry;
		bsdName = bsdNameForTitle(title);
		// is there a previous entry for this interface?
		en = [prevArray objectEnumerator];
		while (prevEntry = [en nextObject]) {
			// look for matching serviceID
			if ([[prevEntry serviceID] isEqualTo:serviceID]) {
				entry = prevEntry;
				break;
			}
			// look for matching interface ID (for location changes)
			if ([[prevEntry interfaceID] isEqualTo:interfaceIDForTitle(title)]) {
				entry = prevEntry;
				break;
			}
		}
		if (!entry) {
			// create and load interface entry with default user settings
			entry = [[[InterfaceEntry alloc] init] autorelease];
			// firewall and external
			if ([bsdName isEqualTo:@"lo0"]) {
				[entry setFilterOn:[NSNumber numberWithInt:0]];
				[entry setExternalOn:[NSNumber numberWithInt:0]];
			}
			else {
				// set first interface for IP filtering and external (primary)
				if (i == 0) {
					[entry setFilterOn:[NSNumber numberWithInt:1]];
					[entry setExternalOn:[NSNumber numberWithInt:1]];
				}
				else {
					[entry setFilterOn:[NSNumber numberWithInt:0]];
					[entry setExternalOn:[NSNumber numberWithInt:0]];
				}
			}
		}
		// include settings from SCF (System Configuration Framework)
			// interfaceName
		if (![[entry interfaceName] length]) [entry setInterfaceName:title];
		[entry setServiceID:serviceID];
		[entry setInterfaceID:[[[SystemConfiguration sharedInstance] interfaceIDs] objectForKey:serviceID]];
			// IP address
		netNumberStr = [[SystemConfiguration sharedInstance]
				service:serviceID interfaceDataForKey:@"netNumber"];
		[entry setIfNet:netNumberStr];
		
		// add dictionary entry to interface array
		[tempArray addObject:entry];
	}
	[self setInterfaceArray:tempArray];
}

// ---------------------------------------------------------------------------
//	¥ scfNotification
// ---------------------------------------------------------------------------
//  (2) Receives notifications from SCF
//		NKE Controller, and KEV controller), and either modifies model state or passes
//		them on.
- (void)scfNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;

	dictionary = [aNotification userInfo];
	[dictionary retain];
	
	if ([[aNotification name] isEqualTo:SystemConfigurationNotification]) {
		NSString* serviceID;
		NSString* interfaceID;
		NSString* bsdName;
		NSArray* addresses;
		NSArray* netMasks;
		NSString* maskStr;
		NSString* prefixLenStr;
		NSString* addressStr;
		NSString* netNumberStr;
		NSMutableArray* netNumbers = [[[NSMutableArray alloc] init] autorelease];
		InterfaceTable* interfaceT;
		InterfaceEntry* interfaceE;
		int i, count;

		// refresh interface entry
		bsdName = [dictionary objectForKey:@"InterfaceName"];
		serviceID = [dictionary objectForKey:@"ServiceID"];
		interfaceID = [[[SystemConfiguration sharedInstance] interfaceIDs] objectForKey:serviceID];
		if (!interfaceID) {
			// a new serviceID was detected indicating we switched to a new set
			// update interface table from SCF
			[[SystemConfiguration sharedInstance] purgeInterfaceIDs];
			interfaceT = self;
			[interfaceT updateFromSCF];
			interfaceID = [[[SystemConfiguration sharedInstance] interfaceIDs] objectForKey:serviceID];
		}
		addresses = [dictionary objectForKey:@"Addresses"];
		netMasks = [dictionary objectForKey:@"SubnetMasks"];
		// there should be only one IPv4 address for a given ServiceID
		count = [addresses count];
		for (i=0; i<count; i++) {
			addressStr = [addresses objectAtIndex:i];
			if (!addressStr) continue;
			maskStr = [netMasks objectAtIndex:i];
			if (!maskStr) prefixLenStr = @"32";
			else {
				prefixLenStr = prefixForMaskStr(maskStr);
				if ([prefixLenStr intValue] == 0) prefixLenStr = @"32";
			}
			netNumberStr = [NSString stringWithFormat:@"%@/%@",addressStr,prefixLenStr];
			[netNumbers addObject:netNumberStr];
		}
		if ([netNumbers count]) netNumberStr = [netNumbers componentsJoinedByString:@","];
		else netNumberStr = kSCNotAvailable;
		interfaceT = self;
		interfaceE = [interfaceT entryForServiceID:serviceID];
		// if no match, use interfaceID
		if (!interfaceID) interfaceID = bsdName;
		if (!interfaceE) interfaceE = [interfaceT entryForInterfaceID:interfaceID];
		if (interfaceE) {
			// have new interface information
			// update table entry
			[interfaceE setIfNet:netNumberStr];
			// log event
			[self updateParameter:SA_logMessage withObject:
				[NSString stringWithFormat:@" SystemConfiguration update %@ %@", bsdName, netNumberStr]];
			// update NKE state
			if (![netNumberStr isEqualTo:kSCNotAvailable] && [self isAttachEntry:interfaceE]) {
				// update firewall on state for ppp interfaces
				if ([bsdName hasPrefix:@"ppp"]) {
					[self updateParameter:SS_firewallOn withObject:SS_firewallOn];
				}
#if !BUILD_AS_HELPER_TOOL
				// download to NKE
				[[SentryModel sharedInstance] downloadInterfaceTable];
#endif
			}
			// update display state
			[self updateParameter:SS_interfaceTable withObject:SS_interfaceTable];
#if IPNetRouter
			if (netNumberStr != kSCNotAvailable) {
				// update DHCP Server currentNameServer
				[self updateParameter:DS_updateHostDNS withObject:DS_updateHostDNS];
				// update port map table
				[self updateParameter:SA_portMapTable withObject:interfaceID];
				// update name server if enabled
				[self updateParameter:SA_interfaceTable withObject:SA_interfaceTable];
			}
#endif
		}	// if (interfaceE)
	}
	else {
		// pass along any other parameter updates (statusInfo, etc...)
		[[NSNotificationCenter defaultCenter]
			//postNotificationName:[aNotification name]
			postNotificationName:InterfaceTableNotification
			object:self
			userInfo:dictionary];		
	}
	[dictionary release];
}


#pragma mark --- COORDINATED ---
// Coordinated settings are settings that are calculated or adjusted automaticallly
// based on the combined state of other settings.
// ---------------------------------------------------------------------------
//	¥ natSettingHasChanged
// ---------------------------------------------------------------------------
// adjust IP Forwarding and singleNet settings when NAT is set to on
- (void)natSettingHasChanged
{
	InterfaceEntry* interfaceE;
	InterfaceEntry* entry;
	InterfaceEntry* foundE = nil;
	NSString* bsdName;
	NSString* str;
	int count;
	int i, j;

	//NSLog(@"Nat setting has changed");	
	count = [interfaceArray count];
	// scan for any NAT enabled interfaces
	for (i=0; i<count; i++) {
		interfaceE = [interfaceArray objectAtIndex:i];
		// if nat is enabled, turn on IP forwarding
		if ([[interfaceE natOn] intValue]) {
			[self updateParameter:SS_ipForwarding withObject:[NSNumber numberWithInt:1]];
			break;
		}
	}
	// scan interface table to identify Single Ethernet configuration
	// and set singleNet to enable Single Ethernet NAPT
		// for each external+nat enabled interface, look for an
		// internal interface on the same port
	for (i=0; i<count; i++) {
		interfaceE = [interfaceArray objectAtIndex:i];
		bsdName = bsdNameForInterfaceID([interfaceE interfaceID]);
		if ([[interfaceE externalOn] intValue] && [[interfaceE natOn] intValue]) {
			foundE = nil;
			for (j=0; j<i; j++) {
				entry = [interfaceArray objectAtIndex:j];
				str = bsdNameForInterfaceID([entry interfaceID]);
				if ([bsdName isEqualTo:str] && ![[entry externalOn] intValue]) {
					foundE = entry;
					break;
				}
			}
			if (!foundE) for (j=i+1; j<count; j++) {
				entry = [interfaceArray objectAtIndex:j];
				str = bsdNameForInterfaceID([entry interfaceID]);
				if ([bsdName isEqualTo:str] && ![[entry externalOn] intValue]) {
					foundE = entry;
					break;
				}
			}
			if (foundE) {
				// found single external and internal interface, configure singleNet
				str = [foundE ifNet];
				[interfaceE setSingleNet:str];
				[foundE setSingleNet:str];
				[self updateParameter:@"statusInfo" withObject:[NSString stringWithFormat:
					@"Internal Interface %@ on External Port %@",str, bsdName]];
			}
			else [interfaceE setSingleNet:nil];
		}	// if (external + nat)
	}	// for (i=0; i<count; i++)
	// portMapLoadCombos
	[self updateParameter:SS_portMapLoadCombos withObject:SS_portMapLoadCombos];
}

#pragma mark -- Access Helpers --
// ---------------------------------------------------------------------------------
//	¥ entryForServiceID
// ---------------------------------------------------------------------------------
// Find entry with matching serviceID.
// Used to correlate SCF callbacks with correct table entry
- (InterfaceEntry *)entryForServiceID:(NSString *)serviceID {
	InterfaceEntry* returnValue = nil;
	NSEnumerator* en;
	InterfaceEntry* entry;
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		if ([serviceID isEqualTo:[entry serviceID]]) {
			returnValue = entry;
			break;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ entryForInterfaceID
// ---------------------------------------------------------------------------------
// Find entry with matching interfaceID.
// Since there can be more than one interface for a given bsdName,
// we index them as en0, en0:1, en0:2 etc.
- (InterfaceEntry *)entryForInterfaceID:(NSString *)interfaceID {
	InterfaceEntry* returnValue = nil;
	NSEnumerator* en;
	InterfaceEntry* entry;
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		if ([interfaceID isEqualTo:[entry interfaceID]]) {
			returnValue = entry;
			break;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ entryForAddress
// ---------------------------------------------------------------------------------
// Find entry with matching IP address.
- (InterfaceEntry *)entryForAddress:(NSString *)inAddress {
	InterfaceEntry* returnValue = nil;
	NSEnumerator* en;
	InterfaceEntry* entry;
	u_int32_t ipAddress = ipForString(inAddress);
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		u_int32_t netNumber;
		u_int32_t mask;
		u_int32_t address;
		netNumber = netNumberForString([entry ifNet], &address, &mask);
		if ((ipAddress & mask) == netNumber) {
			returnValue = entry;
			break;
		}
	}
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ entryForNat
// ---------------------------------------------------------------------------------
// Find first NAT entry.  Used to create default port map entries
- (InterfaceEntry *)entryForNat
{
	InterfaceEntry* returnValue = nil;
	NSEnumerator* en;
	InterfaceEntry* entry;
	
	// walk the interface table
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		if (![[entry ifNet] isEqualTo:kSCNotAvailable]) {
			// set default to first entry with address available
			if (!returnValue) returnValue = entry;
			// look for first entry with "natOn" and "externalOn"
			if ([[entry natOn] intValue] && [[entry externalOn] intValue]) {
				returnValue = entry;
				break;
			}
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ entryForDhcp
// ---------------------------------------------------------------------------------
// Find first DHCP entry.  Used to create default DHCP interface
- (InterfaceEntry *)entryForDhcp
{
	InterfaceEntry* returnValue = nil;
	NSEnumerator* en;
	InterfaceEntry* entry;
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		if (![[entry ifNet] isEqualTo:kSCNotAvailable]) {
			// set default to first active entry
			if (!returnValue) returnValue = entry;
			// look for first !externalOn and address available
			if ([[entry externalOn] intValue]) continue;
			returnValue = entry;
			break;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ entryForPrimary
// ---------------------------------------------------------------------------------
// Primary interface used for DNS and default route
- (InterfaceEntry *)entryForPrimary
{
	InterfaceEntry* returnValue = nil;
	NSEnumerator* en;
	InterfaceEntry* entry;
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		if (![[entry ifNet] isEqualTo:kSCNotAvailable]) {
			returnValue = entry;
			break;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ isAttachEntry:
// ---------------------------------------------------------------------------------
// If external, filter, nat, or bridge is enabled
// call isDetachIndex to skip duplicate port entries.
- (BOOL)isAttachEntry:(InterfaceEntry *)inEntry
{
	BOOL returnValue = NO;
	if ([[inEntry externalOn] intValue] ||
		[[inEntry filterOn] intValue] ||
		[[inEntry natOn] intValue] ||
		[[inEntry bridgeOn] intValue]) {
			returnValue = [self isDetachEntry:inEntry];
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ isDetachEntry:
// ---------------------------------------------------------------------------------
// scan interface table to skip duplicate port entries we don't want to download
- (BOOL)isDetachEntry:(InterfaceEntry *)inEntry
{
	BOOL returnValue = YES;
	InterfaceEntry* entry;
	NSString* bsdName;
	int k, count;
	BOOL seenEntry = NO;

	// is it a NAT entry?
	if (![inEntry natOn]) {	// if yes, just send it
		// check if we should attach/send this interface entry
		// walk interface table to look for matching network port
		bsdName = [inEntry bsdName];
		count = [interfaceArray count];
		for (k=0; k<count; k++) {
			entry = [interfaceArray objectAtIndex:k];
			if (entry == inEntry) {	// skip inEntry
				seenEntry = YES;
				continue;
			}
			if ([bsdName isEqualTo:[entry bsdName]]) {	// matching network port?
				// before inEntry?
				if (seenEntry == NO) {
					returnValue = NO;	// don't need to send inEntry
					break;
				}
				else {
					// after inEntry and NAT is on
					if ([[entry natOn] intValue]) {
						returnValue = NO;	// don't need to send inEntry
						break;
					}
				}
			}	// if ([bsdName isEqualTo:[entry bsdName]]) {
		}	// for (k=0; k<count; k++) {
	}	// if (![inEntry natOn]) {
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ isDupEntry:
// ---------------------------------------------------------------------------------
// scan interface table to identify duplicate port entries
- (BOOL)isDupEntry:(InterfaceEntry *)inEntry
{
	int count, k;
	InterfaceEntry* entry;
	NSString* bsdName;

	// walk interface table
	count = [interfaceArray count];
	bsdName = [inEntry bsdName];
	// is there another entry on this port?
	for (k=0; k<count; k++) {
		entry = [interfaceArray objectAtIndex:k];
		if (entry == inEntry) continue;
		if ([bsdName isEqualTo:[entry bsdName]]) return YES;
	}
	return NO;
}

// these are copies of the values in SentryState
- (NSString *)excludeNet { return excludeNet; }
- (void)setExcludeNet:(NSString *)value {
	[value retain];
	[excludeNet release];
	excludeNet = value;
}

- (NSNumber *)exposedHostSelection { return exposedHostSelection; }
- (void)setExposedHostSelection:(NSNumber *)value {
	[value retain];
	[exposedHostSelection release];
	exposedHostSelection = value;
}

- (NSString *)exposedHost { return exposedHost; }
- (void)setExposedHost:(NSString *)value {
	[value retain];
	[exposedHost release];
	exposedHost = value;
}

#pragma mark --- NSTableViewDelegate ---
//- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
//- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row;
//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
//- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(int)row;
//- (BOOL)tableView:(NSTableView *)tableView shouldSelectTableColumn:(NSTableColumn *)tableColumn;


#pragma mark --- NSTableDataSource ---
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [interfaceArray count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	InterfaceEntry* entry;
	entry = [interfaceArray objectAtIndex:row];
	return [entry valueForKey:[tableColumn identifier]];
}

// optional
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	InterfaceEntry* entry;
	NSString* columnID;
	id oldValue;

	do {	
		if ([interfaceArray count] <= row) break;	// defensive
		entry = [interfaceArray objectAtIndex:row];
		columnID = [tableColumn identifier];
		oldValue = [entry valueForKey:columnID];
		[[oldValue retain] autorelease];
		// detect legal to change (for bridging)
		if ([columnID isEqualTo:IT_bridgeOn]) {
			NSString* serviceID = [entry serviceID];
			// Allow Ethernet bridging on tap devices
			if (![serviceID hasPrefix:kTapServiceID]) {
				NSString* type = [[SystemConfiguration sharedInstance] service:serviceID dataForDictionaryName:@"Interface" key:(NSString *)kSCPropNetInterfaceType];
				if (![type isEqualTo:(NSString *)kSCValNetInterfaceTypeEthernet]) break;
			}
		}
		// assign new value
		[entry setValue:object forKey:columnID];
		// note if value has changed
		BOOL valueDidChange = NO;
		if (!oldValue && !object) valueDidChange = NO;
		else if (oldValue && !object) valueDidChange = YES;
		else if (!oldValue && object) valueDidChange = YES;
		else if ([object isKindOfClass:[NSString class]]) {
			if ([(NSString *)object compare:oldValue] != NSOrderedSame) valueDidChange = YES;
		}
		else if ([object isKindOfClass:[NSNumber class]]) {
			//if ([(NSNumber *)object compare:oldValue] != NSOrderedSame) valueDidChange = YES;
			if ([object intValue] != [oldValue intValue]) valueDidChange = YES;
		}		
		// if changed
		if (valueDidChange) {
			[self updateParameter:SS_documentChangeDone withObject:[NSNumber numberWithInt:NSChangeDone]];
			//[delegate setApplyPending:[NSNumber numberWithInt:1]];
			#ifdef IPNetRouter
			// detect change to nat or external
			if ([columnID isEqualTo:IT_natOn] && [object intValue]) 
				[self natSettingHasChanged];
			if ([columnID isEqualTo:IT_externalOn] && [object intValue])
				[self natSettingHasChanged];
			#endif
		}
	} while (false);
}

@end
