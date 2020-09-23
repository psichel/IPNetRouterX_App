//
// BasicSetup.m
// IPNetSentryX
//
// Created by Peter Sichel on 9/20/05.
// Copyright (c) 2005 Sustainable Softworks. All rights reserved.
//
//	Drive basic setup view of firewall configuration

#import "BasicSetupWC.h"
#import "PSSharedDictionary.h"
#import "PSSupport.h"
#import "DocumentSupport.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "PSArrayTable.h"
#import "PSStateEntry.h"
#import "NameEntry.h"
#import "InterfaceTable.h"
#import "InterfaceEntry.h"
#import "FilterStyleTable.h"
#import "ServiceTable.h"
#import "DeviceTable.h"
#import "FilterStyles.h"
#import "FirewallOptions.h"
#import "MenuDispatch.h"
#import "SystemConfiguration.h"
#import "HardwareAddress.h"
#import "PSEthernetDictionary.h"
#import "SentryController.h"

@interface BasicSetupWC (PrivateMethods)
- (void)setupFirewallSettings;
- (void)setupInterfaceSettings;
- (void)setupFilterStyles;
- (void)setupFilterTypes;
- (void)filterStyleSelect:(id)sender;
- (void)filterTypeSelect:(id)sender;
- (void)setupServices;
- (void)setupDevices;
- (void)deviceSelect:(id)sender;
- (void)setupFirewallOptions;

- (NSString *)myStatus;
- (void)setMyStatus:(NSString *)value;
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;
@end


@implementation BasicSetupWC
- init
{
    if (self = [super init]) {
        // initialize instance vars
		myStatus = nil;
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	[myStatus release];	myStatus = nil;
    [super dealloc];
}

#pragma mark -- NSWindowController --
// ---------------------------------------------------------------------------------
//	� awakeFromNib
// ---------------------------------------------------------------------------------
- (void)awakeFromNib {
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	
	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
//		[failoverLocation1 setEnabled:YES];
//		[failoverLocation2 setEnabled:YES];
	}
	else {
//		[failoverLocation1 setEnabled:NO];
//		[failoverLocation2 setEnabled:NO];
	}
	// init my instance variables
	myStatus = nil;
	
	// setup to receive messages from SentryState and SentryController
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	[sentryState addObserver:self withSelector:@selector(receiveNotification:)];
	[[NKEController sharedInstance] addObserver:self withSelector:@selector(receiveNotification:)];
	// load window
	[self setupFirewallSettings];
	[self setupInterfaceSettings];
	[self setupFilterStyles];
	[self setupFilterTypes];
	[self setupServices];
	[self setupDevices];
	[self setupFirewallOptions];
	// apply button
	if ([[sentryState applyPending] intValue]) [firewallApply setEnabled:YES];
	else [firewallApply setEnabled:NO];
	// firewall state
	[self updateParameter:SS_firewallOn withObject:[sentryState firewallOn]];
}

// ---------------------------------------------------------------------------------
//	� setupFirewallSettings
// ---------------------------------------------------------------------------------
- (void)setupFirewallSettings
{
	PSArrayTable* ds;
	NameEntry* entry;
	ds = [firewallSettingTableView dataSource];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Interfaces" forKey:@"title"];
	[entry setValue:@"interfaces" forKey:@"identifier"];
	[ds addObject:entry];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Filter Styles" forKey:@"title"];
	[entry setValue:@"filterStyles" forKey:@"identifier"];
	[ds addObject:entry];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Services" forKey:@"title"];
	[entry setValue:@"services" forKey:@"identifier"];
	[ds addObject:entry];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Devices" forKey:@"title"];
	[entry setValue:@"devices" forKey:@"identifier"];
	[ds addObject:entry];

	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Options" forKey:@"title"];
	[entry setValue:@"options" forKey:@"identifier"];
	[ds addObject:entry];
	
	[firewallSettingTableView reloadData];
}
// ---------------------------------------------------------------------------------
//	� setupInterfaceSettings
// ---------------------------------------------------------------------------------
- (void)setupInterfaceSettings
{
	NSArray* interfaceArray;
	NSEnumerator* en;
	InterfaceEntry* interfaceE;
	NSString* title;
	
	// build interfaceSelect menu
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
	[interfaceSelect removeAllItems];
	unichar dot = 0x2022;
	title = [NSString stringWithFormat:@"%C %@",dot,NSLocalizedString(@"Automatic",@"Automatic")];
	[interfaceSelect addItemWithTitle:title];
	title = [NSString stringWithFormat:@"%C %@",dot,NSLocalizedString(@"Use Expert View",@"Use Expert View")];
	[interfaceSelect addItemWithTitle:title];
	en = [interfaceArray objectEnumerator];
	while (interfaceE = [en nextObject]) {
		title = [interfaceE interfaceName];
		if (![title hasPrefix:@"Loopback"])
			[interfaceSelect addItemWithTitle:title];
	}
	// find current setting if any
	title = [sentryState basicInterfaceSelect];
	if (title) [interfaceSelect selectItemWithTitle:title];
	else {	// otherwise use "automatic"
		[interfaceSelect selectItemAtIndex:0];
		[self interfaceSelect:nil];
	}
}

// ---------------------------------------------------------------------------------
//	� setupFilterStyles
// ---------------------------------------------------------------------------------
- (void)setupFilterStyles
{
	FilterStyleEntry* filterStyleE;
	// use currently applied state
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	FilterStyleTable* filterStyleT = [sentryState filterStyleTable];
	[filterStyleTableView setDataSource:filterStyleT];
		
	// load template settings
	NSDictionary* stylesDictionary = [[FilterStyles sharedInstance] stylesDictionary];
	NSArray* keyArray = [stylesDictionary allKeys];
	// sort option names
	NSArray *sortedArray = [keyArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator* en = [sortedArray objectEnumerator];
	NSString* key;
	
	while (key = [en nextObject]) {
		filterStyleE = [[[FilterStyleEntry alloc] init] autorelease];
		[filterStyleE setNodeDictionary:[stylesDictionary objectForKey:key]];
		[filterStyleT addObject:filterStyleE];
	}
	[filterStyleTableView reloadData];
}


// ---------------------------------------------------------------------------------
//	� setupFilterTypes
// ---------------------------------------------------------------------------------
- (void)setupFilterTypes
{
	PSArrayTable* ds;
	NameEntry* entry;
	ds = [filterTypeTableView dataSource];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Blacklist" forKey:@"title"];
	[entry setValue:@"blacklist" forKey:@"identifier"];
	[ds addObject:entry];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Deny" forKey:@"title"];
	[entry setValue:@"denyAccess" forKey:@"identifier"];
	[ds addObject:entry];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Deny by address" forKey:@"title"];
	[entry setValue:@"denyByAddress" forKey:@"identifier"];
	[ds addObject:entry];
	
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Deny by content" forKey:@"title"];
	[entry setValue:@"denyByContent" forKey:@"identifier"];
	[ds addObject:entry];

	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Allow by address" forKey:@"title"];
	[entry setValue:@"allowByAddress" forKey:@"identifier"];
	[ds addObject:entry];

	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Allow by time" forKey:@"title"];
	[entry setValue:@"allowByTime" forKey:@"identifier"];
	[ds addObject:entry];

	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Reserve Bandwidth" forKey:@"title"];
	[entry setValue:@"reserveBandwidth" forKey:@"identifier"];
	[ds addObject:entry];

	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Limit Bandwidth" forKey:@"title"];
	[entry setValue:@"limitBandwidth" forKey:@"identifier"];
	[ds addObject:entry];

	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Notification" forKey:@"title"];
	[entry setValue:@"notification" forKey:@"identifier"];
	[ds addObject:entry];

	entry = [[[NameEntry alloc] init] autorelease];
	[entry setValue:@"Allow" forKey:@"title"];
	[entry setValue:@"allowAccess" forKey:@"identifier"];
	[ds addObject:entry];
	
	[filterTypeTableView reloadData];
	// set initial filter style tab view
	[filterStyleTableView selectRow:0 byExtendingSelection:NO];
	[self filterStyleSelect:self];
}

// ---------------------------------------------------------------------------------
//	� setupServices
// ---------------------------------------------------------------------------------
- (void)setupServices
{
	// use currently applied state
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	[serviceTableView setDataSource:[sentryState serviceTable]];
	// setup table cells for editing
	NSTableColumn* tableColumn;
		// services filterStyle
    tableColumn = [serviceTableView tableColumnWithIdentifier:DE_filterStyle];
	NSPopUpButtonCell* filterStyle = [tableColumn dataCell];
	[filterStyle removeAllItems];
	FilterStyleEntry* filterStyleE;
	NSArray* styleArray = [[sentryState filterStyleTable] tableArray];
	NSEnumerator* en = [styleArray objectEnumerator];
	while (filterStyleE = [en nextObject]) {
		[filterStyle addItemWithTitle:[filterStyleE title]];
	}
}

// ---------------------------------------------------------------------------------
//	� setupDevices
// ---------------------------------------------------------------------------------
- (void)setupDevices
{
	// use currently applied state
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	[deviceTableView setDataSource:[sentryState deviceTable]];
	[deviceEditTableView setDataSource:[sentryState deviceTable]];
	// setup table cells for editing
	NSTableColumn* tableColumn;
		// device filterStyle
    tableColumn = [deviceTableView tableColumnWithIdentifier:DE_filterStyle];
	NSPopUpButtonCell* filterStyle = [tableColumn dataCell];
	[filterStyle removeAllItems];
	FilterStyleEntry* filterStyleE;
	NSArray* styleArray = [[sentryState filterStyleTable] tableArray];
	NSEnumerator* en = [styleArray objectEnumerator];
	while (filterStyleE = [en nextObject]) {
		[filterStyle addItemWithTitle:[filterStyleE title]];
	}

	// load devicePort menu
	[devicePort removeAllItems];
	NSArray* interfaceTitles = [[SystemConfiguration sharedInstance] bsdTitlesAndServiceIDs:nil];
	if ([interfaceTitles count] == 0) {
		[devicePort addItemWithTitle:@"No configured interfaces"];
	}
	else {
		[devicePort addItemsWithTitles:interfaceTitles];
	}
	// try to get default router for IP address
	do {
		NSString* bsdName = bsdNameForTitle([sentryState basicInterfaceUsing]);
		if (!bsdName) break;
//		InterfaceEntry* interfaceE = [[InterfaceTable sharedInstance] entryForInterfaceID:bsdName];
//		NSString* addressString = [interfaceE defaultGateway];
//		if (!addressString) break;
//		[deviceIPAddress setStringValue:addressString];
	} while (false);
	
}

// ---------------------------------------------------------------------------------
//	� setupFirewallOptions
// ---------------------------------------------------------------------------------
- (void)setupFirewallOptions
{
	NSDictionary* optionsDictionary = [[FirewallOptions sharedInstance] optionsDictionary];
	NSArray* keyArray = [optionsDictionary allKeys];
	// sort option names
	NSArray *sortedArray = [keyArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSEnumerator* en = [sortedArray objectEnumerator];
	NSString* key;
	NSDictionary* optionD;
	
	[optionSelect removeAllItems];
	while (key = [en nextObject]) {
		optionD = [optionsDictionary objectForKey:key];
		// add only if supported
		#if IPNetRouter
			if ([[optionD objectForKey:kOptionProduct] isEqualTo:kOptionProduct_ipnr])
				[optionSelect addItemWithTitle:key];
		#endif
		if ([[optionD objectForKey:kOptionProduct] isEqualTo:kOptionProduct_ipns])
			[optionSelect addItemWithTitle:key];
	}
	[self optionSelect:nil];
}

// ---------------------------------------------------------------------------------
//	� windowWillClose
// ---------------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
	
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kBasicSetupName];
 	// release ourself
    [self autorelease];
}

#pragma mark -- delegate Actions --

// ---------------------------------------------------------------------------------
//	� tableViewSelectionDidChange
// ---------------------------------------------------------------------------------
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSTableView* tableView = [aNotification object];
	// firewall setting selection did change
	if (tableView == firewallSettingTableView) {
		// select firewall setting
		PSArrayTable* ds = [firewallSettingTableView dataSource];
		NameEntry* entry = [ds objectAtIndex:[firewallSettingTableView selectedRow]];
		[firewallSettingTabView selectTabViewItemWithIdentifier:[entry identifier]];
	}
	if (tableView == filterStyleTableView) {
		// select device
		[self filterStyleSelect:nil];
	}
	if (tableView == filterTypeTableView) {
		// select device
		[self filterTypeSelect:nil];
	}
	if (tableView == deviceEditTableView) {
		// select device
		[self deviceSelect:nil];
	}
}

// ---------------------------------------------------------------------------------
//	� filterStyleSelect
// ---------------------------------------------------------------------------------
- (void)filterStyleSelect:(id)sender
{
	FilterStyleTable* filterStyleTable = [filterStyleTableView dataSource];
	int row = [filterStyleTableView selectedRow];
	if (row >= 0) {
		FilterStyleEntry* filterStyleEntry = [filterStyleTable objectAtIndex:row];
		NSString* type = [filterStyleEntry type];
		// show corresponding tab view
		[filterStyleTabView selectTabViewItemWithIdentifier:type];
		// select corresponding row in FilterTypeTable
			// walk the table so we're not position sensitive
			// tabviews do need to match table entries one-to-one
		int count, row;
		NameEntry* entry;
		PSArrayTable* filterTypeTable = [filterTypeTableView dataSource];
		count = [filterTypeTable count];
		for (row=0; row<count; row++) {
			 entry = [filterTypeTable objectAtIndex:row];
			 if ([[entry identifier] isEqualTo:type]) {
				[filterTypeTableView selectRow:row byExtendingSelection:NO];
				break;
			 }
		}
		
//		[filterTypeTableView selectRow:
//			[filterStyleTabView indexOfTabViewItem:[filterStyleTabView selectedTabViewItem]]
//			byExtendingSelection:NO];
	}
}

// ---------------------------------------------------------------------------------
//	� filterTypeSelect
// ---------------------------------------------------------------------------------
- (void)filterTypeSelect:(id)sender
{
	int row = [filterTypeTableView selectedRow];
	if (row >= 0) {
		//[filterStyleTabView selectTabViewItemAtIndex:row];
		PSArrayTable* filterTypeTable = [filterTypeTableView dataSource];
		NameEntry* entry = [filterTypeTable objectAtIndex:row];
		[filterStyleTabView selectTabViewItemWithIdentifier:[entry identifier]];
	}
}

// ---------------------------------------------------------------------------------
//	� deviceSelect
// ---------------------------------------------------------------------------------
- (void)deviceSelect:(id)sender
{
	NSString *str;
	DeviceTable* deviceTable = [deviceEditTableView dataSource];
	int row = [deviceEditTableView selectedRow];
	if (row >= 0) {
		DeviceEntry* deviceEntry = [deviceTable objectAtIndex:row];
		// show corresponding tab view
		[deviceTabView selectTabViewItemWithIdentifier:[deviceEntry type]];
		// direction
		NSNumber* num = [deviceEntry direction];
		if (!num) num = [NSNumber numberWithInt:0];
		[deviceDirectionPort setObjectValue:num];
		[deviceDirectionAttached setObjectValue:num];
		// networkPort
		str = [deviceEntry portName];
		if (str) [devicePort selectItemWithTitle:str];
		// hwAddress
		str = [deviceEntry hwAddress];
		if (!str) str = @"";
		[deviceHardwareAddress setStringValue:str];
	}
}

// ---------------------------------------------------------------------------------
//	� tabView:didSelectTabViewItem:
// ---------------------------------------------------------------------------------
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if (tabView == deviceTabView) {
		DeviceTable* deviceTable = [deviceEditTableView dataSource];
		int row = [deviceEditTableView selectedRow];
		if (row >= 0) {
			DeviceEntry* deviceEntry = [deviceTable objectAtIndex:row];
			[deviceEntry setType:[tabViewItem identifier]];
		}
	}
}


#pragma mark -- logistics --
- (NSString *)myStatus { return myStatus; }
- (void)setMyStatus:(NSString *)value
{
	[value retain];
	[myStatus release];
	myStatus = value;
	// provide simplified status
	if ([myStatus length] == 0) {
		[statusInfo setStringValue:@""];
	}
	else {
		NSRange range = [myStatus rangeOfString:@"failed"];
		if (range.length) {
			[statusInfo setStringValue:NSLocalizedString(@"operation failed",@"operation failed")];
		}
		else [statusInfo setStringValue:NSLocalizedString(@"OK",@"OK")];
	}
}
- (void)saveState
{
}

- (void)showDocument
{

}

// ---------------------------------------------------------------------------
//	� receiveNotification
// ---------------------------------------------------------------------------
// Receive notification from SentryState when model state changes
// Update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
- (void)receiveNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;
	NSEnumerator* enumerator;
	NSString* name;
    id key;
    id object;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	do {    
		name = [aNotification name];
		if ([name isEqualTo:NSWindowWillCloseNotification]) {
			[self windowWillClose:aNotification];
			break;
		}

		dictionary = [aNotification userInfo];
		enumerator = [dictionary keyEnumerator];

		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			object = [dictionary objectForKey:key];
			// use key as the name of a class or instance and set its value
			[self updateParameter:key withObject:object];
		}	// while ((key = [enumerator nextObject]))
	} while (false);
    [pool release];
}

// ---------------------------------------------------------------------------------
//	� updateParameter
// ---------------------------------------------------------------------------------
// Update named parameter with value passed as object
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
	BOOL returnValue = YES;
	do {
		// use status for basic setup indicators
		// status
		if ([name isEqualTo:@"statusInfo"])	{
			//[statusInfo setStringValue:anObject];
			[self setMyStatus:anObject];
			break;
		}
		if ([name isEqualTo:@"statusInfoAppend"]) {
			NSRange range;
			// ignore ppp0 errors here
			range = [anObject rangeOfString:@"ppp0"];
			if (!range.length) {
				NSString* str;
				//str = [[statusInfo stringValue] stringByAppendingString:anObject];
				//[statusInfo setStringValue:str];
				if (!myStatus) [self setMyStatus:@""];
				str = [myStatus stringByAppendingString:anObject];
				[self setMyStatus:str];
			}
			break;
		}
		// applyPending
		if ([name isEqualTo:SS_applyPending]) {
			if ([anObject intValue]) [firewallApply setEnabled:YES];
			else [firewallApply setEnabled:NO];
			break;
		}
		// basicInterfaceSelect
		if ([name isEqualTo:SS_basicInterfaceSelect]) {
			[interfaceSelect selectItemWithTitle:anObject];
			break;
		}
		// basicInterfaceUsing
		if ([name isEqualTo:SS_basicInterfaceUsing]) {
			[interfaceUsing setStringValue:anObject];
			break;
		}
		// firewallOn
		if ([name isEqualTo:SS_firewallOn]) {
			if ([anObject intValue]) {
				// on
				[firewallStart setTitle:NSLocalizedString(@"Stop",@"Stop")];
				[firewallStatus setStringValue:NSLocalizedString(@"Firewall On",@"Firewall On")];
			}
			else {
				// off
				[firewallStart setTitle:NSLocalizedString(@"Start",@"Start")];
				[firewallStatus setStringValue:NSLocalizedString(@"Firewall Off",@"Firewall Off")];
			}
			break;
		}
		// blockIPv6
		if ([name isEqualTo:SS_blockIPv6]) {
			[self optionSelect:nil];
			break;
		}
		// connectionLogging
		if ([name isEqualTo:SS_connectionLogging]) {
			[self optionSelect:nil];
			break;
		}
		// disableAlerts
		if ([name isEqualTo:kPreferences_disableAlerts]) {
			[self optionSelect:nil];
			break;
		}
		// automaticFailover
		if ([name isEqualTo:SS_automaticFailover]) {
			[self optionSelect:nil];
			break;
		}
		// loadBalance
		if ([name isEqualTo:SS_loadBalance]) {
			[self optionSelect:nil];
			break;
		}
		// sourceAwareRouting
		if ([name isEqualTo:SS_sourceAwareRouting]) {
			[self optionSelect:nil];
			break;
		}
	#if 0
		// triggerDuration
		if ([name isEqualTo:@"triggerDuration"]) {
			[triggerDefaultDuration setObjectValue:anObject];
			break;
		}
	#endif			
	
	//#if IPNetRouter
	#if 0
		// ipForwarding
		if ([name isEqualTo:SS_ipForwarding]) {
			[ipForwarding setObjectValue:anObject];
			break;
		}
		// SS_excludeNet
		if ([name isEqualTo:SS_excludeNet]) {
			[excludeNetField setStringValue:[sentryState excludeNet]];
			break;
		}
		if ([name isEqualTo:SS_exposedHost]) {
			[exposedHostField setStringValue:[sentryState exposedHost]];
			break;
		}
		if ([name isEqualTo:SS_exposedHostSelection]) {
			[exposedHostPopUp setObjectValue:[sentryState exposedHostSelection]];
			if ([exposedHostPopUp indexOfSelectedItem] == 1) {
				[exposedHostField setEnabled:YES];
			} else {
				[exposedHostField setEnabled:NO];
			}
			break;
		}		
		// portMapLogging
		if ([name isEqualTo:SS_portMapLogging]) {
			[portMapLogging setObjectValue:anObject];
			break;
		}
		// unregisteredOnly
		if ([name isEqualTo:SS_unregisteredOnly]) {
			[unregisteredOnly setObjectValue:anObject];
			break;
		}
		// SS_portMapTable
		if ([name isEqualTo:SS_portMapTable]) {
			[portMapTableView reloadData];
			break;
		}
		// unknown parameter
		returnValue = NO;
	#endif
	} while (false);
	return returnValue;
}

#pragma mark -- IB Actions --
- (IBAction)allowByAddressDelete:(id)sender
{
}

- (IBAction)allowByAddressEdit:(id)sender
{
}

- (IBAction)allowByAddressNew:(id)sender
{
}

- (IBAction)denyByAddressDelete:(id)sender
{
}

- (IBAction)denyByAddressEdit:(id)sender
{
}

- (IBAction)denyByAddressNew:(id)sender
{
}

#pragma mark --- device ---
// ---------------------------------------------------------------------------------
//	� deviceAdd
// ---------------------------------------------------------------------------------
- (IBAction)deviceAdd:(id)sender
{
}
// ---------------------------------------------------------------------------------
//	� devicRemove
// ---------------------------------------------------------------------------------
- (IBAction)deviceRemove:(id)sender
{
}
// ---------------------------------------------------------------------------------
//	� deviceEdit
// ---------------------------------------------------------------------------------
- (IBAction)deviceEdit:(id)sender
{
	[firewallSettingTabView selectTabViewItemWithIdentifier:kFirewallTab_devicesEdit];
	[deviceEditTableView reloadData];
}

- (IBAction)deviceEditAdd:(id)sender
{
	DeviceTable *deviceTable = [deviceEditTableView dataSource];
	DeviceEntry *deviceEntry;
	int row = [deviceEditTableView selectedRow];
	// use currently applied state
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	deviceEntry = [[[DeviceEntry alloc] init] autorelease];
	[deviceEntry setTitle:@"untitled"];
	[deviceEntry setType:DE_typeNetworkPort];
	[deviceEntry setPortName:[sentryState basicInterfaceUsing]];
	if (row >= 0) {
		[deviceTable insertObject:deviceEntry atIndex:row+1];
		[deviceEditTableView reloadData];
		[deviceEditTableView selectRow:row+1 byExtendingSelection:NO];
	}
	else {
		[deviceTable addObject:deviceEntry];
		[deviceEditTableView reloadData];
		[deviceEditTableView selectRow:[deviceTable count]-1 byExtendingSelection:NO];
	}
}

- (IBAction)deviceEditRemove:(id)sender
{
	DeviceTable* deviceT;
	DeviceEntry* deviceE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	
	deviceT = [deviceEditTableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[deviceT count]];
	// gather entries to be deleted before altering indexes
	en = [deviceEditTableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[deviceT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (deviceE = [en nextObject]) [deviceT removeObject:deviceE];
	// refresh tableView
	[deviceEditTableView deselectAll:sender];
	[deviceEditTableView reloadData];
	// use currently applied state
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
}
// ---------------------------------------------------------------------------------
//	� deviceEditDone
// ---------------------------------------------------------------------------------
- (IBAction)deviceEditDone:(id)sender
{
	[firewallSettingTabView selectTabViewItemWithIdentifier:kFirewallTab_devices];
	[deviceTableView reloadData];
}

// ---------------------------------------------------------------------------------
//	� deviceDirection
// ---------------------------------------------------------------------------------
- (IBAction)deviceDirection:(id)sender
{
	// get selected device entry if any
	DeviceTable* deviceTable = [deviceEditTableView dataSource];
	int row = [deviceEditTableView selectedRow];
	if (row >= 0) {
		DeviceEntry* deviceEntry = [deviceTable objectAtIndex:row];
		if ([[[deviceTabView selectedTabViewItem] identifier] isEqualTo:DE_typeNetworkPort])
			[deviceEntry setDirection:[deviceDirectionPort objectValue]];
		else
			[deviceEntry setDirection:[deviceDirectionAttached objectValue]];
	}
}

// ---------------------------------------------------------------------------------
//	� deviceLookup
// ---------------------------------------------------------------------------------
- (IBAction)deviceLookup:(id)sender
{
	NSString* ipAddress;
	NSString* macAddress = nil;
	NSString* org;
	ipAddress = [deviceIPAddress stringValue];
	if (ipAddress) {
		macAddress = hwAddressStringForIPString(ipAddress);
		if (macAddress) {
			[deviceHardwareAddress setStringValue:macAddress];				
			org = [[PSEthernetDictionary sharedInstance] orgForEthernetAddress:macAddress];
			if (org) [deviceVendor setStringValue:org];
			// get selected device entry if any
			DeviceTable* deviceTable = [deviceEditTableView dataSource];
			int row = [deviceEditTableView selectedRow];
			if (row >= 0) {
				DeviceEntry* deviceEntry = [deviceTable objectAtIndex:row];
				[deviceEntry setHwAddress:macAddress];
			}
		}
	}
}

// ---------------------------------------------------------------------------------
//	� devicePort
// ---------------------------------------------------------------------------------
- (IBAction)devicePort:(id)sender
{
	// get selected device entry if any
	DeviceTable* deviceTable = [deviceEditTableView dataSource];
	int row = [deviceEditTableView selectedRow];
	if (row >= 0) {
		DeviceEntry* deviceEntry = [deviceTable objectAtIndex:row];
		[deviceEntry setPortName:[[devicePort selectedItem] title]];
		[deviceEntry setTitle:[[devicePort selectedItem] title]];
		[deviceEditTableView reloadData];
	}
}
// ---------------------------------------------------------------------------------
//	� deviceHardwareAddress
// ---------------------------------------------------------------------------------
- (IBAction)deviceHardwareAddress:(id)sender
{
	// get selected device entry if any
	DeviceTable* deviceTable = [deviceEditTableView dataSource];
	int row = [deviceEditTableView selectedRow];
	if (row >= 0) {
		DeviceEntry* deviceEntry = [deviceTable objectAtIndex:row];
		[deviceEntry setHwAddress:[deviceHardwareAddress stringValue]];
	}
}

- (IBAction)deviceConfigure:(id)sender
{
}

#pragma mark --- filter style ---
// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)filterStyleConfigure:(id)sender
{
}

- (IBAction)filterStyleEdit:(id)sender
{
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)firewallApply:(id)sender
{
	// use currently applied state
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// clear previous status if any
	[statusInfo setStringValue:@""];
	// use our document settings
//	[[DocumentSupport sharedInstance] setSentryState:sentryState];
	[[DocumentSupport sharedInstance] invokeDocumentFirewall];
	// apply no longer pending (mark in [SentryModel -apply])
	[sentryState setApplyPending:[NSNumber numberWithInt:0]];
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)firewallShowActive:(id)sender
{
	// use currently applied state
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	// clear previous status if any
	[statusInfo setStringValue:@""];
	// invoke action
		// For consistency SentryDocument only calls out to SentryState.
		// SentryModel responds to notifications from SentryState allowing
		// other observers to respond as well.
	[sentryState updateParameter:SA_showActive withObject:self];
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)firewallStart:(id)sender
{
	NSNumber* num;
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	[statusInfo setStringValue:@""];
	num = [sentryState firewallOn];
	if ([num intValue]) num = [NSNumber numberWithInt:0];
	else num = [NSNumber numberWithInt:1];
	[sentryState setFirewallOn:num];
}

// ---------------------------------------------------------------------------------
//	� interfaceSelect
// ---------------------------------------------------------------------------------
- (IBAction)interfaceSelect:(id)sender
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	NSArray* interfaceArray;
	NSEnumerator* en;
	InterfaceEntry* interfaceE;
	NSString* title;
	NSString* interfaceID = nil;
	do {
		int index = [interfaceSelect indexOfSelectedItem];
		title = [[interfaceSelect selectedItem] title];
		if (index == 1) { // use Expert Settings - ignore
			[sentryState setBasicInterfaceUsing:@""];
			break;
		}
		if (index == 0) {	// automatic
			interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
			en = [interfaceArray objectEnumerator];
			while (interfaceE = [en nextObject]) {
				if (![[interfaceE ifNet] isEqualTo:kSCNotAvailable]) {
					title = [interfaceE interfaceName];
					interfaceID = [interfaceE interfaceID];
					[sentryState setBasicInterfaceUsing:title];
					//[interfaceUsing setStringValue:[NSString stringWithFormat:@"Using: %@",title]];
					break;
				}
			}
		}
		else {
			[sentryState setBasicInterfaceUsing:@""];
			//[interfaceUsing setStringValue:@""];
			interfaceID = interfaceIDForTitle(title);
			//interfaceE = [[InterfaceTable sharedInstance] entryForInterfaceID:interfaceID];
		}
		if (interfaceID) {
			// unmark other interfaces
			interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
			en = [interfaceArray objectEnumerator];
			while (interfaceE = [en nextObject]) {
				if ([interfaceID isEqualTo:[interfaceE interfaceID]]) {
					[interfaceE setExternalOn:[NSNumber numberWithInt:1]];
					[interfaceE setFilterOn:[NSNumber numberWithInt:1]];
				} else {
					[interfaceE setExternalOn:[NSNumber numberWithInt:0]];
					[interfaceE setFilterOn:[NSNumber numberWithInt:0]];
				}
				
			}
			// update model
			[sentryState updateParameter:SS_interfaceTable withObject:SS_interfaceTable];
		}
	} while (false);
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)limitBandwidthInStep:(id)sender
{
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)limitBandwidthOutStep:(id)sender
{
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)myHelp:(id)sender
{
    NSString *filePath;
	NSURL *fileURL;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	NSString* tabID;
	NSString* document = nil;

	tabID = [[firewallSettingTabView selectedTabViewItem] identifier];
		 if ([tabID isEqualTo:@"interfaces"])	document = @"FirewallDocument";
	else if ([tabID isEqualTo:@"filterStyles"])	document = @"FirewallDocument";
	else if ([tabID isEqualTo:@"services"])		document = @"FirewallDocument";
	else if ([tabID isEqualTo:@"devices"])		document = @"FirewallDocument";
	else if ([tabID isEqualTo:@"options"])		document = @"FirewallDocument";
	
	filePath = [thisBundle pathForResource:document ofType:@"html" inDirectory:PS_HELP_DIRECTORY];
	if (filePath)
		if ((fileURL = [NSURL fileURLWithPath:filePath]))
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)notificationBrowse:(id)sender
{
}

#pragma mark -- firewall options --
// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)optionOn:(id)sender
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	NSNumber* num;
	// get key and option dictionary
	NSString* key = [[optionSelect selectedItem] title];
	NSDictionary* optionsDictionary = [[FirewallOptions sharedInstance] optionsDictionary];
	NSDictionary* optionD = [optionsDictionary objectForKey:key];
	// find option identifier and invoke corresponding setting
	NSString* identifier = [optionD objectForKey:kOptionIdentifier];
	if ([identifier isEqualTo:kOptionIdentifier_blockIPv6]) {
		num = [optionOn objectValue];
		[sentryState setBlockIPv6:num];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_connectionLogging]) {
		num = [optionOn objectValue];
		[sentryState setConnectionLogging:num];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_disableAlerts]) {
		num = [optionOn objectValue];
		[sentryState setDisableAlerts:num];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_automaticFailover]) {
		num = [optionOn objectValue];
		[sentryState setAutomaticFailover:num];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_loadBalance]) {
		num = [optionOn objectValue];
		[sentryState setLoadBalance:num];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_sourceAwareRouting]) {
		num = [optionOn objectValue];
		[sentryState setSourceAwareRouting:num];
	}
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)optionOpenPreferences:(id)sender
{
	[[MenuDispatch sharedInstance] preferencesShowWindow:nil];
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)optionSelect:(id)sender
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	// get key and option dictionary
	NSString* key = [[optionSelect selectedItem] title];
	NSDictionary* optionsDictionary = [[FirewallOptions sharedInstance] optionsDictionary];
	NSDictionary* optionD = [optionsDictionary objectForKey:key];
	// description
	[optionDescription setString:[optionD objectForKey:kOptionDescription]];
	// hide or reveal setting field based on option type
	NSString* type = [optionD objectForKey:kOptionType];
	if ([type isEqualTo:kOptionType_bool]) {
		unhideView(optionOn);
		hideView(optionValue);
	}
	else if ([type isEqualTo:kOptionType_value]) {
		hideView(optionOn);
		unhideView(optionValue);
	}
	// find option identifier and display corresponding setting
	NSString* identifier = [optionD objectForKey:kOptionIdentifier];
	if ([identifier isEqualTo:kOptionIdentifier_blockIPv6]) {
		[optionOn setObjectValue:[sentryState blockIPv6]];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_connectionLogging]) {
		[optionOn setObjectValue:[sentryState connectionLogging]];		
	}
	else if ([identifier isEqualTo:kOptionIdentifier_disableAlerts]) {
		[optionOn setObjectValue:[sentryState disableAlerts]];		
	}
	else if ([identifier isEqualTo:kOptionIdentifier_automaticFailover]) {
		[optionOn setObjectValue:[sentryState automaticFailover]];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_loadBalance]) {
		[optionOn setObjectValue:[sentryState loadBalance]];
	}
	else if ([identifier isEqualTo:kOptionIdentifier_sourceAwareRouting]) {
		[optionOn setObjectValue:[sentryState sourceAwareRouting]];
	}
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)optionValue:(id)sender
{
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)reserveBandwidthInStep:(id)sender
{
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
- (IBAction)reserveBandwidthOutStep:(id)sender
{
}

#pragma mark -- service --
// ---------------------------------------------------------------------------------
//	� serviceAdd
// ---------------------------------------------------------------------------------
- (IBAction)serviceAdd:(id)sender
{
}
// ---------------------------------------------------------------------------------
//	� serviceRemove
// ---------------------------------------------------------------------------------
- (IBAction)serviceRemove:(id)sender
{
}
// ---------------------------------------------------------------------------------
//	� serviceEdit
// ---------------------------------------------------------------------------------
- (IBAction)serviceEdit:(id)sender
{
	[firewallSettingTabView selectTabViewItemWithIdentifier:kFirewallTab_servicesEdit];
	[serviceEditTableView reloadData];
}

// ---------------------------------------------------------------------------------
//	� serviceSortBy
// ---------------------------------------------------------------------------------
- (IBAction)serviceSortBy:(id)sender
{
}

// ---------------------------------------------------------------------------------
//	� serviceEditAdd
// ---------------------------------------------------------------------------------
- (IBAction)serviceEditAdd:(id)sender
{
}
// ---------------------------------------------------------------------------------
//	� serviceRemove
// ---------------------------------------------------------------------------------
- (IBAction)serviceEditRemove:(id)sender
{
}
// ---------------------------------------------------------------------------------
//	� serviceEditDone
// ---------------------------------------------------------------------------------
- (IBAction)serviceEditDone:(id)sender
{
	[firewallSettingTabView selectTabViewItemWithIdentifier:kFirewallTab_services];
	[serviceTableView reloadData];
}

@end

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
