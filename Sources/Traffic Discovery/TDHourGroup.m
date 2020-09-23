//
//  TDHourGroup.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 3/1/06.
//  Copyright 2006 Sustainable Softworks Inc. All rights reserved.
//
#import "TrafficDiscoveryModel.h"
#import "TDHourGroup.h"
#import "TDEntry.h"
#import "IPSupport.h"

// Private Methods
@interface TDHourGroup (PrivateMethods)
- (int64_t)bytesInForIndex:(unsigned)index;
- (int64_t)bytesOutForIndex:(unsigned)index;
- (int64_t)maxIn;
- (int64_t)maxOut;
	// repeat for attach
- (int)attachBytesInForIndex:(unsigned)index;
- (int)attachBytesOutForIndex:(unsigned)index;
@end

@implementation TDHourGroup
// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init
{
	if (self = [super init]) {
        // initialize our instance variables
		bzero(&sampleData, sizeof(hourSample_t));
		sampleData.length = sizeof(hourSample_t);
		sampleData.type = kIntervalMinute;
		sampleData.version = kSampleDataVersion;
		tdMinutes = [[NSMutableDictionary alloc] initWithCapacity:kTDMinutesOfHour];
		identifier = nil;
		bsdName = nil;
		dayGroup = nil;
		needsUpdate = NO;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[tdMinutes release];
	[self setIdentifier:nil];
	[self setBsdName:nil];
	dayGroup = nil;
	[super dealloc];
}

#pragma mark -- save and restore --
// ---------------------------------------------------------------------------------
//	• dictionary
// ---------------------------------------------------------------------------------
- (NSDictionary*)dictionary
{
	NSData* myData = [NSData dataWithBytes:&sampleData length:sizeof(hourSample_t)];
	// convert tdMinutes to dictionary of dictionaries
	NSMutableDictionary* tdMinutesD = [NSMutableDictionary dictionary];
	NSNumber* key;
	TDMinuteGroup* minuteGroup;
	NSEnumerator* en = [tdMinutes keyEnumerator];
	while (key = [en nextObject]) {
		minuteGroup = [tdMinutes objectForKey:key];
		[tdMinutesD setObject:[minuteGroup dictionary] forKey:key];
	}
	return [NSDictionary dictionaryWithObjectsAndKeys:
		myData,@"sampleData",
		tdMinutesD,@"tdMinutes",
		identifier,@"identifier",
		bsdName,@"bsdName",
		nil];
}

// ---------------------------------------------------------------------------------
//	• objectFromDictionary
// ---------------------------------------------------------------------------------
+ (TDHourGroup*)objectFromDictionary:(NSDictionary*)inDictionary
{
	TDHourGroup* object = [[TDHourGroup alloc] init];
	NSDictionary* tdMinutesD = [inDictionary objectForKey:@"tdMinutes"];
	NSNumber* key;
	TDMinuteGroup* minuteGroup;
	NSEnumerator* en = [tdMinutesD keyEnumerator];
	while (key = [en nextObject]) {
		minuteGroup = [TDMinuteGroup objectFromDictionary:[tdMinutesD objectForKey:key]];
		[object setMinuteGroupForIndex:[key intValue] withObject:minuteGroup];
	}
	[object setSampleData:[inDictionary objectForKey:@"sampleData"]];
	[object setIdentifier:[inDictionary objectForKey:@"identifier"]];
	[object setBsdName:[inDictionary objectForKey:@"bsdName"]];
	return [object autorelease];
}
- (void)setSampleData:(NSData*)inData
{
	hourSample_t* dp;
	dp = (hourSample_t *const)[inData bytes];
	if (dp->version == kSampleDataVersion) {	
		int length = [inData length];
		if (length > sizeof(hourSample_t)) length = sizeof(hourSample_t);
		memcpy(&sampleData, [inData bytes], length);
		if (length < sizeof(hourSample_t)) {
			int delta = sizeof(hourSample_t) - length;
			u_int8_t* dp = (u_int8_t*)&sampleData;
			bzero(&dp[length], delta);
		}
	}
}

#pragma mark -- accessors --
- (NSString*)identifier { return identifier; }
- (void)setIdentifier:(NSString*)value
{
	[value retain];
	[identifier release];
	identifier = value;
}

- (NSString*)bsdName { return bsdName; }
- (void)setBsdName:(NSString*)value
{
	[value retain];
	[bsdName release];
	bsdName = value;
	// update dayGroup to reflect most recent traffic
	if (value) [dayGroup setBsdName:value];
}

- (TDDayGroup*)dayGroup { return dayGroup; }
- (void)setDayGroup:(TDDayGroup*)value
{
	// not retained to avoid loop
	dayGroup = value;
}

- (int)hourOfDay { return sampleData.hourOfDay; }
- (void)setHourOfDay:(int)value {
	sampleData.hourOfDay = value;
}

#pragma mark -- data access --
// ---------------------------------------------------------------------------------
//	• minuteGroupForIndex
// ---------------------------------------------------------------------------------
// return TDMinuteGroup for minute allocating a new one if previously empty
- (TDMinuteGroup*)minuteGroupForIndex:(int)minuteOfHour allocate:(BOOL)allocate
{
	TDMinuteGroup* minuteGroup = nil;
	do {
		if ((minuteOfHour < 0) || (minuteOfHour >= kTDMinutesOfHour)) break;
		NSString* key = [NSString stringWithFormat:@"%d",minuteOfHour];
		minuteGroup = [tdMinutes objectForKey:key];
		if (!minuteGroup && allocate) {
			minuteGroup = [[[TDMinuteGroup alloc] init] autorelease];
			if (!minuteGroup) break;
			[tdMinutes setObject:minuteGroup forKey:key];
			[minuteGroup setIdentifier:[self identifier]];
			[minuteGroup setHourGroup:self];
			[minuteGroup setMinuteOfHour:minuteOfHour];
			if ([bsdName length]) [minuteGroup setBsdName:bsdName];
		}
	} while (false);
	return minuteGroup;
}
// ---------------------------------------------------------------------------------
//	• setMinuteGroupForIndex:
// ---------------------------------------------------------------------------------
- (void)setMinuteGroupForIndex:(int)index withObject:anObject
{
	[tdMinutes setObject:anObject forKey:[NSString stringWithFormat:@"%d",index]];
}

// ---------------------------------------------------------------------------------
//	• tdEntryForIndex
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

	return tdEntry;
}

// ---------------------------------------------------------------------------------
//	• bytesInForIndex
// ---------------------------------------------------------------------------------
- (int64_t)bytesInForIndex:(unsigned)index
{
	int64_t returnValue = 0;
	TDMinuteGroup* minuteGroup;
	minuteGroup = [tdMinutes objectForKey:[NSString stringWithFormat:@"%d",index]];
	// if no minuteGroup, return will not be int64_t 
	if (minuteGroup) returnValue = (int64_t)[minuteGroup totalIn];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• bytesOutForIndex
// ---------------------------------------------------------------------------------
- (int64_t)bytesOutForIndex:(unsigned)index
{
	int64_t returnValue = 0;
	TDMinuteGroup* minuteGroup;
	minuteGroup = [tdMinutes objectForKey:[NSString stringWithFormat:@"%d",index]];
	// if no minuteGroup, return will not be int64_t 
	if (minuteGroup) returnValue = (int64_t)[minuteGroup totalOut];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• totalIn
// ---------------------------------------------------------------------------------
- (int64_t)totalIn
{
	if (needsUpdate) [self doUpdate];
	return sampleData.totalIn;
}
// ---------------------------------------------------------------------------------
//	• totalOut
// ---------------------------------------------------------------------------------
- (int64_t)totalOut
{
	if (needsUpdate) [self doUpdate];
	return sampleData.totalOut;
}

// ---------------------------------------------------------------------------------
//	• maxIn
// ---------------------------------------------------------------------------------
- (int64_t)maxIn
{
	if (needsUpdate) [self doUpdate];
	return sampleData.maxIn;
}

// ---------------------------------------------------------------------------------
//	• maxOut
// ---------------------------------------------------------------------------------
- (int64_t)maxOut
{
	if (needsUpdate) [self doUpdate];
	return sampleData.maxOut;
}

#pragma mark -- actions --
// ---------------------------------------------------------------------------------
//	• setNeedsUpdate
// ---------------------------------------------------------------------------------
- (void)setNeedsUpdate:(BOOL)value
{
	needsUpdate = value;
	[dayGroup setNeedsUpdate:value];
}

// ---------------------------------------------------------------------------------
//	• doUpdate
// ---------------------------------------------------------------------------------
- (void)doUpdate
{
	NSEnumerator* en;
	TDMinuteGroup* minuteGroup;
	int64_t totalIn, totalOut;
	
	sampleData.totalIn = 0;
	sampleData.totalOut = 0;
	sampleData.maxIn = 0;
	sampleData.maxOut = 0;
	en = [tdMinutes objectEnumerator];
	while (minuteGroup = [en nextObject]) {
		totalIn = [minuteGroup totalIn];
		totalOut = [minuteGroup totalOut];
		sampleData.totalIn += totalIn;
		sampleData.totalOut += totalOut;
		if (totalIn > sampleData.maxIn) sampleData.maxIn = totalIn;
		if (totalOut > sampleData.maxOut) sampleData.maxOut = totalOut;
	}
	needsUpdate = NO;
}

@end
