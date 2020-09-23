//
//  LocalNetworksDS.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 9/25/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//
//	localNetworksTableView Data Source

#import <Cocoa/Cocoa.h>


@interface LocalNetworksDS : NSObject {
    IBOutlet NSTableView *hostNamesTableView;
}

- (NSTableView *)hostNamesTableView;
- (void)setHostNamesTableView:(NSTableView *)value;

// NSTableViewDelegate
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
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

#define kColumn_on			@"on"
#define kColumn_network		@"network"
#define kColumn_zoneName	@"zoneName"
#define kLocalNetworksTableView	@"localNetworksTableView"
