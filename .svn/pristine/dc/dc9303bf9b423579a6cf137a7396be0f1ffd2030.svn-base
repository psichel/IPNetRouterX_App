//
//  DHCPServerOptionsEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003-04 Sustainable Softworks, Inc. All rights reserved.
//

#import "PSStateEntry.h"
#import "DHCPEntry.h"

// =================================================================================
//	¥ DHCPServerOptionsEntry
// =================================================================================
@interface DHCPServerOptionsEntry : PSStateEntry {
}

+ (DHCPServerOptionsEntry *)entryFromDictionary:(NSDictionary *)entryDictionary;

// accessors
- (NSString *)dhcpOptionNumber;
- (void)setDhcpOptionNumber:(NSString *)value;

- (NSNumber *)dhcpOptionType;
- (void)setDhcpOptionType:(NSNumber *)value;

- (NSString *)dhcpOptionText;
- (void)setDhcpOptionText:(NSString *)value;

- (NSString *)comment;
- (void)setComment:(NSString *)value;
@end

#define kDhcpOptionTypeText			0
#define kDhcpOptionTypeIPAddress	1