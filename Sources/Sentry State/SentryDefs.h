//
//  SentryDefs.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//  Common Sentry Definitions separate for SentryState object

// Basic Setup
#define SS_basicInterfaceSelect		@"basicInterfaceSelect"
#define SS_basicInterfaceUsing		@"basicInterfaceUsing"
#define SS_filterStyleTable			@"filterStyleTable"
#define SS_serviceTable				@"serviceTable"
#define SS_deviceTable				@"deviceTable"

// Expert View
#define SS_filterTable				@"filterTable"
#define SS_filterItem				@"filterItem"
#define SS_filterExpanded			@"filterExpanded"
#define SS_triggerTable				@"triggerTable"
#define SS_triggerItem				@"triggerItem"
#define SS_interfaceTable			@"interfaceTable"
#define SS_interfaceItem			@"interfaceItem"
#define SS_natTable					@"natTable"
#define SS_natItem					@"natItem"
#define SS_portMapTable				@"portMapTable"
#define SS_portMapItem				@"portMapItem"
#define SS_routeTable				@"routeTable"
#define SS_arpTable					@"arpTable"
#define SS_nameServiceDictionary	@"nameServiceDictionary"

#define SS_firewallOn				@"firewallOn"
#define SS_selectedParameter		@"selectedParameter"
//#define SS_ipForwarding				@"ipForwarding"
#define SS_automaticFailover		@"automaticFailover"
#define SS_loadBalance				@"loadBalance"
#define SS_sourceAwareRouting		@"sourceAwareRouting"
#define SS_portMapLogging			@"portMapLogging"
#define SS_portMapLoadCombos		@"portMapLoadCombos"
#define SS_unregisteredOnly			@"unregisteredOnly"
#define SS_blockIPv6				@"blockIPv6"
	#define SS_trafficDiscovery			@"trafficDiscovery"
	#define SS_tdDevice					@"tdDevice"
	#define SS_tdService				@"tdService"
	#define SS_tdNetflow				@"tdNetflow"
#define SS_triggerDuration			@"triggerDuration"
#define SS_connectionLogging		@"connectionLogging"
#define SS_bandwidthAccounting 		@"bandwidthAccounting"
#define SS_accountingInterval		@"accountingInterval"
#define SS_logUpdateInterval		@"logUpdateInterval"
#define SS_writeInterval 			@"writeInterval"
#define SS_excludeNet				@"excludeNet"
#define SS_exposedHostSelection		@"exposedHostSelection"
#define SS_exposedHost				@"exposedHost"
//#define SS_failoverLocation1		@"failoverLocation1"
//#define SS_failoverLocation2		@"failoverLocation2"
#define SS_applyPending				@"applyPending"
#define SS_documentChangeDone		@"documentChangeDone"

// Sentry Logger Actions
#define SA_logMessage				@"logMessage"
#define SA_appendMessage			@"appendMessage"

// document settings in prefs pane
#define kPreferences_connectionLogging	@"Preferences_connectionLogging"
#define kPreferences_bandwidthAccounting @"Preferences_bandwidthAccounting"
#define kPreferences_accountingInterval	@"Preferences_accountingInterval"
#define kPreferences_writeInterval 		@"Preferences_writeInterval"
// preference settings saved in document for startupItem
#define kPreferences_logFormat			@"Preferences_logFormat"
#define kPreferences_logUpdateInterval	@"Preferences_logUpdateInterval"
#define kPreferences_saveToCheckBox		@"Preferences_saveToCheckBox"
#define kPreferences_emailToField		@"Preferences_emailToField"
#define kPreferences_emailFromField		@"Preferences_emailFromField"
#define kPreferences_emailNameField		@"Preferences_emailNameField"

#define kPreferences_emailBandwidthLog	@"Preferences_emailBandwidthLog"
#define kPreferences_emailConnectionLog	@"Preferences_emailConnectionLog"
#define kPreferences_emailDHCPLog	@"Preferences_emailDHCPLog"
#define kPreferences_emailSecurityLog	@"Preferences_emailSecurityLog"

#define kPreferences_disableAlerts		@"Preferences_disableAlerts"
#define kPreferences_disableCommandQ	@"Preferences_disableCommandQ"
#define kPreferences_appleScriptFile	@"Preferences_appleScriptFile"

#define kLogFormat_propertyList	0
#define kLogFormat_text			1
#define kLogFormat_ipfw			2


