//
//  HostNamesDS.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 9/25/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//
//	hostNamesTableView Data Source

#import <Cocoa/Cocoa.h>


@interface HostNamesDS : NSObject {
    IBOutlet NSTableView *localNetworksTableView;
	IBOutlet NSTableView *hostNamesTableView;
	NSMutableDictionary* selectedSet;
	NSArray*	sortedKeys;
}

// get/set
- (NSTableView *)localNetworksTableView;
- (void)setLocalNetworksTableView:(NSTableView *)value;

- (NSTableView *)hostNamesTableView;
- (void)setHostNamesTableView:(NSTableView *)value;

- (NSArray *)sortedKeys;
- (void)setSortedKeys:(NSArray *)value;
// actions
- (IBAction)hostNameAddButton:(id)sender;
- (IBAction)hostNameRemoveButton:(id)sender;


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

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

#define kColumn_name			@"name"
#define kColumn_ipAddress		@"ipAddress"
#define kHostNamesTableView		@"hostNamesTableView"
