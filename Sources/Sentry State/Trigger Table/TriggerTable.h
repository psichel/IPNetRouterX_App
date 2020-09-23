//  TriggerTable.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for interface table

#import <Cocoa/Cocoa.h>
#import "TriggerEntry.h"
#import "avl.h"


@class SentryDocument;

@interface TriggerTable : NSObject
{
	avl_tree *triggerAddressTree;
	id delegate;
}

- (id)init;
- (void) dealloc;
- (id)delegate;
- (void)setDelegate:(id)value;
- (NSMutableArray *)triggerArray;
- (NSArray *)arrayOfDictionaries;
- (BOOL)loadArrayOfDictionaries:(NSArray *)inArray;

- (TriggerEntry *)objectForKey:(TriggerEntry *)value;
- (int)insertObject:(TriggerEntry *)value;
- (int)removeObject:(TriggerEntry *)value;
- (int)removeAllObjects;
- (TriggerEntry *)objectAtIndex:(int)row;
- (unsigned)count;

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
