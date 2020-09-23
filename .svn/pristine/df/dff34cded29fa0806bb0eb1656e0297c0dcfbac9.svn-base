//
//  LocalNetworksDS.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 9/25/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//
//	localNetworksTableView Data Source

#import "LocalNetworksDS.h"
#import "HostNamesDS.h"
#import "NameServiceModel.h"
#import "SentryModel.h"
#import "InterfaceTable.h"
#import "InterfaceEntry.h"

@implementation LocalNetworksDS

// ---------------------------------------------------------------------------------
//	• init and dealloc
// ---------------------------------------------------------------------------------
- (id) init {
    if (self = [super init]) {
		// instance vars
		hostNamesTableView = nil;
    }
    return self;
}

- (void)dealloc {
    [hostNamesTableView release];
	[super dealloc];
}

- (NSTableView *)hostNamesTableView { return hostNamesTableView; }
- (void)setHostNamesTableView:(NSTableView *) value {
	[value retain];
	[hostNamesTableView release];
	hostNamesTableView = value;
}

#pragma mark -- NSTableViewDelegate --
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// update host names table to show new set
	[[hostNamesTableView dataSource] setSortedKeys:nil];
	[hostNamesTableView reloadData];
}


#pragma mark -- NSTableView Data Source --
// ---------------------------------------------------------------------------------
//	• numberOfRowsInTableView
// ---------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	NSArray* list = [[NameServiceModel sharedInstance] internals];
	return [list count];
}

// ---------------------------------------------------------------------------------
//	• tableView:objectValueForTableColumn:row
// ---------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id returnValue = nil;
	NSArray* list = [[NameServiceModel sharedInstance] internals];
	NSString* network = [list objectAtIndex:row];
	NSString* cid = [tableColumn identifier];
	if ([cid isEqualTo:kColumn_network]) returnValue = network;
	else if ([cid isEqualTo:kColumn_on]) {
		// lookup whether "on" selected for this network?
		NSMutableDictionary* on = [[NameServiceModel sharedInstance] localCachingOn];
		returnValue = [on objectForKey:network];
		if (!returnValue) returnValue = [NSNumber numberWithInt:0];
	}
	else if ([cid isEqualTo:kColumn_zoneName]) {
		// lookup zone name for this network
		returnValue = [[NameServiceModel sharedInstance] zoneNameForNetwork:network];
		if (!returnValue) {
			// make up a zone name
			InterfaceEntry* interfaceE = [[InterfaceTable sharedInstance] entryForAddress:network];
			if (row && interfaceE) returnValue = [NSString stringWithFormat:@"lan_%@",[interfaceE bsdName]];
			else returnValue = @"lan";
			// save it
			[[NameServiceModel sharedInstance] setZoneName:returnValue forNetwork:network];
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• tableView:setObjectValue:forTableColumn:row
// ---------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	NSArray* list = [[NameServiceModel sharedInstance] internals];
	NSString* network = [list objectAtIndex:row];
	NSString* cid = [tableColumn identifier];
	if ([cid isEqualTo:kColumn_on]) {
		// update whether "on" selected for this network?
		NSMutableDictionary* on = [[NameServiceModel sharedInstance] localCachingOn];
		if ([object intValue]) [on setObject:object forKey:network];
		else [on removeObjectForKey:network];
		// put changed setting back
		[[NameServiceModel sharedInstance] setLocalCachingOn:on];
		[tableView reloadData];
	}
	else if ([cid isEqualTo:kColumn_zoneName]) {
		// update zone name for this network
		[[NameServiceModel sharedInstance] setZoneName:object forNetwork:network];
		[tableView reloadData];
	}
}
#pragma mark --- CODING_AND_COPYING ---
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:hostNamesTableView];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
	hostNamesTableView = [[coder decodeObject] retain];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    LocalNetworksDS *copy;
	copy = [[[self class] allocWithZone:zone] init];
    [copy setHostNamesTableView:hostNamesTableView];
    return copy;
}

@end
