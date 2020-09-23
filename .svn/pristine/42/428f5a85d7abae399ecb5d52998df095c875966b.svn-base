//
//  SentryState.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//  Encapsulate IPNetSentryX/IPNetRouterX settings and network state as part
//  of MVC design pattern
//
//  SentryDocument displays the current model and interprets user input to change model state.
//  SentryState maintains the model state and notifies observers when it changes.
//  SentryModel observes state changes and performs the corresponding model action.
//
//  SentryState communicates in two basic ways:
//  (1) Called explicitly to change model state and notifies any observers when state changes;
//  (2) Receives notifications from underlying network subsystems (SystemConfiguration,
//		and NKE Controller), and either modifies model state or passes them on.
//		NKE Controller observes KEVController when NKE is attached.

#import <Foundation/Foundation.h>
#import "PSToolState.h"
#import "SentryDefs.h"

@class SentryController;
// Basci Setup
@class FilterStyleTable;
@class ServiceTable;
@class DeviceTable;
// Expert View
@class FilterTable;
@class InterfaceTable;
@class TriggerTable;
@class TrafficDiscoveryState;
#ifdef IPNetRouter
@class PortMapTable;
@class NatTable;
@class RouteTable;
@class ArpTable;
@class AlternateRouteTable;
#endif

@interface SentryState : PSToolState {		
    // Store firewall state variables (model) in a mutable dictionary to simplify
    // coding and decoding interface entries.
//    NSMutableDictionary* nodeDictionary;
    // The variables to be represented are:
	//
	// - Basic Setup -
	// FilterStyleTable
	// ServiceTable
	// DeviceTable
	// - Expert View -
	// FilterTable* filterTable
	// InterfaceTable* interfaceTable
	// TriggerTable* triggerTable
	// PortMapTable* portMapTable
	// NatTable* natTable
	// NSNumber* firewallOn
	// NSNumber* selectedParameter
	// NSNumber* ipForwarding
	// NSNumber* triggerDuration
	// NSString* excludeNet
	// NSNumber* exposedHostSelection
	// NSString* exposedHost
	//
    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding
}

- (void)receiveNotification:(NSNotification *)aNotification;
// Apply pending
- (NSNumber *)applyPending;
- (void)setApplyPending:(NSNumber *)value;

// Basic Setup
// -----------
- (NSString *)basicInterfaceSelect;
- (void)setBasicInterfaceSelect:(NSString *)value;

- (NSString *)basicInterfaceUsing;
- (void)setBasicInterfaceUsing:(NSString *)value;

- (FilterStyleTable *)filterStyleTable;
- (void)setFilterStyleTable:(FilterStyleTable *)value;

- (ServiceTable *)serviceTable;
- (void)setServiceTable:(ServiceTable *)value;

- (DeviceTable *)deviceTable;
- (void)setDeviceTable:(DeviceTable *)value;

// Expert View
// -----------
// Table Accessors
- (FilterTable *)filterTable;
- (void)setFilterTable:(FilterTable *)value;

- (InterfaceTable *)interfaceTable;
- (void)setInterfaceTable:(InterfaceTable *)value;

- (TriggerTable *)triggerTable;
- (void)setTriggerTable:(TriggerTable *)value;

#ifdef IPNetRouter
- (NatTable *)natTable;
- (void)setNatTable:(NatTable *)value;

- (PortMapTable *)portMapTable;
- (void)setPortMapTable:(PortMapTable *)value;

- (RouteTable *)routeTable;
- (void)setRouteTable:(RouteTable *)value;

- (ArpTable *)arpTable;
- (void)setArpTable:(ArpTable *)value;

- (NSMutableDictionary *)nameServiceDictionary;
- (void)setNameServiceDictionary:(NSMutableDictionary *)value;
#endif
// other state
- (NSNumber *)firewallOn;
- (BOOL)setFirewallOn:(NSNumber *)value;

- (NSNumber *)selectedParameter;
- (void)setSelectedParameter:(NSNumber *)value;

- (NSNumber *)ipForwarding;
- (void)setIpForwarding:(NSNumber *)value;

- (NSNumber *)automaticFailover;
- (void)setAutomaticFailover:(NSNumber *)value;

- (NSNumber *)loadBalance;
- (void)setLoadBalance:(NSNumber *)value;

- (NSNumber *)sourceAwareRouting;
- (void)setSourceAwareRouting:(NSNumber *)value;

- (NSNumber *)portMapLogging;
- (void)setPortMapLogging:(NSNumber *)value;

- (NSNumber *)unregisteredOnly;
- (void)setUnregisteredOnly:(NSNumber *)value;

- (NSNumber *)blockIPv6;
- (void)setBlockIPv6:(NSNumber *)value;

#if 0
- (NSNumber *)trafficDiscovery;
- (void)setTrafficDiscovery:(NSNumber *)value;
- (NSNumber *)tdDevice;
- (void)setTdDevice:(NSNumber *)value;
- (NSNumber *)tdService;
- (void)setTdService:(NSNumber *)value;
- (NSNumber *)tdNetflow;
- (void)setTdNetflow:(NSNumber *)value;
#endif

- (NSNumber *)triggerDuration;
- (void)setTriggerDuration:(NSNumber *)value;

- (NSString *)excludeNet;
- (void)setExcludeNet:(NSString *)value;

- (NSNumber *)exposedHostSelection;
- (void)setExposedHostSelection:(NSNumber *)value;

- (NSString *)exposedHost;
- (void)setExposedHost:(NSString *)value;

// Preferences
- (NSNumber *)connectionLogging;
- (void)setConnectionLogging:(NSNumber *)value;

- (NSNumber *)bandwidthAccounting;
- (void)setBandwidthAccounting:(NSNumber *)value;

- (NSString *)accountingInterval;
- (void)setAccountingInterval:(NSString *)value;

- (NSNumber *)writeInterval;
- (void)setWriteInterval:(NSNumber *)value;

// Other Preference Settings
- (NSNumber *)logFormat;
- (void)setLogFormat:(NSNumber *)value;

- (NSString *)logUpdateInterval;
- (void)setLogUpdateInterval:(NSString *)value;

- (NSNumber *)saveToCheckBox;
- (void)setSaveToCheckBox:(NSNumber *)value;

- (NSString *)emailToField;
- (void)setEmailToField:(NSString *)value;

- (NSNumber *)emailBandwidthLog;
- (void)setEmailBandwidthLog:(NSNumber *)value;
- (NSNumber *)emailConnectionLog;
- (void)setEmailConnectionLog:(NSNumber *)value;
- (NSNumber *)emailDHCPLog;
- (void)setEmailDHCPLog:(NSNumber *)value;
- (NSNumber *)emailSecurityLog;
- (void)setEmailSecurityLog:(NSNumber *)value;

- (NSString *)appleScriptFile;
- (void)setAppleScriptFile:(NSString *)value;

- (NSNumber *)disableAlerts;
- (void)setDisableAlerts:(NSNumber *)value;

- (NSNumber *)disableCommandQ;
- (void)setDisableCommandQ:(NSNumber *)value;

@end
