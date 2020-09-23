//
//  TDEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 3/21/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import "TDEntry.h"
#import "PSSharedDictionary.h"

@implementation TDEntry

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		identifier = nil;
		attachBytesIn = nil;
		attachBytesOut = nil;
		percentIn = nil;
		percentOut = nil;
		bytesIn = nil;
		bytesOut = nil;
		totalIn = nil;
		totalOut = nil;
		maxIn =  nil;
		maxOut =  nil;
		service = nil;
		name = nil;
		bsdName = nil;
		dataIndex = -1;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {

	[identifier release];	identifier = nil;
	[attachBytesIn release];	attachBytesIn = nil;
	[attachBytesOut release];	attachBytesOut = nil;
	[percentIn release];	percentIn = nil;
	[percentOut release];	percentOut = nil;
	[bytesIn release];		bytesIn = nil;
	[bytesOut release];		bytesOut = nil;
	[totalIn release];		totalIn = nil;
	[totalOut release];		totalOut = nil;
	[maxIn release];		maxIn =  nil;
	[maxOut release];		maxOut =  nil;
	[service release];		service = nil;
	[name release];			name = nil;
	[bsdName release];		bsdName = nil;
	dataIndex = -1;
	[super dealloc];
}
#if 0
// ---------------------------------------------------------------------------------
//	• valueForKey
// ---------------------------------------------------------------------------------
// key vaklue coding
- (id)valueForKey:(NSString *)key
{
	id returnValue = nil;
	if ([key isEqualTo:TDE_service])		returnValue = service;
	else if ([key isEqualTo:TDE_attachBytesIn])	returnValue = attachBytesIn;
	else if ([key isEqualTo:TDE_attachBytesOut]) returnValue = attachBytesOut;
	else if ([key isEqualTo:TDE_percentIn])	returnValue = percentIn;
	else if ([key isEqualTo:TDE_percentOut]) returnValue = percentOut;
	else if ([key isEqualTo:TDE_bytesIn])	returnValue = bytesIn;
	else if ([key isEqualTo:TDE_bytesOut])	returnValue = bytesOut;
	else if ([key isEqualTo:TDE_totalIn])	returnValue = totalIn;
	else if ([key isEqualTo:TDE_totalOut])	returnValue = totalOut;
	else if ([key isEqualTo:TDE_maxIn])		returnValue = maxIn;
	else if ([key isEqualTo:TDE_maxOut])	returnValue = maxOut;
	else if ([key isEqualTo:TDE_identifier]) returnValue = identifier;
	else if ([key isEqualTo:TDE_name])		returnValue = name;
	else if ([key isEqualTo:TDE_bsdName])	returnValue = bsdName;
	else {
		NSLog(@"TDEntry unknown key value %@",key);
		NSBeep();
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• setValue:forKey:
// ---------------------------------------------------------------------------------
- (void)setValue:(id)value forKey:(NSString *)key
{
	[value retain];
	if ([key isEqualTo:TDE_service])		{ [service release]; service = value; }
	else if ([key isEqualTo:TDE_attachBytesIn])	{ [attachBytesIn release]; attachBytesIn = value; }
	else if ([key isEqualTo:TDE_attachBytesOut]) { [attachBytesOut release]; attachBytesOut = value; }
	else if ([key isEqualTo:TDE_percentIn])	{ [percentIn release]; percentIn = value; }
	else if ([key isEqualTo:TDE_percentOut]) { [percentOut release]; percentOut = value; }
	else if ([key isEqualTo:TDE_bytesIn])	{ [bytesIn release]; bytesIn = value; }
	else if ([key isEqualTo:TDE_bytesOut])	{ [bytesOut release]; bytesOut = value; }
	else if ([key isEqualTo:TDE_totalIn])	{ [totalIn release]; totalIn = value; }
	else if ([key isEqualTo:TDE_totalOut])	{ [totalOut release]; totalOut = value; }
	else if ([key isEqualTo:TDE_maxIn])		{ [maxIn release]; maxIn = value; }
	else if ([key isEqualTo:TDE_maxOut])	{ [maxOut release]; maxOut = value; }
	else if ([key isEqualTo:TDE_identifier]) { [identifier release]; identifier = value; }
	else if ([key isEqualTo:TDE_name])		{ [name release]; name = value; }
	else if ([key isEqualTo:TDE_bsdName])	{ [bsdName release]; bsdName = value; }
	else {
		NSLog(@"TDEntry unknown key value %@",key);
		NSBeep();
	}
}
#endif

// ---------------------------------------------------------------------------------
//	• identifier
// ---------------------------------------------------------------------------------
- (NSString *)identifier { return identifier; }
- (void)setIdentifier:(NSString *)value {
	[value retain];
	[identifier release];
	identifier = value;
}

// ---------------------------------------------------------------------------------
//	• attachBytesIn
// ---------------------------------------------------------------------------------
- (NSNumber *)attachBytesIn { return attachBytesIn; }
- (void)setAttachBytesIn:(NSNumber *)value {
	[value retain];
	[attachBytesIn release];
	attachBytesIn = value;
}

// ---------------------------------------------------------------------------------
//	• attachBytesOut
// ---------------------------------------------------------------------------------
- (NSNumber *)attachBytesOut { return attachBytesOut; }
- (void)setAttachBytesOut:(NSNumber *)value {
	[value retain];
	[attachBytesOut release];
	attachBytesOut = value;
}

// ---------------------------------------------------------------------------------
//	• percentIn
// ---------------------------------------------------------------------------------
- (NSNumber *)percentIn { return percentIn; }
- (void)setPercentIn:(NSNumber *)value {
	[value retain];
	[percentIn release];
	percentIn = value;
}

// ---------------------------------------------------------------------------------
//	• percentOut
// ---------------------------------------------------------------------------------
- (NSNumber *)percentOut { return percentOut; }
- (void)setPercentOut:(NSNumber *)value {
	[value retain];
	[percentOut release];
	percentOut = value;
}

// ---------------------------------------------------------------------------------
//	• bytesIn
// ---------------------------------------------------------------------------------
- (NSNumber *)bytesIn { return bytesIn; }
- (void)setBytesIn:(NSNumber *)value {
	[value retain];
	[bytesIn release];
	bytesIn = value;
}

// ---------------------------------------------------------------------------------
//	• bytesOut
// ---------------------------------------------------------------------------------
- (NSNumber *)bytesOut { return bytesOut; }
- (void)setBytesOut:(NSNumber *)value {
	[value retain];
	[bytesOut release];
	bytesOut = value;
}

// ---------------------------------------------------------------------------------
//	• totalIn
// ---------------------------------------------------------------------------------
- (NSNumber *)totalIn { return totalIn; }
- (void)setTotalIn:(NSNumber *)value {
	[value retain];
	[totalIn release];
	totalIn = value;
}

// ---------------------------------------------------------------------------------
//	• totalOut
// ---------------------------------------------------------------------------------
- (NSNumber *)totalOut { return totalOut; }
- (void)setTotalOut:(NSNumber *)value {
	[value retain];
	[totalOut release];
	totalOut = value;
}

// ---------------------------------------------------------------------------------
//	• maxIn
// ---------------------------------------------------------------------------------
- (NSNumber *)maxIn { return maxIn; }
- (void)setMaxIn:(NSNumber *)value {
	[value retain];
	[maxIn release];
	maxIn = value;
}

// ---------------------------------------------------------------------------------
//	• maxOut
// ---------------------------------------------------------------------------------
- (NSNumber *)maxOut { return maxOut; }
- (void)setMaxOut:(NSNumber *)value {
	[value retain];
	[maxOut release];
	maxOut = value;
}

// ---------------------------------------------------------------------------------
//	• service
// ---------------------------------------------------------------------------------
- (NSString *)service { return service; }
- (void)setService:(NSString *)value {
	[value retain];
	[service release];
	service = value;
}

// ---------------------------------------------------------------------------------
//	• name
// ---------------------------------------------------------------------------------
- (NSString *)name { return name; }
- (void)setName:(NSString *)value {
	[value retain];
	[name release];
	name = value;
}

// ---------------------------------------------------------------------------------
//	• bsdName
// ---------------------------------------------------------------------------------
- (NSString *)bsdName { return bsdName; }
- (void)setBsdName:(NSString *)value {
	[value retain];
	[bsdName release];
	bsdName = value;
}

// ---------------------------------------------------------------------------------
//	• info
// ---------------------------------------------------------------------------------
- (NSString*)info { return info; }
- (void)setInfo:(NSString*)value
{
	[value retain];
	[info release];
	info = value;
}

// ---------------------------------------------------------------------------------
//	• lastTime
// ---------------------------------------------------------------------------------
- (NSCalendarDate*)lastTime { return lastTime; }
- (void)setLastTime:(NSCalendarDate*)value;
{
	[value retain];
	[lastTime release];
	lastTime = value;
}
- (NSString*)lastTimeStr { return  [[self lastTime] descriptionWithCalendarFormat:@"%H:%M:%S"]; }


// ---------------------------------------------------------------------------------
//	• viewBy
// ---------------------------------------------------------------------------------
- (int)viewBy { return viewBy; }
- (void)setViewBy:(int)value { viewBy = value; }

// ---------------------------------------------------------------------------------
//	• dataIndex
// ---------------------------------------------------------------------------------
- (int)dataIndex { return dataIndex; }
- (void)setDataIndex:(int)value { dataIndex = value; }

// ---------------------------------------------------------------------------------
//	• plotIndex
// ---------------------------------------------------------------------------------
- (int)plotIndex { return plotIndex; }
- (void)setPlotIndex:(int)value { plotIndex = value; }

// ---------------------------------------------------------------------------------
//	• description
// ---------------------------------------------------------------------------------
- (NSString *)description
{
	return [NSString stringWithFormat:@"service=%@ bytesIn=%@ bytesOut=%@",service, bytesIn, bytesOut];
}

#pragma mark -- sorting --
// ---------------------------------------------------------------------------------
//	• compare
// ---------------------------------------------------------------------------------
- (NSComparisonResult)compare:(TDEntry *)inEntry
{
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
	NSString* sortBy = [sd objectForKey:kTrafficDiscovery_sortBy];

	// compare based on sortBy column identifier
	if ([sortBy isEqualTo:TDE_service]) {
		return [[self valueForKey:TDE_identifier] compare:[inEntry valueForKey:TDE_identifier] options:NSNumericSearch];
	}
	else if ([sortBy isEqualTo:TDE_name]) {
		return [[self valueForKey:name] caseInsensitiveCompare:[inEntry valueForKey:name]];
	}
	else if ([sortBy isEqualTo:TDE_info]) {
		int value;
		value = [[self valueForKey:sortBy] compare:[inEntry valueForKey:sortBy]];
		if (value == NSOrderedSame) value = [[self valueForKey:identifier] compare:[inEntry valueForKey:identifier] options:NSNumericSearch];
		return value;
	}
	else if ([sortBy isEqualTo:TDE_bsdName]) {
		int value;
		value = [[self valueForKey:sortBy] caseInsensitiveCompare:[inEntry valueForKey:sortBy]];
		if (value == NSOrderedSame) {
			NSString* str1 = [self valueForKey:identifier];
			NSString* str2 = [inEntry valueForKey:identifier]; 
			value = [str1 compare:str2 options:NSNumericSearch];
			return value;
		}
	}
	else if ([sortBy isEqualTo:TDE_lastTime]) {
		int value;
		value = [[inEntry valueForKey:sortBy] compare:[self valueForKey:sortBy]];
		if (value == NSOrderedSame) value = [[self valueForKey:identifier] compare:[inEntry valueForKey:identifier] options:NSNumericSearch];
		return value;
	}
	else {
		// more sort parameters
		int a = [[self valueForKey:sortBy] intValue];
		int b = [[inEntry valueForKey:sortBy] intValue];
		if (a < b) return NSOrderedDescending;
		if (a > b) return NSOrderedAscending;
		//else return [[self identifier] compare:[inEntry identifier] options:NSNumericSearch];
		else return NSOrderedSame;
	}
	return NSOrderedSame;
}


#pragma mark --- CODING_AND_COPYING ---
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:identifier];
	[coder encodeObject:attachBytesIn];
	[coder encodeObject:attachBytesOut];
	[coder encodeObject:percentIn];
	[coder encodeObject:percentOut];
	[coder encodeObject:bytesIn];
	[coder encodeObject:bytesOut];
	[coder encodeObject:totalIn];
	[coder encodeObject:totalOut];
	[coder encodeObject:maxIn];
	[coder encodeObject:maxOut];
	[coder encodeObject:service];
	[coder encodeObject:name];
	[coder encodeObject:bsdName];
	[coder encodeObject:info];
	[coder encodeObject:lastTime];

	[coder encodeValueOfObjCType:@encode(int) at:&viewBy];
	[coder encodeValueOfObjCType:@encode(int) at:&dataIndex];
	[coder encodeValueOfObjCType:@encode(int) at:&plotIndex];		
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
	identifier = [[coder decodeObject] retain];
	attachBytesIn = [[coder decodeObject] retain];
	attachBytesOut = [[coder decodeObject] retain];
	percentIn = [[coder decodeObject] retain];
	percentOut = [[coder decodeObject] retain];
	bytesIn = [[coder decodeObject] retain];
	bytesOut = [[coder decodeObject] retain];
	totalIn = [[coder decodeObject] retain];
	totalOut = [[coder decodeObject] retain];
	maxIn = [[coder decodeObject] retain];
	maxOut = [[coder decodeObject] retain];
	service = [[coder decodeObject] retain];
	name = [[coder decodeObject] retain];
	bsdName = [[coder decodeObject] retain];
	info = [[coder decodeObject] retain];
	lastTime = [[coder decodeObject] retain];

	[coder decodeValueOfObjCType:@encode(int) at:&viewBy];
	[coder decodeValueOfObjCType:@encode(int) at:&dataIndex];
	[coder decodeValueOfObjCType:@encode(int) at:&plotIndex];	
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}

// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    TDEntry *copy;
	copy = [[[self class] allocWithZone:zone] init];
	[copy setIdentifier:identifier];
	[copy setAttachBytesIn:attachBytesIn];
	[copy setAttachBytesOut:attachBytesOut];
	[copy setPercentIn:percentIn];
	[copy setPercentOut:percentOut];
	[copy setBytesIn:bytesIn];
	[copy setBytesOut:bytesOut];
	[copy setTotalIn:totalIn];
	[copy setTotalOut:totalOut];
	[copy setMaxIn:maxIn];
	[copy setMaxOut:maxOut];
	[copy setService:service];
	[copy setName:name];
	[copy setBsdName:bsdName];
	[copy setInfo:info];
	[copy setLastTime:lastTime];
	
	[copy setViewBy:viewBy];
	[copy setDataIndex:dataIndex];
	[copy setPlotIndex:plotIndex];
    return copy;
}

@end
