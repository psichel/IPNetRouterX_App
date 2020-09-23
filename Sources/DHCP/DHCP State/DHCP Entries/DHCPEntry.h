//
//  DHCPEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

//  Common DHCP state definitions
// status entry
#define DS_ipAddress		@"ipAddress"
#define DS_leaseState		@"leaseState"
#define DS_lastUpdate		@"lastUpdate"
#define DS_lastUpdateStr	@"lastUpdateStr"
#define DS_expireTime       @"expireTime"
#define DS_expireTimeStr	@"expireTimeStr"
#define DS_hardwareAddress  @"hardwareAddress"
#define DS_clientID			@"clientID"
#define DS_action			@"action"
#define kActionUpdate 1
#define kActionDelete 2
// static config entry
#define DS_networkInterface @"networkInterface"
#define DS_comment			@"comment"
// dynamic config entry
#define DS_startingAddress  @"startingAddress"
#define DS_endingAddress	@"endingAddress"
// lease options entry
#define DS_dhcpOn			@"dhcpOn"
#define DS_router			@"router"
#define DS_nameServers		@"nameServers"
#define DS_defaultLeaseTime @"defaultLeaseTime"
#define DS_maxLeaseTime		@"maxLeaseTime"
#define DS_searchDomains	@"searchDomains"
// server options entry
#define DS_dhcpOptionNumber @"dhcpOptionNumber"
#define DS_dhcpOptionType	@"dhcpOptionType"
#define DS_dhcpOptionText   @"dhcpOptionText"
// dhcp state
#define DS_applyPending		@"applyPending"
#define DS_dhcpServerOn		@"dhcpServerOn"
#define DS_verboseLogging   @"verboseLogging"
#define DS_ignoreBootp		@"ignoreBootp"
#define DS_dynamicBootp		@"dynamicBootp"
#define DS_pingCheck		@"pingCheck"
#define DS_grantedMessage   @"grantedMessage"
#define DS_notGrantedMessage @"notGrantedMessage"
#define DS_hostDNS			@"hostDNS"
#define DS_localDNS			@"localDNS"
// update request
#define DS_updateHostDNS	@"updateHostDNS"
// record change to dhcp state
#define DS_changeDone		@"changeDone"

// table entry objects
#define DS_statusEntry					@"statusEntry"
#define DS_staticConfigEntry			@"staticConfigEntry"
#define DS_dynamicConfigEntry			@"dynamicConfigEntry"
#define DS_leaseOptionsEntry			@"leaseOptionsEntry"
#define DS_serverOptionsEntry			@"serverOptionsEntry"

