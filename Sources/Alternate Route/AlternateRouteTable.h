//  AlternateRouteTable.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Wed Jan 3 2007.
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.
//
//	Delegate and data source for alternateRoute table

#import <Cocoa/Cocoa.h>
#import "AlternateRouteEntry.h"

@interface AlternateRouteTable : NSObject <NSCopying>
{
	NSMutableArray* alternateRouteArray;
}

- (id)init;
- (void)dealloc;
- (void)removeAllObjects;

- (NSMutableArray *)alternateRouteArray;
- (void)setAlternateRouteArray:(NSMutableArray *)value;
- (NSArray *)arrayOfDictionaries;
- (BOOL)loadArrayOfDictionaries:(NSArray *)inArray;
// access helpers
- (int)addObject:(id)entry;
    // add an object to the end of the Table data array
    // return its row index;
- (BOOL)removeObjectAtIndex:(int)index;
- (BOOL)replaceObjectAtIndex:(int)index withObject:(id)object;
    // replace object for specified index
    // return NO if index is beyond end of array+1
- (id)objectAtIndex:(unsigned)row;
    // get object value from Table data array for specified index.
    // Return nil if index is beyond end of array.
- (AlternateRouteEntry *)routeForGatewayIP:(NSString *)gatewayIP;
- (unsigned)count;

@end
