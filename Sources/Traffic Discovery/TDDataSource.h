//
//  TDDataSource.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 1/24/07.
//  Copyright 2007 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class TDEntry;


@interface TDDataSource : NSObject {
	NSMutableDictionary* serviceTable;
	NSMutableDictionary* deviceTable;
	NSMutableDictionary* netflowTable;
	NSMutableArray* sortedKeys;
	NSString* mySortBy;
	int myViewBy;
	NSString* clientPrefix;	// recognize responses that are for me
	id delegate;
}
// Accessors
-(id)delegate;
- (void)setDelegate:(id)value;

- (int)viewBy;
- (void)setViewBy:(int )value;

- (NSString *)sortBy;
- (void)setSortBy:(NSString *)value;

- (void)updateSort;
- (TDEntry *)tdEntryForRow:(int)row;

// Request Update
- (void)tableUpdate;
- (void)reloadPlotFromIndex:(int)fromIndex toIndex:(int)toIndex;
- (void)requestUpdates;

// Receive data
- (void)receiveDictionary:(NSDictionary *)dictionary;

// NSTableDataSource
- (int)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView
        objectValueForTableColumn:(NSTableColumn *)tableColumn
        row:(int)row;
@end
