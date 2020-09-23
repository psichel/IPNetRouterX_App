//
//  DHCPLeaseOptionsEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003-04 Sustainable Softworks, Inc. All rights reserved.
//

#import "PSStateEntry.h"
#import "DHCPEntry.h"

// =================================================================================
//	¥ DHCPLeaseOptionsEntry
// =================================================================================
@interface DHCPLeaseOptionsEntry : PSStateEntry {
}

+ (DHCPLeaseOptionsEntry *)entryFromDictionary:(NSDictionary *)entryDictionary;

// accessors
- (NSString *)networkInterface;
- (void)setNetworkInterface:(NSString *)value;

- (NSNumber *)dhcpOn;
- (void)setDhcpOn:(NSNumber *)value;

- (NSString *)router;
- (void)setRouter:(NSString *)value;

- (NSString *)nameServers;
- (void)setNameServers:(NSString *)value;

- (NSNumber *)defaultLeaseTime;
- (void)setDefaultLeaseTime:(NSNumber *)value;

- (NSNumber *)maxLeaseTime;
- (void)setMaxLeaseTime:(NSNumber *)value;

- (NSString *)searchDomains;
- (void)setSearchDomains:(NSString *)value;

- (NSString *)comment;
- (void)setComment:(NSString *)value;
@end

