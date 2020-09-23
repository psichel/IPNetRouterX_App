//
//  DHCPSupport.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 7/20/07.
//  Copyright 2007 Sustainable Softworks. All rights reserved.
//
//  Support routines used by both DHCP Server and UI Client

#import <Foundation/Foundation.h>
@class DHCPState;

#define kDhcpSettingsFile	@"dhcpServerConfig.plist"

NSDictionary* readDhcpSettings();
BOOL writeDhcpSettings(NSDictionary* dhcpSaveDictionary);
NSMutableDictionary* saveDictionaryForDhcpState(DHCPState* dhcpState);
DHCPState* dhcpStateForSaveDictionary(NSDictionary* saveDictionary);



#define kSentryDocument_dhcpState @"SentryDocument_dhcpState"
#define kSentryDocument_dhcpServerOn @"SentryDocument_dhcpServerOn"
#define kSentryDocument_dhcpWindowOpen @"SentryDocument_dhcpWindowOpen"

// logging levels
#define kDHCP_exceptionLogging  0
#define kDHCP_summaryLogging	1
#define kDHCP_verboseLogging	2

#define kServerWriteStatus  @"writeStatus"
