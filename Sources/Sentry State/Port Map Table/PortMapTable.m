//  PortMapTable.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for portMap table

#import "PortMapTable.h"
#import "SentryDefs.h"
#import "IPTypes.h"
#import PS_TNKE_INCLUDE
#import "kft.h"

// Globals
NSString *PortMapTableNotification = @"PortMapTableNotification";


// forward internal function declarations
int portMapActualFree (void * key);
int portMapActualCompare (void * compare_arg, void * a, void * b);
int portMapApparentFree (void * key);
int portMapApparentCompare (void * compare_arg, void * a, void * b);

@implementation PortMapTable

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
	if (self = [super init]) {
        // initialize our instance variables
		KFT_avlExternalType(1);
		portMapActualTree = new_avl_tree (portMapActualCompare, NULL);
		portMapApparentTree = new_avl_tree (portMapApparentCompare, NULL);
		KFT_avlExternalType(0);
		oldTree = nil;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	// free actual tree first since it doesn't release table entries
	if (portMapActualTree) free_avl_tree(portMapActualTree, portMapActualFree);
    if (portMapApparentTree) free_avl_tree(portMapApparentTree, portMapApparentFree);
    if (oldTree) free_avl_tree(oldTree, portMapApparentFree);
    [super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:PortMapTableNotification 
    object:self];
}

// ---------------------------------------------------------------------------------
//	¥ removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:PortMapTableNotification
        object:nil];	// remove any previous PortMapTableNotification
}

// ---------------------------------------------------------------------------------
//	¥ updateParameter
// ---------------------------------------------------------------------------------
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
    NSDictionary* myDictionary;
	myDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:anObject, name, nil];
	// notify listeners with dictionary
	[[NSNotificationCenter defaultCenter]
		postNotificationName:PortMapTableNotification
		object:self
		userInfo:myDictionary];		
	[myDictionary release];
	return YES;
}


// ---------------------------------------------------------------------------------
//	¥ portMapArray
// ---------------------------------------------------------------------------------
- (NSMutableArray *)portMapArray
{
	NSMutableArray* portMapArray = nil;
	PortMapEntry* entry;
	int count, i;
	int result;
	
	do {
		if (portMapApparentTree) count = portMapApparentTree->length;
		else break;
		portMapArray = [NSMutableArray array];
		for (i=0; i<count; i++) {
			result = get_item_by_index(portMapApparentTree, i, (void **)&entry);
			if (!result) [portMapArray addObject:entry];
		}
	} while (false);
	return portMapArray;
}

// ---------------------------------------------------------------------------------
//	¥ arrayOfDictionaries
// ---------------------------------------------------------------------------------
- (NSArray *)arrayOfDictionaries {
	NSMutableArray* arrayOfDictionaries = nil;
	PortMapEntry* entry;
	int count, i;
	int result;
	
	do {
		if (portMapApparentTree) count = portMapApparentTree->length;
		else break;
		arrayOfDictionaries = [NSMutableArray array];
		for (i=0; i<count; i++) {
			result = get_item_by_index(portMapApparentTree, i, (void **)&entry);
			if (!result) [arrayOfDictionaries addObject:[entry nodeDictionary]];
		}
	} while (false);
	return (NSArray *)arrayOfDictionaries;
}

// ---------------------------------------------------------------------------------
//	¥ loadArrayOfDictionaries
// ---------------------------------------------------------------------------------
- (BOOL)loadArrayOfDictionaries:(NSArray *)inArray
{
	int returnValue = YES;
	NSEnumerator* en;
	NSDictionary* nodeDictionary;
	PortMapEntry* entry;
	
	en = [inArray objectEnumerator];
	while (nodeDictionary = [en nextObject]) {
		entry = [PortMapEntry entryFromDictionary:nodeDictionary];
		if (entry) [self insertObject:entry];
	}
	return returnValue;
}
// ---------------------------------------------------------------------------------
//	¥ containsObject
// ---------------------------------------------------------------------------------
- (BOOL)containsObject:(PortMapEntry *)value
{
	BOOL returnValue = NO;
	PortMapEntry* entry = NULL;
	int status;
	
	do {
		if (!value) break;
		if (portMapActualTree) {
			status = get_item_by_key(portMapActualTree, (void *)value, (void **)&entry);
			if (status == 0) {
				returnValue = YES;
				break;
			}
		}
		if (portMapApparentTree) {
			status = get_item_by_key(portMapApparentTree, (void *)value, (void **)&entry);
			if (status == 0) {
				returnValue = YES;
				break;
			}
		}
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ insertObject
// ---------------------------------------------------------------------------------
//	0=success, 1=duplicate found, -1=failure
- (int)insertObject:(PortMapEntry *)value
{
	int returnValue = -1;
	PortMapEntry* entry = NULL;
	KFT_avlExternalType(1);
	if (portMapApparentTree && value) {
		// don't allow multiple keys with same value
		if (portMapActualTree) {
			int status;
			status = get_item_by_key(portMapActualTree, (void *)value, (void **)&entry);
			if (status == 0) remove_by_key(portMapActualTree, (void *)entry, portMapActualFree);
		}
		returnValue = get_item_by_key(portMapApparentTree, (void *)value, (void **)&entry);
		if (returnValue == 0) {
			// found a match update rest of entry
			[entry setActualPort:[value actualPort]];
			[entry setActualAddress:[value actualAddress]];
			//[entry setLastTime:[value lastTime]];
			returnValue = 1;
			// put in other tree so we can test for conflicting keys
			if (portMapActualTree) insert_by_key(portMapActualTree, (void *)entry);
		}
		else {
			if (oldTree) {
				// look for match in old tree to preserve comment
				returnValue = get_item_by_key(oldTree, (void *)value, (void **)&entry);
				if (returnValue == 0) {
					[value setComment:[entry comment]];
					remove_by_key(oldTree, (void *)entry, portMapApparentFree);
				}
			}
			returnValue = insert_by_key(portMapApparentTree, (void *)value);
			if (returnValue == 0) {
				[value retain];
				// put in other tree so we can test for conflicting keys
				if (portMapActualTree) insert_by_key(portMapActualTree, (void *)value);
			}
		}
	}
	KFT_avlExternalType(0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ removeObject
// ---------------------------------------------------------------------------------
// return -1 if no matching object found
- (int)removeObject:(PortMapEntry *)value
{
	int returnValue = -1;
	PortMapEntry* foundEntry = nil;
	
	KFT_avlExternalType(1);
	if (value) {
		if (portMapApparentTree) {
			// look for matching entry to delete
			returnValue = get_item_by_key(portMapApparentTree, (void *)value, (void **)&foundEntry);
			if (returnValue == 0) {	
				// do actual tree first since it doesn't retain objects
				if (portMapActualTree) {
					remove_by_key(portMapActualTree, (void *)value, portMapActualFree);
				}
				remove_by_key(portMapApparentTree, (void *)value, portMapApparentFree);
			}
		}
	}
	KFT_avlExternalType(0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ removeAllObjects
// ---------------------------------------------------------------------------------
- (int)removeAllObjects
{
	int returnValue = 0;
	KFT_avlExternalType(1);
	// release old tree if any
    if (oldTree) {
		free_avl_tree(oldTree, portMapApparentFree);
		oldTree = nil;
	}
	// release and reallocate current trees
		// actual tree first since it doesn't retain entries
	if (portMapActualTree) {
		free_avl_tree(portMapActualTree, portMapActualFree);
		portMapActualTree = new_avl_tree(portMapActualCompare, NULL);
	}
	if (portMapApparentTree) {
		free_avl_tree(portMapApparentTree, portMapApparentFree);
		portMapApparentTree = new_avl_tree(portMapApparentCompare, NULL);
		if (!portMapApparentTree) returnValue = -1;
	}
	KFT_avlExternalType(0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ removeAllObjectsToOldTree
// ---------------------------------------------------------------------------------
- (int)removeAllObjectsToOldTree
{
	int returnValue = 0;
	KFT_avlExternalType(1);
	// release old tree if any
    if (oldTree) {
		free_avl_tree(oldTree, portMapApparentFree);
		oldTree = nil;
	}
	if (portMapApparentTree) {
		// transfer current to old tree to preserve extra fields
		oldTree = portMapApparentTree;
		if (portMapActualTree) {
			free_avl_tree(portMapActualTree, portMapActualFree);
			portMapActualTree = new_avl_tree(portMapActualCompare, NULL);
		}
		//free_avl_tree(portMapApparentTree, portMapApparentFree);
		portMapApparentTree = new_avl_tree(portMapApparentCompare, NULL);
		if (!portMapApparentTree) returnValue = -1;
	}
	KFT_avlExternalType(0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ objectAtIndex
// ---------------------------------------------------------------------------------
- (PortMapEntry *)objectAtIndex:(int)row
{
	id object = nil;
	PortMapEntry* entry;
	int result;
	result = get_item_by_index(portMapApparentTree, row, (void **)&entry);
	if (result == 0) object = entry;
	return object;
}

// ---------------------------------------------------------------------------------
//	¥ count
// ---------------------------------------------------------------------------------
- (unsigned)count
{
	if (portMapApparentTree) return portMapApparentTree->length;
	else return 0;
}

#pragma mark --- NSTableViewDelegate ---
//- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
//- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row;
//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
//- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(int)row;
//- (BOOL)tableView:(NSTableView *)tableView shouldSelectTableColumn:(NSTableColumn *)tableColumn;

#pragma mark --- NSTableDataSource ---
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (portMapApparentTree) return portMapApparentTree->length;
	else return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	id object = nil;
	PortMapEntry* entry;
	int result;
	result = get_item_by_index(portMapApparentTree, row, (void **)&entry);
	if (result == 0) {
		object = [entry valueForKey:[tableColumn identifier]];
//		if ([[tableColumn identifier] isEqualTo:PM_apparentPort])
//			NSLog(@"Row %d, entry %@", row, [entry description]);
	}
	return object;
}

// optional
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	PortMapEntry* entry;
	NSString* cid;	// column identifier
	NSString* oldValue;
	int result;
	result = get_item_by_index(portMapApparentTree, row, (void **)&entry);
	if (result == 0) {
		// test if value has changed
		cid = [tableColumn identifier];
		oldValue = [entry valueForKey:cid];
		if (![oldValue isEqualTo:object]) {
			BOOL didChange = YES;
			// test for apparent endpoint
			if ([cid isEqualTo:PM_apparentAddress] ||
				[cid isEqualTo:PM_apparentPort] ||
				[cid isEqualTo:PM_actualAddress] ||
				[cid isEqualTo:PM_actualPort] ||
				[cid isEqualTo:PM_protocol]) {						
				[[entry retain] autorelease];
				[self removeObject:entry];
				[entry setValue:object forKey:cid];
				// check for endpoint already in use
				if ([self containsObject:entry]) {
					[self updateParameter:@"statusInfo" withObject:@"That endpoint is already assigned."];
					NSBeep();
					// put it back
					[entry setValue:oldValue forKey:cid];
					didChange = NO;
				}
				[self insertObject:entry];
				[tableView reloadData];
			}
			else [entry setValue:object forKey:cid];
			if (didChange) {
				// notify listeners
				[self updateParameter:SS_documentChangeDone withObject:[NSNumber numberWithInt:NSChangeDone]];
				//[delegate setApplyPending:[NSNumber numberWithInt:1]];
			}
		}	// if (![oldValue isEqualTo:object])
	}	// if (result == 0)
}

@end

// ---------------------------------------------------------------------------------
//	¥ portMapActualFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int portMapActualFree (void * key) {
  // don't release entry since it is still in ApparentTree
  return 0;
}

// ---------------------------------------------------------------------------------
//	¥ portMapActualCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
int portMapActualCompare (void * compare_arg, void * a, void * b)
{
  PortMapEntry *ta;
  PortMapEntry *tb;
  ta = (PortMapEntry *)a;
  tb = (PortMapEntry *)b;
  
  return [ta compareActual:tb];
}

// ---------------------------------------------------------------------------------
//	¥ portMapApparentFree()
// ---------------------------------------------------------------------------------
// used as avl_free_key_fun_type
int portMapApparentFree (void * key) {
  PortMapEntry *entry;
  entry = (PortMapEntry *)key;
  [entry release];
  return 0;
}

// ---------------------------------------------------------------------------------
//	¥ portMapApparentCompare()
// ---------------------------------------------------------------------------------
// used as avl_key_compare_fun_type
int portMapApparentCompare (void * compare_arg, void * a, void * b)
{
  PortMapEntry *ta;
  PortMapEntry *tb;
  ta = (PortMapEntry *)a;
  tb = (PortMapEntry *)b;
  
  return [ta compareApparent:tb];
}

