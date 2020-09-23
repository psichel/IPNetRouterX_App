//
//  ArpEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Jun 3 2004.
//  Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//
// represent a Network Routing entry
// ipAddress
// hwAddress
// interface
// attributes [Temp Publish]
// comment

#import <Foundation/Foundation.h>
#import "PSStateEntry.h"

@interface ArpEntry : PSStateEntry {
}

// accessors
// could use key value coding, but this convenient and allows us to intervene
- (NSNumber *)restore;
- (void)setRestore:(NSNumber *)value;

- (NSString *)ipAddress;
- (void)setIpAddress:(NSString *)value;

- (NSString *)hwAddress;
- (void)setHwAddress:(NSString *)value;

- (NSString *)interface;
- (void)setInterface:(NSString *)value;

- (NSString *)attributes;
- (void)setAttributes:(NSString *)value;

- (NSString *)comment;
- (void)setComment:(NSString *)value;

- (NSString *)description;
@end

#define RE_restore		@"restore"
#define RE_ipAddress	@"ipAddress"
#define RE_hwAddress	@"hwAddress"
#define RE_interface	@"interface"
#define RE_attributes   @"attributes"
#define RE_comment		@"comment"

// arp attributes
#define RE_attributePerm  @"Perm "
#define RE_attributePublish  @"Publish "
#define RE_attributeProxy @"Proxy "
