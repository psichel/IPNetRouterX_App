//  PortMapTable.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for Nat Static table

#import <Cocoa/Cocoa.h>
#import "PortMapEntry.h"
#import "avl.h"

extern NSString* PortMapTableNotification;


@interface PortMapTable : NSObject
{
	avl_tree *portMapApparentTree;
	avl_tree *portMapActualTree;
	avl_tree *oldTree;
}

- (id)init;
- (void) dealloc;
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;
//- (id)delegate;
//- (void)setDelegate:(id)value;

- (NSMutableArray *)portMapArray;
- (NSArray *)arrayOfDictionaries;
- (BOOL)loadArrayOfDictionaries:(NSArray *)inArray;

- (BOOL)containsObject:(PortMapEntry *)value;
- (int)insertObject:(PortMapEntry *)value;
- (int)removeObject:(PortMapEntry *)value;
- (int)removeAllObjects;
- (int)removeAllObjectsToOldTree;
- (PortMapEntry *)objectAtIndex:(int)row;
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
