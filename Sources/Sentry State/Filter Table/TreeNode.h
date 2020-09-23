//
//  TreeNode.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Tue Aug 06 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate a hierarchical tree node for use with NSOutlineView.
//  Each node may contain an array of child nodes and is linked to its parent.

#import <Foundation/Foundation.h>
@class NSOutlineView;

@interface TreeNode : NSObject {
    // Store our instance variables in a mutable dictionary to simplify
    // coding and decoding tree nodes as an XML property list.
    // Any subclasses can use this dictionary to store their own instance data.
    // We will use this text encoding for both open/save file and copy/paste.
    NSMutableDictionary* nodeDictionary;
    // The variables to be represented are:
    // NSString* nodeNumber	- x.x.x rule number
    // NSMutableArray* children	- array of children if any
    // TreeNode* nodeParent		- link to parent
	// NSNumber* expandedState	- remember if this item was expanded.
     
    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding
	int nodeCount;	// cache nodeCount for efficiency
}

+ (TreeNode *)treeNode;
- (id)init;
- (void) dealloc;

// accesors
- (NSMutableDictionary *)nodeDictionary;
- (void)setNodeDictionary:(NSMutableDictionary *)value;
- (NSString *)nodeNumber;
- (void)setNodeNumber:(NSString *)value;
- (NSMutableArray *)children;
- (void)setChildren:(NSMutableArray *)value;
- (id)nodeParent;
- (void)setNodeParent:(TreeNode *)value;
- (int)nodeCount;
- (void)setNodeCount:(int)value;

// access hierarchy
- (unsigned)numberOfChildren;
- (unsigned)nodeIndex;
- (unsigned)indexOfChild:(TreeNode *)anObject;
- (id)childAtIndex:(int)index;
- (void)insertChild:(TreeNode *)item atIndex:(unsigned)index;
- (BOOL)replaceChildAtIndex:(unsigned)index withChild:(TreeNode *)item;
- (BOOL)addChild:(TreeNode *)item;
- (BOOL)removeChild:(TreeNode *)child;
- (void)removeFromParent;
- (BOOL)insertNextItem:(TreeNode *)item;

// identify subtrees
- (BOOL)isDescendantOfNode:(TreeNode *)node;
- (BOOL)isDescendantOfNodeInArray:(NSArray*)nodes;
+ (NSArray *)treeCover:(NSArray *)nodes;

// expanded state
- (void)saveExpandedForOutlineView:(NSOutlineView *)olv;
- (void)restoreExpandedForOutlineView:(NSOutlineView *)olv;
- (NSNumber *)expandedState;
- (void)setExpandedState:(NSNumber *)value;
@end


// instance variable keys
#define TN_nodeNumber		@"nodeNumber"
#define TN_children			@"children"
#define TN_nodeParent		@"nodeParent"
#define TN_expandedState	@"expandedState"
// default capacity for TN dictionary
#define TN_capacity	20
