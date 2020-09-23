//
//  TreeNode.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Tue Aug 06 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate a hierarchical tree node for use with NSOutlineView.
//  Each node may contain an array of child nodes and is linked to its parent.

#import "TreeNode.h"
#import "NSOutlineView_Extensions.h"

@implementation TreeNode
+ (TreeNode *)treeNode
{
    return [[[TreeNode alloc] init] autorelease];
}

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
        nodeDictionary = [[NSMutableDictionary alloc] initWithCapacity:TN_capacity];
        if (!nodeDictionary) return nil;
        // by default object for key is nil
		nodeCount = 0;
    }
    return self;
}
// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
    [nodeDictionary release]; nodeDictionary = nil;
    [super dealloc];
}

#pragma mark --- Accessors ---
// =================================================================================
// accessors
// =================================================================================
- (NSMutableDictionary *)nodeDictionary { return nodeDictionary; };
- (void)setNodeDictionary:(NSMutableDictionary *)value {
    [value retain];
    [nodeDictionary release];
    nodeDictionary = value;
}


// ---------------------------------------------------------------------------------
//	¥ nodeNumber
// ---------------------------------------------------------------------------------
//	Determine node number (x.x.x) based on position in hierarchy.
//	Cache the result for efficiency under the key TN_nodeNumber.
- (NSString *)nodeNumber
{
    NSString* returnValue;
    TreeNode* node;
    TreeNode* parent;
    if ([self nodeParent] == nil) returnValue = @"Root";
    // use nodeNumber if already set
    else returnValue = [nodeDictionary objectForKey:TN_nodeNumber];	
    if (!returnValue) {
        NSString* suffix = nil;
        node = self;
        while ((parent = [node nodeParent])) {
            if ([suffix length]) returnValue = [NSString stringWithFormat:@"%d.%@",
                [node nodeIndex]+1, suffix];
            else returnValue = [NSString stringWithFormat:@"%d", [node nodeIndex]+1];
            suffix = returnValue;
            node = parent;
        }
        [self setNodeNumber:returnValue];
    }
    return returnValue;
}
- (void)setNodeNumber:(NSString *)value {
	if (value) [nodeDictionary setObject:value forKey:TN_nodeNumber];
	else {
		// value is nil, update nodeNumber cache for ourselves and our descendents
		NSEnumerator* en;
		TreeNode* node;
		[nodeDictionary removeObjectForKey:TN_nodeNumber];
		[self nodeNumber];	// calculate new value
		if ((en = [[self children] objectEnumerator])) {
			while (node = [en nextObject]) {
				[node setNodeNumber:nil];
			}
		}
	}
}

- (NSMutableArray *)children { return [nodeDictionary objectForKey:TN_children]; }
- (void)setChildren:(NSMutableArray *)value {
    if (value) [nodeDictionary setObject:value forKey:TN_children];
    else [nodeDictionary removeObjectForKey:TN_children];
}

- (id)nodeParent { return [nodeDictionary objectForKey:TN_nodeParent]; }
- (void)setNodeParent:(TreeNode *)value {
    if (value) [nodeDictionary setObject:value forKey:TN_nodeParent];
    else [nodeDictionary removeObjectForKey:TN_nodeParent];
}

// ---------------------------------------------------------------------------------
//	¥ nodeCount
// ---------------------------------------------------------------------------------
- (int)nodeCount
{
	int returnValue = 1;	// count 1 for self
	NSEnumerator* en;
	TreeNode* node;
	
	// check for saved result
	if (nodeCount) returnValue = nodeCount;
	else {
		en = [[self children] objectEnumerator];
		while (node = [en nextObject]) {
			// add count for each child
			returnValue += [node nodeCount];
		}
		[self setNodeCount:returnValue];	// save result
	}
	return returnValue;
}
- (void)setNodeCount:(int)value {
	nodeCount = value;
	if (value == 0) {
		NSEnumerator* en;
		TreeNode* node;
		en = [[self children] objectEnumerator];
		while (node = [en nextObject]) {
			// clear children
			[node setNodeCount:0];
		}
	}
}


#pragma mark --- ACCESS_HIERARCHY ---
// =================================================================================
// access hierarchy
// =================================================================================
- (unsigned)numberOfChildren { return [[self children] count]; }
- (unsigned)nodeIndex { return [[self nodeParent] indexOfChild:self]; }
// ---------------------------------------------------------------------------------
//	¥ indexOfChild
// ---------------------------------------------------------------------------------
- (unsigned)indexOfChild:(TreeNode *)node
{
    unsigned returnValue = NSNotFound;
    NSArray* list;
    if ((list = [self children])) returnValue = [list indexOfObject:node];
    return returnValue;
}
// ---------------------------------------------------------------------------------
//	¥ childAtIndex:
// ---------------------------------------------------------------------------------
- (id)childAtIndex:(int)index { return [[self children] objectAtIndex:index]; }
// ---------------------------------------------------------------------------------
//	¥ insertChild:atIndex:
// ---------------------------------------------------------------------------------
- (void)insertChild:(TreeNode *)item atIndex:(unsigned)index
{
    int i;
    NSMutableArray* children = [self children];
    do {
        if (!children) {
            children = [NSMutableArray array];
            if (!children) break;
            [self setChildren:children];
        }
        unsigned count = [children count];
        if (index < count) [children insertObject:item atIndex:index];
        else [children addObject:item];
        [item setNodeParent:self];
        // renumber as needed
        for (i=index;i<=count;i++) [[children objectAtIndex:i] setNodeNumber:nil];
    } while (false);
}

// ---------------------------------------------------------------------------------
//	¥ replaceChildAtIndex:withChild:
// ---------------------------------------------------------------------------------
//	Return NO if no children and allocation fails
- (BOOL)replaceChildAtIndex:(unsigned)index withChild:(TreeNode *)item
{
    BOOL returnValue = NO;
    NSMutableArray* children = [self children];
    do {
        if (!children) {
            children = [NSMutableArray array];
            if (!children) break;
            [self setChildren:children];
        }
        unsigned count = [children count];
        if (index < count) [children replaceObjectAtIndex:index withObject:item];
        else [children addObject:item];
        [item setNodeParent:self];
        // renumber as needed
        [item setNodeNumber:nil];
        returnValue = YES;
    } while (false);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ addChild:
// ---------------------------------------------------------------------------------
- (BOOL)addChild:(TreeNode *)item
{
    BOOL returnValue = NO;
    NSMutableArray* children = [self children];
    do {
        if (!children) {
            children = [NSMutableArray array];
            if (!children) break;
            [self setChildren:children];
        }
        [children addObject:item];
        [item setNodeParent:self];
        [item setNodeNumber:nil];
        returnValue = YES;
    } while (false);
    return returnValue;
}
// ---------------------------------------------------------------------------------
//	¥ removeChild:
// ---------------------------------------------------------------------------------
- (BOOL)removeChild:(TreeNode *)child
{
    BOOL returnValue = NO;
    NSMutableArray* children;
    NSUInteger index, i;
    children = [self children];
    index = [children indexOfObject:child];
    if (index != NSNotFound) {
        [children removeObjectAtIndex:index];
        for (i=index;i<[children count];i++) [[children objectAtIndex:i] setNodeNumber:nil];
        returnValue = YES;
    }
    return returnValue;
}
// ---------------------------------------------------------------------------------
//	¥ removeFromParent:
// ---------------------------------------------------------------------------------
- (void)removeFromParent {
    [[self nodeParent] removeChild:self];
}
// ---------------------------------------------------------------------------------
//	¥ insertNextItem:
// ---------------------------------------------------------------------------------
- (BOOL)insertNextItem:(TreeNode *)item {
    BOOL returnValue = NO;
    TreeNode* parent = [self nodeParent];
    unsigned index = [self nodeIndex];
    if (parent) {
        [parent insertChild:item atIndex:index+1];
        returnValue = YES;
    }
    return returnValue;
}

#pragma mark --- IDENTIFY_SUBTREES ---
// ---------------------------------------------------------------------------------
//	¥ isDescendantOfNode:
// ---------------------------------------------------------------------------------
- (BOOL)isDescendantOfNode:(TreeNode *)node
{
    // returns YES if 'node' is an ancestor.
    // Walk up the tree, to see if any of our ancestors is 'node'.
    TreeNode* parent = [self nodeParent];	// not a descendant of ourself
    while (parent) {
        if (parent == node) return YES;
        parent = [parent nodeParent];
    }
    return NO;
}
// ---------------------------------------------------------------------------------
//	¥ isDescendantOfNodeInArray:
// ---------------------------------------------------------------------------------
- (BOOL)isDescendantOfNodeInArray:(NSArray*)nodes
{
    // returns YES if any 'node' in the array 'nodes' is an ancestor of ours.
    // For each node in nodes, if node is an ancestor return YES.  If none is an
    // ancestor, return NO.
    NSEnumerator* en = [nodes objectEnumerator];
    TreeNode* node = nil;
    while (node=[en nextObject]) {
        if([self isDescendantOfNode:node]) return YES;
    }
    return NO;
}

// ---------------------------------------------------------------------------------
//	¥ treeCover:
// ---------------------------------------------------------------------------------
// return list of nodes that are not descendents of any others in list
+ (NSArray *)treeCover:(NSArray *)nodes
{
    NSEnumerator* en;
    TreeNode* node;
    NSMutableArray* returnValue;
    returnValue = [NSMutableArray array];
    en = [nodes objectEnumerator];
    while (node = [en nextObject]) {
        if (![node isDescendantOfNodeInArray:nodes]) [returnValue addObject:node];
    }
    return returnValue;
}


#pragma mark --- EXPANDED_STATE ---
// ---------------------------------------------------------------------------------
//	¥ saveExpandedForOutlineView:
// ---------------------------------------------------------------------------------
- (void)saveExpandedForOutlineView:(NSOutlineView *)olv
{
	// save our own state
	if ([olv isItemExpanded:self]) [self setExpandedState:[NSNumber numberWithInt:1]];
	else {
		[self setExpandedState:nil];
	}
	// use recursion to process our children if any
	{
		NSEnumerator* en;
		TreeNode* node;
		en = [[self children] objectEnumerator];
		while (node = [en nextObject]) [node saveExpandedForOutlineView:olv];
	}
}

// ---------------------------------------------------------------------------------
//	¥ restoreExpandedForOutlineView:
// ---------------------------------------------------------------------------------
- (void)restoreExpandedForOutlineView:(NSOutlineView *)olv
{
	// expand or collapse ourself to match saved state
	if ([[self expandedState] intValue]) {
		[olv expandItem:self];
	}
	else [olv collapseItem:self];
	// use recursion to process our children if any
	{
		NSEnumerator* en;
		TreeNode* node;
		en = [[self children] objectEnumerator];
		while (node = [en nextObject]) {
			[node restoreExpandedForOutlineView:olv];
		}
	}
}

- (NSNumber *)expandedState { return [nodeDictionary objectForKey:TN_expandedState]; }
- (void)setExpandedState:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:TN_expandedState];
    else [nodeDictionary removeObjectForKey:TN_expandedState];
}

@end

