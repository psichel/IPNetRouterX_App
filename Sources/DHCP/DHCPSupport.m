//
//  DHCPSupport.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 7/20/07.
//  Copyright 2007 Sustainable Softworks. All rights reserved.
//
//  Support routines used by both DHCP Server and UI Client

#import "DHCPSupport.h"
#import "AppSupport.h"
#import "DHCPState.h"

// Globals
NSString *DHCPLoggerNotification = @"DHCPLoggerNotification";

// ---------------------------------------------------------------------------------
//	• readDhcpSettings
// ---------------------------------------------------------------------------------
NSDictionary* readDhcpSettings()
{
	NSDictionary* dhcpSaveDictionary = nil;
	NSString* path;
	
	path = [AppSupport appPrefsPath:@"dhcpServerConfig.plist"];

	dhcpSaveDictionary = [NSDictionary dictionaryWithContentsOfFile:path];
	if (dhcpSaveDictionary) {
		// log what we did
		NSLog(@"DHCP Server read settings from: %@",path);
	}
	return dhcpSaveDictionary;
}

// ---------------------------------------------------------------------------------
//	• writeDhcpSettings
// ---------------------------------------------------------------------------------
BOOL writeDhcpSettings(NSDictionary* dhcpStateDictionary)
{
	BOOL returnValue = NO;
	NSString* path;
	
	path = [AppSupport appPrefsPath:@"dhcpServerConfig.plist"];

	returnValue = [dhcpStateDictionary writeToFile:path atomically:YES];
	if (returnValue) {
		NSLog(@"DHCP Server save settings to: %@",path);
	}
	return returnValue;
}


// ---------------------------------------------------------------------------
//	• saveDictionaryForDhcpState
// ---------------------------------------------------------------------------
// convert dhcpState to saveDictionary
NSMutableDictionary* saveDictionaryForDhcpState(DHCPState* dhcpState)
{
	NSMutableDictionary* dhcpDictionary = nil;
	if (dhcpState) {
		id tableDictionary;
		dhcpDictionary = [NSMutableDictionary dictionaryWithDictionary:[dhcpState nodeDictionary]];
		// convert DHCP tables to dictionary form
			[dhcpDictionary removeObjectForKey:DS_statusTable];
		tableDictionary = [[dhcpDictionary objectForKey:DS_staticConfigTable] dictionaryOfDictionaries];
			[dhcpDictionary setObject:tableDictionary forKey:DS_staticConfigTable];
		tableDictionary = [[dhcpDictionary objectForKey:DS_dynamicConfigTable] dictionaryOfDictionaries];
			[dhcpDictionary setObject:tableDictionary forKey:DS_dynamicConfigTable];
		tableDictionary = [[dhcpDictionary objectForKey:DS_leaseOptionsTable] dictionaryOfDictionaries];
			[dhcpDictionary setObject:tableDictionary forKey:DS_leaseOptionsTable];
		tableDictionary = [[dhcpDictionary objectForKey:DS_serverOptionsTable] dictionaryOfDictionaries];
			[dhcpDictionary setObject:tableDictionary forKey:DS_serverOptionsTable];
	}
	return dhcpDictionary;
}

// ---------------------------------------------------------------------------
//	• dhcpStateForSaveDictionary
// ---------------------------------------------------------------------------
// Create a DHCPState object from saveDictionary (read from disk)
DHCPState* dhcpStateForSaveDictionary(NSDictionary* saveDictionary)
{
	DHCPState* myState;
	NSMutableDictionary* dhcpDictionary;
	NSDictionary* tableDictionary;
	id table;

	dhcpDictionary = [NSMutableDictionary dictionaryWithDictionary:saveDictionary];

	// statusTable
	if (tableDictionary = [dhcpDictionary objectForKey:DS_statusTable]) {
		table = [DHCPStatusTable tableFromDictionary:tableDictionary];
		[dhcpDictionary setObject:table forKey:DS_statusTable];
	}

	// staticConfigTable
	if (tableDictionary = [dhcpDictionary objectForKey:DS_staticConfigTable]) {
		table = [DHCPStaticConfigTable tableFromDictionary:tableDictionary];
		[dhcpDictionary setObject:table forKey:DS_staticConfigTable];
	}
	
	// dynamicConfigTable
	if (tableDictionary = [dhcpDictionary objectForKey:DS_dynamicConfigTable]) {
		table = [DHCPDynamicConfigTable tableFromDictionary:tableDictionary];
		[dhcpDictionary setObject:table forKey:DS_dynamicConfigTable];
	}
	
	// leaseOptionsTable
	if (tableDictionary = [dhcpDictionary objectForKey:DS_leaseOptionsTable]) {
		table = [DHCPLeaseOptionsTable tableFromDictionary:tableDictionary];
		[dhcpDictionary setObject:table forKey:DS_leaseOptionsTable];
	}
	
	// serverOptionsTable
	if (tableDictionary = [dhcpDictionary objectForKey:DS_serverOptionsTable]) {
		table = [DHCPServerOptionsTable tableFromDictionary:tableDictionary];
		[dhcpDictionary setObject:table forKey:DS_serverOptionsTable];
	}

	myState = [[[DHCPState alloc] initWithNodeDictionary:dhcpDictionary] autorelease];
	[myState setRecordChanges:YES];
	
	return myState;
}



// ---------------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------------
