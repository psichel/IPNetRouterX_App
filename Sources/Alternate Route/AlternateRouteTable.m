//  AlternateRouteTable.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Wed Jan 3 2007.
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for alternateRoute table

#import "AlternateRouteTable.h"
#import "SentryState.h"
#import "kftSupport.h"
#import "SystemConfiguration.h"
#import "IPSupport.h"
#import "HardwareAddress.h"

@implementation AlternateRouteTable

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
	if (self = [super init]) {
        // initialize our instance variables
		alternateRouteArray = [[NSMutableArray alloc] init];
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
    [alternateRouteArray release];	alternateRouteArray = nil;
    [super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ removeAllObjects
// ---------------------------------------------------------------------------------
- (void)removeAllObjects {
    [alternateRouteArray removeAllObjects];
}

// ---------------------------------------------------------------------------------
//	¥ alternateRouteArray
// ---------------------------------------------------------------------------------
// Get or set underlying NSMutableArray object to examine or update alternateRoute list
- (NSMutableArray *)alternateRouteArray { return alternateRouteArray; }
- (void)setAlternateRouteArray:(NSMutableArray *)value {
	[value retain];
	[alternateRouteArray release];
	alternateRouteArray = value;
}

// ---------------------------------------------------------------------------------
//	¥ arrayOfDictionaries
// ---------------------------------------------------------------------------------
// Return as array of dictionaries for export as XML
- (NSArray *)arrayOfDictionaries {
	NSEnumerator* en;
	NSMutableArray* arrayOfDictionaries;
	AlternateRouteEntry* routeE;
	
	arrayOfDictionaries = [NSMutableArray array];
	en = [alternateRouteArray objectEnumerator];
	while (routeE = [en nextObject]) {
		[arrayOfDictionaries addObject:[routeE nodeDictionary]];
	}
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
	AlternateRouteEntry* routeE;
	
	en = [inArray objectEnumerator];
	while (nodeDictionary = [en nextObject]) {
		routeE = [AlternateRouteEntry entryFromDictionary:nodeDictionary];
		if (routeE) [self addObject:routeE];
	}
	return returnValue;
}

#pragma mark -- Access Helpers --

// ---------------------------------------------------------------------------------
//	¥ addObject:
// ---------------------------------------------------------------------------------
// add an object to the end of the Table data array
// return its index;
- (int)addObject:(id)entry {
	NSString* gatewayIP;
	AlternateRouteEntry* oldEntry;
    int count, i;
	BOOL found = NO;
	
    count = [alternateRouteArray count];
	// check for dup
	gatewayIP = [entry gatewayIP];
	for (i=0; i<count; i++) {
		oldEntry = [self objectAtIndex:i];
		if ([gatewayIP isEqualTo:[oldEntry gatewayIP]]) {
			found = YES;
			count = i;
			// replace old entry with new information
			[oldEntry setNodeDictionary:[entry nodeDictionary]];
			break;
		}
	}
    if (!found) [alternateRouteArray addObject:entry];
    return count;
}

// ---------------------------------------------------------------------------------
//	¥ removeObjectAtIndex:
// ---------------------------------------------------------------------------------
- (BOOL)removeObjectAtIndex:(int)index
{
    int count;
    BOOL result = NO;
    count = [alternateRouteArray count];
    if (index < count) {
        [alternateRouteArray removeObjectAtIndex:index];
        result = YES;
    }
    return result;
}

// ---------------------------------------------------------------------------------
//	¥ replaceObjectAtIndex:
// ---------------------------------------------------------------------------------
// replace object for specified index
// return NO if index is beyond end of array+1
- (BOOL)replaceObjectAtIndex:(int)index withObject:(id)object {
    int count;
    BOOL result = NO;
    count = [alternateRouteArray count];
    if (index < count) {
        [alternateRouteArray replaceObjectAtIndex:index withObject:object];
        result = YES;
    }
    else if (index == count) {
        [self addObject:object];
        result = YES;
    }
    return result;
}

// ---------------------------------------------------------------------------------
//	¥ objectAtIndex:
// ---------------------------------------------------------------------------------
// get object value from Table data array for specified index.
// Return nil if index is beyond end of array.
- (id)objectAtIndex:(unsigned)index {
    id result;
    int count;
    count = [alternateRouteArray count];
    if (index < count) {
        result = [alternateRouteArray objectAtIndex:index];
    } else {
        result = nil;
    }
    return result;
}

// ---------------------------------------------------------------------------------
//	¥ routeForGatewayIP:
// ---------------------------------------------------------------------------------
// get object value from Table data array for matching IP addres.
// Return nil if index is beyond end of array.
- (AlternateRouteEntry *)routeForGatewayIP:(NSString *)gatewayIP {
    AlternateRouteEntry *result = nil;
	AlternateRouteEntry *entry;
	NSEnumerator *en = [alternateRouteArray objectEnumerator];
    while (entry = [en nextObject]) {
		if ([gatewayIP isEqualTo:[entry gatewayIP]]) {
			result = entry;
			break;
		}
	}
    return result;
}

// ---------------------------------------------------------------------------------
//	¥ count
// ---------------------------------------------------------------------------------
- (unsigned)count
{
    return [alternateRouteArray count];
}

// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    AlternateRouteTable *copy;
    copy = [[AlternateRouteTable allocWithZone:zone] init];
    [copy loadArrayOfDictionaries:[self arrayOfDictionaries]];
    return copy;
}

@end
