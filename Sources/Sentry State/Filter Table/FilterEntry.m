//
//  FilterEntry.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Tue Aug 06 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate a hierarchical filter entry.

#import "FilterEntry.h"

@implementation FilterEntry
+ (FilterEntry *)filterEntry
{
    return [[[FilterEntry alloc] init] autorelease];
}

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
        // by default object for key is nil
            // filter spec
        [nodeDictionary setObject:@"Any" forKey:FE_propertyName];
        [nodeDictionary setObject:@"==" forKey:FE_relationName];
        [nodeDictionary setObject:@"->" forKey:FE_filterActionName];
		// setup arrays for converting menu index to name
		sd = [PSSharedDictionary sharedInstance];
		if (![sd objectForKey:FE_property]) {
			[sd setObject:[NSArray arrayWithObjects:
				@"Any", @"None", @"Direction", @"Interface", @"Include",
					@"Source MAC Address", @"Dest MAC Address", @"__1",
				@"Source net", @"Dest net", @"Protocol", @"IPFragmentOffset", @"IPOptions",
					@"ICMP type", @"ICMP code",@"__2",
				@"TCP header flags", @"TCPOptions", @"Source port", @"Dest port",
					@"Data content", @"URL keyword", @"__3",
				@"Time of day", @"Day of week", @"Date and time", @"Idle seconds",
					@"Parent idle seconds", @"Parent match count", @"Parent match rate", @"Parent byte count",						nil] forKey:FE_property];
		}
		if (![sd objectForKey:FE_relation]) {
			[sd setObject:[NSArray arrayWithObjects:
				@"==", @"!=", @"a=A", @">=", @"<=",
				nil] forKey:FE_relation];
		}
		if (![sd objectForKey:FE_filterAction]) {
			[sd setObject:[NSArray arrayWithObjects:
				@"->", @"++", @"Group", @"Exit group", @"Pass", @"Delete", @"Reject",
				@"Drop connection", @"Keep address", @"Keep invalid", @"Authorize", @"Trigger", @"Delay",
				@"Rate limit in", @"Rate limit out", @"Route to",
				@"Log", @"Dont log", @"Alert", @"Email", @"URL", @"Reset parent", @"AppleScript",
				nil] forKey:FE_filterAction];
		}
    }
    return self;
}

// =================================================================================
// accessors
// =================================================================================
- (NSNumber *)property {
	NSNumber* returnValue =  nil;
	NSString* str;
	// if we have a redundant name, use it
	if ((str = [self propertyName])) {
		NSInteger index = [[sd objectForKey:FE_property] indexOfObject:str];
		if (index != NSNotFound) returnValue = [NSNumber numberWithInt:index];
		else returnValue = [nodeDictionary objectForKey:FE_property];
	}
	else returnValue = [nodeDictionary objectForKey:FE_property];
	return returnValue;
}
- (void)setProperty:(NSNumber *)value {
	[self setPropertyName:[[sd objectForKey:FE_property] objectAtIndex:[value intValue]]];
	//[nodeDictionary setObject:value forKey:FE_property];	// see setPropertyName
}

- (NSNumber *)relation {
	NSNumber* returnValue =  nil;
	NSString* str;
	// if we have a redundant name, use it
	if ((str = [self relationName])) {
		NSInteger index = [[sd objectForKey:FE_relation] indexOfObject:str];
		if (index != NSNotFound) returnValue = [NSNumber numberWithInt:index];
		else returnValue = [nodeDictionary objectForKey:FE_relation];
	}
	else returnValue = [nodeDictionary objectForKey:FE_relation];
	return returnValue;
}
- (void)setRelation:(NSNumber *)value {
	[self setRelationName:[[sd objectForKey:FE_relation] objectAtIndex:[value intValue]]];
	//[nodeDictionary setObject:value forKey:FE_relation];	// see setRelationName
}

- (NSString *)propertyValue {
	NSString* returnValue = [nodeDictionary objectForKey:FE_propertyValue];
	if ([[self property] intValue] == kFilterDateAndTime) {
		returnValue = [[NSDate dateWithTimeIntervalSince1970:[returnValue intValue]] description];
	}
	return returnValue;
}
- (void)setPropertyValue:(NSString *)value {
	if (value) {
		if ([[self property] intValue] == kFilterDateAndTime) {
			NSDate* date;
			unsigned long seconds;
			date = [NSDate dateWithString:value];
			seconds = [date timeIntervalSince1970];
			value = [NSString stringWithFormat:@"%ld",seconds];
		}
		[nodeDictionary setObject:value forKey:FE_propertyValue];
	}
	else [nodeDictionary removeObjectForKey:FE_propertyValue];
}

- (NSNumber *)filterAction {
	NSNumber* returnValue =  nil;
	NSString* str;
	// if we have a redundant name, use it
	if ((str = [self filterActionName])) {
		// perform name conversion if needed
		// look for in list
		NSInteger index = [[sd objectForKey:FE_filterAction] indexOfObject:str];
		if (index != NSNotFound) returnValue = [NSNumber numberWithInt:index];
		else returnValue = [nodeDictionary objectForKey:FE_filterAction];
	}
	else returnValue = [nodeDictionary objectForKey:FE_filterAction];
	return returnValue;
}
- (void)setFilterAction:(NSNumber *)value {
	[self setFilterActionName:[[sd objectForKey:FE_filterAction] objectAtIndex:[value intValue]]];
	//[nodeDictionary setObject:value forKey:FE_filterAction];
}

- (NSString *)parameter { return [nodeDictionary objectForKey:FE_parameter]; }
- (void)setParameter:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:FE_parameter];
    else [nodeDictionary removeObjectForKey:FE_parameter];
}

- (NSNumber *)matchCount {
	id returnValue;
	returnValue = [nodeDictionary objectForKey:FE_matchCount];
	if ([returnValue isKindOfClass:[NSString class]]) {
		NSScanner* scanner;
		int64_t value;
		scanner = [NSScanner scannerWithString:returnValue];
		if (![scanner scanLongLong:&value]) value = 0;
		returnValue = [NSNumber numberWithLongLong:value];
	}
	return returnValue;
}
- (void)setMatchCount:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:FE_matchCount];
    else [nodeDictionary removeObjectForKey:FE_matchCount];
}

- (NSNumber *)matchDelta { return [nodeDictionary objectForKey:FE_matchDelta]; }
- (void)setMatchDelta:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:FE_matchDelta];
    else [nodeDictionary removeObjectForKey:FE_matchDelta];
}

- (NSNumber *)byteCount {
	id returnValue;
	returnValue = [nodeDictionary objectForKey:FE_byteCount];
	if ([returnValue isKindOfClass:[NSString class]]) {
		NSScanner* scanner;
		int64_t value;
		scanner = [NSScanner scannerWithString:returnValue];
		if (![scanner scanLongLong:&value]) value = 0;
		returnValue = [NSNumber numberWithLongLong:value];
	}
	return returnValue;
}
- (void)setByteCount:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:FE_byteCount];
    else [nodeDictionary removeObjectForKey:FE_byteCount];
}

- (NSNumber *)byteDelta { return [nodeDictionary objectForKey:FE_byteDelta]; }
- (void)setByteDelta:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:FE_byteDelta];
    else [nodeDictionary removeObjectForKey:FE_byteDelta];
}

- (NSNumber *)lastTime { return [nodeDictionary objectForKey:FE_lastTime]; }
- (void)setLastTime:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:FE_lastTime];
    else [nodeDictionary removeObjectForKey:FE_lastTime];
}

- (NSString *)nodeName { return [nodeDictionary objectForKey:FE_nodeName]; }
- (void)setNodeName:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:FE_nodeName];
    else [nodeDictionary removeObjectForKey:FE_nodeName];
}
- (NSNumber *)enabled { return [nodeDictionary objectForKey:FE_enabled]; }
- (void)setEnabled:(NSNumber *)value {
	[nodeDictionary setObject:value forKey:FE_enabled];
}
// =================================================================================
// redundant names
// =================================================================================
- (NSString *)propertyName { return [nodeDictionary objectForKey:FE_propertyName]; }
- (void)setPropertyName:(NSString *)value {
	if (value) [nodeDictionary setObject:value forKey:FE_propertyName];
	else [nodeDictionary removeObjectForKey:FE_propertyName];
	// corresponding index
	NSNumber* nValue = [self property];
	if (nValue) [nodeDictionary setObject:nValue forKey:FE_property];
	else [nodeDictionary removeObjectForKey:FE_property];
}

- (NSString *)relationName { return [nodeDictionary objectForKey:FE_relationName]; }
- (void)setRelationName:(NSString *)value {
	if (value) [nodeDictionary setObject:value forKey:FE_relationName];
	else [nodeDictionary removeObjectForKey:FE_relationName];
	// corresponding index
	NSNumber* nValue = [self relation];
	if (nValue) [nodeDictionary setObject:nValue forKey:FE_relation];
	else [nodeDictionary removeObjectForKey:FE_relation];
}

- (NSString *)filterActionName { return [nodeDictionary objectForKey:FE_filterActionName]; }
- (void)setFilterActionName:(NSString *)value {
	if (value) [nodeDictionary setObject:value forKey:FE_filterActionName];
	else [nodeDictionary removeObjectForKey:FE_filterActionName];
	// corresponding index
	NSNumber* nValue = [self filterAction];
	if (nValue) [nodeDictionary setObject:nValue forKey:FE_filterAction];
	else [nodeDictionary removeObjectForKey:FE_filterAction];
}


// =================================================================================
// text representation
// =================================================================================
- (NSString *)description
{
	return [dictionaryFromTree(self) description];
}

@end


// =================================================================================
// dictionary coding
// =================================================================================
// ---------------------------------------------------------------------------------
//	¥ dictionaryFromTree()
// ---------------------------------------------------------------------------------
//	Convert tree node to corresponding dictionary including any children
//  Creates a copy so as not to disrupt the existing structure of tree nodes
NSMutableDictionary* dictionaryFromTree(TreeNode* tree)
{
    NSMutableDictionary* theDictionary;
    NSMutableArray* childrenAsNode;
    NSMutableArray* childrenAsDictionary =  nil;
    unsigned index, count;
    NSMutableDictionary* itemDictionary;
    TreeNode* node;
    
    // create a mutable copy of the node dictionary
    theDictionary = [[[NSMutableDictionary alloc] initWithCapacity:TN_capacity] autorelease];
    [theDictionary addEntriesFromDictionary:[tree nodeDictionary]];
    // remove link to parent to avoid looping
    [theDictionary removeObjectForKey:TN_nodeParent];
    // convert children (using recursion)
    childrenAsNode = [theDictionary objectForKey:TN_children];
    if (childrenAsNode) {
        // store in a new array
        childrenAsDictionary = [NSMutableArray array];
		count = [childrenAsNode count];
        for (index=0; index<count; index++) {
            node = [childrenAsNode objectAtIndex:index];
            itemDictionary = dictionaryFromTree(node);
            [childrenAsDictionary addObject:itemDictionary];
        }
        // point dictionary to new array of children as dictionaries
        [theDictionary setObject:childrenAsDictionary forKey:TN_children];
    }
    return theDictionary;    
}

// ---------------------------------------------------------------------------------
//	¥ treeFromDictionary()
// ---------------------------------------------------------------------------------
FilterEntry* treeFromDictionary(NSMutableDictionary* dictionary)
{
    NSMutableArray* childrenAsDictionary;
    NSMutableArray* childrenAsNode = nil;
    unsigned index, count;
    NSMutableDictionary* itemDictionary;
    FilterEntry* node;
    FilterEntry* parent;
	NSString* str;
    
    // check for nil input
    if (!dictionary) return nil;
    // create parent
    parent = [FilterEntry filterEntry];
    [parent setNodeDictionary:dictionary];	// set dictionary for parent
	// synchronize redundant names and index values 
	if ((str = [parent propertyName])) [parent setPropertyName:str];
	else [parent setProperty:[parent property]];
	if ((str = [parent relationName])) [parent setRelationName:str];
	else [parent setRelation:[parent relation]];
	if ((str = [parent filterActionName])) [parent setFilterActionName:str];
	else [parent setFilterAction:[parent filterAction]];
    // initialize children if any from corresponding dictionaries
    childrenAsDictionary = [dictionary objectForKey:TN_children];
    if (childrenAsDictionary) {
        // store in a new array
        childrenAsNode = [NSMutableArray array];
		count = [childrenAsDictionary count];
        for (index=0; index<count; index++) {
            itemDictionary = [childrenAsDictionary objectAtIndex:index];
            node = treeFromDictionary(itemDictionary);
            [childrenAsNode addObject:node];
            [node setNodeParent:parent];
        }
        // set children of entry
        [parent setChildren:childrenAsNode];
    }
    return parent;
}

// ---------------------------------------------------------------------------------
//	¥ removeKeysFromDictionaryTree()
// ---------------------------------------------------------------------------------
//  Iterate tree of dictionaries to remove keys from each one
void removeKeysFromDictionaryTree(NSArray* keys, NSMutableDictionary* dictionary)
{
	NSEnumerator* enKey;
	NSEnumerator* enChild;
	NSString* key;
	NSMutableDictionary* child;
	
	// remove keys from root
	enKey = [keys objectEnumerator];
	while (key = [enKey nextObject]) {
		[dictionary removeObjectForKey:key];
	}
	// use recursion to process any children
	enChild = [[dictionary objectForKey:TN_children] objectEnumerator];
	while (child = [enChild nextObject]) {
		removeKeysFromDictionaryTree(keys, child);
	}
}

