//
//  DocumentSupport.m
//  IPNetRouterX
//
//  Created by psichel on Fri Dec 26 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Factor out non-window functions of loading & saving documents

#import "DocumentSupport.h"
#import "NSMutableDictionary_Extensions.h"
#import "NSDate_Extensions.h"
#import "NSException_Extensions.h"
#import "AppDelegate.h"
#import "MenuDispatch.h"
#import "SentryLogger.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "TrafficDiscoveryState.h"
#import "SentryController.h"
// - Basic Setup
#import "FilterStyleTable.h"
#import "ServiceTable.h"
#import "DeviceTable.h"
// - Expert View
#import "InterfaceTable.h"
#import "TriggerTable.h"
#ifdef IPNetRouter
	#import "NatTable.h"
	#import "PortMapTable.h"
	#import "RouteTable.h"
	#import "ArpTable.h"
	#import "AlternateRouteModel.h"
	#import "RouteAction.h"
	#import "NameServiceModel.h"
	#import "DHCPSupport.h"
#endif
// filter tree
#import "FilterTable.h"
#import "FilterEntry.h"
// DHCP
#ifdef IPNetRouter
#import "DHCPController.h"
//#import "DHCPServer.h"
#import "DHCPState.h"
#import "DHCPServerWindowC.h"
//#import "DHCPAction.h"
#endif

//#import <Apple80211/Apple80211.h>
#import "Apple80211.h"
// supply missing forward declaration from Apple80211.h
WirelessError WirelessIBSSDisable(WirelessRef inRef);

@interface DocumentSupport (PrivateMethods)
- (void)sentrySaveState;
- (void)sentryRestoreState;
// - Basic Setup -
- (void)filterStyleTableRestoreState;
- (void)serviceTableRestoreState;
- (void)deviceTableRestoreState;
// - Expert View -
- (void)filterTableRestoreState;
- (void)triggerTableRestoreState;
- (void)interfaceTableRestoreState;
- (void)natTableRestoreState;
- (void)portMapTableRestoreState;
#ifdef IPNetRouter
- (void)dhcpSaveState;
- (void)dhcpRestoreState;
#endif
@end

@implementation DocumentSupport

// ---------------------------------------------------------------------------
//	� init and dealloc
// ---------------------------------------------------------------------------
+ (DocumentSupport *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[DocumentSupport allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

- (id) init {
    if (self = [super init]) {
		// initialize our instance variables
		saveDictionary = nil;
		sentryState = nil;
		delegate = nil;
    }
    return self;
}

- (void)dealloc {
    [saveDictionary release];   saveDictionary = nil;
	[sentryState release];		sentryState = nil;
	[self setDelegate:nil];
	[super dealloc];
}

- (id)delegate { return delegate; }
- (void)setDelegate:(id)value {
	//[value retain];
	//[delegate release];
	delegate = value;
}

// ---------------------------------------------------------------------------
//	� read/write
// ---------------------------------------------------------------------------
- (BOOL)writeToFile:(NSString *)fileName
{
	BOOL returnValue = NO;
	returnValue = [saveDictionary writeToFile:fileName atomically:YES];
	// log what we did
	NSString* str = [NSString stringWithFormat:@"Write settings to: %@",fileName];
	[[SentryLogger sharedInstance] logMessage:[[NSDictionary dictionaryWithObject:str forKey:@"statusInfo"] description]];
	return returnValue;
}

- (BOOL)readFromFile:(NSString *)fileName
{
	BOOL returnValue = NO;
	NSMutableDictionary* dictionary;
	NSString* str;

	dictionary = [NSMutableDictionary dictionaryWithContentsOfFile:fileName];
	if (dictionary) {
		[dictionary retain];
		[saveDictionary release];
		saveDictionary = dictionary;
		returnValue = YES;
		// log what we did
		str = [NSString stringWithFormat:@"Read settings from: %@",fileName];
		[[SentryLogger sharedInstance] logMessage:[[NSDictionary dictionaryWithObject:str forKey:@"statusInfo"] description]];
	}
	return returnValue;
}

// accessors
- (NSMutableDictionary *)saveDictionary { return saveDictionary; }

#pragma mark --- save all / restore all ---
// ---------------------------------------------------------------------------
//	� saveState
// ---------------------------------------------------------------------------
// transfer application state to saveDictionary
- (void)saveState
{
	[self sentrySaveState];
#ifdef IPNetRouter
	[self dhcpSaveState];
#endif
}
// ---------------------------------------------------------------------------
//	� restoreState
// ---------------------------------------------------------------------------
// load model State from saveDictionary
// invoke firewall (apply) if enabled
- (void)restoreState
{
	// load model state
	[self sentryRestoreState];
	// check if we have any saved airport state before trying to apply it
	if ([[saveDictionary objectForKey:kAirPort_restore] intValue]) [self airPortApply];
	if ([[AppDelegate sharedInstance] authorizationCompleted]) {
		// If document has firewall set to enabled, apply and set firewall active state
		if ([[saveDictionary objectForKey:kSentryDocument_firewallOn] intValue]) {
			[self invokeDocumentFirewall];
		}
		[self invokeDocumentRouter];
	}
	else {
		// tell NSApp to invoke us when authorization has completed
			// If document has firewall set to enabled, apply and set firewall active state
		if ([[saveDictionary objectForKey:kSentryDocument_firewallOn] intValue]) {
			[[PSSharedDictionary sharedInstance] setObject:self forKey:kInvokeDocumentFirewall];
		}
		[[PSSharedDictionary sharedInstance] setObject:self forKey:kInvokeDocumentRouter];
	}


}

// ---------------------------------------------------------------------------------
//	� invokeDocumentFirewall
// ---------------------------------------------------------------------------------
// Called after authorization has completed to finish restore and invoke document state
- (void)invokeDocumentFirewall
{
	id object;
	int count = 0;
	// If launched without a document
	if ([[PSSharedDictionary sharedInstance] objectForKey:kLaunchingWithoutDocument] != NULL) {
		count = [[SentryController sharedInstance] sendURL:kKFTInterfaceCount];
		// and NKE is attached to an interface (firewall is already on)
		if (count) {
			[sentryState updateParameter:SA_showActive withObject:self];
			[sentryState setFirewallOn:[NSNumber numberWithInt:1]];
		}
		[[PSSharedDictionary sharedInstance] removeObjectForKey:kLaunchingWithoutDocument];
	}
	if (count == 0) {
		// Download rules to NKE (Apply) and set firewall enabled based on saved state
		[sentryState updateParameter:SA_apply withObject:self];
		// Set firewall state explicitly if needed
		if ((object = [saveDictionary objectForKey:kSentryDocument_firewallOn])) {
			NSNumber *firewallOn = [sentryState firewallOn];
			if ([firewallOn intValue] != [object intValue]) {
				[sentryState setFirewallOn:object];
			}
			// clear change count in document
			[[SentryModel sharedInstance] updateChangeCount:NSChangeCleared];
		}
		// remember we did this
		[[PSSharedDictionary sharedInstance] setObject:self forKey:kInvokeDocumentDone];
	}
	// notify listeners with firewall state
//	[sentryState updateParameter:SS_firewallOn withObject:[sentryState firewallOn]];
}

// ---------------------------------------------------------------------------------
//	� invokeDocumentRouter
// ---------------------------------------------------------------------------------
// Called after authorization has completed to finish restore and invoke document state
- (void)invokeDocumentRouter
{
#ifdef IPNetRouter
	// restore any arp, routes, and dhcp we might have deferred (for authorization to complete)
	[self arpTableRestoreState];
	[self routeTableRestoreState];
	[self dhcpRestoreState];
	[[NameServiceModel sharedInstance] nameServiceRestore];
	[[PSSharedDictionary sharedInstance] setObject:self forKey:kInvokeDocumentDone];
#endif
}


#pragma mark --- Sentry State ---
// ---------------------------------------------------------------------------
//	� sentryState
// ---------------------------------------------------------------------------
- (SentryState *)sentryState { return sentryState; }
- (void)setSentryState:(SentryState *)value {
	[value retain];
	[sentryState release];
	sentryState = value;
	// mark state as not yet applied
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	� sentrySaveState
// ---------------------------------------------------------------------------
// transfer sentryState to saveDictionary
- (void)sentrySaveState
{
    NSMutableDictionary* dictionary;

		// save tables
	// - Basic Setup -
		// save filterStyleTable table
	[saveDictionary setValue:[[sentryState filterStyleTable] arrayOfDictionaries]
		forKey:kSentryDocument_filterStyleArray];
		// save serviceTable
	[saveDictionary setValue:[[sentryState serviceTable] arrayOfDictionaries]
		forKey:kSentryDocument_serviceArray];
		// save deviceTable
	[saveDictionary setValue:[[sentryState deviceTable] arrayOfDictionaries]
		forKey:kSentryDocument_deviceArray];
	// - Expert View -
	// get filter entry of root item and convert to dictionary
    dictionary = dictionaryFromTree([sentryState filterTable]);
	// remove status fields before saving state
	removeKeysFromDictionaryTree([NSArray arrayWithObjects:
		FE_matchCount,
		FE_matchDelta,
		FE_byteCount,
		FE_byteDelta,
		FE_lastTime,
		nil], dictionary);
	// store in save dictionary
	[saveDictionary setValue:dictionary forKey:kSentryDocument_filterTable];	
	// save trigger table
	[self writeTriggerTable];
	// save interface table
	[saveDictionary setValue:[[InterfaceTable sharedInstance] interfaceArrayOfDictionaries]
		forKey:kSentryDocument_interfaceArray];
#ifdef IPNetRouter
	// save nat table
	//[saveDictionary setValue:[[sentryState natTable] arrayOfDictionaries]
	//	forKey:kSentryDocument_natArray];
	// save portmap table
	[saveDictionary setValue:[[sentryState portMapTable] arrayOfDictionaries]
		forKey:kSentryDocument_portMapArray];
	// save route table
	[saveDictionary setValue:[[sentryState routeTable] arrayOfDictionaries]
		forKey:kSentryDocument_routeArray];
	// save arp table
	[saveDictionary setValue:[[sentryState arpTable] arrayOfDictionaries]
		forKey:kSentryDocument_arpArray];
	// save alternateRoute table
//	[saveDictionary setValue:[[[AlternateRouteModel sharedInstance] alternateRouteTable] arrayOfDictionaries]
//		forKey:kSentryDocument_alternateRouteArray];
	[[AlternateRouteModel sharedInstance] saveModelToSaveDictionary:saveDictionary];
#endif
		// other sentry state (corresponds to window controls)
	// parameter popup
	[saveDictionary setValue:[sentryState selectedParameter] forKey:kSentryDocument_selectedParameter];
	// remember trigger expiration
	[saveDictionary setValue:[sentryState triggerDuration] forKey:kSentryDocument_triggerDuration];
#ifdef IPNetRouter
	// ipForwarding
	[saveDictionary setValue:[sentryState ipForwarding] forKey:kSentryDocument_ipForwarding];
	// excludeNet
	[saveDictionary setValue:[sentryState excludeNet] forKey:kSentryDocument_excludeNet];
	// exposedHost
	[saveDictionary setValue:[sentryState exposedHost] forKey:kSentryDocument_exposedHost];
	// exposedHostSelection
	[saveDictionary setValue:[sentryState exposedHostSelection] forKey:kSentryDocument_exposedHostSelection];
	// automaticFailover
	[saveDictionary setValue:[sentryState automaticFailover] forKey:kSentryDocument_automaticFailover];
	// loadBalance
	[saveDictionary setValue:[sentryState loadBalance] forKey:kSentryDocument_loadBalance];
	// sourceAwareRouting
	[saveDictionary setValue:[sentryState sourceAwareRouting] forKey:kSentryDocument_sourceAwareRouting];
	// portMapLogging
	[saveDictionary setValue:[sentryState portMapLogging] forKey:kSentryDocument_portMapLogging];
	// unregisteredOnly
	[saveDictionary setValue:[sentryState unregisteredOnly] forKey:kSentryDocument_unregisteredOnly];
		// DNS Server
	[saveDictionary setValue:[sentryState nameServiceDictionary] forKey:kSentryDocument_nameServiceDictionary];
#endif
	// blockIPv6
	[saveDictionary setValue:[sentryState blockIPv6] forKey:kSentryDocument_blockIPv6];
	// trafficDiscovery
	TrafficDiscoveryState *tds = [TrafficDiscoveryState sharedInstance];
	[saveDictionary setValue:[tds trafficDiscovery] forKey:kSentryDocument_trafficDiscovery];
	[saveDictionary setValue:[tds tdDevice] forKey:kSentryDocument_tdDevice];
	[saveDictionary setValue:[tds tdService] forKey:kSentryDocument_tdService];
	[saveDictionary setValue:[tds tdNetflow] forKey:kSentryDocument_tdNetflow];
	// save firewall state in root dictionary
	[saveDictionary setValue:[sentryState firewallOn] forKey:kSentryDocument_firewallOn];
}

// ---------------------------------------------------------------------------
//	� sentryRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)sentryRestoreState
{
	id object;
	// allocate a new sentry state if needed
	if (!sentryState) {
		[self setSentryState:[[[SentryState alloc] init] autorelease]  ];
	}
	// update SentryModel with state we're about to restore
		// since interfaceTable is restored in place
	[[SentryModel sharedInstance] setSentryState:sentryState];

	// load FilterStyle table
	[self filterStyleTableRestoreState];
	// load Service table
	[self serviceTableRestoreState];
	// load Device table
	[self deviceTableRestoreState];
	
	// load Filter table
	[self filterTableRestoreState];
	// load Trigger table
	[self triggerTableRestoreState];
	// load Interface table
	[self interfaceTableRestoreState];
#if IPNetRouter
	// load Nat table
	[self natTableRestoreState];
	// load PortMap table
	[self portMapTableRestoreState];
	// load AlternateRoute model
	[[AlternateRouteModel sharedInstance] loadModelFromSaveDictionary:saveDictionary];
#endif
	// other sentry state
	// parameter popup
	if ((object = [saveDictionary objectForKey:kSentryDocument_selectedParameter]))
		[sentryState setSelectedParameter:object];
	else [sentryState setSelectedParameter:[NSNumber numberWithInt:1]]; // default to "match count"
	// trigger expiration
	if ((object = [saveDictionary objectForKey:kSentryDocument_triggerDuration])) {
		[sentryState setTriggerDuration:object];
	}

#if IPNetRouter	
	// ipForwarding
	if ((object = [saveDictionary objectForKey:kSentryDocument_ipForwarding])) {
		[sentryState setIpForwarding:object];
	}
	// excludeNet
	if ((object = [saveDictionary objectForKey:kSentryDocument_excludeNet])) {
		[sentryState setExcludeNet:object];
	}
	// exposedHost
	if ((object = [saveDictionary objectForKey:kSentryDocument_exposedHost])) {
		[sentryState setExposedHost:object];
	}
	// exposedHostSelection
	if ((object = [saveDictionary objectForKey:kSentryDocument_exposedHostSelection]))
		[sentryState setExposedHostSelection:object];

	// automaticFailover
	if ((object = [saveDictionary objectForKey:kSentryDocument_automaticFailover]))
		[sentryState setAutomaticFailover:object];
	// loadBalance
	if ((object = [saveDictionary objectForKey:kSentryDocument_loadBalance]))
		[sentryState setLoadBalance:object];
	// sourceAwareRouting
	if ((object = [saveDictionary objectForKey:kSentryDocument_sourceAwareRouting]))
		[sentryState setSourceAwareRouting:object];
	// portMapLogging
	if ((object = [saveDictionary objectForKey:kSentryDocument_portMapLogging]))
		[sentryState setPortMapLogging:object];
	// unregisteredOnly
	if ((object = [saveDictionary objectForKey:kSentryDocument_unregisteredOnly]))
		[sentryState setUnregisteredOnly:object];
	// DNS Server
	if ((object = [saveDictionary objectForKey:kSentryDocument_nameServiceDictionary]))
		[sentryState setNameServiceDictionary:object];
#endif	
	// trafficDiscovery
	TrafficDiscoveryState *tds = [TrafficDiscoveryState sharedInstance];
	if ((object = [saveDictionary objectForKey:kSentryDocument_trafficDiscovery]))
		[tds setTrafficDiscovery:object];
	if ((object = [saveDictionary objectForKey:kSentryDocument_tdDevice])) [tds setTdDevice:object];
		else [tds setTdDevice:[NSNumber numberWithInt:1]];
	if ((object = [saveDictionary objectForKey:kSentryDocument_tdService])) [tds setTdService:object];
		else [tds setTdService:[NSNumber numberWithInt:1]];
	if ((object = [saveDictionary objectForKey:kSentryDocument_tdNetflow])) [tds setTdNetflow:object];
		else [tds setTdNetflow:[NSNumber numberWithInt:1]];
	// blockIPv6
	if ((object = [saveDictionary objectForKey:kSentryDocument_blockIPv6]))
		[sentryState setBlockIPv6:object];

	// update SentryModel with state we restored
	//[[SentryModel sharedInstance] setSentryState:sentryState];
	
// can't do this here cuz authorization might not be ready, done in restoreState
#if 0	
	// firewallOn
		// do this last so that other state is ready
	if (object = [saveDictionary objectForKey:kSentryDocument_firewallOn]) {
		[sentryState setFirewallOn:object];
	}
#endif
}

#pragma mark - Basic Setup -
// ---------------------------------------------------------------------------
//	� filterStyleTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)filterStyleTableRestoreState
{
	id object;
	FilterStyleTable* filterStyleTable = [sentryState filterStyleTable];
	if (!filterStyleTable) {
		filterStyleTable = [[[FilterStyleTable alloc] init] autorelease];
		[sentryState setFilterStyleTable:filterStyleTable];
	}
	if ((object = [saveDictionary objectForKey:kSentryDocument_filterStyleArray])) {
		[filterStyleTable loadArrayOfDictionaries:object forEntryClass:[FilterStyleEntry class]];
	}
	// setup delegate in case new table was not assigned
	[filterStyleTable setDelegate:sentryState];
}

// ---------------------------------------------------------------------------
//	� serviceTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)serviceTableRestoreState
{
	id object;
	ServiceTable* serviceTable = [sentryState serviceTable];
	if (!serviceTable) {
		serviceTable = [[[ServiceTable alloc] init] autorelease];
		[sentryState setServiceTable:serviceTable];
	}
	if ((object = [saveDictionary objectForKey:kSentryDocument_serviceArray])) {
		[serviceTable loadArrayOfDictionaries:object forEntryClass:[ServiceEntry class]];
	}
	// setup delegate in case new table was not assigned
	[serviceTable setDelegate:sentryState];
}

// ---------------------------------------------------------------------------
//	� deviceTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)deviceTableRestoreState
{
	id object;
	DeviceTable* deviceTable = [sentryState deviceTable];
	if (!deviceTable) {
		deviceTable = [[[DeviceTable alloc] init] autorelease];
		[sentryState setDeviceTable:deviceTable];
	}
	if ((object = [saveDictionary objectForKey:kSentryDocument_deviceArray])) {
		[deviceTable loadArrayOfDictionaries:object forEntryClass:[DeviceEntry class]];
	}
	// setup delegate in case new table was not assigned
	[deviceTable setDelegate:sentryState];
}

#pragma mark - Expert View -
// ---------------------------------------------------------------------------
//	� filterTableRestoreState
// ---------------------------------------------------------------------------
- (void)filterTableRestoreState
{
    NSMutableDictionary* dictionary;
    FilterEntry* entry;
	
	// load filter table
    // build dictionary from saved file
    dictionary = [saveDictionary objectForKey:kSentryDocument_filterTable];
	// check for old format and try to convert it
	if (!dictionary) {
		id object;
		dictionary = [NSMutableDictionary dictionaryWithCapacity:10];
		// extract filter tree and transfer to new dictionary
		object = [saveDictionary objectForKey:TN_children];
		if (object) [dictionary setObject:object forKey:TN_children];
		[saveDictionary removeObjectForKey:TN_children];
		// transfer firewall enabled setting
		object = [saveDictionary objectForKey:FE_enabled];
		if (object) [saveDictionary setObject:object forKey:kSentryDocument_firewallOn];
		[saveDictionary removeObjectForKey:FE_enabled];
		// attach new dictionary
		[saveDictionary setObject:dictionary forKey:kSentryDocument_filterTable];
	}
    if (dictionary) {
        // set root item from converted dictionary
        entry = (FilterEntry *)treeFromDictionary(dictionary);
        if (entry) {
            FilterTable* filterTable;
			filterTable = [sentryState filterTable];
			if (!filterTable) {
				filterTable = [[[FilterTable alloc] init] autorelease];
				[sentryState setFilterTable:filterTable ];
            }
			[filterTable setNodeDictionary:[entry nodeDictionary]];
			// setup delegate in case new table was not assigned
			[filterTable setDelegate:sentryState];
			// update node numbers
			[filterTable setNodeNumber:nil];
			// notice we might not have a document window to show what we did yet
			// update results in windowControllerDidLoadNib
        }
    }
}

// ---------------------------------------------------------------------------
//	� triggerTableRestoreState
// ---------------------------------------------------------------------------
// load trigger table from file or saveDictionary
- (void)triggerTableRestoreState
{
	id object;
	if ([self readTriggerTable] == 0) {
		if ((object = [saveDictionary objectForKey:kSentryDocument_triggerArray])) {
			TriggerTable* triggerTable = [sentryState triggerTable];
			if (!triggerTable) {
				triggerTable = [[[TriggerTable alloc] init] autorelease];
				[sentryState setTriggerTable:triggerTable];
			}
			[triggerTable loadArrayOfDictionaries:object];
			// setup delegate in case new table was not assigned
			[triggerTable setDelegate:sentryState];
		}
	}
}

// ---------------------------------------------------------------------------
//	� interfaceTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)interfaceTableRestoreState
{
	NSDictionary* entryDictionary;
	NSArray* prevArray;
	NSArray* scfArray;
	NSMutableArray* prevInterfaceArray;
	NSMutableArray* interfaceArray;
	InterfaceEntry* entry;
	InterfaceEntry* myEntry;
	InterfaceEntry* prevEntry;
	NSEnumerator* en;
	InterfaceTable* scfTable;
	InterfaceTable* prevTable = nil;
	NSString* serviceID;
	NSString* interfaceID;
		
	// get previously saved interface array if any
	prevArray = [saveDictionary objectForKey:kSentryDocument_interfaceArray];
	if (prevArray) {
		// convert array of dictionaries to interface entries
		prevInterfaceArray = [NSMutableArray arrayWithCapacity:64];
		en = [prevArray objectEnumerator];
		while (entryDictionary = [en nextObject]) {
			[prevInterfaceArray addObject:[InterfaceEntry entryFromDictionary:entryDictionary]];
		}
		prevTable = [[[InterfaceTable alloc] init] autorelease];
		[prevTable setInterfaceArray:prevInterfaceArray];
	}
	// get current interface array from SCF
		// make sure table is up to date
	scfTable = [InterfaceTable sharedInstance];
	[scfTable updateFromSCF];
	scfArray = [scfTable interfaceArray];
	// allocate interfaceArray for new interface table (document data source)
	interfaceArray = [NSMutableArray arrayWithCapacity:64];
	
	// load interface array
	en = [scfArray objectEnumerator];
	while (entry = [en nextObject]) {
		myEntry = [[entry copy] autorelease];
		serviceID = [myEntry serviceID];
		interfaceID = [myEntry interfaceID];
		// apply previously saved user settings
		prevEntry = [prevTable entryForServiceID:serviceID];
			// if no match, try to match interfaceID for host-to-host portability
		if (!prevEntry) prevEntry = [prevTable entryForInterfaceID:interfaceID];
		// transfer user settings while keeping any previous SCF info
		if (prevEntry) {
			[myEntry setInterfaceName:[prevEntry interfaceName]];
			[myEntry setExcludeNet:[prevEntry excludeNet]];
			[myEntry setExposedHostSelection:[prevEntry exposedHostSelection]];
			[myEntry setExposedHost:[prevEntry exposedHost]];
			[myEntry setExposedHostSelection:[prevEntry exposedHostSelection]];
			[myEntry setFilterOn:[prevEntry filterOn]];
			[myEntry setExternalOn:[prevEntry externalOn]];
			[myEntry setNatOn:[prevEntry natOn]];
			[myEntry setBridgeOn:[prevEntry bridgeOn]];
		}
		// add to new array
		[interfaceArray addObject:myEntry];
	}
	// set interfaceArray in sentryState interfaceTable to preserve the dataSource object
	[scfTable setInterfaceArray:interfaceArray];
}

// ---------------------------------------------------------------------------
//	� natTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)natTableRestoreState
{
#ifdef IPNetRouter
	id object;
	NatTable* natTable = [sentryState natTable];
	if (!natTable) {
		natTable = [[[NatTable alloc] init] autorelease];
		[sentryState setNatTable:natTable];
	}
	if ((object = [saveDictionary objectForKey:kSentryDocument_natArray])) {
		[natTable loadArrayOfDictionaries:object];
	}
	// setup delegate in case new table was not assigned
	[natTable setDelegate:sentryState];
#endif
}

// ---------------------------------------------------------------------------
//	� portMapTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)portMapTableRestoreState
{
#ifdef IPNetRouter
	id object;
	PortMapTable* portMapTable = [sentryState portMapTable];
	if (!portMapTable) {
		portMapTable = [[[PortMapTable alloc] init] autorelease];
		[sentryState setPortMapTable:portMapTable];
	}
	else {
		// configure notifications
			// remove any previous PortMapTable notifications (defensive)
		[portMapTable removeObserver:sentryState];
		[portMapTable addObserver:sentryState withSelector:@selector(receiveNotification:)];
	}
	if ((object = [saveDictionary objectForKey:kSentryDocument_portMapArray])) {
		[portMapTable loadArrayOfDictionaries:object];
	}
	// update any dynamic port map entries
	[sentryState updateParameter:SA_portMapTable withObject:@"restoreState"];
#endif
}

#pragma mark -- Trigger Table --
// ---------------------------------------------------------------------------
//	� readTriggerTable
// ---------------------------------------------------------------------------
// triggerTable in /Library/Application Support/Sustainable Softworks/
// move to:
// /Library/Preferences/IPNetRouterX/triggerTable
// /Library/Preferences/IPNetSentryX/triggerTable
// return YES if table was read and loaded successfully.
- (BOOL)readTriggerTable
{
	BOOL returnValue = NO;
	NSString* path;
    NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* dataArray;
	
	do {		
		// get file destination
		// look in new location
		path = [AppSupport appPrefsPath:@"triggerTable"];
		if (![fm fileExistsAtPath:path]) {
			// if no such file, try old location
			path = [AppSupport appSupportSustworksPathRO:@"triggerTable"];
			if (!path) break;
		}
		NS_DURING
			// build array from saved file
			if ((dataArray = [NSArray arrayWithContentsOfFile:path])) {
				TriggerTable* triggerTable = [sentryState triggerTable];
				if (!triggerTable) {
					triggerTable = [[[TriggerTable alloc] init] autorelease];
					[sentryState setTriggerTable:triggerTable];
				}
				returnValue = [triggerTable loadArrayOfDictionaries:dataArray];
				// setup delegate in case new table was not assigned
				[triggerTable setDelegate:sentryState];
				// update display to reflect what we read in
				if (returnValue) [sentryState updateParameter:SS_triggerTable withObject:SS_triggerTable];
			}
		NS_HANDLER
			NSString* str = @"Exception while reading trigger table";
			[[SentryLogger sharedInstance] logMessage:
				[[NSDictionary dictionaryWithObject:str forKey:@"statusInfo"] description]];
		NS_ENDHANDLER
	} while (false);	
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� writeTriggerTable
// ---------------------------------------------------------------------------
- (BOOL)writeTriggerTable
{
	BOOL returnValue = NO;
	NSString* path;
    NSFileManager* fm;
    BOOL flag = YES;
	NSArray* dataArray;
	
	// get file destination
	path = [AppSupport appPrefsFolder];
	fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:path isDirectory:&flag]) {
		flag = [fm createDirectoryAtPath:path attributes:nil];
	}
	path = [path stringByAppendingPathComponent:@"triggerTable"];
	// convert status table to array of dictionaries
    dataArray = [[sentryState triggerTable] arrayOfDictionaries];
	// save array to disk
	returnValue = [dataArray writeToFile:path atomically:YES];
	return returnValue;
}


// ---------------------------------------------------------------------------
//	� triggerExportToFile:
// ---------------------------------------------------------------------------
- (BOOL)triggerExportToFile:(NSString *)filePath
{
	BOOL returnValue = NO;
	NSMutableString* exportText;
	TriggerTable* triggerTable;
	TriggerEntry* entry;
	NSString* address;
	NSString* type;
	NSString* triggeredBy;
	NSString* duration;
	int count, i;
	int value;
	
	do {
		// walk trigger table to extract entries
		triggerTable = [[[SentryModel sharedInstance] sentryState] triggerTable];
		count = [triggerTable count];
		exportText = [NSMutableString stringWithCapacity:count*80];
		for (i=0; i<count; i++) {
			entry = [triggerTable objectAtIndex:i];
			// extract row values
			address = [entry addressString];
			value = [[entry type] intValue];
			switch (value) {
				default:
				case 0: type = kTriggerTypeTriggerStr; break;
				case 1: type = kTriggerTypeAddressStr; break;
				case 2: type = kTriggerTypeAuthorizeStr; break;
				case 3: type = kTriggerTypeInvalidStr; break;
			}
			triggeredBy = [entry triggeredBy];
			duration = [[entry duration] stringValue];
			// append to result
			[exportText appendFormat:@"%@\t%@\t%@\t%@\r",address,type,triggeredBy,duration];
		}
		// write to file
		returnValue = [exportText writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� triggerImportFromFile
// ---------------------------------------------------------------------------
- (BOOL)triggerImportFromFile:(NSString *)filePath useDefaults:(NSDictionary *)defaults
{
	BOOL returnValue = NO;
	NSString* importData;
	NSArray* entryList;
	NSArray* entryFields;
	NSEnumerator* en;
	NSString* entryString;
	NSString* str;
	int value;
	int fieldCount;
	BOOL firstLine = YES;
	NSString* title = nil;
	do {
		importData = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
		if (!importData) break;
		// get list of imported entries and iterate
		NSRange range = [importData rangeOfString:@"\r"];
		if (range.length) entryList = [importData componentsSeparatedByString:@"\r"];
		else entryList = [importData componentsSeparatedByString:@"\n"];
			//NSLog(@"%@",[entryList description]);
		en = [entryList objectEnumerator];
		while (entryString = [en nextObject]) {
			if (![entryString length]) continue;
			if (firstLine) {
				if (([entryString hasPrefix:@"#"]) || ([entryString hasPrefix:@";"])) {
					title = [entryString substringFromIndex:1];
					title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
					continue;
				}
			}
			firstLine = NO;
			if ([entryString hasPrefix:@"#"]) continue;
			// allocate new entry
			TriggerEntry* entry;
			TriggerTable* triggerTable = [[[SentryModel sharedInstance] sentryState] triggerTable];
			entry = [[[TriggerEntry alloc] init] autorelease];
			// add corresponding triggerEntry based on field and dialog settings
			entryFields = [entryString componentsSeparatedByString:@"\t"];
			fieldCount = [entryFields count];
				// address
			[entry setAddressString:[entryFields objectAtIndex:0]];
				// type
			str = nil;
			if (fieldCount >= 2) str = [entryFields objectAtIndex:1];
			if (![str length]) [entry setType:[defaults objectForKey:kTriggerImport_triggerType]];
			else {
				value = 0;
				if ([str isEqualTo:kTriggerTypeTriggerStr]) value = 0;
				else if ([str isEqualTo:kTriggerTypeAddressStr]) value = 1;
				else if ([str isEqualTo:kTriggerTypeAuthorizeStr]) value = 2;
				else if ([str isEqualTo:kTriggerTypeInvalidStr]) value = 3;
				[entry setType:[NSNumber numberWithInt:value]];
			}
				// triggered by
			str = nil;
			if (fieldCount >= 3) str = [entryFields objectAtIndex:2];			
			if (![str length]) str = [defaults objectForKey:kTriggerImport_triggeredBy];
			if (![str length] && title) str = title;			
			[entry setTriggeredBy:str];
				// last time
			[entry setLastTime:[NSDate date]];
				// duration
			str = nil;
			if (fieldCount >= 4) str = [entryFields objectAtIndex:3];
			if (![str length]) [entry setDuration:[defaults objectForKey:kTriggerImport_triggerDuration]];
			else [entry setDuration:[NSNumber numberWithInt:[str intValue]]];
			// add new trigger entry to table
			[triggerTable insertObject:entry];
		}
		// reload trigger table
		[[[SentryModel sharedInstance] sentryState] updateParameter:SS_triggerTable withObject:SS_triggerTable];
		// enable apply button
		[sentryState setApplyPending:[NSNumber numberWithInt:1]];
		returnValue = YES;
	} while (false);
	return returnValue;
}

#pragma mark -- Route/ARP --
// ---------------------------------------------------------------------------
//	� routeTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)routeTableRestoreState
{
#ifdef IPNetRouter
	NSMutableArray* oldList;
	NSMutableArray* currentList;
	RouteTable* routeTable = [sentryState routeTable];
	RouteEntry* oldEntry;
	RouteEntry* currentEntry;
	NSRange range;
	int i, count;
	if (!routeTable) {
		routeTable = [[[RouteTable alloc] init] autorelease];
		[sentryState setRouteTable:routeTable];
	}
	if ((oldList = [saveDictionary objectForKey:kSentryDocument_routeArray])) {
		// convert array of dictionaries to corresponding entries
		[routeTable removeAllObjects];
		[routeTable loadArrayOfDictionaries:oldList];
		oldList = [routeTable routeArray];
		[[oldList retain] autorelease]; // retain so we can replace it
		// set table to use current list
		currentList = [[RouteAction sharedInstance] routeList:nil];
		[routeTable setRouteArray:currentList];
		// for each entry in old list, transfer what we need
		count = [oldList count];
		for (i=0; i<count; i++) {
			oldEntry = [oldList objectAtIndex:i];
			currentEntry = [routeTable matchingRouteEntry:oldEntry];
			if (currentEntry) {
				// transfer extra fields
				[currentEntry setComment:[oldEntry comment]];
				[currentEntry setRestore:[oldEntry restore]];
			}
			else {
				// check if we need to restore previous entry
				if ([[oldEntry restore] intValue]) {
						// only restore static entries
					range = [[oldEntry attributes] rangeOfString:RE_attributeStatic];
					if (range.length) {
						// transfer entry
						[routeTable addObject:oldEntry];
						// add to system Route table
						[[RouteAction sharedInstance] routeAdd:oldEntry];
					}
				}
			}
		}		
	}
#endif
}

// ---------------------------------------------------------------------------
//	� arpTableRestoreState
// ---------------------------------------------------------------------------
// load sentryState from saveDictionary
- (void)arpTableRestoreState
{
#ifdef IPNetRouter
	NSMutableArray* oldList;
	NSMutableArray* currentList;
	ArpTable* arpTable = [sentryState arpTable];
	ArpEntry* oldEntry;
	ArpEntry* currentEntry;
	NSRange range;
	int i, count;
	if (!arpTable) {
		arpTable = [[[ArpTable alloc] init] autorelease];
		[sentryState setArpTable:arpTable];
	}
	if ((oldList = [saveDictionary objectForKey:kSentryDocument_arpArray])) {
		// convert array of dictionaries to corresponding entries
		[arpTable removeAllObjects];
		[arpTable loadArrayOfDictionaries:oldList];
		oldList = [arpTable arpArray];
		[[oldList retain] autorelease]; // retain so we can replace it
		// set table to use current list
		currentList = [[RouteAction sharedInstance] arpList:nil];
		[arpTable setArpArray:currentList];
		// for each entry in old list, transfer what we need
		count = [oldList count];
		for (i=0; i<count; i++) {
			oldEntry = [oldList objectAtIndex:i];
			currentEntry = [arpTable entryForIpAddress:[oldEntry ipAddress]];
			if (currentEntry) {
				// transfer extra fields
				[currentEntry setComment:[oldEntry comment]];
				[currentEntry setRestore:[oldEntry restore]];
			}
			else {
				// check if we need to restore previous entry
				if ([[oldEntry restore] intValue]) {
					// only restore permanent ARP entries
					range = [[oldEntry attributes] rangeOfString:RE_attributePerm];
					if (range.length) {
						// transfer entry
						[arpTable addObject:oldEntry];
						// add to system ARP cache
						[[RouteAction sharedInstance] arpAdd:oldEntry];
					}
				}
			}
		}		
		
	}
#endif
}


#pragma mark --- AirPort ---

// ---------------------------------------------------------------------------
//	� airPortApply
// ---------------------------------------------------------------------------
- (void)airPortApply
{
	WirelessRef ref = 0;
	int unit = 0;
	WirelessError result = 0;;
	WirelessInfo info;
	NSString* str = nil;
	int i;
	
	do {
		// attach to driver
		result = WirelessAttach(&ref, unit);
		if (result == errWirelessKernelError) break;	// no wireless card, just bail
		if (result != errWirelessNoError) {
			str = [NSString stringWithFormat:@"WirelessAttach failed: %@",stringForWirelessError(result)];
			break;
		}
		
		// get info
		result = WirelessGetInfo(ref, &info);
		if (result != errWirelessNoError) {
			str =  [NSString stringWithFormat:@"WirelessGetInfo failed: %@",stringForWirelessError(result)];
			break;
		}
		if (info.linkStatus != kLinkStatusDisabled) {
			// apply saved parameters from document
			NSMutableDictionary* sd = saveDictionary;
			int inPortType;
			NSData* inSSID;
			int inChannel;
			WirelessAPMode inAPMode;
			WirelessEncryptType inKeyType;
			NSString* inPassphrase = nil;
			id object;
			// channel
			object = [sd objectForKey:kAirPort_portType];
			if (object) inPortType = [object intValue];
			else break;
			// network name
			object = [sd objectForKey:kAirPort_networkName];
			if (object) inSSID = [object dataUsingEncoding:NSUTF8StringEncoding];
			else break;
			// channel
			object = [sd objectForKey:kAirPort_channel];
			if (object) inChannel = [object intValue];
			else break;
			// apMode
			object = [sd objectForKey:kAirPort_apMode];
			if (object) inAPMode = [object intValue];
			else break;
			// encryptionType
			object = [sd objectForKey:kAirPort_encryptionType];
			if (object) inKeyType = [object intValue];
			else break;
			// password
			object = [sd objectForKey:kAirPort_password];
			if (object) inPassphrase = object;
			else break;
			
			switch (inPortType) {
			case 0: // kInfoPortTypeClient
				if (info.portType == kInfoPortTypeClient) {
					break;  // nothing to do
				}
				if (info.portType == kInfoPortTypeSWBS) {
					result = WirelessAccessPointDisable(ref);
					if (result != errWirelessNoError) {
						str = [NSString stringWithFormat:@"WirelessAccessPointDisable failed: %@",stringForWirelessError(result)];
						break;
					}
				}
				else if (info.portType == kInfoPortTypeIBSS) {
					result = WirelessIBSSDisable(ref);
					if (result != errWirelessNoError) {
						str =  [NSString stringWithFormat:@"WirelessIBSSDisable failed: %@",stringForWirelessError(result)];
						break;
					}
					// the above fails in testing so try going through AP mode
					result = WirelessGetInfo(ref, &info);
					if (info.portType == kInfoPortTypeIBSS) {
						if ([inSSID length] == 0) inSSID = [@"temp000" dataUsingEncoding:NSUTF8StringEncoding];
						WirelessAccessPointEnable(ref,
							(CFDataRef)inSSID, inChannel, inAPMode, inKeyType, (CFStringRef)inPassphrase);
						WirelessAccessPointDisable(ref);
					}
				}
				// wait for operation to complete so we can update status
				for (i=0; i<10; i++) {
					result = WirelessGetInfo(ref, &info);
					if (info.portType == kInfoPortTypeClient) break;  // we're done
					[NSThread  sleepUntilDate:[NSDate
						dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
				}
				break;
			case 1: // kInfoPortTypeSWBS
				//if (info.portType == kInfoPortTypeSWBS)  update settings below
				if (info.portType == kInfoPortTypeIBSS) {
					result = WirelessIBSSDisable(ref);
					if (result != errWirelessNoError) {
						str =  [NSString stringWithFormat:@"WirelessIBSSDisable failed: %@",stringForWirelessError(result)];
						break;
					}
				}
				// setup SWBS mode
				result = WirelessAccessPointEnable(ref,
					(CFDataRef)inSSID, inChannel, inAPMode, inKeyType, (CFStringRef)inPassphrase);
				if (result != errWirelessNoError) {
					str =  [NSString stringWithFormat:@"WirelessAccessPointEnable failed: %@",stringForWirelessError(result)];
					break;
				}
				// wait for operation to complete so we can update status
				for (i=0; i<10; i++) {
					result = WirelessGetInfo(ref, &info);
					if (info.portType == kInfoPortTypeSWBS) break;  // we're done
					[NSThread  sleepUntilDate:[NSDate
						dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
				}
				break;
			case 2: // kInfoPortTypeIBSS (Computer-to-Computer)
				// if (info.portType == kInfoPortTypeIBSS) => update settings below
				if (info.portType == kInfoPortTypeSWBS) {
					result = WirelessAccessPointDisable(ref);
					if (result != errWirelessNoError) {
						str =  [NSString stringWithFormat:@"WirelessAccessPointDisable failed: %@",stringForWirelessError(result)];
						break;
					}
				}
				// setup IBSS mode
				result = WirelessIBSSEnable(ref,
					(CFDataRef)inSSID, inChannel, inAPMode, inKeyType, (CFStringRef)inPassphrase);
				if (result != errWirelessNoError) {
					str =  [NSString stringWithFormat:@"WirelessIBSSEnable failed: %@",stringForWirelessError(result)];
					break;
				}
				// wait for operation to complete so we can update status
				for (i=0; i<10; i++) {
					result = WirelessGetInfo(ref, &info);
					if (info.portType == kInfoPortTypeIBSS) break;  // we're done
					[NSThread  sleepUntilDate:[NSDate
						dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
				}
				break;
			}
		}   // if (info.linkStatus != kLinkStatusDisabled)
		
	} while (false);
	if (result != errWirelessNoError) {
		[delegate updateParameter:@"statusInfo" withObject:str];
		NSLog(@"%@",str);
	}
	// detach from driver
	if (ref) WirelessDetach(ref);
}

#ifdef IPNetRouter
#pragma mark --- DHCP ---

// ---------------------------------------------------------------------------
//	� dhcpSaveState
// ---------------------------------------------------------------------------
// transfer dhcpState to saveDictionary
- (void)dhcpSaveState
{
	NSMutableDictionary* dhcpDictionary;
	DHCPState *dhcpState = [[DHCPController sharedInstance] dhcpState];
	if (dhcpState) {
		dhcpDictionary = saveDictionaryForDhcpState(dhcpState);
				// store in save dictionary
		[saveDictionary setObject:dhcpDictionary forKey:kSentryDocument_dhcpState];
		// save DHCP Window Open and Server On state from document
		int value = [[MenuDispatch sharedInstance] dhcpServerCount];
		[saveDictionary setObject:[NSNumber numberWithInt:value] forKey:kSentryDocument_dhcpWindowOpen];
		NSNumber* num = [dhcpState dhcpServerOn];
		if (num) [saveDictionary setObject:num forKey:kSentryDocument_dhcpServerOn];
		// save state for local DHCP Server process
		writeDhcpSettings(dhcpDictionary);
	}
}

// ---------------------------------------------------------------------------
//	� dhcpRestoreState
// ---------------------------------------------------------------------------
// load dhcpState from saveDictionary
- (void)dhcpRestoreState
{
	@try {
		id object;
		// get DHCP state from IPNRx saved document (if any)
		object = [saveDictionary objectForKey:kSentryDocument_dhcpState];
		// try to read state for local server process
		if (!object) object = readDhcpSettings();
		if (object) {
			DHCPState *dhcpState = dhcpStateForSaveDictionary(object);

			[[DHCPController sharedInstance] setDhcpState:dhcpState];
			// restore DHCP Window Open and Server On state from document
	//		if (object = [saveDictionary objectForKey:kSentryDocument_dhcpWindowOpen])
	//			if ([object intValue] && !gStartupItem) [[MenuDispatch sharedInstance] showWindow:self];
			if ((object = [saveDictionary objectForKey:kSentryDocument_dhcpServerOn])) {
				int serverOn = [object intValue];
				[[DHCPController sharedInstance] dhcpServerOn:serverOn];
			}
			[dhcpState setRecordChanges:YES];
		}
	}
	@catch( NSException *theException ) {
		NSLog(@"Exception during dhcpRestoreState");
		[theException printStackTrace];
	}
}

// ---------------------------------------------------------------------------
//	� staticConfigExportToFile:
// ---------------------------------------------------------------------------
- (BOOL)staticConfigExportToFile:(NSString *)filePath
{
	BOOL returnValue = NO;
	NSMutableString* exportText;
	DHCPStaticConfigTable* table;
	DHCPStaticConfigEntry* entry;
	NSString* ipAddress;
	NSString* hardwareAddress;
	NSString* clientID;
	NSString* comment;
	int count, i;
	
	DHCPState *dhcpState = [[DHCPController sharedInstance] dhcpState];
	do {
		table = [dhcpState staticConfigTable];		// PSArrayTable
		count = [table count];
		exportText = [NSMutableString stringWithCapacity:count*80];
		for (i=0; i<count; i++) {
			entry = [table objectAtIndex:i];
			// extract row values
			ipAddress = [entry ipAddress];
			hardwareAddress = [entry hardwareAddress];
			if (!hardwareAddress) hardwareAddress = @"";
			clientID = [entry clientID];
			if (!clientID) clientID = @"";
			comment = [entry comment];
			if (!comment) comment = @"";		
			// append to result
			[exportText appendFormat:@"%@\t%@\t%@\t%@\r",ipAddress,hardwareAddress,clientID,comment];
		}
		// write to file
		returnValue = [exportText writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� staticConfigImportFromFile
// ---------------------------------------------------------------------------
- (BOOL)staticConfigImportFromFile:(NSString *)filePath
{
	BOOL returnValue = NO;
	NSString* importData;
	NSArray* entryList;
	NSArray* entryFields;
	NSEnumerator* en;
	NSString* entryString;
	int count;
	NSString* str;
	do {
		DHCPState *dhcpState = [[DHCPController sharedInstance] dhcpState];
		DHCPStaticConfigTable* table = [dhcpState staticConfigTable];		// PSArrayTable
		// read  import data
		importData = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
		if (!importData) break;
		// get list of imported entries and iterate
		entryList = [importData componentsSeparatedByString:@"\r"];
			//NSLog(@"%@",[entryList description]);
		en = [entryList objectEnumerator];
		while (entryString = [en nextObject]) {
			if (![entryString length]) continue;
			// allocate new entry
			DHCPStaticConfigEntry* entry = [[[DHCPStaticConfigEntry alloc] init] autorelease];
			// add corresponding triggerEntry based on field and dialog settings
			entryFields = [entryString componentsSeparatedByString:@"\t"];
			count = [entryFields count];
				// ipAddress
			NSString* ipAddress = [entryFields objectAtIndex:0];
			[entry setIpAddress:ipAddress];
				// hardwareAddress
			[entry setHardwareAddress:[entryFields objectAtIndex:1]];
				// clientID
			if (count > 2) {
				str = [entryFields objectAtIndex:2];
				if ([str length]) [entry setClientID:str];
			}
				// comment
			if (count > 3) {
				str = [entryFields objectAtIndex:3];
				if ([str length]) [entry setComment:str];
			}
			// try to fill in network from IP address
			InterfaceEntry* interfaceE = [[InterfaceTable sharedInstance] entryForAddress:ipAddress];
			[entry setNetworkInterface:[interfaceE ifNet]];
			// add new static confif entry to table
			[table setObject:entry forKey:ipAddress];
		}
		// reload staticConfig table
		[dhcpState updateParameter:DS_staticConfigEntry withObject:DS_staticConfigEntry];
		// enable apply button
		[dhcpState setApplyPending:[NSNumber numberWithInt:1]];
		returnValue = YES;
	} while (false);
	return returnValue;
}

#endif
@end


NSString* stringForWirelessError(int code)
{
	NSString* returnValue = nil;
	switch (code) {
		case errWirelessNotOnThisPlatform:
			returnValue = @"Wireless not on this platform";
			break;
		case errWirelessParameterError:
			returnValue = @"Wireless parameter error";
			break;
		case errWirelessNotAttached:
			returnValue = @"Wireless not attached";
			break;
		case errWirelessKernelError:
			returnValue = @"Wireless kernel error";
			break;
		case errWirelessIOError:
			returnValue = @"Wireless IO error";
			break;
		case errWirelessNoMemory:
			returnValue = @"Wireless no memory";
			break;
		case errWirelessTimeout:
			returnValue = @"Wireless time out";
			break;
		case errWirelessUnexpected:
			returnValue = @"Wireless unexpected";
			break;
		case errWirelessBadPassword:
			returnValue = @"Wireless bad password";
			break;
		case errWirelessNotActive:
			returnValue = @"Wireless not active";
			break;
		case errWirelessSNMPError:
			returnValue = @"Wireless SNMP error";
			break;
		case errWirelessPowerOff:
			returnValue = @"Wireless power off";
			break;
		case errWirelessDuplicateIBSS:
			returnValue = @"Wireless duplicate IBSS";
			break;
		case errWirelessBadAuth:
			returnValue = @"Wireless bad authorization";
			break;
		case errWirelessNotClientMode:
			returnValue = @"Wireless not client mode";
			break;
		case errWirelessAPVersionNotRecognized:
			returnValue = @"Wireless not recognized";
			break;
		case errWirelessNotAuthenticated:
			returnValue = @"Wireless not authenticated";
			break;
		case errWirelessDirectScanFail:
			returnValue = @"Wireless direct scan fail";
			break;
		case errWirelessAssociateTimeout:
			returnValue = @"Wireless associate time out";
			break;
	}
	return returnValue;
}

