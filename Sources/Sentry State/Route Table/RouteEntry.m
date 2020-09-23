//
//  RouteEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Jun 3 2004.
//  Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//

#import "RouteEntry.h"
#import "IPSupport.h"
//#import "PSSharedDictionary.h"
//#import "IPValue.h"
//#import <netinet/tcp_fsm.h>

@implementation RouteEntry
// ---------------------------------------------------------------------------------
//	¥ entryFromDictionary
// ---------------------------------------------------------------------------------
+ (RouteEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	RouteEntry* entry;
	entry = [[[RouteEntry alloc] init] autorelease];
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

- (NSString *)type { return [nodeDictionary objectForKey:RE_type]; }
- (void)setType:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_type];
    else [nodeDictionary removeObjectForKey:RE_type];
}

- (NSString *)destination { return [nodeDictionary objectForKey:RE_destination]; }
- (void)setDestination:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_destination];
    else [nodeDictionary removeObjectForKey:RE_destination];
}

- (NSString *)gateway { return [nodeDictionary objectForKey:RE_gateway]; }
- (void)setGateway:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_gateway];
    else [nodeDictionary removeObjectForKey:RE_gateway];
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

- (NSDate *)lastTime { return [nodeDictionary objectForKey:RE_lastTime]; }
- (void)setLastTime:(NSDate *)value
{
    if (value) [nodeDictionary setObject:value forKey:RE_lastTime];
    else [nodeDictionary removeObjectForKey:RE_lastTime];
}

// ---------------------------------------------------------------------------------
//	¥ isEqualTo
// ---------------------------------------------------------------------------------
- (BOOL)isEqualTo:(RouteEntry *)entry
{
    BOOL returnValue = NO;
	u_int32_t address1, address2;
	u_int32_t mask1, mask2;
	
	// conver to address and netNumber as canonical for
	netNumberForString([self destination], &address1, &mask1);
	netNumberForString([entry destination], &address2, &mask2);
    do {
		if (address1 != address2) break;
        if (mask1 != mask2) break;
         returnValue = YES;
    } while(false);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ description
// ---------------------------------------------------------------------------------
- (NSString *)description
{
	return [NSString stringWithFormat:@"DST=%@ GW=%@ IF=%@ AT=%@ CO=%@",
		[self destination],
		[self gateway],
		[self interface],
		[self attributes],
		[self comment]];
}

@end
