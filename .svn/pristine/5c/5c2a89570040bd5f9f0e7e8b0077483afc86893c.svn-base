//
//  SentryState.m
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

#import "SentryState.h"
#import "SentryModel.h"
#import "SystemConfiguration.h"
#import "SystemConfigurationNotifications.h"
#import "AppDelegate.h"
#import "IPSupport.h"

#import "BasicSetupWC.h"
#import "FilterStyleTable.h"
#import "ServiceTable.h"
#import "DeviceTable.h"

#import "ExpertViewWC.h"
#import "FilterTable.h"
#import "TriggerTable.h"
#import "InterfaceTable.h"
#ifdef IPNetRouter
	#import "NatTable.h"
	#import "PortMapTable.h"
	#import "PortMapEntry.h"
	#import "RouteTable.h"
	#import "ArpTable.h"
	#import "DHCPController.h"
#endif
#import "PreferencesController.h"
#import "SentryLogger.h"
#import "BandwidthAccounting.h"
// NKE test from client
#import PS_TNKE_INCLUDE
#import "kft.h"
#import "SentryTest.h"
#import "AppDelegate.h"

@implementation SentryState

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
	}
    return self;
}
// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	// release dictionaries we allocated
    [super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ receiveNotification:
// ---------------------------------------------------------------------------------
// pass along any notifications we receive
- (void)receiveNotification:(NSNotification *)aNotification
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSDictionary* dictionary;
	NSEnumerator* en;
    id key;
    id object;
	BOOL passOn = YES;

	dictionary = [aNotification userInfo];
    en = [dictionary keyEnumerator];

	while ((key = [en nextObject])) { 
		/* code that uses the returned key */
		if (![key isKindOfClass:[NSString class]]) continue; 
		object = [dictionary objectForKey:key];
			// InterfaceTable, PortMapTable notifications
		// documentChangeDone
		if ([key isEqualTo:SS_documentChangeDone]) {
			[self setApplyPending:[NSNumber numberWithInt:1]];
			passOn = NO;
		}
		else if ([key isEqualTo:SS_ipForwarding]) {
			[self setIpForwarding:object];
			passOn = NO;
		}
		else if ([key isEqualTo:SS_firewallOn]) {
			[self updateParameter:SS_firewallOn withObject:[self firewallOn]];
			passOn = NO;
		}
	}
	if (passOn) {
		// notify listeners with dictionary
		[[NSNotificationCenter defaultCenter]
			postNotificationName:PSToolStateNotification
			object:self
			userInfo:dictionary];
	}
    [pool release];
}

// ---------------------------------------------------------------------------------
//	¥ applyPending
// ---------------------------------------------------------------------------------
- (NSNumber *)applyPending { return [nodeDictionary objectForKey:SS_applyPending]; }
- (void)setApplyPending:(NSNumber *)value
{
	// if setting has changed
	NSNumber* oldValue = [nodeDictionary objectForKey:SS_applyPending];
	if ([value intValue] != [oldValue intValue]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_applyPending];
		else [nodeDictionary removeObjectForKey:SS_applyPending];
		// notify listeners
		[self updateParameter:SS_applyPending withObject:value];
	}
}

#pragma mark - Basic Setup -
- (NSString *)basicInterfaceSelect { return [nodeDictionary objectForKey:SS_basicInterfaceSelect]; }
- (void)setBasicInterfaceSelect:(NSString *)value {
	// if setting has changed
	if (![value isEqualTo:[nodeDictionary objectForKey:SS_basicInterfaceSelect]]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_basicInterfaceSelect];
		else [nodeDictionary removeObjectForKey:SS_basicInterfaceSelect];
		// notify listeners
		[self updateParameterCD:SS_basicInterfaceSelect withObject:value];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}
- (NSString *)basicInterfaceUsing { return [nodeDictionary objectForKey:SS_basicInterfaceUsing]; }
- (void)setBasicInterfaceUsing:(NSString *)value {
	// if setting has changed
	//if (![value isEqualTo:[nodeDictionary objectForKey:SS_basicInterfaceUsing]]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_basicInterfaceUsing];
		else [nodeDictionary removeObjectForKey:SS_basicInterfaceUsing];
		// notify listeners
		[self updateParameter:SS_basicInterfaceUsing withObject:value];
		//[delegate updateParameter:SS_documentChangeDone withObject:[NSNumber numberWithInt:NSChangeDone]];
		//[self setApplyPending:[NSNumber numberWithInt:1]];
	//}
}

// ---------------------------------------------------------------------------------
//	¥ setFilterStyleTable:
// ---------------------------------------------------------------------------------
- (FilterStyleTable *)filterStyleTable { return [nodeDictionary objectForKey:SS_filterStyleTable]; }
- (void)setFilterStyleTable:(FilterStyleTable *)value {
	// if setting has changed
	if (value != [self filterStyleTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_filterStyleTable];
		else [nodeDictionary removeObjectForKey:SS_filterStyleTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_filterStyleTable withObject:SS_filterStyleTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setServiceTable:
// ---------------------------------------------------------------------------------
- (ServiceTable *)serviceTable { return [nodeDictionary objectForKey:SS_serviceTable]; }
- (void)setServiceTable:(ServiceTable *)value {
	// if setting has changed
	if (value != [self serviceTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_serviceTable];
		else [nodeDictionary removeObjectForKey:SS_serviceTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_serviceTable withObject:SS_serviceTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setDeviceTable:
// ---------------------------------------------------------------------------------
- (DeviceTable *)deviceTable { return [nodeDictionary objectForKey:SS_deviceTable]; }
- (void)setDeviceTable:(DeviceTable *)value {
	// if setting has changed
	if (value != [self deviceTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_deviceTable];
		else [nodeDictionary removeObjectForKey:SS_deviceTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_deviceTable withObject:SS_deviceTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}


#pragma mark - Expert View -
#pragma mark --- Table Accessors ---
// ---------------------------------------------------------------------------------
//	¥ setFilterTable:
// ---------------------------------------------------------------------------------
- (FilterTable *)filterTable { return [nodeDictionary objectForKey:SS_filterTable]; }
- (void)setFilterTable:(FilterTable *)value {
	// if setting has changed
	if (value != [self filterTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_filterTable];
		else [nodeDictionary removeObjectForKey:SS_filterTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_filterTable withObject:SS_filterTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setinterfaceTable:
// ---------------------------------------------------------------------------------
- (InterfaceTable *)interfaceTable { return [nodeDictionary objectForKey:SS_interfaceTable]; }
- (void)setInterfaceTable:(InterfaceTable *)value {
	InterfaceTable *previousTable = [self interfaceTable];
	// if setting has changed
	if (value != previousTable) {
		// remove previous notifications
		if (previousTable) {
			[previousTable removeObserver:self];
			#if IPNetRouter
			[previousTable removeObserver:[DHCPController sharedInstance]];
			#endif
		}
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_interfaceTable];
		else [nodeDictionary removeObjectForKey:SS_interfaceTable];
		// configure new notifications
		if (value) {
			[value addObserver:self withSelector:@selector(receiveNotification:)];
			#if IPNetRouter
			[value addObserver:[DHCPController sharedInstance] withSelector:@selector(receiveNotification:)];
			#endif
		}
		// notify listeners
		[self updateParameter:SS_interfaceTable withObject:SS_interfaceTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setTriggerTable:
// ---------------------------------------------------------------------------------
- (TriggerTable *)triggerTable { return [nodeDictionary objectForKey:SS_triggerTable]; }
- (void)setTriggerTable:(TriggerTable *)value {
	// if setting has changed
	if (value != [self triggerTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_triggerTable];
		else [nodeDictionary removeObjectForKey:SS_triggerTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_triggerTable withObject:SS_triggerTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

#ifdef IPNetRouter
// ---------------------------------------------------------------------------------
//	¥ setNatTable:
// ---------------------------------------------------------------------------------
- (NatTable *)natTable { return [nodeDictionary objectForKey:SS_natTable]; }
- (void)setNatTable:(NatTable *)value {
	// if setting has changed
	if (value != [self natTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_natTable];
		else [nodeDictionary removeObjectForKey:SS_natTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_natTable withObject:SS_natTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setPortMapTable:
// ---------------------------------------------------------------------------------
- (PortMapTable *)portMapTable { return [nodeDictionary objectForKey:SS_portMapTable]; }
- (void)setPortMapTable:(PortMapTable *)value {
	PortMapTable *previousTable = [self portMapTable];
	// if setting has changed
	if (value != previousTable) {
		// configure notifications
		[previousTable removeObserver:self];
		[value addObserver:self withSelector:@selector(receiveNotification:)];
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_portMapTable];
		else [nodeDictionary removeObjectForKey:SS_portMapTable];
		// notify listeners
		[self updateParameter:SS_portMapTable withObject:SS_portMapTable];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ routeTable
// ---------------------------------------------------------------------------------
- (RouteTable *)routeTable { return [nodeDictionary objectForKey:SS_routeTable]; }
- (void)setRouteTable:(RouteTable *)value {
	// if setting has changed
	if (value != [self routeTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_routeTable];
		else [nodeDictionary removeObjectForKey:SS_routeTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_routeTable withObject:SS_routeTable];
	}
}

// ---------------------------------------------------------------------------------
//	¥ arpTable
// ---------------------------------------------------------------------------------
- (ArpTable *)arpTable { return [nodeDictionary objectForKey:SS_arpTable]; }
- (void)setArpTable:(ArpTable *)value {
	// if setting has changed
	if (value != [self arpTable]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_arpTable];
		else [nodeDictionary removeObjectForKey:SS_arpTable];
		// notify listeners
		[value setDelegate:self];
		[self updateParameter:SS_arpTable withObject:SS_arpTable];
	}
}

// ---------------------------------------------------------------------------------
//	¥ nameServiceDictionary
// ---------------------------------------------------------------------------------
- (NSMutableDictionary *)nameServiceDictionary { return [nodeDictionary objectForKey:SS_nameServiceDictionary]; }
- (void)setNameServiceDictionary:(NSMutableDictionary *)value {
	// if setting has changed
	if (value != [self nameServiceDictionary]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_nameServiceDictionary];
		else [nodeDictionary removeObjectForKey:SS_nameServiceDictionary];
		// notify listeners
		[self updateParameter:SS_nameServiceDictionary withObject:SS_nameServiceDictionary];
	}
}

#endif

#pragma mark --- Other State ---
// ---------------------------------------------------------------------------------
//	¥ setFirewallOn:
// ---------------------------------------------------------------------------------
// return YES if state changed
- (NSNumber *)firewallOn { return [nodeDictionary objectForKey:SS_firewallOn]; }
- (BOOL)setFirewallOn:(NSNumber *)value {
	BOOL returnValue = NO;
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_firewallOn];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_firewallOn];
		else [nodeDictionary removeObjectForKey:SS_firewallOn];
		// notify listeners
		[self updateParameterCD:SS_firewallOn withObject:value];
		returnValue = YES;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ selectedParameter:
// ---------------------------------------------------------------------------------
- (NSNumber *)selectedParameter { return [nodeDictionary objectForKey:SS_selectedParameter]; }
- (void)setSelectedParameter:(NSNumber *)value
{
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_selectedParameter];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_selectedParameter];
		else [nodeDictionary removeObjectForKey:SS_selectedParameter];
		// notify listeners
		[self updateParameterCD:SS_selectedParameter withObject:value];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setIpForwarding:
// ---------------------------------------------------------------------------------
- (NSNumber *)ipForwarding { return [nodeDictionary objectForKey:SS_ipForwarding]; }
- (void)setIpForwarding:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_ipForwarding];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_ipForwarding];
		else [nodeDictionary removeObjectForKey:SS_ipForwarding];
		// notify listeners
		[self updateParameterCD:SS_ipForwarding withObject:value];
	}
	else {
		// force system setting to update even if model didn't change
		[[SentryModel sharedInstance] enableIpForwarding:value];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setAutomaticFailover:
// ---------------------------------------------------------------------------------
- (NSNumber *)automaticFailover { return [nodeDictionary objectForKey:SS_automaticFailover]; }
- (void)setAutomaticFailover:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_automaticFailover];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_automaticFailover];
		else [nodeDictionary removeObjectForKey:SS_automaticFailover];
		// notify listeners
		[self updateParameterCD:SS_automaticFailover withObject:value];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setLoadBalance:
// ---------------------------------------------------------------------------------
- (NSNumber *)loadBalance { return [nodeDictionary objectForKey:SS_loadBalance]; }
- (void)setLoadBalance:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_loadBalance];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_loadBalance];
		else [nodeDictionary removeObjectForKey:SS_loadBalance];
		// notify listeners
		[self updateParameterCD:SS_loadBalance withObject:value];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setSourceAwareRouting:
// ---------------------------------------------------------------------------------
- (NSNumber *)sourceAwareRouting { return [nodeDictionary objectForKey:SS_sourceAwareRouting]; }
- (void)setSourceAwareRouting:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_sourceAwareRouting];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_sourceAwareRouting];
		else [nodeDictionary removeObjectForKey:SS_sourceAwareRouting];
		// notify listeners
		[self updateParameterCD:SS_sourceAwareRouting withObject:value];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setPortMapLogging:
// ---------------------------------------------------------------------------------
- (NSNumber *)portMapLogging { return [nodeDictionary objectForKey:SS_portMapLogging]; }
- (void)setPortMapLogging:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_portMapLogging];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_portMapLogging];
		else [nodeDictionary removeObjectForKey:SS_portMapLogging];
		// notify listeners
		[self updateParameterCD:SS_portMapLogging withObject:value];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setUnregisteredOnly:
// ---------------------------------------------------------------------------------
- (NSNumber *)unregisteredOnly { return [nodeDictionary objectForKey:SS_unregisteredOnly]; }
- (void)setUnregisteredOnly:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_unregisteredOnly];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_unregisteredOnly];
		else [nodeDictionary removeObjectForKey:SS_unregisteredOnly];
		// notify listeners
		[self updateParameterCD:SS_unregisteredOnly withObject:value];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setBlockIPv6:
// ---------------------------------------------------------------------------------
- (NSNumber *)blockIPv6 { return [nodeDictionary objectForKey:SS_blockIPv6]; }
- (void)setBlockIPv6:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_blockIPv6];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_blockIPv6];
		else [nodeDictionary removeObjectForKey:SS_blockIPv6];
		// notify listeners
		[self updateParameterCD:SS_blockIPv6 withObject:value];
	}
}

#if 0
// ---------------------------------------------------------------------------------
//	¥ setTrafficDiscovery:
// ---------------------------------------------------------------------------------
- (NSNumber *)trafficDiscovery { return [nodeDictionary objectForKey:SS_trafficDiscovery]; }
- (void)setTrafficDiscovery:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_trafficDiscovery];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_trafficDiscovery];
		else [nodeDictionary removeObjectForKey:SS_trafficDiscovery];
		// notify listeners
		[self updateParameterCD:SS_trafficDiscovery withObject:value];
	}
}

- (NSNumber *)tdDevice { return [nodeDictionary objectForKey:SS_tdDevice]; }
- (void)setTdDevice:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_tdDevice];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_tdDevice];
		else [nodeDictionary removeObjectForKey:SS_tdDevice];
		// notify listeners
		[self updateParameterCD:SS_tdDevice withObject:value];
	}
}

- (NSNumber *)tdService { return [nodeDictionary objectForKey:SS_tdService]; }
- (void)setTdService:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_tdService];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_tdService];
		else [nodeDictionary removeObjectForKey:SS_tdService];
		// notify listeners
		[self updateParameterCD:SS_tdService withObject:value];
	}
}

- (NSNumber *)tdNetflow { return [nodeDictionary objectForKey:SS_tdNetflow]; }
- (void)setTdNetflow:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_tdNetflow];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_tdNetflow];
		else [nodeDictionary removeObjectForKey:SS_tdNetflow];
		// notify listeners
		[self updateParameterCD:SS_tdNetflow withObject:value];
	}
}
#endif


// ---------------------------------------------------------------------------------
//	¥ setTriggerDuration:
// ---------------------------------------------------------------------------------
- (NSNumber *)triggerDuration { return [nodeDictionary objectForKey:SS_triggerDuration]; }
- (void)setTriggerDuration:(NSNumber *)value {
	int duration = [value intValue];
	if (duration == 255) {
		// request value from NKE
		[self updateParameter:SS_triggerDuration withObject:value];
	}
	else {
		// if setting has changed
		NSNumber* previous = [nodeDictionary objectForKey:SS_triggerDuration];
		if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
			// update model
			if (value) {
				if ((0 <= duration) && (duration <= kTriggerDurationMax)) {
					[nodeDictionary setObject:value forKey:SS_triggerDuration];
					// notify listeners
					[self updateParameterCD:SS_triggerDuration withObject:value];
				}
			}
			else [nodeDictionary removeObjectForKey:SS_triggerDuration];
		}
	}
}

// ---------------------------------------------------------------------------------
//	¥ excludeNet:
// ---------------------------------------------------------------------------------
//- (NSString *)excludeNet { return [nodeDictionary objectForKey:SS_excludeNet]; }
- (NSString *)excludeNet { return nil; }	// ***
- (void)setExcludeNet:(NSString *)value
{
	// if setting has changed
	if (![value isEqualTo:[nodeDictionary objectForKey:SS_excludeNet]]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_excludeNet];
		else [nodeDictionary removeObjectForKey:SS_excludeNet];
		[[self interfaceTable] setExcludeNet:value];
		// notify listeners
		[self updateParameterCD:SS_excludeNet withObject:value];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ exposedHostSelection:
// ---------------------------------------------------------------------------------
- (NSNumber *)exposedHostSelection { return [nodeDictionary objectForKey:SS_exposedHostSelection]; }
- (void)setExposedHostSelection:(NSNumber *)value
{
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_exposedHostSelection];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_exposedHostSelection];
		else [nodeDictionary removeObjectForKey:SS_exposedHostSelection];
		[[self interfaceTable] setExposedHostSelection:value];
		// notify listeners
		[self updateParameterCD:SS_exposedHostSelection withObject:value];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ exposedHost:
// ---------------------------------------------------------------------------------
- (NSString *)exposedHost { return [nodeDictionary objectForKey:SS_exposedHost]; }
- (void)setExposedHost:(NSString *)value
{
	// if setting has changed
	if (![value isEqualTo:[nodeDictionary objectForKey:SS_exposedHost]]) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_exposedHost];
		else [nodeDictionary removeObjectForKey:SS_exposedHost];
		[[self interfaceTable] setExposedHost:value];
		// notify listeners
		[self updateParameterCD:SS_exposedHost withObject:value];
		[self setApplyPending:[NSNumber numberWithInt:1]];
	}
}

#pragma mark --- PREFERENCES ---
// Some are actually per document settings configured via the preferences panel
// while other will take the setting from the common application prefs if available
// ---------------------------------------------------------------------------
//	¥ setConnectionLogging
// ---------------------------------------------------------------------------
// document setting, use preferences for backward compatibility
- (NSNumber *)connectionLogging {
	id returnValue = [nodeDictionary objectForKey:kPreferences_connectionLogging];
	if (!returnValue)
		returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_connectionLogging];
	return returnValue;
}
- (void)setConnectionLogging:(NSNumber *)value
{
	if ([[self connectionLogging] intValue] != [value intValue]) {	// setting has changed
		// set in preferences
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_connectionLogging];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_connectionLogging];
		else [nodeDictionary removeObjectForKey:kPreferences_connectionLogging];
		// notify listeners
		[self updateParameterCD:SS_connectionLogging withObject:value];
	}
}

// ---------------------------------------------------------------------------
//	¥ setBandwidthAccounting
// ---------------------------------------------------------------------------
// document setting, use preferences for backward compatibility
- (NSNumber *)bandwidthAccounting {
	id returnValue = [nodeDictionary objectForKey:kPreferences_bandwidthAccounting];
	if (!returnValue)
		returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_bandwidthAccounting];
	return returnValue;
}
- (void)setBandwidthAccounting:(NSNumber *)value
{
	if ([[self bandwidthAccounting] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_bandwidthAccounting];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_bandwidthAccounting];
		else [nodeDictionary removeObjectForKey:kPreferences_bandwidthAccounting];
		// notify listeners
		[self updateParameterCD:SS_bandwidthAccounting withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ accountingInterval
// ---------------------------------------------------------------------------
// document setting, use preferences for backward compatibility
- (NSString *)accountingInterval {
	id returnValue = [nodeDictionary objectForKey:kPreferences_accountingInterval];
	if (!returnValue)
		returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_accountingInterval];
	if (!returnValue) returnValue = @"60 minutes";	// default to 1 hour
	return returnValue;
}
- (void)setAccountingInterval:(NSString *)value
{
	NSString* previous;
	previous = [self accountingInterval];
	if (![value isEqualTo:previous]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_accountingInterval];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_accountingInterval];
		else [nodeDictionary removeObjectForKey:kPreferences_accountingInterval];
		// notify listeners
		[self updateParameterCD:SS_accountingInterval withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ setWriteInterval
// ---------------------------------------------------------------------------
// document setting, use preferences for backward compatibility
- (NSNumber *)writeInterval {
	id returnValue = [nodeDictionary objectForKey:kPreferences_writeInterval];
	if (!returnValue)
		returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_writeInterval];
	return returnValue;
}
- (void)setWriteInterval:(NSNumber *)value
{
	if ([[self writeInterval] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_writeInterval];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_writeInterval];
		else [nodeDictionary removeObjectForKey:kPreferences_writeInterval];
		// notify listeners
		[self updateParameterCD:SS_writeInterval withObject:value];
	}
}

// Other Preference Settings
// ---------------------------------------------------------------------------
//	¥ logFormat
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)logFormat {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_logFormat];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_logFormat];
	return returnValue;
}
- (void)setLogFormat:(NSNumber *)value
{
	if ([[self logFormat] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_logFormat];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_logFormat];
		else [nodeDictionary removeObjectForKey:kPreferences_logFormat];
		// notify listeners
		[self updateParameterCD:kPreferences_logFormat withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ logUpdateInterval
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSString *)logUpdateInterval {
	id returnValue = [nodeDictionary objectForKey:kPreferences_logUpdateInterval];
	if (!returnValue)
		returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_logUpdateInterval];
	if (!returnValue) returnValue = @"60 minutes";	// default to 1 hour
	return returnValue;
}
- (void)setLogUpdateInterval:(NSString *)value
{
	NSString* previous;
	previous = [self logUpdateInterval];
	if (![value isEqualTo:previous]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_logUpdateInterval];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_logUpdateInterval];
		else [nodeDictionary removeObjectForKey:kPreferences_logUpdateInterval];
		// notify listeners
		[self updateParameterCD:SS_logUpdateInterval withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ saveToCheckBox
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)saveToCheckBox {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_saveToCheckBox];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_saveToCheckBox];
	return returnValue;
}
- (void)setSaveToCheckBox:(NSNumber *)value
{
	if ([[self saveToCheckBox] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_saveToCheckBox];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_saveToCheckBox];
		else [nodeDictionary removeObjectForKey:kPreferences_saveToCheckBox];
		// notify listeners
		[self updateParameterCD:kPreferences_saveToCheckBox withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ emailToField
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSString *)emailToField {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_emailToField];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_emailToField];
	return returnValue;
}
- (void)setEmailToField:(NSString *)value
{
	NSString* previous;
	previous = [self emailToField];
	if (![value isEqualTo:previous]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_emailToField];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_emailToField];
		else [nodeDictionary removeObjectForKey:kPreferences_emailToField];
		// notify listeners
		[self updateParameterCD:kPreferences_emailToField withObject:value];
	}
}

// ---------------------------------------------------------------------------
//	¥ emailBandwidthLog
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)emailBandwidthLog {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_emailBandwidthLog];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_emailBandwidthLog];
	return returnValue;
}
- (void)setEmailBandwidthLog:(NSNumber *)value
{
	if ([[self emailBandwidthLog] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_emailBandwidthLog];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_emailBandwidthLog];
		else [nodeDictionary removeObjectForKey:kPreferences_emailBandwidthLog];
		// notify listeners
		[self updateParameterCD:kPreferences_emailBandwidthLog withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ emailConnectionLog
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)emailConnectionLog {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_emailConnectionLog];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_emailConnectionLog];
	return returnValue;
}
- (void)setEmailConnectionLog:(NSNumber *)value
{
	if ([[self emailConnectionLog] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_emailConnectionLog];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_emailConnectionLog];
		else [nodeDictionary removeObjectForKey:kPreferences_emailConnectionLog];
		// notify listeners
		[self updateParameterCD:kPreferences_emailConnectionLog withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ emailDHCPLog
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)emailDHCPLog {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_emailDHCPLog];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_emailDHCPLog];
	return returnValue;
}
- (void)setEmailDHCPLog:(NSNumber *)value
{
	if ([[self emailDHCPLog] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_emailDHCPLog];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_emailDHCPLog];
		else [nodeDictionary removeObjectForKey:kPreferences_emailDHCPLog];
		// notify listeners
		[self updateParameterCD:kPreferences_emailDHCPLog withObject:value];
	}
}
// ---------------------------------------------------------------------------
//	¥ emailSecurityLog
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)emailSecurityLog {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_emailSecurityLog];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_emailSecurityLog];
	return returnValue;
}
- (void)setEmailSecurityLog:(NSNumber *)value
{
	if ([[self emailSecurityLog] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_emailSecurityLog];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_emailSecurityLog];
		else [nodeDictionary removeObjectForKey:kPreferences_emailSecurityLog];
		// notify listeners
		[self updateParameterCD:kPreferences_emailSecurityLog withObject:value];
	}
}

// ---------------------------------------------------------------------------
//	¥ appleScriptFile
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSString *)appleScriptFile {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_appleScriptFile];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_appleScriptFile];
	return returnValue;
}
- (void)setAppleScriptFile:(NSString *)value
{
	NSString* previous;
	previous = [self appleScriptFile];
	if (![value isEqualTo:previous]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_appleScriptFile];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_appleScriptFile];
		else [nodeDictionary removeObjectForKey:kPreferences_appleScriptFile];
		// notify listeners
		[self updateParameterCD:kPreferences_appleScriptFile withObject:value];
	}
}

// ---------------------------------------------------------------------------
//	¥ disableAlerts
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)disableAlerts {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_disableAlerts];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_disableAlerts];
	return returnValue;
}
- (void)setDisableAlerts:(NSNumber *)value
{
	if ([[self disableAlerts] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_disableAlerts];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_disableAlerts];
		else [nodeDictionary removeObjectForKey:kPreferences_disableAlerts];
		// notify listeners
		[self updateParameterCD:kPreferences_disableAlerts withObject:value];
	}
}

// ---------------------------------------------------------------------------
//	¥ disableCommandQ
// ---------------------------------------------------------------------------
// preference setting, use document for startupItem
- (NSNumber *)disableCommandQ {
	id returnValue = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_disableCommandQ];
	if (!returnValue)
		returnValue = [nodeDictionary objectForKey:kPreferences_disableCommandQ];
	return returnValue;
}
- (void)setDisableCommandQ:(NSNumber *)value
{
	if ([[self disableCommandQ] intValue] != [value intValue]) {	// setting has changed
		[[[AppDelegate sharedInstance] prefs] setObject:value forKey:kPreferences_disableCommandQ];
		// update model
		if (value) [nodeDictionary setObject:value forKey:kPreferences_disableCommandQ];
		else [nodeDictionary removeObjectForKey:kPreferences_disableCommandQ];
		// notify listeners
		[self updateParameterCD:kPreferences_disableCommandQ withObject:value];
	}
}

@end
