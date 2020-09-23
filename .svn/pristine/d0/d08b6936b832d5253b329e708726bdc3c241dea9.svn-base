//
//  AddressScanUserInfo.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on 3/16/09.
//  Copyright 2009 Sustainable Softworks. All rights reserved.
//
// Keep user specified "Name" and "Comment" values for Address Scan table entries.
// Look Around Scan only, use Ethernet MAC address as key.
// Format of entry is a single NSString name-part<US>comment_part

#import "AddressScanUserInfo.h"
#define preferences [NSUserDefaults standardUserDefaults]


@implementation AddressScanUserInfo
+ (AddressScanUserInfo *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[AddressScanUserInfo allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
		infoD = nil;
    }
    return self;
}
- (void)dealloc {
	[infoD release];	infoD = nil;
	[super dealloc];
}

- (void)save
{
	if (infoD) [preferences setObject:infoD forKey:kAddressScanUserInfo_name];
}
- (void)restore
{
	[infoD release];
	infoD = [[preferences objectForKey:kAddressScanUserInfo_name] retain];
	if (!infoD) {
		infoD = [[NSMutableDictionary alloc] init];
	}

}

#pragma mark -- accessors --
// accessors
// ---------------------------------------------------------------------------------
//	• nameForKey
// ---------------------------------------------------------------------------------
- (NSString *)nameForKey:(NSString *)inKey
{
	NSString *returnValue = nil;
	NSString *str;
	NSArray *list;
	str = [infoD objectForKey:inKey];
	if (str) {
		list = [str componentsSeparatedByString:kUnitSeparator];
		returnValue = [list objectAtIndex:0];
	}
	return returnValue;
}

- (void)setName:(NSString *)value forKey:(NSString *)key
{
	NSString *str, *comment;
	NSArray *list;
	if (!value) value = @"";
	str = [infoD objectForKey:key];
	if (str) {
		list = [str componentsSeparatedByString:kUnitSeparator];
		if (!(comment = [list objectAtIndex:1])) comment = @"";
		str = [NSString stringWithFormat:@"%@%@%@",value,kUnitSeparator,comment];
	}
	else {
		str = [NSString stringWithFormat:@"%@%@",value,kUnitSeparator]; 
	}
	[infoD setObject:str forKey:key];
}

// ---------------------------------------------------------------------------------
//	• commentForKey
// ---------------------------------------------------------------------------------
- (NSString *)commentForKey:(NSString *)key
{
	NSString *returnValue = nil;
	NSString *str;
	NSArray *list;
	str = [infoD objectForKey:key];
	if (str) {
		list = [str componentsSeparatedByString:kUnitSeparator];
		returnValue = [list objectAtIndex:1];
	}
	return returnValue;

}

- (void)setComment:(NSString *)value forKey:(NSString *)key
{
	NSString *str, *name;
	NSArray *list;
	if (!value) value = @"";
	str = [infoD objectForKey:key];
	if (str) {
		list = [str componentsSeparatedByString:kUnitSeparator];
		if (!(name = [list objectAtIndex:0])) name = @"";
		str = [NSString stringWithFormat:@"%@%@%@",name,kUnitSeparator,value];
	}
	else {
		str = [NSString stringWithFormat:@"%@%@",kUnitSeparator,value]; 
	}
	[infoD setObject:str forKey:key];

}

@end

// ---------------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------------
