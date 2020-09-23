//
//  PSPropertyValue.m
//  IPNetMonitorX
//
//  Created by psichel on Tue Oct 28 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates Property Values used as a data source for a Combo Box

#import "PSPropertyValue.h"
#import "SystemConfiguration.h"
#import "AppDelegate.h"
#import "IPSupport.h"
#import "IPValue.h"
#import "FilterEntry.h"
#import "PSServiceDictionary.h"
#import "NSDate_Extensions.h"

@implementation PSPropertyValue
// ---------------------------------------------------------------------------------
// ¥ init
// ---------------------------------------------------------------------------------
- (id) init {
    if (self = [super init]) {
        currentArray = nil;
        valueDictionary = [[NSMutableDictionary alloc] init];
        [self loadDictionary];
    }
    return self;
}
// ---------------------------------------------------------------------------------
// ¥ dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
    [valueDictionary release];
    [super dealloc];
}
// ---------------------------------------------------------------------------------
// ¥ loadDictionary
// ---------------------------------------------------------------------------------
- (void)loadDictionary
{
    //  Interface
    {
        NSMutableArray* valueList;
        NSArray* interfaceTitles;
    
        // load port menu
        interfaceTitles = [[SystemConfiguration sharedInstance] bsdTitlesAndServiceIDs:nil];
        valueList = [NSMutableArray array];
		[valueList addObject:@"internal"];		// add internal/external
		[valueList addObject:@"external"];
        if ([interfaceTitles count] == 0) {
            [valueList addObject:@"No configured interfaces"];
        }
        else {
            [valueList addObjectsFromArray:interfaceTitles];
        }
        [valueDictionary setObject:valueList forKey:PID_interface];
    }
    // MAC Address
	{
        NSMutableArray* valueList;
        NSArray* interfaceTitles;
		NSArray* serviceIDs = nil;
		NSString* macAddress;
		int i, count;
    
        // load port menu
        interfaceTitles = [[SystemConfiguration sharedInstance] interfaceTitlesAndServiceIDs:&serviceIDs];
        valueList = [NSMutableArray array];
		count = [interfaceTitles count];
		for (i=0; i<count; i++) {
			macAddress = [[SystemConfiguration sharedInstance] service:[serviceIDs objectAtIndex:i] interfaceDataForKey:@"hardwareAddress"];
			if (![macAddress isEqualTo:kSCNotAvailable])
				[valueList addObject:[NSString stringWithFormat:@"%@ (%@)",macAddress,
					bsdNameForTitle([interfaceTitles objectAtIndex:i])]];
		}
		[valueList addObject:@"ff:ff:ff:ff:ff:ff (broadcast)"];
        [valueDictionary setObject:valueList forKey:PID_MACAddress];
	}
	// Direction
    [valueDictionary setObject:[NSArray arrayWithObjects:@"inbound",@"outbound",nil] forKey:PID_direction];
    // NetNumber
    {
        NSMutableArray* valueList;
        NSArray* interfaceTitles;
		NSArray* serviceIDs = nil;
        int i, count;
        NSString* bsdName;
        NSString* userName;
        NSString* title = nil;
		NSString* titleWithName;
        NSString* addressStr;
        NSString* maskStr;
		NSString* prefixLenStr;
        // load port menu
        valueList = [NSMutableArray array];
        interfaceTitles = [[SystemConfiguration sharedInstance] interfaceTitlesAndServiceIDs:&serviceIDs];
        [interfaceTitles retain];
        count = [interfaceTitles count];
        for (i=count-1; i>=0; i--) {
            bsdName = bsdNameForTitle([interfaceTitles objectAtIndex:i]);
            // try to get network number
            do {
                addressStr = [[SystemConfiguration sharedInstance]
                    service:[serviceIDs objectAtIndex:i] interfaceDataForKey:@"grantAddress"];
                if (!addressStr) break;
                maskStr = [[SystemConfiguration sharedInstance]
                    service:[serviceIDs objectAtIndex:i] interfaceDataForKey:@"subnetMask"];
				if ( !(prefixLenStr = prefixForMaskStr(maskStr)) ) break;
				title = [NSString stringWithFormat:@"%@/%@",addressStr,prefixLenStr];
                userName = [interfaceTitles objectAtIndex:i];
                titleWithName = [NSString stringWithFormat:@"%@ (%@)",title,userName];    
                [valueList addObject:titleWithName];
            } while (false);
        }
        [interfaceTitles release];
		// show an address range
		if (title) {
			IPValue* value = [[[IPValue alloc] init] autorelease];
			[value setStringValue:title];
			title = [NSString stringWithFormat:@"%@-%@",
				stringForIP([value startOfRange]),
				stringForIP([value startOfRange] + [value endOffset])];
			[valueList addObject:title];
		}
		// include broadcast address
		title = [NSString stringWithFormat:@"255.255.255.255/32 (broadcast)"];
		[valueList addObject:title];
        [valueDictionary setObject:valueList forKey:PID_netNumber];
    }
    // Protocol
    [valueDictionary setObject:[NSArray arrayWithObjects:
		@"6 (TCP)",
		@"17 (UDP)",
		@"1 (ICMP)",
		@"47 (GRE)",
		nil] forKey:PID_protocol];  // IPPROTO_TCP

    // IP Fragment
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"0",
        @"1-63",
        nil] forKey:PID_IPFragmentOffset];
    // IP Options
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"9 (strict source route)",
        @"3 (loose source route)",
        @"7 (record route)",
        @"68 (timestamp)",
        nil] forKey:PID_IPOptions];
    // TCP Header Flags
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"ack",
        @"fin",
        @"psh",
        @"rst",
        @"syn",
        @"urg",
        @"syn,ack (comma separated list)",
        @"-ack (not ack)",
        nil] forKey:PID_TCPHeaderFlags];
    // TCP Options
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"2 (maximum segment size)",
		@"3 (window scale)",
		@"4 (Sack-Permitted)",
        @"5 (SACK selective acknowledgement)",
        @"8 (rfc1323 timestamp)",
        @"11 (rfc1644 t/tcp CC)",
		@"12 (rfc1644 t/tcp CC.NEWw)",
		@"13 (rfc1644 t/tcp CC.ECHO)",
        nil] forKey:PID_TCPOptions];
    // Protocol Port
    {
        NSMutableArray* valueList;
        NSDictionary* portDictionary;
        NSArray* keys;
        NSArray* sorted;
        NSEnumerator* en;
        NSString* str;
        NSString* serviceName;
        valueList = [NSMutableArray array];
        portDictionary = [[PSServiceDictionary sharedInstance] tcpServiceNames];
        keys = [portDictionary allKeys];
        sorted = [keys sortedArrayUsingFunction:intSort context:NULL];
        en = [sorted objectEnumerator];
        while (str = [en nextObject]) {
            serviceName = [portDictionary objectForKey:str];
            [valueList addObject:[NSString stringWithFormat:@"%@ (%@)",str,serviceName]];
        }
        [valueDictionary setObject:valueList forKey:PID_portNumber];
    }
    // Include
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"trigger",
		@"address",
		@"authorize",
		@"invalid",
		@"state",
        nil] forKey:PID_include];
    // URL keyword
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"doubleclick.net",
        @"adsource.net",
        nil] forKey:PID_URLKeyword];
    // TimeOfDay
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"8:00",
        @"8:30-17:30",
        nil] forKey:PID_timeOfDay];
    // DayOfWeek
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"0 (Sun)",
        @"1 (Mon)",
		@"2 (Tue)",
		@"3 (Wed)",
		@"4 (Thu)",
		@"5 (Fri)",
		@"6 (Sat)",
		@"1-5 (Mon-Fri)",
        nil] forKey:PID_dayOfWeek];
    // Date and Time
    [valueDictionary setObject:[NSArray arrayWithObjects:
        [[NSDate psDate] description],
        nil] forKey:PID_dateAndTime];
	// DataContent
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"matchText",
        @"[byteOffset]matchText",
        @"[byteOffset:length]matchText",
        @"[+OffsetFromLastFound:length]matchText",
        nil] forKey:PID_dataContent];
    // ICMP Type
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"0 (echo reply)",
        @"3 (destination unreachable)",
        @"4 (source quench)",
        @"5 (redirect)",
        @"8 (echo request)",
        @"11 (time exceeded)",
        @"12 (parameter problem)",
        nil] forKey:PID_ICMPType];
    // ICMP Code
    [valueDictionary setObject:[NSArray arrayWithObjects:
        @"0 (network unreachable)",
        @"1 (host unreachable)",
        @"2 (protocol unreachable)",
        @"3 (port unreachable)",
        @"6 (destination network unknown)",
        @"7 (destination host unknown)",
        @"9 (desination network admin restricted)",
        @"10 (destination host admin restricted)",
        @"13 (communication admin filtered)",
        nil] forKey:PID_ICMPCode];
}
// ---------------------------------------------------------------------------------
// ¥ resetDictionary
// ---------------------------------------------------------------------------------
- (void)resetDictionary {
    [valueDictionary removeAllObjects];
}


// Expand Values
// ---------------------------------------------------------------------------------
// ¥ expandEntry:
// ---------------------------------------------------------------------------------
- (void)expandEntry:(FilterEntry *)entry
{
	NSEnumerator* en;
	FilterEntry* child;
	NSString* expanded;
	
	// expand children of entry
	en = [[entry children] objectEnumerator];
	while (child = [en nextObject]) {
		[self expandEntry:child];
	}
	// expand entry
	expanded = [self expandProperty:[[entry property] intValue] value:[entry propertyValue]];
	[entry setPropertyValue:expanded];
}

// ---------------------------------------------------------------------------------
// ¥ expandProperty:value:
// ---------------------------------------------------------------------------------
//	expand matching property values to include descriptive information
- (NSString *)expandProperty:(int)propertyID value:(NSString *)value
{
	NSString* returnValue;
	NSArray* valueArray = nil;
	
    // default to current value
	returnValue = value;
	// set value array based on propertyID
    switch (propertyID) {
        case kFilterInterface:
            valueArray = [valueDictionary objectForKey:PID_interface];
			{
				NSEnumerator* en;
				NSString* str;
				en = [valueArray objectEnumerator];
				while (str = [en nextObject]) {
					if ([str hasSuffix:[NSString stringWithFormat:@"(%@)",value]]) {
						returnValue = str;
						break;
					}
				}
			}
			valueArray = nil;   // indicate we're done
            break;
		case kFilterSourceMACAddress:
        case kFilterDestMACAddress:
            valueArray = [valueDictionary objectForKey:PID_MACAddress];
            break;
        case kFilterSourceNet:
        case kFilterDestNet:
            valueArray = [valueDictionary objectForKey:PID_netNumber];
            break;
        case kFilterProtocol:
            valueArray = [valueDictionary objectForKey:PID_protocol];
            break;            
        case kFilterIPOptions:
            valueArray = [valueDictionary objectForKey:PID_IPOptions];
            break;            
        case kFilterTCPHeaderFlags:
            valueArray = [valueDictionary objectForKey:PID_TCPHeaderFlags];
            break;
        case kFilterTCPOptions:
            valueArray = [valueDictionary objectForKey:PID_TCPOptions];
            break;
        case kFilterSourcePort:
        case kFilterDestPort:
            valueArray = [valueDictionary objectForKey:PID_portNumber];
            break;
        case kFilterDayOfWeek:
            valueArray = [valueDictionary objectForKey:PID_dayOfWeek];
            break;
        case kFilterDateAndTime:
            valueArray = [valueDictionary objectForKey:PID_dateAndTime];
            break;
        case kFilterICMPType:
            valueArray = [valueDictionary objectForKey:PID_ICMPType];
            break;
        case kFilterICMPCode:
            valueArray = [valueDictionary objectForKey:PID_ICMPCode];
            break;
    }
	// if value matches start of entry in value array, replace with expanded version
	if (valueArray) {
		NSEnumerator* en;
		NSString* str;
		en = [valueArray objectEnumerator];
		while (str = [en nextObject]) {
			if ([str hasPrefix:[value stringByAppendingString:@" "]]) {
				returnValue = str;
				break;
			}
		}
	}
	
    return returnValue;
}


// ACCESS
// ---------------------------------------------------------------------------------
// ¥ selectProperty:
// ---------------------------------------------------------------------------------
//	select current array for property
- (NSArray *)selectProperty:(int)propertyID
{
    // set value array based on propertyID
    switch (propertyID) {
        case kFilterAny:
		case kFilterNone:
            currentArray = nil;
            break;
        case kFilterDirection:
            currentArray = [valueDictionary objectForKey:PID_direction];
            break;
        case kFilterInterface:
            currentArray = [valueDictionary objectForKey:PID_interface];
            break;
        case kFilterSourceMACAddress:
        case kFilterDestMACAddress:
            currentArray = [valueDictionary objectForKey:PID_MACAddress];
            break;
        case kFilterSourceNet:
        case kFilterDestNet:
            currentArray = [valueDictionary objectForKey:PID_netNumber];
            break;
        case kFilterProtocol:
            currentArray = [valueDictionary objectForKey:PID_protocol];
            break;            
        case kFilterIPFragmentOffset:
            currentArray = [valueDictionary objectForKey:PID_IPFragmentOffset];
            break;
        case kFilterIPOptions:
            currentArray = [valueDictionary objectForKey:PID_IPOptions];
            break;            
        case kFilterTCPHeaderFlags:
            currentArray = [valueDictionary objectForKey:PID_TCPHeaderFlags];
            break;
        case kFilterTCPOptions:
            currentArray = [valueDictionary objectForKey:PID_TCPOptions];
            break;
        case kFilterSourcePort:
        case kFilterDestPort:
            currentArray = [valueDictionary objectForKey:PID_portNumber];
            break;
        case kFilterInclude:
            currentArray = [valueDictionary objectForKey:PID_include];
            break;
        case kFilterDataContent:
            currentArray = [valueDictionary objectForKey:PID_dataContent];
            break;
        case kFilterURLKeyword:
            currentArray = [valueDictionary objectForKey:PID_URLKeyword];
            break;
        case kFilterTimeOfDay:
            currentArray = [valueDictionary objectForKey:PID_timeOfDay];
            break;
        case kFilterDayOfWeek:
            currentArray = [valueDictionary objectForKey:PID_dayOfWeek];
            break;
        case kFilterDateAndTime:
			// Update current time
			[valueDictionary setObject:[NSArray arrayWithObjects:
				[[NSDate psDate] description],
				nil] forKey:PID_dateAndTime];
            currentArray = [valueDictionary objectForKey:PID_dateAndTime];
            break;
        case kFilterIdleSeconds:
		case kFilterParentIdleSeconds:
        case kFilterParentMatchCount:
		case kFilterParentMatchRate:
            currentArray = nil;
            break;
        case kFilterICMPType:
            currentArray = [valueDictionary objectForKey:PID_ICMPType];
            break;
        case kFilterICMPCode:
            currentArray = [valueDictionary objectForKey:PID_ICMPCode];
            break;
    }
    return currentArray;
}


// =================================================================================
// save and restore values for current property
// =================================================================================
- (void)saveWithKey:(NSString *)key {
    [[[AppDelegate sharedInstance] prefs] setObject:currentArray forKey:key];
}

- (void)restoreWithKey:(NSString *)key {
    NSMutableArray* theArray;
    theArray = [[[AppDelegate sharedInstance] prefs] objectForKey:key];
    if (theArray != nil) {
        [self addObjects:theArray];
    }
}

// =================================================================================
// access
// =================================================================================
// ---------------------------------------------------------------------------------
// ¥ addObject:
// ---------------------------------------------------------------------------------
// add an object to the current array
// return its row index;
- (int)addObject:(NSString *)entry {
    if ((entry != nil) && [entry length]) {
        [self removeObject:entry];		// remove any duplicates
        if ([self count] >= ListSize-1) [self removeObjectAtIndex:ListSize-1];
        [currentArray insertObject:entry atIndex: 0];
    }
    return 0;
}

// ---------------------------------------------------------------------------------
// ¥ addObjects:
// ---------------------------------------------------------------------------------
- (void)addObjects:(NSArray *)theArray
{
    // add from last to first since new objects are inserted at front
    int count, i;
    count = [theArray count];
    for (i=count-1; i>=0; i--) {
        [self addObject:[theArray objectAtIndex:i]];
    }

}

// ---------------------------------------------------------------------------------
// ¥ removeObject:
// ---------------------------------------------------------------------------------
// remove object, return true if any removed
- (BOOL)removeObject:(NSString *)inEntry {
    int count, index;
    NSString* entry;
    BOOL result = NO;
    // walk the list to find matching object
    count = [self count];
    for (index=count-1; index>=0; index--) {
        entry = [self objectAtIndex:index];
        if ([entry isEqualTo:inEntry]) {
            result = [self removeObjectAtIndex:index];
        }
    }
    return result;
}

// ---------------------------------------------------------------------------------
// ¥ removeObjectAtIndex:
// ---------------------------------------------------------------------------------
- (BOOL)removeObjectAtIndex:(int)index
{
    int count;
    BOOL result = NO;
    count = [currentArray count];
    if (index < count) {
        [currentArray removeObjectAtIndex:index];
        result = YES;
    }
    return result;
}

// ---------------------------------------------------------------------------------
// ¥ objectAtIndex:
// ---------------------------------------------------------------------------------
// get object value from current array for specified index.
// Return nil if row is beyond end of array.
- (NSString *)objectAtIndex:(int)index {
    NSString *result=nil;
    int count;
    
    count = [currentArray count];    
    if (index < count) result = [currentArray objectAtIndex:index];
    return result;
}

// ---------------------------------------------------------------------------------
// ¥ replaceObjectAtIndex:withObject:
// ---------------------------------------------------------------------------------
- (BOOL)replaceObjectAtIndex:(int)index withObject:(NSString *)entry {
    int count;
    BOOL result=NO;
    count = [currentArray count];
    if (index < count) {
        [currentArray replaceObjectAtIndex:index withObject:entry];
        result = YES;
    }
    return result;
}

// ---------------------------------------------------------------------------------
// ¥ count:
// ---------------------------------------------------------------------------------
- (unsigned)count {
    int result = 0;
    if (currentArray) result = [currentArray count];
    return result;
}

#pragma mark -- NSComboBoxCell DataSource --
// ---------------------------------------------------------------------------------
// ¥ numberOfItemsInComboBox:
// ---------------------------------------------------------------------------------
//- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
- (int)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBox {
    return [self count];
}
// ---------------------------------------------------------------------------------
// ¥ comboBox:objectValueForItemAtIndex:
// ---------------------------------------------------------------------------------
//- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index {
- (id)comboBoxCell:(NSComboBoxCell *)aComboBox objectValueForItemAtIndex:(int)index {
    NSString* result = nil;
    result = [self objectAtIndex:index];
    return result;
}
// ---------------------------------------------------------------------------------
// ¥ comboBox:indexOfItemWithStringValue:
// ---------------------------------------------------------------------------------
//- (unsigned int)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)string {
- (unsigned int)comboBoxCell:(NSComboBoxCell *)aComboBox indexOfItemWithStringValue:(NSString *)string {
    int count, index;
    NSString* entry;
    // walk the list to find matching object
    count = [self count];
    for (index=0; index<count; index++) {
        entry = [self objectAtIndex:index];
        if ([entry isEqualTo:string]) break;
    }
    return index;
}
// ---------------------------------------------------------------------------------
// ¥ comboBox:completedString:
// ---------------------------------------------------------------------------------
//- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)string {
- (NSString *)comboBoxCell:(NSComboBoxCell *)aComboBox completedString:(NSString *)string {
    NSString* result=nil;
    NSRange r;	// location, length
    int count, index, bestL;
    NSString* entry;
    // walk the list to find longest match
    bestL = 0;
    count = [self count];
    for (index=0; index<count; index++) {
        entry = [self objectAtIndex:index];
        r = [entry rangeOfString:string options:NSAnchoredSearch];
        if (r.length > bestL) {
            bestL = r.length;
            result = entry;
        }
    }
    return result;
}

@end
