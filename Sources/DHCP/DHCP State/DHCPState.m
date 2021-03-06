//
//  DHCPState.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003-04 Sustainable Softworks, Inc. All rights reserved.
//

#import "DHCPState.h"
//#import "DHCPAction.h"  // access isServing method

// =================================================================================
//	� DHCPState
// =================================================================================
@implementation DHCPState

// ---------------------------------------------------------------------------------
//	� initWithDefaults
// ---------------------------------------------------------------------------------
- (id)initWithDefaults
{
    if (self = [super init]) {
        // initialize our instance variables
		delegate = nil;
		recordChanges = NO;
		[self allocTables];
		// set defaults
		[self setIgnoreBootp:[NSNumber numberWithInt:0]];
		[self setDynamicBootp:[NSNumber numberWithInt:1]];
		[self setPingCheck:[NSNumber numberWithInt:1]];
		[self setVerboseLogging:[NSNumber numberWithInt:1]];
		[self setNotGrantedMessage:@"The requested DHCP lease could not be granted.  Please contact your System Administrator."];
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	� initWithNodeDictionary:
// ---------------------------------------------------------------------------------
- (id)initWithNodeDictionary:(NSMutableDictionary *)value
{
    if (self = [super init]) {
        // initialize our instance variables
		delegate = nil;
		recordChanges = NO;
		[self setNodeDictionary:value];
		[self allocTables];
		// make sure table delegates are initialized
		[[self statusTable] setDelegate:self];
		[[self staticConfigTable] setDelegate:self];
		[[self dynamicConfigTable] setDelegate:self];
		[[self leaseOptionsTable] setDelegate:self];
		[[self serverOptionsTable] setDelegate:self];
		
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	� allocTables
// ---------------------------------------------------------------------------------
// allocate any tables we don't already have
- (void)allocTables
{
	id table;
	// status table
	if (![self statusTable]) {
		table = [[[DHCPStatusTable alloc] init] autorelease];
		[self setStatusTable:table];
	}
	// static config table
	if (![self staticConfigTable]) {
		table = [[[DHCPStaticConfigTable alloc] init] autorelease];
		[self setStaticConfigTable:table];
	}
	// dynamic config table
	if (![self dynamicConfigTable]) {
		table = [[[DHCPDynamicConfigTable alloc] init] autorelease];
		[self setDynamicConfigTable:table];
		[table newDefaultEntry:-1]; // load default entry
	}
	// lease options table
	if (![self leaseOptionsTable]) {
		table = [[[DHCPLeaseOptionsTable alloc] init] autorelease];
		[self setLeaseOptionsTable:table];
		[table newDefaultEntry:-1]; // load default entry
	}
	// server options table
	if (![self serverOptionsTable]) {
		table = [[[DHCPServerOptionsTable alloc] init] autorelease];
		[self setServerOptionsTable:table];
	}
}

// ---------------------------------------------------------------------------------
//	� dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
    [self setDelegate:nil];
    [super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"{ dhcpState = %@; statusTable = %@; staticConfigTable = %@; dynamicConfigTable = %@; leaseOptionsTable = %@; serverOptionsTable = %@; }",
		[nodeDictionary description],
		[[[self statusTable] tableDictionary] description],
		[[[self staticConfigTable] tableDictionary] description],
		[[[self dynamicConfigTable] tableDictionary] description],
		[[[self leaseOptionsTable] tableDictionary] description],
		[[[self serverOptionsTable] tableDictionary] description]
	];
}

#pragma mark --- Accessors ---
// ---------------------------------------------------------------------------------
//	� delegate
// ---------------------------------------------------------------------------------
- (id)delegate { return delegate; }
- (void)setDelegate:(id)value {
	//[value retain];   // not retained to avoid retain loop
	//[delegate release];
	delegate = value;
}
- (BOOL)recordChanges { return recordChanges; }
- (void)setRecordChanges:(BOOL)value { recordChanges = value; }

// ---------------------------------------------------------------------------------
//	� changeDone
// ---------------------------------------------------------------------------------
- (void)changeDone
{
	if (recordChanges) {
		[self updateParameter:DS_changeDone withObject:DS_changeDone];
	}
}

// ---------------------------------------------------------------------------------
//	� updateParameter
// ---------------------------------------------------------------------------------
// PSTableDelegate method
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
	BOOL returnValue = NO;
	if ([delegate respondsToSelector:@selector(updateParameter:withObject:)]) {
		[delegate updateParameter:name withObject:anObject];
		returnValue = YES;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� applyPending
// ---------------------------------------------------------------------------------
- (NSNumber *)applyPending { return [nodeDictionary objectForKey:DS_applyPending]; }
- (void)setApplyPending:(NSNumber *)value
{
	// if setting has changed
	NSNumber* oldValue = [nodeDictionary objectForKey:DS_applyPending];
	if ([value intValue] != [oldValue intValue]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:DS_applyPending];
		else [nodeDictionary removeObjectForKey:DS_applyPending];
		// notify listeners
		[self updateParameter:DS_applyPending withObject:value];
		//[self changeDone];
	}
	else if (!oldValue) [self updateParameter:DS_applyPending withObject:value];
}

// global parameters
- (NSNumber *)dhcpServerOn { return [nodeDictionary objectForKey:DS_dhcpServerOn]; }
- (void)setDhcpServerOn:(NSNumber *)value {
	NSNumber* oldValue = [nodeDictionary objectForKey:DS_dhcpServerOn];
	if (![value isEqualTo:oldValue]) {
		// value has changed
		if (value) [nodeDictionary setObject:value forKey:DS_dhcpServerOn];
		else [nodeDictionary removeObjectForKey:DS_dhcpServerOn];
		[self changeDone];
	}
}

- (NSNumber *)verboseLogging { return [nodeDictionary objectForKey:DS_verboseLogging]; }
- (void)setVerboseLogging:(NSNumber *)value {
	NSNumber* oldValue = [nodeDictionary objectForKey:DS_verboseLogging];
	if (![value isEqualTo:oldValue]) {
		// value has changed
		if (value) [nodeDictionary setObject:value forKey:DS_verboseLogging];
		else [nodeDictionary removeObjectForKey:DS_verboseLogging];
		[self changeDone];
	}
}

- (NSNumber *)ignoreBootp { return [nodeDictionary objectForKey:DS_ignoreBootp]; }
- (void)setIgnoreBootp:(NSNumber *)value {
	if (![value isEqualTo:[nodeDictionary objectForKey:DS_ignoreBootp]]) {
		[self changeDone];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
    if (value) [nodeDictionary setObject:value forKey:DS_ignoreBootp];
    else [nodeDictionary removeObjectForKey:DS_ignoreBootp];
}

- (NSNumber *)dynamicBootp { return [nodeDictionary objectForKey:DS_dynamicBootp]; }
- (void)setDynamicBootp:(NSNumber *)value {
	if (![value isEqualTo:[nodeDictionary objectForKey:DS_dynamicBootp]]) {
		[self changeDone];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
    if (value) [nodeDictionary setObject:value forKey:DS_dynamicBootp];
    else [nodeDictionary removeObjectForKey:DS_dynamicBootp];
}

- (NSNumber *)pingCheck { return [nodeDictionary objectForKey:DS_pingCheck]; }
- (void)setPingCheck:(NSNumber *)value {
	if (![value isEqualTo:[nodeDictionary objectForKey:DS_pingCheck]]) {
		[self changeDone];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
    if (value) [nodeDictionary setObject:value forKey:DS_pingCheck];
    else [nodeDictionary removeObjectForKey:DS_pingCheck];
}

- (NSString *)grantedMessage { return [nodeDictionary objectForKey:DS_grantedMessage]; }
- (void)setGrantedMessage:(NSString *)value {
	if (![value isEqualToString:[nodeDictionary objectForKey:DS_grantedMessage]]) {
		[self changeDone];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
    if (value) [nodeDictionary setObject:value forKey:DS_grantedMessage];
    else [nodeDictionary removeObjectForKey:DS_grantedMessage];
}

- (NSString *)notGrantedMessage { return [nodeDictionary objectForKey:DS_notGrantedMessage]; }
- (void)setNotGrantedMessage:(NSString *)value {
	if (![value isEqualToString:[nodeDictionary objectForKey:DS_notGrantedMessage]]) {
		[self changeDone];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
    if (value) [nodeDictionary setObject:value forKey:DS_notGrantedMessage];
    else [nodeDictionary removeObjectForKey:DS_notGrantedMessage];
}

- (NSString *)hostDNS { return [nodeDictionary objectForKey:DS_hostDNS]; }
- (void)setHostDNS:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_hostDNS];
    else [nodeDictionary removeObjectForKey:DS_hostDNS];
}

- (NSString *)localDNS { return [nodeDictionary objectForKey:DS_localDNS]; }
- (void)setLocalDNS:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_localDNS];
    else [nodeDictionary removeObjectForKey:DS_localDNS];
}

#pragma mark --- Tables ---	
- (DHCPStatusTable *)statusTable {
	return [nodeDictionary objectForKey:DS_statusTable];
}
- (DHCPStaticConfigTable *)staticConfigTable {
	return [nodeDictionary objectForKey:DS_staticConfigTable];
}
- (DHCPDynamicConfigTable *)dynamicConfigTable {
	return [nodeDictionary objectForKey:DS_dynamicConfigTable];
}
- (DHCPLeaseOptionsTable *)leaseOptionsTable {
	return [nodeDictionary objectForKey:DS_leaseOptionsTable];
}
- (DHCPServerOptionsTable *)serverOptionsTable {
	return [nodeDictionary objectForKey:DS_serverOptionsTable];
}

- (void)setStatusTable:(DHCPStatusTable *)value {
    if (value) {
		[nodeDictionary setObject:value forKey:DS_statusTable];
		[value setDelegate:self];
    }
	else {
		[nodeDictionary removeObjectForKey:DS_statusTable];
	}
}
- (void)setStaticConfigTable:(DHCPStaticConfigTable *)value {
    if (value) {
		[nodeDictionary setObject:value forKey:DS_staticConfigTable];
		[value setDelegate:self];
	}
    else [nodeDictionary removeObjectForKey:DS_staticConfigTable];
}
- (void)setDynamicConfigTable:(DHCPDynamicConfigTable *)value {
    if (value) {
		[nodeDictionary setObject:value forKey:DS_dynamicConfigTable];
		[value setDelegate:self];
	}
    else [nodeDictionary removeObjectForKey:DS_dynamicConfigTable];
}
- (void)setLeaseOptionsTable:(DHCPLeaseOptionsTable *)value {
    if (value) {
		[nodeDictionary setObject:value forKey:DS_leaseOptionsTable];
		[value setDelegate:self];
	}
    else [nodeDictionary removeObjectForKey:DS_leaseOptionsTable];
}
- (void)setServerOptionsTable:(DHCPServerOptionsTable *)value {
    if (value) {
		[nodeDictionary setObject:value forKey:DS_serverOptionsTable];
		[value setDelegate:self];
	}
    else [nodeDictionary removeObjectForKey:DS_serverOptionsTable];
}

#pragma mark --- Table Dictionaries ---
// used for key value coding
- (NSMutableDictionary *)statusTableDictionary {
	return [[nodeDictionary objectForKey:DS_statusTable] tableDictionary];
}
- (NSMutableDictionary *)staticConfigTableDictionary {
	return [[nodeDictionary objectForKey:DS_staticConfigTable] tableDictionary];
}
- (NSMutableDictionary *)dynamicConfigTableDictionary {
	return [[nodeDictionary objectForKey:DS_dynamicConfigTable] tableDictionary];
}
- (NSMutableDictionary *)leaseOptionsTableDictionary {
	return [[nodeDictionary objectForKey:DS_leaseOptionsTable] tableDictionary];
}
- (NSMutableDictionary *)serverOptionsTableDictionary {
	return [[nodeDictionary objectForKey:DS_serverOptionsTable] tableDictionary];
}

- (void)setStatusTableDictionary:(NSMutableDictionary *)value {
	[[self statusTable] setTableDictionary:value];
}
- (void)setStaticConfigTableDictionary:(NSMutableDictionary *)value {
	[[self staticConfigTable] setTableDictionary:value];
}
- (void)setDynamicConfigTableDictionary:(NSMutableDictionary *)value {
	[[self dynamicConfigTable] setTableDictionary:value];
}
- (void)setLeaseOptionsTableDictionary:(NSMutableDictionary *)value {
	[[self leaseOptionsTable] setTableDictionary:value];
	//NSLog(@"%@",[[self leaseOptionsTable] description]);
}
- (void)setServerOptionsTableDictionary:(NSMutableDictionary *)value {
	[[self serverOptionsTable] setTableDictionary:value];
}

#pragma mark --- Table Arrays ---
// used for key value coding
- (NSMutableArray *)statusTableArray {
	return [[nodeDictionary objectForKey:DS_statusTable] tableArray];
}
- (NSMutableArray *)staticConfigTableArray {
	return [[nodeDictionary objectForKey:DS_staticConfigTable] tableArray];
}
- (NSMutableArray *)dynamicConfigTableArray {
	return [[nodeDictionary objectForKey:DS_dynamicConfigTable] tableArray];
}
- (NSMutableArray *)leaseOptionsTableArray {
	return [[nodeDictionary objectForKey:DS_leaseOptionsTable] tableArray];
}
- (NSMutableArray *)serverOptionsTableArray {
	return [[nodeDictionary objectForKey:DS_serverOptionsTable] tableArray];
}

- (void)setStatusTableArray:(NSMutableArray *)value {
	[[self statusTable] setTableArray:value];
}
#if 0	// implemented as dictionary tables
- (void)setStaticConfigTableArray:(NSMutableArray *)value {
	[[self staticConfigTable] setTableArray:value];
}
- (void)setDynamicConfigTableArray:(NSMutableArray *)value {
	[[self dynamicConfigTable] setTableArray:value];
}
- (void)setLeaseOptionsTableArray:(NSMutableArray *)value {
	[[self leaseOptionsTable] setTableArray:value];
	//NSLog(@"%@",[[self leaseOptionsTable] description]);
}
- (void)setServerOptionsTableArray:(NSMutableArray *)value {
	[[self serverOptionsTable] setTableArray:value];
}
#endif

#pragma mark --- Table Entries ---
- (DHCPStatusEntry *)statusEntry {
	return nil;		// need secondary key to select which entry
}

- (void)setStatusEntry:(DHCPStatusEntry *)value {
    DHCPStatusTable* table;
	NSString* key;
	table = [nodeDictionary objectForKey:DS_statusTable];
	key = [value key];
	[table setObject:value forKey:key];
}
@end


