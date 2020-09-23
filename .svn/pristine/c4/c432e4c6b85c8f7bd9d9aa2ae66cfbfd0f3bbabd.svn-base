//
//  Scripting.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 8/9/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SentryModel.h"
#import "InterfaceTable.h"
#import "PortMapTable.h"
#import "TriggerTable.h"


@interface NSApplication (Scripting)

#pragma mark -- IPNetRouter Suite --
// ip forwarding
- (NSNumber *)ipForwarding;
- (void)setIpForwarding:(NSNumber *)value;

// IPNetRouterOn
- (NSNumber *)firewallOn;
- (void)setFirewallOn:(NSNumber *)value;

// interface table
- (NSMutableArray *)interfaces;
- (void)setInterfaceEntries:(NSMutableArray *)value;

// port map table
- (NSMutableArray *)portMaps;

// trigger table
- (NSMutableArray *)triggers;

@end
