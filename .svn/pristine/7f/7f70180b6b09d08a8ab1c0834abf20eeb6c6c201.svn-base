//
//  DocumentSupport.h
//  IPNetRouterX
//
//  Created by psichel on Fri Dec 26 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Factor out non-window functions of loading & saving documents

#import <Foundation/Foundation.h>
@class FilterTable;
@class SentryState;
@class InterfaceTable;

@interface DocumentSupport : NSObject
{
	NSMutableDictionary* saveDictionary;
	SentryState* sentryState;
	id delegate;		// used to set statusInfo if any
}
+ (DocumentSupport *)sharedInstance;
- (id)delegate;
- (void)setDelegate:(id)value;
- (BOOL)writeToFile:(NSString *)fileName;
- (BOOL)readFromFile:(NSString *)fileName;
// accessors
- (NSMutableDictionary *)saveDictionary;

// application state
- (void)saveState;
- (void)restoreState;
- (void)invokeDocumentFirewall;
- (void)invokeDocumentRouter;

// sentry state
- (SentryState *)sentryState;
- (void)setSentryState:(SentryState *)value;
//- (void)sentryApply;
//- (void)sentryOn:(BOOL)value;

// trigger table
- (BOOL)readTriggerTable;
- (BOOL)writeTriggerTable;
- (BOOL)triggerExportToFile:(NSString *)filePath;
- (BOOL)triggerImportFromFile:(NSString *)filePath useDefaults:(NSDictionary *)defaults;

// Routes
- (void)routeTableRestoreState;
- (void)arpTableRestoreState;
// AirPort
- (void)airPortApply;

#ifdef IPNetRouter
// DHCP
- (BOOL)staticConfigExportToFile:(NSString *)filePath;
- (BOOL)staticConfigImportFromFile:(NSString *)filePath;
#endif

@end

NSString* stringForWirelessError(int code);


#define kSentryDocument_name					@"SentryDocument_name"
#define kSentryDocument_columns					@"SentryDocument_columns1"
#define kSentryDocument_tabViewIdentifier		@"SentryDocument_tabViewIdentifier"
#define kSentryDocument_selectedParameter		@"SentryDocument_parameter"
#define kSentryDocument_logDrawerOpen			@"SentryDocument_logDrawerOpen"
#define kSentryDocument_logDrawerSize			@"SentryDocument_logDrawerSize"
#define kSentryDocument_firewallOn				@"SentryDocument_firewallOn"

#define kSentryDocument_filterStyleArray		@"SentryDocument_filterStyleArray"
#define kSentryDocument_serviceArray			@"SentryDocument_serviceArray"
#define kSentryDocument_deviceArray				@"SentryDocument_deviceArray"

#define kSentryDocument_filterTable				@"SentryDocument_filterTable"
#define kSentryDocument_triggerArray			@"SentryDocument_triggerArray"
#define kSentryDocument_interfaceArray			@"SentryDocument_interfaceArray"
#define kSentryDocument_natArray				@"SentryDocument_natArray"
#define kSentryDocument_portMapArray			@"SentryDocument_portMapArray"
#define kSentryDocument_routeArray				@"SentryDocument_routeArray"
#define kSentryDocument_arpArray				@"SentryDocument_arpArray"
#define kSentryDocument_alternateRouteArray		@"SentryDocument_alternateRouteArray"

#define kSentryDocument_triggerDuration			@"SentryDocument_triggerDuration"
#define kSentryDocument_excludeNet				@"SentryDocument_excludeNet"
#define kSentryDocument_ipForwarding			@"SentryDocument_ipForwarding"
#define kSentryDocument_exposedHostSelection	@"SentryDocument_exposedHostSelection"
#define kSentryDocument_exposedHost				@"SentryDocument_exposedHost"
#define kSentryDocument_automaticFailover		@"SentryDocument_automaticFailover"
#define kSentryDocument_loadBalance				@"SentryDocument_loadBalance"
#define kSentryDocument_sourceAwareRouting		@"SentryDocument_sourceAwareRouting"
#define kSentryDocument_portMapLogging			@"SentryDocument_portMapLogging"
#define kSentryDocument_unregisteredOnly		@"SentryDocument_unregisteredOnly"
#define kSentryDocument_blockIPv6				@"SentryDocument_blockIPv6"
#define kSentryDocument_trafficDiscovery		@"SentryDocument_trafficDiscovery"
#define kSentryDocument_tdDevice				@"SentryDocument_tdDevice"
#define kSentryDocument_tdService				@"SentryDocument_tdService"
#define kSentryDocument_tdNetflow				@"SentryDocument_tdNetflow"

//#define kSentryDocument_dhcpState @"SentryDocument_dhcpState"
//#define kSentryDocument_dhcpServerOn @"SentryDocument_dhcpServerOn"
//#define kSentryDocument_dhcpWindowOpen @"SentryDocument_dhcpWindowOpen"

#define kSentryDocument_nameServiceDictionary @"SentryDocument_nameServiceDictionary"

// Trigger Import constants
#define kTriggerImport_triggerType @"TriggerImport_triggerType"
#define kTriggerImport_triggeredBy @"TriggerImport_triggeredBy"
#define kTriggerImport_triggerDuration @"TriggerImport_triggerDuration"

// AirPort settings
#define kAirPort_restore @"AirPort_restore"
#define kAirPort_portType @"AirPort_portType"
#define kAirPort_networkName @"AirPort_networkName"
#define kAirPort_channel @"AirPort_channel"
#define kAirPort_apMode @"AirPort_apMode"
#define kAirPort_encryptionType @"AirPort_encryptionType"
#define kAirPort_password @"AirPort_password"

// invoke document after authorization has completed
#define kInvokeDocumentFirewall @"invokeDocumentFirewall"
#define kInvokeDocumentRouter @"invokeDocumentRouter"
// remember if we have invoked a document since Tiger might not do this
#define kInvokeDocumentDone @"invokeDocumentDone"
// remember if app was launched directly without a document
#define kLaunchingWithoutDocument @"launchedWithoutDocument"
