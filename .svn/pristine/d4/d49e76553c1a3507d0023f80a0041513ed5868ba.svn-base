//
//  ArpEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Jun 3 2004.
//  Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//

#import "ArpEntry.h"
#import "IPSupport.h"
//#import "PSSharedDictionary.h"
//#import "IPValue.h"
//#import <netinet/tcp_fsm.h>

@implementation ArpEntry
// ---------------------------------------------------------------------------------
//	¥ entryFromDictionary
// ---------------------------------------------------------------------------------
+ (ArpEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	ArpEntry* entry;
	entry = [[[ArpEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

// accessors
- (NSNumber *)restore { return [nodeDictionary objectForKey:RE_restore]; }
- (void)setRestore:(NSNumber *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_restore];
    else [nodeDictionary removeObjectForKey:RE_restore];
}

- (NSString *)ipAddress { return [nodeDictionary objectForKey:RE_ipAddress]; }
- (void)setIpAddress:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_ipAddress];
    else [nodeDictionary removeObjectForKey:RE_ipAddress];
}

- (NSString *)hwAddress { return [nodeDictionary objectForKey:RE_hwAddress]; }
- (void)setHwAddress:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_hwAddress];
    else [nodeDictionary removeObjectForKey:RE_hwAddress];
}

- (NSString *)interface { return [nodeDictionary objectForKey:RE_interface]; }
- (void)setInterface:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_interface];
    else [nodeDictionary removeObjectForKey:RE_interface];
}

- (NSString *)attributes { return [nodeDictionary objectForKey:RE_attributes]; }
- (void)setAttributes:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_attributes];
    else [nodeDictionary removeObjectForKey:RE_attributes];
}

- (NSString *)comment { return [nodeDictionary objectForKey:RE_comment]; }
- (void)setComment:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_comment];
    else [nodeDictionary removeObjectForKey:RE_comment];
}

#pragma mark -- support --

// ---------------------------------------------------------------------------------
//	¥ isEqualTo
// ---------------------------------------------------------------------------------
- (BOOL)isEqualTo:(ArpEntry *)entry
{
    BOOL returnValue = NO;
	u_int32_t address1, address2;
	
	// conver to address as canonical for
	address1 = ipForString([self ipAddress]);
	address2 = ipForString([entry ipAddress]);
    do {
		if (address1 != address2) break;
         returnValue = YES;
    } while(false);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ description
// ---------------------------------------------------------------------------------
- (NSString *)description
{
	return [NSString stringWithFormat:@"IP=%@ HW=%@ IF=%@ AT=%@ CO=%@",
		[self ipAddress],
		[self hwAddress],
		[self interface],
		[self attributes],
		[self comment]];
}

@end
