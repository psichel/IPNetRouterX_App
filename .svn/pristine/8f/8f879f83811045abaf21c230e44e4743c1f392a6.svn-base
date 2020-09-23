//
//  HostNamesDS.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 9/25/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//
//	hostNamesTableView Data Source

#import "HostNamesDS.h"
#import "LocalNetworksDS.h"
#import "NameServiceModel.h"
#import "IPSupport.h"

@interface HostNamesDS (PrivateMethods)
- (NSMutableDictionary*)selectedSet;
- (void)setSelectedSet:(NSMutableDictionary*)value;
@end

@implementation HostNamesDS

// ---------------------------------------------------------------------------------
//	• init and dealloc
// ---------------------------------------------------------------------------------
- (id) init {
    if (self = [super init]) {
		// instance vars
		localNetworksTableView = nil;
		hostNamesTableView = nil;
		selectedSet = nil;
		sortedKeys = nil;
    }
    return self;
}

- (void)dealloc {
    [localNetworksTableView release];	localNetworksTableView = nil;
	[hostNamesTableView release];		hostNamesTableView = nil;
	[selectedSet release];				selectedSet = nil;
	[sortedKeys release];				sortedKeys = nil;
	[super dealloc];
}

#pragma mark -- get/set --
// ---------------------------------------------------------------------------------
//	• localNetworksTableView
// ---------------------------------------------------------------------------------
- (NSTableView *)localNetworksTableView { return localNetworksTableView; }
- (void)setLocalNetworksTableView:(NSTableView *) value {
	[value retain];
	[localNetworksTableView release];
	localNetworksTableView = value;
}

// ---------------------------------------------------------------------------------
//	• hostNamesTableView
// ---------------------------------------------------------------------------------
- (NSTableView *)hostNamesTableView { return hostNamesTableView; }
- (void)setHostNamesTableView:(NSTableView *) value {
	[value retain];
	[hostNamesTableView release];
	hostNamesTableView = value;
}

// ---------------------------------------------------------------------------------
//	• sortedKeys
// ---------------------------------------------------------------------------------
- (NSArray *)sortedKeys { return sortedKeys; }
- (void)setSortedKeys:(NSArray *) value {
	[value retain];
	[sortedKeys release];
	sortedKeys = value;
}

// ---------------------------------------------------------------------------------
//	• selectedSet
// ---------------------------------------------------------------------------------
- (NSMutableDictionary*)selectedSet
{
	NSMutableDictionary* mySet = selectedSet;
	if (!mySet || !sortedKeys) {
		// get selectedSet from model
		NSString* selectedNetwork = nil;
		// get localHostNames from SentryModel
		NSMutableDictionary* localHostNames = [[NameServiceModel sharedInstance] localHostNames];
		if (!localHostNames) {
			// allocate if needed
			localHostNames = [NSMutableDictionary dictionary];
			[[NameServiceModel sharedInstance] setLocalHostNames:localHostNames];
		}
		// get selectedNetwork name from window
		NSTableColumn* column = [[localNetworksTableView tableColumns] objectAtIndex:
			[localNetworksTableView columnWithIdentifier:kColumn_network]];
		int selectedRow = [localNetworksTableView selectedRow];
		// is there a selected row?
		if (selectedRow >= 0) {
			selectedNetwork = [[localNetworksTableView dataSource]
				tableView:localNetworksTableView
				objectValueForTableColumn:column
				row:selectedRow];
		}
		if (selectedNetwork) {
			mySet = [localHostNames objectForKey:selectedNetwork];
			if (!mySet) {
				// allocate if needed
				mySet = [NSMutableDictionary dictionary];
				[localHostNames setObject:mySet forKey:selectedNetwork];
			}
			// remember it
			[self setSelectedSet:mySet];
	}
	}
	return mySet;
}
- (void)setSelectedSet:(NSMutableDictionary*)value
{
	[value retain];
	[selectedSet release];
	selectedSet = value;
}


#pragma mark -- actions --

// ---------------------------------------------------------------------------------
//	• hostNameAddButton
// ---------------------------------------------------------------------------------
- (IBAction)hostNameAddButton:(id)sender
{
	NSMutableDictionary* mySet;
	NSString* title;
	NSString* ipAddress;
	NSString* name = nil;
	// find key for selected row
	if (!sortedKeys) {
		mySet = [self selectedSet];
		[self setSortedKeys:[[mySet allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
	}
	mySet = [self selectedSet];
	int row = [hostNamesTableView selectedRow];
	if (row >= 0) name = [sortedKeys objectAtIndex:row];
	// try to insert after
	if (name) {
		u_int32_t address = ipForString([mySet objectForKey:name])+1;
		ipAddress = stringForIP(address);
		NSRange range = [name rangeOfString:@"_"];
		if (range.length) name = [name substringToIndex:range.location];
		title = [name stringByAppendingFormat:@"_%d",address&0xFF];
	}
	else {
		title = @"myHostName";
		// find selected network
		NSTableColumn* column = [[localNetworksTableView tableColumns] objectAtIndex:
			[localNetworksTableView columnWithIdentifier:kColumn_network]];
		NSString* selectedNetwork = [[localNetworksTableView dataSource]
			tableView:localNetworksTableView
			objectValueForTableColumn:column
			row:[localNetworksTableView selectedRow]];
		// next address
		u_int32_t address = ipForString(selectedNetwork);
		ipAddress = stringForIP(address + 1);
	}
	// set key in dictionary
	[mySet setObject:ipAddress forKey:title];
	// update sort order
	[self setSortedKeys:nil];
	// refresh display
	[hostNamesTableView noteNumberOfRowsChanged];
	//[hostNamesTableView reloadData];
	// select the entry we just added
	row = [sortedKeys indexOfObject:title];
	[hostNamesTableView selectRow:row byExtendingSelection:NO];
}

// ---------------------------------------------------------------------------------
//	• hostNameRemoveButton
// ---------------------------------------------------------------------------------
- (IBAction)hostNameRemoveButton:(id)sender
{
	NSMutableDictionary* mySet;
	NSString* name = nil;
	// find key for selected row
	if (!sortedKeys) {
		mySet = [self selectedSet];
		[self setSortedKeys:[[mySet allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
	}
	mySet = [self selectedSet];
	int row = [hostNamesTableView selectedRow];
	if (row >= 0) name = [sortedKeys objectAtIndex:row];
	if (name) {
		// remove key from dictionary
		[mySet removeObjectForKey:name];
		// update sort order
		int count = [sortedKeys count]-1;
		[self setSortedKeys:nil];
		// refresh display
		[hostNamesTableView noteNumberOfRowsChanged];
		[hostNamesTableView reloadData];
		// update selection?
		if (row == count) [hostNamesTableView selectRow:row-1 byExtendingSelection:NO];
	}
}

#pragma mark -- NSTableDataSource --
// ---------------------------------------------------------------------------------
//	• numberOfRowsInTableView
// ---------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (!sortedKeys) {
		NSMutableDictionary* mySet = [self selectedSet];
		[self setSortedKeys:[[mySet allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
	}
	return [sortedKeys count];
}

// ---------------------------------------------------------------------------------
//	• tableView:objectValueForTableColumn:row
// ---------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id returnValue = nil;
	if (!sortedKeys) [self numberOfRowsInTableView:tableView];
	NSString* cid = [tableColumn identifier];
	if ([cid isEqualTo:kColumn_name]) returnValue = [sortedKeys objectAtIndex:row];
	else if ([cid isEqualTo:kColumn_ipAddress]) {
		NSString* name = [sortedKeys objectAtIndex:row];
		returnValue = [[self selectedSet] objectForKey:name];
	}
	[[returnValue retain] autorelease];	// don't delete it accidentally
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• tableView:setObjectValue:forTableColumn:row
// ---------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if (!sortedKeys) [self numberOfRowsInTableView:tableView];
	NSMutableDictionary* mySet = [self selectedSet];
	NSString* cid = [tableColumn identifier];
	if ([cid isEqualTo:kColumn_name]) {
		// get previous key and value
		NSString* name = [sortedKeys objectAtIndex:row];
		NSString* ipAddress = [mySet objectForKey:name];
		// replace key in dictionary
		[mySet setObject:ipAddress forKey:object];
		if (![name isEqualTo:object]) {
			[mySet removeObjectForKey:name];
			// update sort order
			[self setSortedKeys:nil];
		}
	}
	else if ([cid isEqualTo:kColumn_ipAddress]) {
		// get key
		NSString* name = [sortedKeys objectAtIndex:row];
		// replace value
		[mySet setObject:object forKey:name];
	}
	[tableView reloadData];
}

#pragma mark --- CODING_AND_COPYING ---
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:localNetworksTableView];
	[coder encodeObject:hostNamesTableView];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
	localNetworksTableView = [[coder decodeObject] retain];
	hostNamesTableView = [[coder decodeObject] retain];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    HostNamesDS *copy;
	copy = [[[self class] allocWithZone:zone] init];
    [copy setLocalNetworksTableView:localNetworksTableView];
    [copy setHostNamesTableView:hostNamesTableView];
    return copy;
}

@end
