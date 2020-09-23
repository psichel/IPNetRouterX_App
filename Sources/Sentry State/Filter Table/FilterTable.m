//
//  FilterTable.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu Oct 03 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulates the root of a hierarchical filter table (NSOutlineView)
//  This class serves as a data source and Delegate for an NSOutlineView.

#import "FilterTable.h"
#import "SentryState.h"
#import "NSOutlineView_Extensions.h"
#import "PSNumberFormatter.h"
#import "NSOutlineView_Extensions.h"
//#import "ExpertViewWC.h"

// informal protocol for examing window selections from datasource
@interface NSObject (ExpertViewDataSource)
- (id)selectProperty:(int)propertyID;	// call through for data source
- (int)indexOfSelectedParameter;
@end

// Private Methods
@interface FilterTable (PrivateMethods)
- (NSString *)stringForObjectValue:(id)anObject;
@end


@implementation FilterTable


// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		draggedNodes = nil;
		delegate = nil;
	}
	return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	[self setDelegate:nil];
    [super dealloc];
}

// ---------------------------------------------------------------------------------
// ¥ delegate
// ---------------------------------------------------------------------------------
- (id)delegate { return delegate; }
- (void)setDelegate:(id)value {
	//[value retain];
	//[delegate release];
	delegate = value;
}


- (NSArray*)draggedNodes   { return draggedNodes; }

// ---------------------------------------------------------------------------------
//	¥ stringForObjectValue:
// ---------------------------------------------------------------------------------
// Return the string representing a large quantity or bandwidth (K, M, G)
// anObject is expected to be an NSNumber
- (NSString *)stringForObjectValue:(id)anObject {
    NSString* returnValue;
    float value;
    
    value = [anObject floatValue];
    if (value > 4.294967e+09) returnValue = [NSString stringWithFormat:@"%.00fG", value/1.073742e+09];
    else if (value > 4194304) returnValue = [NSString stringWithFormat:@"%.0fM", value/1048576];
    else if (value > 4096) returnValue = [NSString stringWithFormat:@"%.0fK", value/1024];
    else returnValue = [NSString stringWithFormat:@"%.0f", value];
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ nodeForIndex:
// ---------------------------------------------------------------------------------
- (id)nodeForIndex:(int)index
{
	NSEnumerator* en;
	TreeNode* node;
	TreeNode* child;
	int offset, nextOffset;
	
	offset = 0;
	node = self;
	while (offset < index) {
		offset += 1;	// count 1 for parent
		en = [[node children] objectEnumerator];
		while (child = [en nextObject]) {
			nextOffset = offset + [child nodeCount];
			if (nextOffset <= index) offset = nextOffset;	// not child or descendent
			else break;		// is child or descendent
		 }
		 node = child;
		 if (!node) break;	// ran out of children
	}	
	return node;
}


#pragma mark --- DATA_SOURCE_METHODS ---
// =================================================================================
// data source methods
// =================================================================================
// ---------------------------------------------------------------------------------
//	¥ outlineView:child:ofItem:
// ---------------------------------------------------------------------------------
//	If no item specified, return self as root item
- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    return (item == nil) ? [self childAtIndex:index] : [item childAtIndex:index];
}

// ---------------------------------------------------------------------------------
//	¥ outlineView:isItemExpandable:
// ---------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if ([item numberOfChildren]) return YES;
	return NO;
}

// ---------------------------------------------------------------------------------
//	¥ outlineView:numberOfChildrenOfItem:
// ---------------------------------------------------------------------------------
//	If no item specified, return count of our children for the root item
- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return (item == nil) ? [self numberOfChildren] : [item numberOfChildren];
}

// ---------------------------------------------------------------------------------
//	¥ outlineView:objectValueForTablecolumn:byItem:
// ---------------------------------------------------------------------------------
//	Uses key-value coding
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    id returnValue = nil;
	NSString* key;
	NSNumber* valueNum;
	NSNumber* deltaNum;
	key = [tableColumn identifier];
	// adjust key for selectable parameter
	if ([key isEqualTo:CID_MATCHCOUNT]) {
		if ([[outlineView delegate] indexOfSelectedParameter] == 0) {
			key = CID_MATCHCOUNT;
			valueNum = [[[item valueForKey:key] retain] autorelease];
			deltaNum = [[[item valueForKey:FE_matchDelta] retain] autorelease];
			if ([deltaNum intValue])
				returnValue = [NSString stringWithFormat:@"%@ (+%@)",
					[self stringForObjectValue:valueNum],
					[self stringForObjectValue:deltaNum]];
			else if ([valueNum intValue])
				returnValue = [self stringForObjectValue:valueNum];
			else returnValue = nil;
		}
		else if ([[outlineView delegate] indexOfSelectedParameter] == 1) {
			key = CID_BYTECOUNT;
			valueNum = [[[item valueForKey:key] retain] autorelease];
			deltaNum = [[[item valueForKey:FE_byteDelta] retain] autorelease];
			if ([deltaNum intValue])
				returnValue = [NSString stringWithFormat:@"%@ (+%@)",
					[self stringForObjectValue:valueNum],
					[self stringForObjectValue:deltaNum]];
			else if ([valueNum intValue])
				returnValue = [self stringForObjectValue:valueNum];
			else returnValue = nil;
		}
		else if ([[outlineView delegate] indexOfSelectedParameter] == 2) {
			key = CID_LASTTIME;
			valueNum = [[[item valueForKey:key] retain] autorelease];
			if (valueNum) {
				NSDate* valueDate = [NSDate dateWithTimeIntervalSince1970:[valueNum doubleValue]];
				returnValue = [valueDate descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"
					timeZone:nil locale:nil];
			}
			else returnValue = nil;
		}
	}
	else returnValue = (item == nil)? [self valueForKey:key] : [item valueForKey:key];
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ outlineView:setObjectValue:ForTablecolumn:byItem:
// ---------------------------------------------------------------------------------
// Optional method: needed to allow editing.
- (void)outlineView:(NSOutlineView *)olv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item  {
	NSString* columnID;
	id oldValue;
	BOOL didChange = NO;
	// remember old value (if any)
	columnID = [tableColumn identifier];
	oldValue = [item valueForKey:columnID];
	[[oldValue retain] autorelease];
	// use NSKeyValueCoding to assign new value
	[item setValue:object forKey:columnID];
	// select property
    if ([columnID isEqualToString:CID_PROPERTY]) {        
        [[olv delegate] selectProperty:[object intValue]];
    }
	// note if value has changed
	if (oldValue) {
		if ([object isKindOfClass:[NSString class]]) {
			if ([(NSString *)object compare:oldValue] != NSOrderedSame) didChange = YES;
		}
		else if ([object isKindOfClass:[NSNumber class]]) {
			//if ([(NSNumber *)object compare:oldValue] != NSOrderedSame)
			if ([object intValue] != [oldValue intValue]) didChange = YES;
		}
		else didChange = YES;
	}
	else if (object) didChange = YES;
	if (didChange) {
		[delegate updateParameter:SS_documentChangeDone withObject:[NSNumber numberWithInt:NSChangeDone]];
		[delegate setApplyPending:[NSNumber numberWithInt:1]];
	}
/*
    if ([columnID isEqualToString:CID_PROPERTY]) {
        [item setProperty:object];
    }
    else if ([columnID isEqualToString:CID_RELATION]) {
        [item setRelation:object];
    }
    else if ([columnID isEqualToString:CID_VALUE]) {
        [item setPropertyValue:object];
    }
    else if ([columnID isEqualToString:CID_ACTION]) {
        [item setFilterAction:object];
    }
    else if ([columnID isEqualToString:CID_LOG]) {
        [item setLog:object];
    }
    else if ([columnID isEqualToString:CID_ALERT]) {
        [item setAlert:object];
    }
    else if ([columnID isEqualToString:CID_NAME]) {
        [item setNodeName:object];
    }
*/
}

#pragma mark --- DRAGGING METHODS ---
#if DRAG_ENABLE
// =================================================================================
//  NSOutlineView data source methods. (dragging related)
// =================================================================================
// ---------------------------------------------------------------------------------
//	¥ outlineView:writeItems:toPasteboard:
// ---------------------------------------------------------------------------------
    // This method is called after it has been determined that a drag should begin, but before the drag has been started.  To refuse the drag, return NO.  To start a drag, return YES and place the drag data onto the pasteboard (data, owner, etc...).  The drag image and other drag related information will be set up and provided by the outline view once this call returns with YES.  The items array is the list of items that will be participating in the drag.
- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pboard {
    // disable drag and drop for now
//	return NO;
		
	draggedNodes = [TreeNode treeCover:items]; // Don't retain since this is just holding temporaral drag information, and it is only used during a drag!  We could put this in the pboard actually.
    
    // Provide data for our custom type, and simple NSStrings.
    [pboard declareTypes:[NSArray arrayWithObjects: FilterEntryPboardType, NSStringPboardType, nil] owner:self];
    
    // the actual data doesn't matter since DragDropSimplePboardType drags aren't recognized by anyone but us!.
    [pboard setData:[NSData data] forType:FilterEntryPboardType]; 
    
    // Put string data on the pboard... notice you can drag into TextEdit!
    [pboard setString:[draggedNodes description] forType:NSStringPboardType];
    
    //NSLog(@"dragged nodes copied to clipboard");

    return YES;
}


// ---------------------------------------------------------------------------------
//	¥ outlineView:validateDrop:proposedItem:proposedChildIndex:
// ---------------------------------------------------------------------------------
    // This method is used by NSOutlineView to determine a valid drop target.  Based on the mouse position, the outline view will suggest a proposed drop location.  This method must return a value that indicates which dragging operation the data source will perform.  The data source may "re-target" a drop if desired by calling setDropItem:dropChildIndex: and returning something other than NSDragOperationNone.  One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position).
- (unsigned int)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)childIndex {
    // This method validates whether or not the proposal is a valid one.
    // Returns NO if the drop should not be allowed.
    FilterEntry* targetNode = item;
    BOOL targetNodeIsValid = YES;
	
	// Refuse if: dropping "on" the view itself unless we have no data in the view.
	if (targetNode==nil && childIndex==NSOutlineViewDropOnItemIndex && [[self children] count]!=0) 
	    targetNodeIsValid = NO;
    	    
	// Check to make sure we don't allow a node to be inserted into one of its descendants!
	if (targetNodeIsValid && ([info draggingSource]==[[olv delegate] outlineViewOutlet]) && [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject: FilterEntryPboardType]] != nil) {
	    NSArray *_draggedNodes = [[[info draggingSource] dataSource] draggedNodes];
	    targetNodeIsValid = ![targetNode isDescendantOfNodeInArray: _draggedNodes];
	}
    
    // Set the item and child index in case we computed a retargeted one.
//    [[document outlineViewOutlet] setDropItem:targetNode dropChildIndex:childIndex];
    
    return targetNodeIsValid ? NSDragOperationGeneric : NSDragOperationNone;
}

// ---------------------------------------------------------------------------------
//	¥ outlineView:acceptDrop:item:childIndex:
// ---------------------------------------------------------------------------------
    // This method is called when the mouse is released over an outline view that previously decided to allow a drop via the validateDrop method.  The data source should incorporate the data from the dragging pasteboard at this time.
- (BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(int)childIndex
{
    NSPasteboard * pboard = [info draggingPasteboard];
    	
    // handle pboard data
    if ([pboard availableTypeFromArray:[NSArray arrayWithObject: NSStringPboardType]]) {
        NSString* string = [pboard stringForType: NSStringPboardType];

        // remove dragged nodes
        [[olv delegate] delete:draggedNodes];
        draggedNodes = nil;
        
        //NSLog(@"Try to paste");
        [[olv delegate] paste:string toTarget:targetItem childIndex:childIndex];
    }    

    return YES;
}
#endif

/*

- (void)_performDropOperation:(id <NSDraggingInfo>)info onNode:(TreeNode*)parentNode atIndex:(int)childIndex {
    // Helper method to insert dropped data into the model. 
    NSPasteboard * pboard = [info draggingPasteboard];
    NSMutableArray * itemsToSelect = nil;
    
    // Do the appropriate thing depending on wether the data is DragDropSimplePboardType or NSStringPboardType.
    if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:DragDropSimplePboardType, nil]] != nil) {
        AppController *dragDataSource = [[info draggingSource] dataSource];
        NSArray *_draggedNodes = [TreeNode minimumNodeCoverFromNodesInArray: [dragDataSource draggedNodes]];
        NSEnumerator *draggedNodesEnum = [_draggedNodes objectEnumerator];
        SimpleTreeNode *_draggedNode = nil, *_draggedNodeParent = nil;
        
	itemsToSelect = [NSMutableArray arrayWithArray:[self selectedNodes]];
	
        while ((_draggedNode = [draggedNodesEnum nextObject])) {
            _draggedNodeParent = (SimpleTreeNode*)[_draggedNode nodeParent];
            if (parentNode==_draggedNodeParent && [parentNode indexOfChild: _draggedNode]<childIndex) childIndex--;
            [_draggedNodeParent removeChild: _draggedNode];
        }
        [parentNode insertChildren: _draggedNodes atIndex: childIndex];
    } 
    else if ([pboard availableTypeFromArray:[NSArray arrayWithObject: NSStringPboardType]]) {
        NSString *string = [pboard stringForType: NSStringPboardType];
	SimpleTreeNode *newItem = [SimpleTreeNode treeNodeWithData: [SimpleNodeData leafDataWithName:string]];
	
	itemsToSelect = [NSMutableArray arrayWithObject: newItem];
	[parentNode insertChild: newItem atIndex:childIndex++];
    }

    [outlineView reloadData];
    [outlineView selectItems: itemsToSelect byExtendingSelection: NO];
}
*/

@end
