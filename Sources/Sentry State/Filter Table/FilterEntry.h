//
//  FilterEntry.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Tue Aug 06 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate a hierarchical filter entry.
//  Each filter entry may contain an array of child filter entries.

#import <Foundation/Foundation.h>
#import "TreeNode.h"
#import "PSSharedDictionary.h"
#import "FilterTypes.h"

@interface FilterEntry : TreeNode {
    // Store our instance variables in a mutable dictionary to simplify
    // coding and decoding filter entries as an XML property list.
    // We will use this text encoding for both open/save file and copy/paste.
    
    // The variables to be represented are:
    // NSNumber* property		- packet property to compare
    // NSNumber* relation		- relation to value
    // NSString* propertyValue	- value to compare against
    // NSNumber* filterAction	- what to do if compare succeeds
	// NSString* parameter		- optional action parameter
	// NSNumber* matchCount		- kernel matchCount of this entry
	// NSNumber* matchDelta		- change in kernel matchCount of this entry
	// NSNumber* byteCount		- byte count of traffic matching this entry
	// NSNumber* byteDelta		- change in byte count of traffic matching this entry
	// NSNumber* lastTime		- time of last update as timval seconds
	// NSNumber* enabled		- rule enabled
    // NSString* nodeName		- 31 character name describing this entry
    
    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding

    // For long term stability, we provide two accessors for some variables.
    // The NSNumber is used internally for convenience.
    // The NSString is actually stored in the dictionary
    // in case the number (menu index) changes.

    // NSString* propertyName
    // NSString* relationName
    // NSString* filterActionName
    PSSharedDictionary* sd;		// dictionary holding translation arrays
}

+ (FilterEntry *)filterEntry;
- (id)init;

// accessors
- (NSNumber *)property;
- (void)setProperty:(NSNumber *)value;
- (NSNumber *)relation;
- (void)setRelation:(NSNumber *)value;
- (NSString *)propertyValue;
- (void)setPropertyValue:(NSString *)value;
- (NSNumber *)filterAction;
- (void)setFilterAction:(NSNumber *)value;
- (NSString *)parameter;
- (void)setParameter:(NSString *)value;

- (NSNumber *)matchCount;
- (void)setMatchCount:(NSNumber *)value;
- (NSNumber *)matchDelta;
- (void)setMatchDelta:(NSNumber *)value;
- (NSNumber *)byteCount;
- (void)setByteCount:(NSNumber *)value;
- (NSNumber *)byteDelta;
- (void)setByteDelta:(NSNumber *)value;

- (NSNumber *)lastTime;
- (void)setLastTime:(NSNumber *)value;
- (NSString *)nodeName;
- (void)setNodeName:(NSString *)value;
- (NSNumber *)enabled;
- (void)setEnabled:(NSNumber *)value;
    // redundant names
- (NSString *)propertyName;
- (void)setPropertyName:(NSString *)value;
- (NSString *)relationName;
- (void)setRelationName:(NSString *)value;
- (NSString *)filterActionName;
- (void)setFilterActionName:(NSString *)value;

// text representation
- (NSString *)description;

@end

// dictionary coding
NSMutableDictionary* dictionaryFromTree(TreeNode* tree);
FilterEntry* treeFromDictionary(NSMutableDictionary* dictionary);
void removeKeysFromDictionaryTree(NSArray* keys, NSMutableDictionary* dictionary);

// instance variable keys
#define FE_property	@"property"
#define FE_relation	@"relation"
#define FE_propertyValue	@"propertyValue"
#define FE_filterAction	@"filterAction"
#define FE_parameter @"parameter"
#define FE_matchCount @"matchCount"
#define FE_matchDelta @"matchDelta"
#define FE_byteCount @"byteCount"
#define FE_byteDelta @"byteDelta"
#define FE_lastTime @"lastTime"
#define FE_nodeName	@"nodeName"
#define FE_enabled @"enabled"

#define FE_propertyName	@"propertyName"
#define FE_relationName	@"relationName"
#define FE_filterActionName	@"filterActionName"

// default capacity for FE dictionary
#define FE_capacity	20

// Table Columns
#define CID_NUMBER @"nodeNumber"
#define CID_ENABLED @"enabled"
#define CID_NAME @"nodeName"
#define CID_PROPERTY @"property"
#define CID_RELATION @"relation"
#define CID_VALUE @"propertyValue"
#define CID_ACTION @"filterAction"
#define CID_PARAMETER @"parameter"
#define CID_MATCHCOUNT @"matchCount"
#define CID_BYTECOUNT @"byteCount"
#define CID_LASTTIME @"lastTime"

#define FilterEntryPboardType 	@"FilterEntryPboardType"
