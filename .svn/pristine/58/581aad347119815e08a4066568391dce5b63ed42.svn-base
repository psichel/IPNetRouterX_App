//  InterfaceTable.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 1 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for interface table

#import <Cocoa/Cocoa.h>
#import "InterfaceEntry.h"

extern NSString* InterfaceTableNotification;


@interface InterfaceTable : NSObject
{
	NSMutableArray* interfaceArray;
	// implicit fields
	NSString *excludeNet;
	NSNumber *exposedHostSelection;
	NSString *exposedHost;
}

+ (InterfaceTable *)sharedInstance;
- (id)init;
- (void) dealloc;
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;

- (NSMutableArray *)interfaceArray;
- (void)setInterfaceArray:(NSMutableArray *)value;
- (NSArray *)interfaceArrayOfDictionaries;
- (void)updateFromSCF;
- (void)scfNotification:(NSNotification *)aNotification;
// coordinated
- (void)natSettingHasChanged;
// access helpers
- (InterfaceEntry *)entryForServiceID:(NSString *)serviceID;
- (InterfaceEntry *)entryForInterfaceID:(NSString *)interfaceID;
- (InterfaceEntry *)entryForAddress:(NSString *)inAddress;
- (InterfaceEntry *)entryForNat;
- (InterfaceEntry *)entryForDhcp;
- (InterfaceEntry *)entryForPrimary;
- (BOOL)isAttachEntry:(InterfaceEntry *)inEntry;
- (BOOL)isDetachEntry:(InterfaceEntry *)inEntry;
- (BOOL)isDupEntry:(InterfaceEntry *)inEntry;
// implicit fields

- (NSString *)excludeNet;
- (void)setExcludeNet:(NSString *)value;

- (NSNumber *)exposedHostSelection;
- (void)setExposedHostSelection:(NSNumber *)value;

- (NSString *)exposedHost;
- (void)setExposedHost:(NSString *)value;


// NSTableViewDelegate
//- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
//- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row;
//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
//- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(int)row;
//- (BOOL)tableView:(NSTableView *)tableView shouldSelectTableColumn:(NSTableColumn *)tableColumn;

// NSTableDataSource
- (int)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
// optional
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;

@end

#define SS_ipForwarding				@"ipForwarding"
#define SA_ipForwardingApply		@"ipForwardingApply"

// Action notifications that are separate from state changes
// Example: an interface or port map entry has changed and should be sent to NKE
#define SA_interfaceTable			@"SA_interfaceTable"
#define SA_portMapTable				@"SA_portMapTable"
