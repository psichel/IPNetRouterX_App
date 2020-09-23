//
//  DHCPLeaseOptionsEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003-04 Sustainable Softworks, Inc. All rights reserved.
//
#import "DHCPLeaseOptionsEntry.h"

// =================================================================================
//	¥ DHCPLeaseOptionsEntry
// =================================================================================
@implementation DHCPLeaseOptionsEntry
+ (DHCPLeaseOptionsEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	DHCPLeaseOptionsEntry* entry;
	entry = [[[DHCPLeaseOptionsEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

#pragma mark --- Accessors ---
- (id)key { return [nodeDictionary objectForKey:DS_networkInterface]; }
- (NSString *)networkInterface { return [nodeDictionary objectForKey:DS_networkInterface]; }
- (void)setNetworkInterface:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_networkInterface];
    else [nodeDictionary removeObjectForKey:DS_networkInterface];
}

- (NSNumber *)dhcpOn { return [nodeDictionary objectForKey:DS_dhcpOn]; }
- (void)setDhcpOn:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_dhcpOn];
    else [nodeDictionary removeObjectForKey:DS_dhcpOn];
}

- (NSString *)router { return [nodeDictionary objectForKey:DS_router]; }
- (void)setRouter:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_router];
    else [nodeDictionary removeObjectForKey:DS_router];
}

- (NSString *)nameServers { return [nodeDictionary objectForKey:DS_nameServers]; }
- (void)setNameServers:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_nameServers];
    else [nodeDictionary removeObjectForKey:DS_nameServers];
}

- (NSNumber *)defaultLeaseTime { return [nodeDictionary objectForKey:DS_defaultLeaseTime]; }
- (void)setDefaultLeaseTime:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_defaultLeaseTime];
    else [nodeDictionary removeObjectForKey:DS_defaultLeaseTime];
}

- (NSNumber *)maxLeaseTime { return [nodeDictionary objectForKey:DS_maxLeaseTime]; }
- (void)setMaxLeaseTime:(NSNumber *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_maxLeaseTime];
    else [nodeDictionary removeObjectForKey:DS_maxLeaseTime];
}

- (NSString *)searchDomains { return [nodeDictionary objectForKey:DS_searchDomains]; }
- (void)setSearchDomains:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_searchDomains];
    else [nodeDictionary removeObjectForKey:DS_searchDomains];
}

- (NSString *)comment { return [nodeDictionary objectForKey:DS_comment]; }
- (void)setComment:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:DS_comment];
    else [nodeDictionary removeObjectForKey:DS_comment];
}
@end

