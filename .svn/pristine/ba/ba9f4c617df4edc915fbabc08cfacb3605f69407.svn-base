//
//  DeviceEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 10/14/05.
//  Copyright 2005 Sustainable Softworks. All rights reserved.
//

#import "DeviceEntry.h"
#import "IPSupport.h"
//#import "PSSharedDictionary.h"
//#import "IPValue.h"
//#import <netinet/tcp_fsm.h>

@implementation DeviceEntry
// ---------------------------------------------------------------------------------
//	¥ entryFromDictionary
// ---------------------------------------------------------------------------------
+ (DeviceEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	DeviceEntry* entry;
	entry = [[[DeviceEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

#pragma mark -- accessors --
- (NSNumber *)enabled { return [nodeDictionary objectForKey:DE_enabled]; }
- (void)setEnabled:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:DE_enabled];
    else [nodeDictionary removeObjectForKey:DE_enabled];
}

- (NSString *)title { return [nodeDictionary objectForKey:DE_title]; }
- (void)setTitle:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DE_title];
    else [nodeDictionary removeObjectForKey:DE_title];
}

- (NSString *)type { return [nodeDictionary objectForKey:DE_type]; }
- (void)setType:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DE_type];
    else [nodeDictionary removeObjectForKey:DE_type];
}

- (NSNumber *)direction { return [nodeDictionary objectForKey:DE_direction]; }
- (void)setDirection:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:DE_direction];
    else [nodeDictionary removeObjectForKey:DE_direction];
}

- (NSString *)portName { return [nodeDictionary objectForKey:DE_portName]; }
- (void)setPortName:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DE_portName];
    else [nodeDictionary removeObjectForKey:DE_portName];
}

- (NSString *)hwAddress { return [nodeDictionary objectForKey:DE_hwAddress]; }
- (void)setHwAddress:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DE_hwAddress];
    else [nodeDictionary removeObjectForKey:DE_hwAddress];
}

- (NSString *)filterStyle { return [nodeDictionary objectForKey:DE_filterStyle]; }
- (void)setFilterStyle:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DE_filterStyle];
    else [nodeDictionary removeObjectForKey:DE_filterStyle];
}

#pragma mark -- support --

// ---------------------------------------------------------------------------------
//	¥ description
// ---------------------------------------------------------------------------------
- (NSString *)description
{
	return [nodeDictionary description];
}

@end
