//
//  NSOutlineView_Extensions.h
//
//  Created by psichel on Wed Oct 23 2002.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//	Initial version based on DragNDropOutlineView sample code from Apple Computer

#import "NSOutlineView_Extensions.h"

@implementation NSOutlineView (PSExtensions)

- (id)selectedItem
{
    return [self itemAtRow:[self selectedRow]];
}

- (NSArray*)selectedItems
{
    NSMutableArray* items = [NSMutableArray array];
    NSEnumerator* en = [self selectedRowEnumerator];
    NSNumber* selectedRow = nil;
    id item;
    while (selectedRow = [en nextObject]) {
        if ((item = [self itemAtRow:[selectedRow intValue]])) 
            [items addObject:item];
    }
    return items;
}

- (void)selectItem:(id)item
{
    [self selectRow:[self rowForItem:item] byExtendingSelection:NO];
}

- (void)selectItems:(NSArray*)items byExtendingSelection:(BOOL)extend {
    int i;
    if (extend==NO) [self deselectAll:nil];
    for (i=0;i<[items count];i++) {
        int row = [self rowForItem:[items objectAtIndex:i]];
        if(row>=0) [self selectRow: row byExtendingSelection:YES];
    }
}

@end
