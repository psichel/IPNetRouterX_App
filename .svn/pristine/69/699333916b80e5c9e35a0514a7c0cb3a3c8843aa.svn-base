//
//  TDDataSource.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 1/24/07.
//  Copyright 2007 Sustainable Softworks. All rights reserved.
//

#import "TDDataSource.h"
#import "TrafficDiscoveryModel.h"
#import "TDEntry.h"
#import "TrafficDiscoveryWC.h"
#import "PSSharedDictionary.h"
#import "kftSupport.h"

@implementation TDDataSource

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		serviceTable = [[NSMutableDictionary alloc] init];
		deviceTable = [[NSMutableDictionary alloc] init];
		netflowTable = [[NSMutableDictionary alloc] init];
		sortedKeys = nil;
		mySortBy = nil;
		myViewBy = kViewByService;
		{
			u_int8_t buf[12];
			PSData db;
			db.bytes = &buf[0];
			db.length = 0;
			db.bufferLength = 12;
			db.offset = 0;
			appendHexInt(&db, (int)self, 8);
			appendBytes(&db, (u_int8_t*)"_", 1);
			buf[9] = 0;	// null terminate string
			clientPrefix = [[NSString stringWithCString:(char*)db.bytes length:db.length] retain];
		}
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	// release ivars
	[serviceTable release];	serviceTable = nil;
	[deviceTable release]; deviceTable = nil;
	[netflowTable release]; netflowTable = nil;
	[sortedKeys release]; sortedKeys = nil;
	[mySortBy release]; mySortBy = nil;
	[clientPrefix release]; clientPrefix = nil;
	[super dealloc];
}

#pragma mark Accessors
// ---------------------------------------------------------------------------------
//	• delegate
// ---------------------------------------------------------------------------------
- (id)delegate { return delegate; }
- (void)setDelegate:(id)value
{
	[value retain];
	[delegate release];
	delegate = value;
}

// ---------------------------------------------------------------------------------
//	• viewBy:
// ---------------------------------------------------------------------------------
- (int)viewBy
{
	return myViewBy;
}
- (void)setViewBy:(int )value
{
	if (myViewBy != value) {
		[sortedKeys release]; sortedKeys = nil;
	}
	myViewBy = value;
}

// ---------------------------------------------------------------------------------
//	• sortBy:
// ---------------------------------------------------------------------------------
- (NSString *)sortBy
{
	return [[mySortBy retain] autorelease];
}
- (void)setSortBy:(NSString *)value
{
	if (value && ![mySortBy isEqualTo:value]) {
		[sortedKeys release]; sortedKeys = nil;
	}
	[value retain];
	[mySortBy release];
	mySortBy = value;
}

// ---------------------------------------------------------------------------------
//	• updateSort
// ---------------------------------------------------------------------------------
- (void)updateSort {
	[sortedKeys release]; sortedKeys = nil;
}

// ---------------------------------------------------------------------------------
//	• tdEntryForRow:
// ---------------------------------------------------------------------------------
- (TDEntry *)tdEntryForRow:(int)row
{
	NSMutableDictionary* plist;
	NSString* identifier;						// tdEntry key in dictionary
	TDEntry* tdEntry = nil;
	// determine which table
	if (myViewBy == kViewByDevice) plist = deviceTable;
	else if (myViewBy == kViewByService) plist = serviceTable;
	else plist = netflowTable;

	identifier = [sortedKeys objectAtIndex:row];
	tdEntry = [plist objectForKey:identifier];
	return tdEntry;
}


#pragma mark Request update
// ---------------------------------------------------------------------------------
//	• tableUpdate
// ---------------------------------------------------------------------------------
// update table based on current WC (delegate) settings
- (void)tableUpdate
{
	// get delegate settings
	int viewBy = [delegate viewBy];
	NSString* sortBy = [delegate sortBy];
	int interval = [delegate interval];
	NSCalendarDate* trafficDiscoveryTime = [delegate showDate];
	NSTimeInterval timeInterval = [trafficDiscoveryTime timeIntervalSince1970];
	int showNow = [delegate showNow];
	
	// update our own Data Source settings
	[self setViewBy:viewBy];
	[self setSortBy:sortBy];
}

// ---------------------------------------------------------------------------------
//	• reloadPlot
// ---------------------------------------------------------------------------------
// reload plot based on current WC (delegate) settings
// Plot index starts from zero for present time at the far right and counts up to go left
- (void)reloadPlotFromIndex:(int)fromIndex toIndex:(int)toIndex
{
	// get delegate settings
	int viewBy = [delegate viewBy];
	NSString* sortBy = [delegate sortBy];
	int interval = [delegate interval];
	NSCalendarDate* trafficDiscoveryTime = [delegate showDate];
	NSTimeInterval timeInterval = [trafficDiscoveryTime timeIntervalSince1970];
	int showNow = [delegate showNow];
	NSString* dayGroupKey = [delegate dayGroupKey];
	
	// update our own Data Source settings
	[self setViewBy:viewBy];
	[self setSortBy:sortBy];
}

// ---------------------------------------------------------------------------------
//	• requestUpdates
// ---------------------------------------------------------------------------------
// request real time traffic updates from TDModel
- (void)requestUpdates
{
	// get delegate settings
	int viewBy = [delegate viewBy];
	NSString* sortBy = [delegate sortBy];
	int interval = [delegate interval];
	NSCalendarDate* trafficDiscoveryTime = [delegate showDate];
	NSTimeInterval timeInterval = [trafficDiscoveryTime timeIntervalSince1970];
	int showNow = [delegate showNow];
	
	// update our own Data Source settings
	[self setViewBy:viewBy];
	[self setSortBy:sortBy];
}


#pragma mark Receive Data
// ---------------------------------------------------------------------------------
//	• receiveDictionary:
// ---------------------------------------------------------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSEnumerator* enumerator;
    id key;

	enumerator = [dictionary keyEnumerator];
	while ((key = [enumerator nextObject])) { 
		/* code that uses the returned key */
		if (![key isKindOfClass:[NSString class]]) continue;
		// check clientPrefix to identify responses for me
		if ([key hasPrefix:clientPrefix]) {
			// assume it's a TD entry with key that identifies the entry
			TDEntry* tdEntry = [dictionary objectForKey:key];
			switch ([tdEntry viewBy]) {
				case kViewByDevice:
					[deviceTable setObject:tdEntry forKey:[tdEntry identifier]];
//NSLog(@"TDDataSource device traffic"); // ***
					break;
				case kViewByService:
					[serviceTable setObject:tdEntry forKey:[tdEntry identifier]];
//NSLog(@"TDDataSource service traffic"); // ***
					break;
				case kViewByNetflow:
					[netflowTable setObject:tdEntry forKey:[tdEntry identifier]];
//NSLog(@"TDDataSource netflow traffic %@ total %d",[tdEntry identifier],[netflowTable count]); // ***
					break;
				case kViewByPlotEntry:
					[delegate loadPlotEntry:tdEntry];
NSLog(@"TDDataSource plotEntry traffic"); // ***
					break;
			}
		}
		// just pass it on
		else {
			[delegate receiveDictionary:dictionary];
//NSLog(@"TDDataSource receive parameterUpdate"); // ***
		}
	}	// while ((key = [enumerator nextObject]))
	[pool release];
}

#pragma mark NSTableDataSource
// ---------------------------------------------------------------------------------
//	• numberOfRowsInTableView:
// ---------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	int viewBy = [[tableView delegate] viewBy];
	NSMutableDictionary* plist = nil;

	// determine which table
	if (viewBy == kViewByDevice) plist = deviceTable;
	else if (viewBy == kViewByService) plist = serviceTable;
	else plist = netflowTable;
//NSLog(@"TDDataSource numberOfRowsInTableView: %d",[plist count]);		// ***
	return ([plist count]);
}

// ---------------------------------------------------------------------------------
//	• tableView:objectValueForTableColumn:row:
// ---------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)tableView
        objectValueForTableColumn:(NSTableColumn *)tableColumn
        row:(int)row
{
	NSString* returnValue = nil;
	int viewBy = [[tableView delegate] viewBy];	// viewBy
	NSString* sortBy = [[tableView highlightedTableColumn] identifier];
	NSString* cid = [tableColumn identifier];	// column requested
	if (cid) {
		NSMutableDictionary* plist;
		NSString* identifier;						// tdEntry key in dictionary
		TDEntry* tdEntry = nil;
		// determine which table
		if (viewBy == kViewByDevice) plist = deviceTable;
		else if (viewBy == kViewByService) plist = serviceTable;
		else plist = netflowTable;
		// use sort keys to find table row
		[self setViewBy:viewBy];
		[self setSortBy:sortBy];
		if (!sortedKeys) {
			PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
			[sd setObject:mySortBy forKey:kTrafficDiscovery_sortBy];
			sortedKeys = [[plist keysSortedByValueUsingSelector:@selector(compare:)] retain];
		}
		identifier = [sortedKeys objectAtIndex:row];
		tdEntry = [plist objectForKey:identifier];
		// get value from entry
		returnValue = [tdEntry valueForKey:cid];
	}
	return (returnValue);
}

@end
