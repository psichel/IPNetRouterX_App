//
//  DHCPState.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003-04 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSStateEntry.h"

#import "DHCPStatusEntry.h"
#import "DHCPStaticConfigEntry.h"
#import "DHCPDynamicConfigEntry.h"
#import "DHCPLeaseOptionsEntry.h"
#import "DHCPServerOptionsEntry.h"
#import "DHCPEntry.h"

#import "DHCPTable.h"
@class DHCPStatusTable;
@class DHCPStaticConfigTable;
@class DHCPDynamicConfigTable;
@class DHCPLeaseOptionsTable;
@class DHCPServerOptionsTable;

// =================================================================================
//	¥ DHCPState
// =================================================================================
@interface DHCPState : PSStateEntry <PSTableDelegate> {
	id delegate;
	BOOL recordChanges;
}
- (id)initWithDefaults;
- (id)initWithNodeDictionary:(NSMutableDictionary *)value;
- (void)allocTables;
- (NSString *)description;
// accessors
- (id)delegate;
- (void)setDelegate:(id)value;
- (BOOL)recordChanges;
- (void)setRecordChanges:(BOOL)value;
- (void)changeDone;
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;
// Apply pending
- (NSNumber *)applyPending;
- (void)setApplyPending:(NSNumber *)value;
	// global parameters
- (NSNumber *)dhcpServerOn;
- (void)setDhcpServerOn:(NSNumber *)value;

- (NSNumber *)verboseLogging;
- (void)setVerboseLogging:(NSNumber *)value;

- (NSNumber *)ignoreBootp;
- (void)setIgnoreBootp:(NSNumber *)value;

- (NSNumber *)dynamicBootp;
- (void)setDynamicBootp:(NSNumber *)value;

- (NSNumber *)pingCheck;
- (void)setPingCheck:(NSNumber *)value;

- (NSString *)grantedMessage;
- (void)setGrantedMessage:(NSString *)value;

- (NSString *)notGrantedMessage;
- (void)setNotGrantedMessage:(NSString *)value;

- (NSString *)hostDNS;
- (void)setHostDNS:(NSString *)value;

// list of local DNS server IPs
- (NSString *)localDNS;
- (void)setLocalDNS:(NSString *)value;

	// tables
- (DHCPStatusTable *)statusTable;
- (DHCPStaticConfigTable *)staticConfigTable;
- (DHCPDynamicConfigTable *)dynamicConfigTable;
- (DHCPLeaseOptionsTable *)leaseOptionsTable;
- (DHCPServerOptionsTable *)serverOptionsTable;

- (void)setStatusTable:(DHCPStatusTable *)value;
- (void)setStaticConfigTable:(DHCPStaticConfigTable *)value;
- (void)setDynamicConfigTable:(DHCPDynamicConfigTable *)value;
- (void)setLeaseOptionsTable:(DHCPLeaseOptionsTable *)value;
- (void)setServerOptionsTable:(DHCPServerOptionsTable *)value;
	// table dictionaries
- (NSMutableDictionary *)statusTableDictionary;
- (NSMutableDictionary *)staticConfigTableDictionary;
- (NSMutableDictionary *)dynamicConfigTableDictionary;
- (NSMutableDictionary *)leaseOptionsTableDictionary;
- (NSMutableDictionary *)serverOptionsTableDictionary;

- (void)setStatusTableDictionary:(NSMutableDictionary *)value;
- (void)setStaticConfigTableDictionary:(NSMutableDictionary *)value;
- (void)setDynamicConfigTableDictionary:(NSMutableDictionary *)value;
- (void)setLeaseOptionsTableDictionary:(NSMutableDictionary *)value;
- (void)setServerOptionsTableDictionary:(NSMutableDictionary *)value;
	// table arrays
- (NSMutableArray *)statusTableArray;
- (NSMutableArray *)staticConfigTableArray;
- (NSMutableArray *)dynamicConfigTableArray;
- (NSMutableArray *)leaseOptionsTableArray;
- (NSMutableArray *)serverOptionsTableArray;

- (void)setStatusTableArray:(NSMutableArray *)value;
#if 0
- (void)setStaticConfigTableArray:(NSMutableArray *)value;
- (void)setDynamicConfigTableArray:(NSMutableArray *)value;
- (void)setLeaseOptionsTableArray:(NSMutableArray *)value;
- (void)setServerOptionsTableArray:(NSMutableArray *)value;
#endif

	// table entries
- (DHCPStatusEntry *)statusEntry;
- (void)setStatusEntry:(DHCPStatusEntry *)value;
@end
