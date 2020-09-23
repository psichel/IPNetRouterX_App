//
//  DHCPServerOptionsEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003-04 Sustainable Softworks, Inc. All rights reserved.
//
#import "DHCPServerOptionsEntry.h"

// =================================================================================
//	¥ DHCPServerOptionsEntry
// =================================================================================
@implementation DHCPServerOptionsEntry
+ (DHCPServerOptionsEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	DHCPServerOptionsEntry* entry;
	entry = [[[DHCPServerOptionsEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

#pragma mark --- Accessors ---
- (id)key { return [nodeDictionary objectForKey:DS_dhcpOptionNumber]; }
- (NSString *)dhcpOptionNumber { return [nodeDictionary objectForKey:DS_dhcpOptionNumber]; }
- (void)setDhcpOptionNumber:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_dhcpOptionNumber];
    else [nodeDictionary removeObjectForKey:DS_dhcpOptionNumber];
}


- (NSNumber *)dhcpOptionType { return [nodeDictionary objectForKey:DS_dhcpOptionType]; }
- (void)setDhcpOptionType:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_dhcpOptionType];
    else [nodeDictionary removeObjectForKey:DS_dhcpOptionType];
}

- (NSString *)dhcpOptionText { return [nodeDictionary objectForKey:DS_dhcpOptionText]; }
- (void)setDhcpOptionText:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_dhcpOptionText];
    else [nodeDictionary removeObjectForKey:DS_dhcpOptionText];
}

- (NSString *)comment { return [nodeDictionary objectForKey:DS_comment]; }
- (void)setComment:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_comment];
    else [nodeDictionary removeObjectForKey:DS_comment];
}
@end

