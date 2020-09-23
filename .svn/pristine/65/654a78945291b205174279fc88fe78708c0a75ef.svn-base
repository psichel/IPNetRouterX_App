//
//  TDDayGroup.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 3/1/06.
//  Copyright 2006 Sustainable Softworks Inc. All rights reserved.
//
#import "TrafficDiscoveryModel.h"
#import "TrafficDiscoveryWC.h"
#import "TDDayGroup.h"
#import "TDEntry.h"
#import "IPSupport.h"

// Private Methods
@interface TDDayGroup (PrivateMethods)
// data access
- (int64_t)bytesInForIndex:(unsigned)index;
- (int64_t)bytesOutForIndex:(unsigned)index;
- (int64_t)totalIn;
- (int64_t)totalOut;
- (int64_t)maxIn;
- (int64_t)maxOut;
@end

@implementation TDDayGroup
// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
		// initialize our instance variables
		bzero(&sampleData, sizeof(daySample_t));
		sampleData.length = sizeof(daySample_t);
		sampleData.type = kIntervalHour;
		sampleData.version = kSampleDataVersion;
		tdHours = [[NSMutableDictionary alloc] initWithCapacity:kTDHoursOfDay];
		tdCache = [[NSMutableDictionary alloc] initWithCapacity:1];
		identifier = nil;
		name = nil;
		bsdName = nil;
		info = nil;
		lastTime = nil;
		viewBy = 0;
		needsUpdate = NO;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[tdHours release]; tdHours = nil;
	[tdCache release]; tdCache = nil;
	[self setIdentifier:nil];
	[self setName:nil];
	[self setBsdName:nil];
	[self setInfo:nil];
	[self setLastTime:nil];
	[super dealloc];
}


#pragma mark -- accessors --
- (NSString*)identifier { return identifier; }
- (void)setIdentifier:(NSString*)value
{
	[value retain];
	[identifier release];
	identifier = value;
}

- (NSString*)name { return name; }
- (void)setName:(NSString*)value
{
	[value retain];
	[name release];
	name = value;
}

- (NSString*)bsdName { return bsdName; }
- (void)setBsdName:(NSString*)value
{
	[value retain];
	[bsdName release];
	bsdName = value;
}

- (NSString*)info { return info; }
- (void)setInfo:(NSString*)value
{
	[value retain];
	[info release];
	info = value;
}

- (NSCalendarDate*)lastTime { return lastTime; }
- (void)setLastTime:(NSCalendarDate*)value;
{
	[value retain];
	[lastTime release];
	lastTime = value;
}

- (int)localEP { return localEP; }
- (void)setLocalEP:(int)value { localEP = value; }
- (int)protocol { return protocol; }
- (void)setProtocol:(int)value { protocol = value; }
- (int)viewBy { return viewBy; }
- (void)setViewBy:(int)value { viewBy = value; }

#pragma mark -- save and restore --
// ---------------------------------------------------------------------------------
//	¥ dictionary
// ---------------------------------------------------------------------------------
- (NSDictionary*)dictionary
{
	NSData* myData = [NSData dataWithBytes:&sampleData length:sizeof(hourSample_t)];
	// convert tdHours to dictionary of dictionaries
	NSMutableDictionary* tdHoursD = [NSMutableDictionary dictionary];
	NSNumber* key;
	TDHourGroup* hourGroup;
	NSEnumerator* en = [tdHours keyEnumerator];
	while (key = [en nextObject]) {
		hourGroup = [tdHours objectForKey:key];
		[tdHoursD setObject:[hourGroup dictionary] forKey:key];
	}
	return [NSDictionary dictionaryWithObjectsAndKeys:
		myData,@"sampleData",
		tdHoursD,@"tdHours",
		identifier,@"identifier",
		name,@"name",
		bsdName,@"bsdName",
		info,@"info",
		lastTime,@"lastTime",
		[NSNumber numberWithInt:localEP],@"localEP",
		[NSNumber numberWithInt:protocol],@"protocol",
		nil];
}

// ---------------------------------------------------------------------------------
//	¥ objectFromDictionary
// ---------------------------------------------------------------------------------
+ (TDDayGroup*)objectFromDictionary:(NSDictionary*)inDictionary
{
	TDDayGroup* object = [[TDDayGroup alloc] init];
	NSDictionary* tdHoursD = [inDictionary objectForKey:@"tdHours"];
	NSNumber* key;
	TDHourGroup* hourGroup;
	NSEnumerator* en = [tdHoursD keyEnumerator];
	while (key = [en nextObject]) {
		hourGroup = [TDHourGroup objectFromDictionary:[tdHoursD objectForKey:key]];
		[object setHourGroupForIndex:[key intValue] withObject:hourGroup];
	}
	[object setSampleData:[inDictionary objectForKey:@"sampleData"]];
	[object setIdentifier:[inDictionary objectForKey:@"identifier"]];
	[object setName:[inDictionary objectForKey:@"name"]];
	[object setBsdName:[inDictionary objectForKey:@"bsdName"]];
	[object setInfo:[inDictionary objectForKey:@"info"]];
	NSDate* date = [inDictionary objectForKey:@"lastTime"];
	[object setLastTime:[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:[date timeIntervalSinceReferenceDate]]];
	[object setLocalEP:[[inDictionary objectForKey:@"localEP"] intValue]];
	[object setProtocol:[[inDictionary objectForKey:@"protocol"] intValue]];
	return [object autorelease];
}
- (void)setSampleData:(NSData*)inData
{
	daySample_t* dp;
	dp = (daySample_t *const)[inData bytes];
	if (dp->version == kSampleDataVersion) {	
		int length = [inData length];
		if (length > sizeof(daySample_t)) length = sizeof(daySample_t);
		memcpy(&sampleData, [inData bytes], length);
	}
}

#pragma mark -- data access --
// ---------------------------------------------------------------------------------
//	¥ tdEntryForDate:interval:
// ---------------------------------------------------------------------------------
- (TDEntry *)tdEntryForDate:(NSCalendarDate*)trafficDiscoveryTime interval:(int)interval
{
	TDEntry* tdEntry = nil;
	TDEntry* attachEntry = nil;
	TDHourGroup* hourGroup;
	TDMinuteGroup* minuteGroup;

	// check cache
	NSString* key = [NSString stringWithFormat:@"%@ %d",trafficDiscoveryTime,interval];
	tdEntry = [tdCache objectForKey:key];
	if (!tdEntry) {
		if (interval == kIntervalSecond) {
			hourGroup = [self hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:NO];
			minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:NO];
			tdEntry = [minuteGroup tdEntryForIndex:[trafficDiscoveryTime secondOfMinute]];
		}
		else if (interval == kIntervalMinute) {
			hourGroup = [self hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:NO];
			tdEntry = [hourGroup tdEntryForIndex:[trafficDiscoveryTime minuteOfHour]];
		}
		else if (interval == kIntervalHour) {
			tdEntry = [self tdEntryForIndex:[trafficDiscoveryTime hourOfDay]];
		}
		else if (interval == kIntervalDay) {
			// replace with week group when ready
			tdEntry = [self tdEntryForIndex:[trafficDiscoveryTime hourOfDay]];
		}
		else if (interval == kIntervalRecent) {	// recent used to sort by recent second data
			hourGroup = [self hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:NO];
			minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:NO];
			tdEntry = [minuteGroup tdEntryRecentForIndex:[trafficDiscoveryTime secondOfMinute]];
		}
		// might not be an hour or minute group for this time
		if (!tdEntry) {
			tdEntry = [[[TDEntry alloc] init] autorelease];
			[tdEntry setValue:bsdName forKey:TDE_bsdName];
		}
		if (tdEntry) {
			// get attach info from corresponding attachEntry
			NSString* attachName = [tdEntry bsdName];
			attachEntry = [[TrafficDiscoveryModel sharedInstance] tdEntryForAttach:attachName
				date:trafficDiscoveryTime interval:interval];
			if (!attachEntry) {
				attachName = @"en4";	// primary interface SCF? ***
				attachEntry = [[TrafficDiscoveryModel sharedInstance] tdEntryForAttach:attachName
					date:trafficDiscoveryTime interval:interval];
			}
				// transfer attachBytes
			[tdEntry setValue:[attachEntry valueForKey:TDE_bytesIn] forKey:TDE_attachBytesIn];
			[tdEntry setValue:[attachEntry valueForKey:TDE_bytesOut] forKey:TDE_attachBytesOut];
				// calculate percent
			int64_t bytesIn = 0;
			int64_t bytesOut = 0;
			int64_t attachBytesIn = 0;
			int64_t attachBytesOut = 0;
			NSNumber* num;
			num = [tdEntry attachBytesIn]; if (num) attachBytesIn = [num longLongValue];
			num = [tdEntry attachBytesOut]; if (num) attachBytesOut = [num longLongValue];
			num = [tdEntry bytesIn]; if (num) bytesIn = [num longLongValue];
			num = [tdEntry bytesOut]; if (num) bytesOut = [num longLongValue];
			int percentIn = 0;
			int percentOut = 0;
			if (attachBytesIn) percentIn = bytesIn * 100 / attachBytesIn;
			if (attachBytesOut) percentOut = bytesOut * 100 / attachBytesOut;
			if (percentIn) [tdEntry setValue:[NSNumber numberWithInt:percentIn] forKey:TDE_percentIn];
			if (percentOut) [tdEntry setValue:[NSNumber numberWithInt:percentOut] forKey:TDE_percentOut];
			// cache
			[tdCache removeAllObjects];
			[tdCache setObject:tdEntry forKey:key];
		}
		// load other identifying information
		[tdEntry setIdentifier:identifier];
		[tdEntry setService:identifier];
		[tdEntry setName:name];
		[tdEntry setBsdName:bsdName];
		[tdEntry setInfo:info];
		[tdEntry setLastTime:lastTime];
		[tdEntry setViewBy:viewBy];
	}
	return tdEntry;
}

// ---------------------------------------------------------------------------------
//	¥ tdEntryForIndex
// ---------------------------------------------------------------------------------
- (TDEntry*)tdEntryForIndex:(unsigned)index
{
	TDEntry* tdEntry = [[[TDEntry alloc] init] autorelease];
	[tdEntry setDataIndex:index];
	// bytes
	[tdEntry setValue:[NSNumber numberWithInt:[self bytesInForIndex:index]] forKey:TDE_bytesIn];
	[tdEntry setValue:[NSNumber numberWithInt:[self bytesOutForIndex:index]] forKey:TDE_bytesOut];
	// total
	[tdEntry setValue:[NSNumber numberWithLongLong:[self totalIn]] forKey:TDE_totalIn];
	[tdEntry setValue:[NSNumber numberWithLongLong:[self totalOut]] forKey:TDE_totalOut];
	// max
	[tdEntry setValue:[NSNumber numberWithLongLong:[self maxIn]] forKey:TDE_maxIn];
	[tdEntry setValue:[NSNumber numberWithLongLong:[self maxOut]] forKey:TDE_maxOut];
	
	[tdEntry setValue:identifier forKey:TDE_identifier];
	[tdEntry setValue:bsdName forKey:TDE_bsdName];
	// service
	[tdEntry setValue:identifier forKey:TDE_service];
	// viewBy
	[tdEntry setViewBy:viewBy];

	return tdEntry;
}

// ---------------------------------------------------------------------------------
//	¥ hourGroupForIndex:
// ---------------------------------------------------------------------------------
// return TDHourGroup for hour allocating a new one if previously empty
- (TDHourGroup*)hourGroupForIndex:(int)hourOfDay allocate:(BOOL)allocate
{
	TDHourGroup* hourGroup = nil;
	do {
		if ((hourOfDay < 0) || (hourOfDay >= kTDHoursOfDay)) break;
		NSString* key = [NSString stringWithFormat:@"%d",hourOfDay];
		hourGroup = [tdHours objectForKey:key];
		// if hourGroup not previously allocated
		if (!hourGroup && allocate) {
			hourGroup = [[[TDHourGroup alloc] init] autorelease];
			if (!hourGroup) break;
			[tdHours setObject:hourGroup forKey:key];	// hourGroup is retained
			[hourGroup setIdentifier:[self identifier]];
			[hourGroup setDayGroup:self];
			[hourGroup setHourOfDay:hourOfDay];
			if ([bsdName length]) [hourGroup setBsdName:bsdName];
		}
	} while (false);
	return hourGroup;
}
// ---------------------------------------------------------------------------------
//	¥ setHourGroupForIndex:
// ---------------------------------------------------------------------------------
- (void)setHourGroupForIndex:(int)index withObject:anObject
{
	[tdHours setObject:anObject forKey:[NSString stringWithFormat:@"%d",index]];
}

#pragma mark -- own data --
// ---------------------------------------------------------------------------------
//	¥ bytesInForIndex
// ---------------------------------------------------------------------------------
- (int64_t)bytesInForIndex:(unsigned)index
{
	int64_t returnValue = 0;
	TDHourGroup* hourGroup;
	hourGroup = [tdHours objectForKey:[NSString stringWithFormat:@"%d",index]];
	// if no hourGroup, return will not be int64_t 
	if (hourGroup) returnValue = (int64_t)[hourGroup totalIn];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ bytesOutForIndex
// ---------------------------------------------------------------------------------
- (int64_t)bytesOutForIndex:(unsigned)index
{
	int64_t returnValue = 0;
	TDHourGroup* hourGroup;
	hourGroup = [tdHours objectForKey:[NSString stringWithFormat:@"%d",index]];
	// if no hourGroup, return will not be int64_t 
	if (hourGroup) returnValue = (int64_t)[hourGroup totalOut];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ totalIn
// ---------------------------------------------------------------------------------
- (int64_t)totalIn
{
	if (needsUpdate) [self doUpdate];
	return sampleData.totalIn;
}
// ---------------------------------------------------------------------------------
//	¥ totalOut
// ---------------------------------------------------------------------------------
- (int64_t)totalOut
{
	if (needsUpdate) [self doUpdate];
	return sampleData.totalOut;
}

// ---------------------------------------------------------------------------------
//	¥ maxIn
// ---------------------------------------------------------------------------------
- (int64_t)maxIn
{
	if (needsUpdate) [self doUpdate];
	return sampleData.maxIn;
}

// ---------------------------------------------------------------------------------
//	¥ maxOut
// ---------------------------------------------------------------------------------
- (int64_t)maxOut
{
	if (needsUpdate) [self doUpdate];
	return sampleData.maxOut;
}

#pragma mark -- actions --
// ---------------------------------------------------------------------------------
//	¥ setNeedsUpdate
// ---------------------------------------------------------------------------------
- (void)setNeedsUpdate:(BOOL)value
{
	needsUpdate = value;
	[tdCache removeAllObjects];
}

// ---------------------------------------------------------------------------------
//	¥ doUpdate
// ---------------------------------------------------------------------------------
- (void)doUpdate
{
	NSEnumerator* en;
	TDHourGroup* hourGroup;
	int64_t totalIn, totalOut;
	
	sampleData.totalIn = 0;
	sampleData.totalOut = 0;
	sampleData.maxIn = 0;
	sampleData.maxOut = 0;
	en = [tdHours objectEnumerator];
	while (hourGroup = [en nextObject]) {
		if (hourGroup == (TDHourGroup*)[NSNull null]) continue;
		totalIn = [hourGroup totalIn];
		totalOut = [hourGroup totalOut];
		sampleData.totalIn += totalIn;
		sampleData.totalOut += totalOut;
		if (totalIn > sampleData.maxIn) sampleData.maxIn = totalIn;
		if (totalOut > sampleData.maxOut) sampleData.maxOut = totalOut;
	}
	needsUpdate = NO;
}

#pragma mark -- sorting --
- (NSComparisonResult)compareTableViewRow:(TDDayGroup *)inDayGroup
{
	NSCalendarDate* sortDate;
	NSTableView* tableView;
	NSString* sortBy;
	int interval;
	
	// get sort parameters
	tableView = [[TrafficDiscoveryModel sharedInstance] sortTableView];
	sortBy = [[tableView highlightedTableColumn] identifier];
	if ([sortBy isEqualTo:TDE_service]) {
		return [[self identifier] compare:[inDayGroup identifier] options:NSNumericSearch];
	}
	else if ([sortBy isEqualTo:TDE_name]) {
		return [[self name] caseInsensitiveCompare:[inDayGroup name]];
	}
	else if ([sortBy isEqualTo:TDE_info]) {
		int value;
		value = [[self info] compare:[inDayGroup info]];
		if (value == NSOrderedSame) value = [[self identifier] compare:[inDayGroup identifier] options:NSNumericSearch];
		return value;
	}
	else if ([sortBy isEqualTo:TDE_bsdName]) {
		sortDate = [[TrafficDiscoveryModel sharedInstance] sortDate];
		interval = [(TrafficDiscoveryWC *)[tableView delegate] interval];
		TDEntry* tdEntryA = [self tdEntryForDate:sortDate interval:interval];
		TDEntry* tdEntryB = [inDayGroup tdEntryForDate:sortDate interval:interval];
		int value;
		value = [[tdEntryA valueForKey:sortBy] caseInsensitiveCompare:[tdEntryB valueForKey:sortBy]];
		if (value == NSOrderedSame) value = [[self identifier] compare:[inDayGroup identifier] options:NSNumericSearch];
		return value;
	}
	else if ([sortBy isEqualTo:TDE_lastTime]) {
		int value;
		value = [[inDayGroup lastTime] compare:[self lastTime]];
		if (value == NSOrderedSame) value = [[self identifier] compare:[inDayGroup identifier] options:NSNumericSearch];
		return value;
	}
	else {
		// more sort parameters
		sortDate = [[TrafficDiscoveryModel sharedInstance] sortDate];
		interval = [(TrafficDiscoveryWC *)[tableView delegate] interval];
		if (interval == kIntervalSecond) interval = kIntervalRecent;
		TDEntry* tdEntryA = [self tdEntryForDate:sortDate interval:interval];
		TDEntry* tdEntryB = [inDayGroup tdEntryForDate:sortDate interval:interval];
		int a = [[tdEntryA valueForKey:sortBy] intValue];
		int b = [[tdEntryB valueForKey:sortBy] intValue];
		if (a < b) return NSOrderedDescending;
		if (a > b) return NSOrderedAscending;
		//else return [[self identifier] compare:[inDayGroup identifier] options:NSNumericSearch];
		else return NSOrderedSame;
	}
	return NSOrderedSame;
}

@end
