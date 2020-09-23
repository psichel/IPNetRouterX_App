//
//  SentryModel.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//  Encapsulate IPNetSentryX/IPNetRouterX model actions as part of MVC design pattern.
//
//  SentryDocument displays the current model and interprets user input to change model state.
//  SentryState maintains the model state and notifies observers when it changes.
//  SentryModel observes state changes and performs the corresponding model action.
//
//	SentryModel performs the corresponding model action when notified of state
//	changes from SentryState.

#include "Test_In_Client.h"
#import "SentryModel.h"
#import "DocumentSupport.h"
#import "SentryState.h"
#import "TrafficDiscoveryState.h"
#import "SentryTest.h"
#import "SentryController.h"
#import "FilterTable.h"
#import "PSPropertyValue.h"
#import "TriggerTable.h"
#import "InterfaceTable.h"
#import "InterfaceEntry.h"
#if IPNetRouter
	#import "NatTable.h"
	#import "PortMapTable.h"
	#import "PortMapEntry.h"
	#import "kftNatTable.h"
	#import "kftPortMapTable.h"
	#import "DHCPController.h"
	#import "DHCPState.h"		// DS_updateHostDNS
	#import "NameServiceModel.h"
	#import "AlternateRouteModel.h"
#endif
#import "SystemConfiguration.h"
#import "SystemConfigurationNotifications.h"
//#import "PreferencesController.h"
#import "SentryLogger.h"
#import "BandwidthAccounting.h"
#import "ConnectionLog.h"
#import "NSDate_Extensions.h"
#import "PSURL.h"
#import "IPValue.h"
#import "IPHost.h"
#import "IPSupport.h"
#import "AppDelegate.h"
#import PS_TNKE_INCLUDE
#import "kft.h"
#import "kftTrigger.h"


// globals for testing in client
// =============================
// drop Connection response
// max size of drop Response
#define KFT_dropResponseMax 1000

// drop Connection response
u_int8_t PROJECT_dropResponseBuffer[KFT_dropResponseMax];
int PROJECT_dropResponseLength;
// time of day info
sopt_timeParam_t PROJECT_timeOfDay;
// timer Ref Count (firewall enabled)
int32_t PROJECT_timerRefCount;
// flags
u_int32_t PROJECT_flags;
    // ipk_timeout reschedules itself when PROJECT_timerRefCount>0
int PROJECT_doRateLimit;			// packet matched a rate limit rule
	// reserve bandwidth info
KFT_reserveInfo_t PROJECT_rReserveInfo;
KFT_reserveInfo_t PROJECT_sReserveInfo;
// ---------------------------------------------------------------------------
// Advanced Routing Table
// ---------------------------------------------------------------------------
KFT_routeEntry_t PROJECT_route[kMaxRoute+1];
int PROJECT_routeCount;

// Array of DLIL attach instances
attach_t PROJECT_attach[kMaxAttach+1];


// Private Methods
@interface SentryModel (PrivateMethods)
- (void)enableFirewallOn:(NSNumber *)value;
- (void)enableBandwidthAccounting:(NSNumber *)value;
- (void)enableAccountingInterval:(NSString *)value;
- (void)enableConnectionLogging:(NSNumber *)value;
// Actions
- (void)apply:(id)sender;
- (void)showActive:(id)sender;
- (void)testButton:(id)sender;
- (void)triggerDelete:(NSString *)url;
// support
- (int)downloadFilterTable;
- (void)downloadInterfaceTable;
- (void)downloadTriggerTable;
- (void)uploadFilterTable;
- (void)uploadTriggerTable;
- (void)uploadInterfaceTable;
#ifdef IPNetRouter
- (void)setProxyLocal:(PortMapEntry *)portMapE;
- (void)uploadPortMapTable;
- (void)uploadNatTable;
#endif
// testing
- (void)attachInterfaceEntry:(InterfaceEntry *)entry;
- (void)detachInterfaceEntry:(InterfaceEntry *)entry;
@end

@implementation SentryModel

// ---------------------------------------------------------------------------------
//	• sharedInstance
// ---------------------------------------------------------------------------------
+ (SentryModel *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[SentryModel alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
		sentryState = nil;
		pending = NO;
		logger = [SentryLogger sharedInstance];
		windowController = nil;
		document = nil;
#if TEST_IN_CLIENT
		{
			int i;
			for (i=0; i<=kMaxAttach; i++) {
				bzero(&PROJECT_attach[i], sizeof(attach_t));
			}
		}
#endif		
		// setup KFT structures
		KFT_init();
    }
    return self;
}
// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
    // remove ourself as observer
	[self setSentryState:nil];
	[windowController release]; windowController = nil;
	[document release]; document = nil;
	
    [super dealloc];
}

#pragma mark - ACCESSORS -
// ---------------------------------------------------------------------------------
//	• sentryState
// ---------------------------------------------------------------------------------
- (SentryState *)sentryState
{
	// If we don't have a sentry state yet (user has not read a document or pressed Apply),
	// try to get one from last read document
	if (!sentryState) [self setSentryState:[[DocumentSupport sharedInstance] sentryState]];
	// if that fails, just create an empty one
	// [could try to read default settings like [ExpertViewWC -showDocument]
	if (!sentryState) sentryState = [[SentryState alloc] init];
	return sentryState;
}

// ---------------------------------------------------------------------------------
//	• setSentryState
// ---------------------------------------------------------------------------------
- (void)setSentryState:(SentryState *)value
{
	[value retain];
	[sentryState removeObserver:self];
	[sentryState release];
	sentryState = value;
	[sentryState addObserver:self withSelector:@selector(receiveNotification:)];
}

// ---------------------------------------------------------------------------------
//	• interfaceTable
// ---------------------------------------------------------------------------------
- (InterfaceTable *)interfaceTable
{
	return [[self sentryState] interfaceTable];
}


#pragma mark --- EDIT HELPERS ---
// =================================================================================
// edit helpers
// =================================================================================
- (id)windowController { return windowController; }
- (void)setWindowController:(id)value
{
    [value retain];
	[windowController release];
	windowController = value;
	
	value = [windowController document];
	[value retain];
	[document release];
	document = value;
}

// ---------------------------------------------------------------------------------
//	• updateChangeCount
// ---------------------------------------------------------------------------------
- (void)updateChangeCount:(NSDocumentChangeType)change
{
	[document updateChangeCount:change];
}

#pragma mark - ACTIONS -
// ---------------------------------------------------------------------------
//	• receiveNotification
// ---------------------------------------------------------------------------
// perform corresponding action when state changes
// PSToolStateNotification
- (void)receiveNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;
	NSEnumerator* enumerator;
    id key;
    id object;

	dictionary = [aNotification userInfo];
    enumerator = [dictionary keyEnumerator];

	while ((key = [enumerator nextObject])) { 
		/* code that uses the returned key */
		if (![key isKindOfClass:[NSString class]]) continue; 
		object = [dictionary objectForKey:key];

		// documentChangeDone
		if ([key isEqualTo:SS_documentChangeDone]) {
			[self updateChangeCount:NSChangeDone];
			continue;
		}
		if ([key isEqualTo:SA_logMessage]) {
			[logger logMessage:object];
			continue;
		}
		if ([key isEqualTo:SA_appendMessage]) {
			[logger appendMessage:object];
			continue;
		}
		// log statusInfo or statusInfoAppend messages
		if ([key isEqualTo:@"statusInfo"] || [key isEqualTo:@"statusInfoAppend"]) {
			//[logger logMessage:object];
			[logger logMessage:[dictionary description]];
			if (gStartupItem) NSLog(@"%@",object);
			continue;
		}
		// firewallOn
		if ([key isEqualTo:SS_firewallOn]) {
			[self enableFirewallOn:object];
			continue;
		}
		// ipForwarding
		if ([key isEqualTo:SS_ipForwarding]) {
			[self enableIpForwarding:object];
			continue;
		}
		// ipForwardingApply
		if ([key isEqualTo:SA_ipForwardingApply]) {
			[self enableIpForwarding:[sentryState ipForwarding]];
			continue;
		}
		// automaticFailover
		if ([key isEqualTo:SS_automaticFailover]) {
			[self enableAutomaticFailover:object];
			continue;
		}
		// loadBalance
		if ([key isEqualTo:SS_loadBalance]) {
			[self enableLoadBalance:object];
			continue;
		}
		// sourceAwareRouting
		if ([key isEqualTo:SS_sourceAwareRouting]) {
			[self enableSourceAwareRouting:object];
			continue;
		}
		// portMapLogging
		if ([key isEqualTo:SS_portMapLogging]) {
			[self enablePortMapLogging:object];
			continue;
		}
		// unregisteredOnly
		if ([key isEqualTo:SS_unregisteredOnly]) {
			[self enableUnregisteredOnly:object];
			continue;
		}
		// blockIPv6
		if ([key isEqualTo:SS_blockIPv6]) {
			[self enableBlockIPv6:object];
			continue;
		}
		// trafficDiscovery
		if ([key isEqualTo:SS_trafficDiscovery]) {
			[self enableTrafficDiscovery:object];
			continue;
		}
		// triggerDuration
		if ([key isEqualTo:SS_triggerDuration]) {
			[self enableTriggerDuration:object];
			continue;
		}
		// bandwidthAccounting
		if ([key isEqualTo:SS_bandwidthAccounting]) {
			[self enableBandwidthAccounting:object];
			continue;
		}
		// accountingInterval
		else if ([key isEqualTo:SS_accountingInterval]) {
			[self enableAccountingInterval:object];
		}
		// connectionLogging
		else if ([key isEqualTo:SS_connectionLogging]) {
			[self enableConnectionLogging:object];
		}
		// disableCommandQ
		else if ([key isEqualTo:kPreferences_disableCommandQ]) {
			[self disableCommandQ:object];
		}
			// Actions
		// apply
		else if ([key isEqualTo:SA_apply]) {
			[self apply:object];
		}
		// showActive
		else if ([key isEqualTo:SA_showActive]) {
			[self showActive:object];
		}
		// testButton
		else if ([key isEqualTo:SA_testButton]) {
			[self testButton:object];
		}
		// triggerDelete
		else if ([key isEqualTo:SA_triggerDelete]) {
			[self triggerDelete:object];
		}
		// SA_interfaceTable
		else if ([key isEqualTo:SA_interfaceTable]) {
			[self downloadInterfaceTable];
			//[[InterfaceTable sharedInstance] downloadInterfaceTable];
		}
#ifdef IPNetRouter
		// SA_portMapTable
		else if ([key isEqualTo:SA_portMapTable]) {
			[self updatePortMapTable:object];
		}
#endif
#if TEST_IN_CLIENT
		// SA_attach
		else if ([key isEqualTo:SA_attach]) {
			[self attachInterfaceEntry:object];
		}
		// SA_detach
		else if ([key isEqualTo:SA_detach]) {
			[self detachInterfaceEntry:object];
		}
#endif
	}	// while ((key = [enumerator nextObject]))
}

// ---------------------------------------------------------------------------------
//	• enableFirewallOn:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableFirewallOn:(NSNumber *)value {
	SentryController* nkeController;
//	int result;
	
	nkeController = [SentryController sharedInstance];
	// update firewall state
	if ([value intValue]) {
		// update implicit entries in Interface Table prior to download
		InterfaceTable *interfaceTable = [InterfaceTable sharedInstance];
		[interfaceTable setExcludeNet:[sentryState excludeNet]];
		[interfaceTable setExposedHostSelection:[sentryState exposedHostSelection]];
		[interfaceTable setExposedHost:[sentryState exposedHost]];
		// Apply settings and attach to NKE
		//[self apply:self];
		// Insert NKE for specified interfaces
		// Interface table is downloaded when we insert our NKE
		// since it is stored in PROJECT_attach instance.
		[[SentryController sharedInstance] insertNKE];
		#if TEST_IN_CLIENT
			[nkeController sendURL:kSentryOff];
			// update trigger expiration in case user didn't press Apply
			// request current value
//			result = KFT_triggerDuration(255);
		#else
			[nkeController sendURL:kSentryOn];
			// update trigger expiration in case user didn't press Apply
			// request current value
//			result = [nkeController synchSendURL:[NSString stringWithFormat:@"%@255",kTriggerDuration]];
		#endif
				// set state with current value
//		[sentryState setTriggerDuration:[NSNumber numberWithInt:result]];
		// begin bandwidth accounting if enabled
		[[BandwidthAccounting sharedInstance] accountingStart];
	}
	else {
		[nkeController sendURL:kSentryOff];
		[nkeController removeNKE];
		// stop bandwidth accounting if enabled
		[[BandwidthAccounting sharedInstance] accountingStop];
	}
}

// ---------------------------------------------------------------------------------
//	• enableIpForwarding:
// ---------------------------------------------------------------------------------
// set IP forwarding using sysctl
// net.inet.ip.forwarding 4.2.0.1
- (void)enableIpForwarding:(NSNumber *)value
{
#ifdef IPNetRouter
    NSString* toolPath;
	BOOL toolExists;
    int result;

	// set sysctl parameter value
	// get tool path
	toolPath = [AppSupport toolPathForName:@"ConfigSysctl" fileExists:&toolExists];
	if (toolExists) {
		// run tool to set value
		result = [AppSupport doTask:toolPath arguments:[NSArray arrayWithObjects:@"-set",
			@"4.2.0.1",
			[value stringValue],
			nil] output:nil];
			
		// show result
		if (result) {
			[sentryState updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"%s", strerror(result)]];
		}
	}
#endif
}

// ---------------------------------------------------------------------------------
//	• enableAutomaticFailover:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableAutomaticFailover:(NSNumber *)value {
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
			if ([value intValue]) PROJECT_flags |= kFlag_failover;
			else PROJECT_flags &= ~kFlag_failover;
		#else
			int result;
			NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_automaticFailover,[value stringValue]];
			result = [[SentryController sharedInstance] sendURL:str];
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	• enableLoadBalance:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableLoadBalance:(NSNumber *)value {
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
			if ([value intValue])
				PROJECT_flags |= kFlag_loadBalance;
			else
				PROJECT_flags &= ~kFlag_loadBalance;
		#else
			int result;
			NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_loadBalance,[value stringValue]];
			result = [[SentryController sharedInstance] sendURL:str];
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	• enableSourceAwareRouting:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableSourceAwareRouting:(NSNumber *)value {
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
			if ([value intValue]) PROJECT_flags |= kFlag_sourceAwareRouting;
			else PROJECT_flags &= ~kFlag_sourceAwareRouting;
		#else
			int result;
			NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_sourceAwareRouting,[value stringValue]];
			result = [[SentryController sharedInstance] sendURL:str];
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	• enablePortMapLogging:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enablePortMapLogging:(NSNumber *)value {
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
			if ([value intValue]) PROJECT_flags |= kFlag_portMapLogging;
			else PROJECT_flags &= ~kFlag_portMapLogging;
		#else
			int result;
			NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_portMapLogging,[value stringValue]];
			result = [[SentryController sharedInstance] sendURL:str];
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	• enableUnregisteredOnly:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableUnregisteredOnly:(NSNumber *)value {
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
			if ([value intValue]) PROJECT_flags |= kFlag_unregisteredOnly;
			else PROJECT_flags &= ~kFlag_unregisteredOnly;
		#else
			int result;
			NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_unregisteredOnly,[value stringValue]];
			result = [[SentryController sharedInstance] sendURL:str];
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	• enableBlockIPv6:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableBlockIPv6:(NSNumber *)value {
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
			if ([value intValue]) PROJECT_flags |= kFlag_blockIPv6;
			else PROJECT_flags &= ~kFlag_blockIPv6;
		#else
			int result;
			NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_blockIPv6,[value stringValue]];
			result = [[SentryController sharedInstance] sendURL:str];
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	• enableTrafficDiscovery:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableTrafficDiscovery:(NSNumber *)value {
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
			if ([value intValue]) PROJECT_flags |= kFlag_trafficDiscovery;
			else PROJECT_flags &= ~kFlag_trafficDiscovery;
		#else
			int result;
			NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_trafficDiscovery,[value stringValue]];
			result = [[SentryController sharedInstance] sendURL:str];
		#endif
	}
}

// ---------------------------------------------------------------------------------
//	• enableTriggerDuration:
// ---------------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableTriggerDuration:(NSNumber *)value {
	int result;
	if (!pending) {	// don't allow multiples
		if (!value) value = [NSNumber numberWithInt:0];
		#if TEST_IN_CLIENT
		result = KFT_setTriggerDuration([value intValue]);
		#else
		NSString* str = [NSString stringWithFormat:@"%@%@",kTriggerDuration,[value stringValue]];
		result = [[SentryController sharedInstance] sendURL:str];
		#endif
		// update value based on result
		pending = YES;
		[sentryState setTriggerDuration:[NSNumber numberWithInt:result]];
		pending = NO;
	}
}

// ---------------------------------------------------------------------------
//	• enableBandwidthAccounting
// ---------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableBandwidthAccounting:(NSNumber *)value
{
	if ([value intValue]) {	// turn on if needed
		if ([[sentryState firewallOn] intValue])
			[[BandwidthAccounting sharedInstance] accountingStart];
	}
	else {	// turn it off
		[[BandwidthAccounting sharedInstance] accountingStop];
	}
}

// ---------------------------------------------------------------------------
//	• enableAccountingInterval
// ---------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableAccountingInterval:(NSString *)value
{
	// if firewall and bandwidth accounting are on, update accounting interval
	if ( [[sentryState firewallOn] intValue] &&
		 [[sentryState bandwidthAccounting] intValue] ) {
		[[BandwidthAccounting sharedInstance] accountingStop];
		[[BandwidthAccounting sharedInstance] accountingStart];
	}
}

// ---------------------------------------------------------------------------
//	• enableConnectionLogging
// ---------------------------------------------------------------------------
// model state has changed, perform corresponding model action
- (void)enableConnectionLogging:(NSNumber *)value
{
	if ([value intValue]) {	// turn on if needed
		if ([[sentryState firewallOn] intValue])
			[[ConnectionLog sharedInstance] connectionLogStart];
	}
	else {	// turn it off
		[[ConnectionLog sharedInstance] connectionLogStop];
	}
}

// ---------------------------------------------------------------------------
//	• disableCommandQ
// ---------------------------------------------------------------------------
- (void)disableCommandQ:(NSNumber*)value
{
	NSMenu* menuBar;
	NSMenu* appMenu;
	NSMenuItem* quitItem;
	
	menuBar = [NSApp mainMenu];
	appMenu = [[menuBar itemAtIndex:0] submenu];
	quitItem = [appMenu itemWithTag:99];
	if ([value intValue]) [quitItem setKeyEquivalent:@""];
	else {
		[quitItem setKeyEquivalent:@"q"];
//		[quitItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	}
}


// For consistency SentryDocument only calls out to SentryState.
// We pass these actions through to SentryModel so that SentryState can
// capture relavent state in the future as needed.
// SentryModel responds to notifications from SentryState allowing other
// observers to respond as well.
// ---------------------------------------------------------------------------
//	• apply
// ---------------------------------------------------------------------------
// Send document configuration tables to NKE
- (void)apply:(id)sender
{
	int status = 0;
	do {
		// reset previous rules in NKE if Option key is pressed
		if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
			status = [[SentryController sharedInstance] sendURL:kKFTReset];
			if (status == -1) break;
		}
		status = [self downloadFilterTable];
		if (status == -1) break;
		[self downloadTriggerTable];
	#ifdef IPNetRouter
		// download port mapping table
		[self downloadPortMapTable];
		// reflect port map logging state
		[self enablePortMapLogging:[sentryState portMapLogging]];
		// reflect unregisteredOnly state
		[self enableUnregisteredOnly:[sentryState unregisteredOnly]];
		// apply alternateRouteTable
		[[AlternateRouteModel sharedInstance] alternateRouteApply];
		// reflect automaticFailover state
		[self enableAutomaticFailover:[sentryState automaticFailover]];
		// reflect loadBalance state
		[self enableLoadBalance:[sentryState loadBalance]];
		// reflect sourceAwareRouting state
		[self enableSourceAwareRouting:[sentryState sourceAwareRouting]];
	#endif
		// reflect trafficDiscovery state
		[self enableTrafficDiscovery:[[TrafficDiscoveryState sharedInstance] trafficDiscovery]];
		// reflect blockIPv6 state
		[self enableBlockIPv6:[sentryState blockIPv6]];
	#if TEST_IN_CLIENT
		// set time
		{
			NSCalendarDate* cd;
			// gather information
			cd = [NSCalendarDate calendarDate];
			PROJECT_timeOfDay.timeStamp = (int)[NSDate psInterval];
			PROJECT_timeOfDay.day = [cd dayOfWeek];
			PROJECT_timeOfDay.secondOfDay = [cd hourOfDay]*3600 + [cd minuteOfHour]*60 + [cd secondOfMinute];
		}
		// set drop response in NKE
		{
			NSString* path;
			NSString* dataString = nil;
			NSData* data;
			path = [[NSBundle mainBundle] pathForResource:@"DropResponse" ofType:@"html"];
			if (path) dataString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
			if (dataString)	{
				data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
				PROJECT_dropResponseLength = [data length];
				memcpy(&PROJECT_dropResponseBuffer[40], [data bytes], [data length]);
			}
		}
	#endif
		if ([[sentryState firewallOn] intValue]) {
			// Interface table is downloaded when we insert our NKE
			// since it is stored in PROJECT_attach instance.
			// Attach NKE after initialize other tables.
			[self downloadInterfaceTable];
			//[[InterfaceTable sharedInstance] downloadInterfaceTable];
		}
		// show Aply no longer pending
		[sentryState setApplyPending:[NSNumber numberWithInt:0]];
	} while (0);
}

// ---------------------------------------------------------------------------
//	• showActive
// ---------------------------------------------------------------------------
- (void)showActive:(id)sender
{
	[self uploadFilterTable];
	[self uploadTriggerTable];
	[self uploadInterfaceTable];
#ifdef IPNetRouter
	[self uploadNatTable];
	[self uploadPortMapTable];
#endif
	// get triggerDuration
	[self enableTriggerDuration:[NSNumber numberWithInt:255]];
}

// ---------------------------------------------------------------------------
//	• testButton
// ---------------------------------------------------------------------------
- (void)testButton:(id)sender
{
#if TEST_IN_CLIENT
	//logAttachTable(PROJECT_attach);
	NSLog(@"Starting SentryTest server");
	//[[SentryTest sharedInstance] doTest];
	PsClient* testClient = nil;
	if (!testClient) {
		testClient = [[PsClient alloc] init];
		[testClient setCallbackTarget:nil];	// don't care about test server notifications
		[testClient setServerClass:[SentryTest class]];
	}
	if (![testClient isConnected]) [testClient createNewServer:[SentryTest class]];
	if ([testClient isConnected]) {
		// launch test
		[testClient startService:kSentryTest withObject:nil];
	}
#else
	NSURL* url;
	NSArray* interfaceArray;
	NSEnumerator* en;
	InterfaceEntry* entry;
	NSString* addressStr = nil;
	BOOL result;
	interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
	en = [interfaceArray objectEnumerator];
	while (entry = [en nextObject]) {
		if ([[entry filterOn] intValue] && [[entry externalOn] intValue]) {
			addressStr = [entry ifNet];
			if (![addressStr isEqualTo:kSCNotAvailable]) continue;
		}
	}
	if (addressStr) {
#if 0
		url = [NSURL URLWithString:[NSString stringWithFormat:
			@"http://www.sustworks.com/cgi-bin/test_ipnsx.pl?tip=%@",addressStr]];
#else
		url = [NSURL URLWithString:@"https://www.grc.com/x/ne.dll?bh0bkyd2"];
#endif
		result = [[NSWorkspace sharedWorkspace] openURL:url];
	}
	else {
		[sentryState updateParameter:@"statusInfo"
			withObject:@"Please check interface settings, no external IP address found."];
	}
#endif
}

// ---------------------------------------------------------------------------
//	• triggerDelete
// ---------------------------------------------------------------------------
// Remove matching entries from trigger table in NKE
- (void)triggerDelete:(NSString *)str
{
	str = [NSString stringWithFormat:@"%@%@",kTriggerAddress,str];
#if !TEST_IN_CLIENT
	[[SentryController sharedInstance] sendURL:str];
#else
	{
		NSRange range;
		NSArray* arrayOfStrings;
		NSEnumerator* en;
		IPValue* ipValue = [[[IPValue alloc] init] autorelease];
		KFT_triggerKey_t value[60];
		int i, result;
		int count = 0;
		// extract value from URL string
		range = [str rangeOfString:@":"];
		if (range.length) {
			str = [str substringFromIndex:range.location+1];
			arrayOfStrings = [str componentsSeparatedByString:@","];
			en = [arrayOfStrings objectEnumerator];
			i = 0;
			while (str = [en nextObject]) {
				// str is of format address:type
				[ipValue setStringValue:str];
				value[i].address = [ipValue ipAddress];
				value[i].type = [ipValue startPort];
				i++;
				if (i > 50) {
					result = KFT_triggerRemoveByKey(value, i);
					count += result;
					i = 0;
				}
			}
			if (i) {
				result = KFT_triggerRemoveByKey(value, i);
				count += result;
			}
		}
		NSLog(@"triggerDelete removed: %d", count);
		NSLog(@"trigger table %d remain", KFT_triggerCount());
	}
#endif
}

#pragma mark - SUPPORT -
// ---------------------------------------------------------------------------
//	• downloadFilterTable
// ---------------------------------------------------------------------------
- (int)downloadFilterTable
{
    FilterTable* filterTable;
	NSMutableDictionary* dictionary;
	NSString* dataString;
	NSString* tString;
	NSData* data;
	int status;
#if TEST_IN_CLIENT
	PSData tableData;
#endif

	filterTable = [sentryState filterTable];
	// make sure root is enabled
	[filterTable setEnabled:[NSNumber numberWithInt:1]];
	// update node numbers
	[filterTable setNodeNumber:nil];
	// get filter entry of root item and convert to dictionary
    dictionary = dictionaryFromTree(filterTable);
	// remove unnecessary status fields before sending to NKE
	if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
		// if option key is pressed, reset counts
		removeKeysFromDictionaryTree([NSArray arrayWithObjects:
			FE_matchCount,
			FE_matchDelta,
			FE_byteCount,
			FE_byteDelta,
			FE_lastTime,
			nil], dictionary);
	}
	else {
		removeKeysFromDictionaryTree([NSArray arrayWithObjects:
			FE_matchDelta,
			FE_byteDelta,
			FE_lastTime,
			nil], dictionary);
	}
	// convert to string
	dataString = [dictionary description];
	// compress by removing extra spaces
	{
		NSMutableData* tData;
		u_int8_t* src;
		u_int8_t* dst;
		u_int8_t c;
		int spaceCount;
		// compress configuration by removing extra spaces
		data = [dataString dataUsingEncoding:NSASCIIStringEncoding];
		tData = [NSMutableData dataWithCapacity:[data length]];
		[tData setData:data];
		dst = [tData mutableBytes];
		spaceCount = 0;
		for (src=[tData mutableBytes]; src<((u_int8_t*)[tData mutableBytes]+[tData length]); src++) {
			c = *src;
			if (c == ' ') {
				// found a space
				if (spaceCount == 0) *dst++ = c;	// transfer first one
				spaceCount += 1;
			}
			else {
				// just transfer it
				*dst++ = c;
				spaceCount = 0;
			}
		}
		// set new length
		[tData setLength:dst-(u_int8_t*)[tData mutableBytes]];
		// convert back to string
		dataString = [[[NSString alloc] initWithData:tData encoding:NSASCIIStringEncoding] autorelease];
	}
	// download new filter rules to NKE
	tString = [NSString stringWithFormat:@"%@%@",kKFTFilterDownload,dataString];
	status = [[SentryController sharedInstance] sendURL:tString];
	#if !TEST_IN_CLIENT
	if (status == 0) {
		int count = [[SentryController sharedInstance] sendURL:kKFTFilterCount];
		tString = [NSString stringWithFormat:@" download %d filters",count];
		[sentryState updateParameter:@"statusInfoAppend" withObject:tString];
	}
	#endif
	// reset nodeCount cache
	[filterTable setNodeCount:0];
#if TEST_IN_CLIENT
	// download filter rules
	data = [dataString dataUsingEncoding:NSASCIIStringEncoding];
	[data retain];
	tableData.bytes = (UInt8*)[data bytes];
	tableData.length = [data length];
	tableData.bufferLength = [data length];
	tableData.offset	= 0;
	// try to download
	{
		KFT_filterEntry_t table[KFT_filterTableSize];
		PSData outBuf;
		outBuf.bytes = (u_int8_t *)table;
		outBuf.length = 0;
		outBuf.bufferLength = KFT_filterTableSize * sizeof(KFT_filterEntry_t);
		outBuf.offset = 0;  // use for table index of next entry
		// convert from plist to table form
		status = filterText2Table(&tableData, &outBuf);
		status = KFT_filterDownload(&outBuf);
		int count = KFT_filterCount();
		tString = [NSString stringWithFormat:@" download %d filters",count];
		[sentryState updateParameter:@"statusInfoAppend" withObject:tString];
	}
	[data release];
#endif
	return status;
}

// ---------------------------------------------------------------------------------
//	• downloadInterfaceTable
// ---------------------------------------------------------------------------------
// updates AttachCount in SentryController
- (void)downloadInterfaceTable
{
	int status;
	InterfaceTable* table;
	NSArray* interfaceArray;
	InterfaceEntry* interfaceE;
	NSString* natNet;
	KFT_interfaceEntry_t kftInterfaceEntry;
    int count, i;
	int attachCount = 0;
		
	// get interface table
	table = [InterfaceTable sharedInstance];
	interfaceArray = [table interfaceArray];
	// make sure NAT settings are current
	[table natSettingHasChanged];
	natNet = [[table entryForNat] ifNet];
	
	// attach NKE to each configured port
	count = [interfaceArray count];
	for (i=0; i<count; i++) {
		interfaceE = [interfaceArray objectAtIndex:i];
		// check if we should attach this interface
		if ([table isAttachEntry:interfaceE]) {
			// Don't configure if not available
			if ([[interfaceE ifNet] isEqualTo:kSCNotAvailable]) continue;
			// prepare interface entry
			if ([[interfaceE natOn] intValue]) {
				// natNet
				if ([[interfaceE externalOn] intValue]) [interfaceE setNatNet:[interfaceE ifNet]];
				else [interfaceE setNatNet:natNet];
				// update implicit fields in entry
				[interfaceE setExcludeNet:[table excludeNet]];
				[interfaceE setExposedHost:[table exposedHost]];
				[interfaceE setExposedHostSelection:[table exposedHostSelection]];
			}
			interfaceObjectToData(interfaceE, &kftInterfaceEntry);
			// attach NKE to corresponding interface 
			//status = [self sendURL:[NSString stringWithFormat:@"%@%@",kSentryAttach,[interfaceE bsdName]]];
			kftInterfaceEntry.protocolFilter = 0;
			status = [[NKEController sharedInstance] sentryAttach:&kftInterfaceEntry];
			if (status == 0) attachCount++;
			// update local copy for client testing
			[table updateParameter:SA_attach withObject:interfaceE];
			// log what we did
			[table updateParameter:SA_logMessage withObject:[interfaceE description]];
		}
		else if (![table isDupEntry:interfaceE]) {
			interfaceObjectToData(interfaceE, &kftInterfaceEntry);
			// remove if interface should no longer be attached
			//status = [self sendURL:[NSString stringWithFormat:@"%@%@",kSentryDetach,[interfaceE bsdName]]];
			status = [[NKEController sharedInstance] sentryDetach:&kftInterfaceEntry];
			// update local copy for client testing
			[table updateParameter:SA_detach withObject:interfaceE];
		}
	}
	[[SentryController sharedInstance] setAttachCount:attachCount];
}

// ---------------------------------------------------------------------------
//	• downloadTriggerTable
// ---------------------------------------------------------------------------
// Send trigger table information to NKE
- (void)downloadTriggerTable
{
	int result;
	TriggerTable* table;
	TriggerEntry* entry;
	unsigned char buffer[kUpdateBufferSize];
	ipk_triggerUpdate_t* message;
	int sizeLimit;
	int i, j;
	int count;

	// setup interface update message
	message = (ipk_triggerUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kTriggerUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(KFT_triggerEntry_t);
	j = 0;
	// We tag the trigger entries in the NKE, walk the table to download any edits,
	// and then remove any previously tagged entries in the NKE.  This avoids releasing
	// existing entries before downloading updated versions.
		// tell NKE to tag any previous entries
	bzero(&message->triggerUpdate[j], sizeof(KFT_triggerEntry_t));
	message->triggerUpdate[j].flags = kTriggerFlagTagAll;
	message->length += sizeof(KFT_triggerEntry_t);
	j += 1;	
	// walk trigger table
	table = [sentryState triggerTable];
	count = [table count];
	for (i=0; i<count; i++) {
		entry = [table objectAtIndex:i];
		// if we found one
		if (entry) {
			// add to update message
			result = triggerObjectToData(entry, &message->triggerUpdate[j]);
			if (result == 0) {
				message->triggerUpdate[j].flags = kTriggerFlagUpdate;
				message->length += sizeof(KFT_triggerEntry_t);
				j += 1;
				// if message buffer is full, send it
				int retryCount = 0;
				while (message->length >= sizeLimit) {
					#if TEST_IN_CLIENT
					result = KFT_receiveMessage((ipk_message_t*)message);
					#else
					result = [[SentryController sharedInstance] sendURL:kKFTReceiveMessage withObject:
						[NSData dataWithBytes:(void *)message length:message->length]];
					#endif
					if (result != 0) {
						// Download failed (out of memory).  Wait before trying again.
						if (retryCount == 0) {
							[[SentryLogger sharedInstance] logMessage:@"  Download trigger table waiting for memory"];
						}
						[NSThread  sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)1.0]];
						retryCount += 1;
						if (retryCount > 10) {
							[[SentryLogger sharedInstance] logMessage:@"  Download trigger table out of memory"];
							break;
						}
					}
					else {
						message->length = 8;	// offset to first entry
						message->flags = 0;
						j = 0;
						retryCount = 0;			// message accepted, reset retry counter
					}
				}	//while (message->length >= sizeLimit)
				if (retryCount > 10) {
					message->length = 8;	// offset to first entry
					message->flags = 0;
					j = 0;
					break;		// download failed waiting for memory
				}
			}
		}
	}
	// tell NKE to remove any previously tagged entries
	bzero(&message->triggerUpdate[j], sizeof(KFT_triggerEntry_t));
	message->triggerUpdate[j].flags = kTriggerFlagRemoveTagged;
	message->length += sizeof(KFT_triggerEntry_t);
	j += 1;	
	// are there any updates to send?
	if (j > 0) {
		// send message to each active controller
		#if TEST_IN_CLIENT
		KFT_receiveMessage((ipk_message_t*)message);
		#else
		[[SentryController sharedInstance] sendURL:kKFTReceiveMessage withObject:
			[NSData dataWithBytes:(void *)message length:message->length]];
		#endif
	}
	// default duration
	NSNumber* tNum;
	{
		tNum = [sentryState triggerDuration];
		[self enableTriggerDuration:tNum];
	}
#if TEST_IN_CLIENT
	// set trigger expiration
	{
		tNum = [sentryState triggerDuration];
		KFT_setTriggerDuration([tNum intValue]);
	}
#endif
	// report results
	#if TEST_IN_CLIENT
	count = KFT_triggerCount();
	#else
	count = [[SentryController sharedInstance] sendURL:kKFTTriggerCount];
	#endif
	if (count) {
		NSString* tString = [NSString stringWithFormat:@" download %d triggers",count];
		[sentryState updateParameter:@"statusInfoAppend" withObject:tString];
	}
	// save trigger table to disk
	DocumentSupport *ds = [DocumentSupport sharedInstance];
	[[ds sentryState] setTriggerTable:table];
	[ds writeTriggerTable];
}

// ---------------------------------------------------------------------------
//	• downloadTriggerEntry
// ---------------------------------------------------------------------------
// Send trigger entry to NKE
- (void)downloadTriggerEntry:(TriggerEntry *)entry
{
	int result;
	unsigned char buffer[kUpdateBufferSize];
	ipk_triggerUpdate_t* message;
	int j;

	// setup interface update message
	message = (ipk_triggerUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kTriggerUpdate;
	message->version = 0;
	message->flags = 0;
	j = 0;
	if (entry) {
		// add to update message
		result = triggerObjectToData(entry, &message->triggerUpdate[j]);
		if (result == 0) {
			message->triggerUpdate[j].flags = kTriggerFlagUpdate;
			message->length += sizeof(KFT_triggerEntry_t);
			j += 1;
		}
	}
	// are there any updates to send?
	if (j > 0) {
		// send message to each active controller
		#if TEST_IN_CLIENT
		KFT_receiveMessage((ipk_message_t*)message);
		#else
		[[SentryController sharedInstance] sendURL:kKFTReceiveMessage withObject:
			[NSData dataWithBytes:(void *)message length:message->length]];
		#endif
	}
}


#if IPNetRouter
// ---------------------------------------------------------------------------
//	• downloadPortMapTable
// ---------------------------------------------------------------------------
- (void)downloadPortMapTable
{
	int result;
	PortMapTable* table;
	PortMapEntry* entry;
	unsigned char buffer[kUpdateBufferSize];
	ipk_natUpdate_t* message;
	int sizeLimit;
	int i, j;
	int count;

	// setup interface update message
	message = (ipk_natUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kPortMapUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(KFT_natEntry_t);
	j = 0;
	// tell NKE to delete any previous entries
	bzero(&message->natUpdate[j], sizeof(KFT_natEntry_t));
	message->natUpdate[j].flags = kNatFlagRemoveAll;
	message->length += sizeof(KFT_natEntry_t);
	j += 1;	
	// walk port map table
	table = [sentryState portMapTable];
	count = [table count];
	for (i=0; i<count; i++) {
		//result = get_item_by_index(kft_interfaceApparentTree, i, (void **)&foundEntry);
		entry = [table objectAtIndex:i];
		// if we found one
		if (entry) {
			// flag local transparent proxy if needed
			[self setProxyLocal:entry];
			// add to update message
			//memcpy(&message->natUpdate[j], foundEntry, sizeof(KFT_natEntry_t));
			result = portMapObjectToData(entry, &message->natUpdate[j]);
			if (result == 0) {
				message->natUpdate[j].flags = kNatFlagUpdate;
				message->length += sizeof(KFT_natEntry_t);
				j += 1;
				// if message buffer is full, send it
				if (message->length >= sizeLimit) {
					#if TEST_IN_CLIENT
					KFT_receiveMessage((ipk_message_t*)message);
					#else
					[[SentryController sharedInstance] sendURL:kKFTReceiveMessage withObject:
						[NSData dataWithBytes:(void *)message length:message->length]];
					#endif
					message->length = 8;	// ofset to first entry
					message->flags = 0;
					j = 0;
				}
			}
		}
	}
	// are there any updates to send?
	if (j > 0) {
		// send message to each active controller
		#if TEST_IN_CLIENT
		KFT_receiveMessage((ipk_message_t*)message);
		#else
		[[SentryController sharedInstance] sendURL:kKFTReceiveMessage withObject:
			[NSData dataWithBytes:(void *)message length:message->length]];
		#endif
	}
	// report results
	#if TEST_IN_CLIENT
	count = KFT_portMapCount();
	#else
	count = [[SentryController sharedInstance] sendURL:kKFTPortMapCount];
	#endif
	if (count) {
		NSString* tString = [NSString stringWithFormat:@" download %d port maps",count];
		[sentryState updateParameter:@"statusInfoAppend" withObject:tString];
	}
}

// ---------------------------------------------------------------------------
//	• setProxyLocal
// ---------------------------------------------------------------------------
// Check for transpapent proxy to local endpoint and set proxy local flag as needed
- (void)setProxyLocal:(PortMapEntry *)portMapE;
{
	// transparent proxy?
	if (ipForString([portMapE apparentAddress]) == 0) {
		u_int32_t proxyDst = ipForString([portMapE actualAddress]);
		u_int32_t localDst;
		NSArray* interfaceArray;
		NSEnumerator* en;
		InterfaceEntry* interfaceE;
		// clear localProxy flag 
		[portMapE setLocalProxy:[NSNumber numberWithInt:0]];
		// look for matching local interface
		interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
		en = [interfaceArray objectEnumerator];
		while (interfaceE = [en nextObject]) {
			localDst = ipForString([interfaceE ifNet]);
			if (proxyDst == localDst) {
				[portMapE setLocalProxy:[NSNumber numberWithInt:1]];
				break;
			}
		}
	}
}
#endif


// ---------------------------------------------------------------------------
//	• uploadFilterTable
// ---------------------------------------------------------------------------
- (void)uploadFilterTable
{
#if TEST_IN_CLIENT
	FilterTable* filterTable;
	id plist;
	FilterEntry* pasteItem;
	NSString* dataString;
	NSMutableData* data;
	PSData tableData;
	int count, size;
	int result;
	
	count = KFT_filterCount();
	size = count * KFT_filterEntry_size;
	data = [[NSMutableData alloc] initWithCapacity:size];
	[data setLength:size];
	tableData.bytes = (UInt8*)[data bytes];
	tableData.length = 0;
	tableData.bufferLength = size;
	tableData.offset	= 0;
	// try to upload
	{
		KFT_filterEntry_t table[KFT_filterTableSize];
		PSData outBuf;
		outBuf.bytes = (u_int8_t *)table;
		outBuf.length = 0;
		outBuf.bufferLength = KFT_filterTableSize * sizeof(KFT_filterEntry_t);
		outBuf.offset = 0;  // use for table index of next entry
		result = KFT_filterUpload(&outBuf);
		// convert from table to plist form
		result = filterTable2Text(&outBuf,&tableData);
	}
	//result = KFT_filterUpload(&tableData);
	[data setLength:tableData.length];
	// convert to array of dictionary entries
	dataString = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
	//dataString = [NSString stringWithUTF8String:[data bytes]];
	//NSLog(@"data length: %d, string length: %d",[data length], [dataString length]);
	filterTable = [sentryState filterTable];
	NS_DURING
		plist = [dataString propertyList];
		if ([plist isKindOfClass:[NSDictionary class]]) {
			pasteItem = treeFromDictionary(plist);
			// replace contents of root item with upload data
			[filterTable setNodeDictionary:[pasteItem nodeDictionary]];
			// notify listeners
			[sentryState updateParameter:SS_filterTable withObject:SS_filterTable];
			// expand abbreviated items
			[sentryState updateParameter:SS_filterExpanded withObject:filterTable];
			// tell user we succeeded
			NSString* str = [NSString stringWithFormat:@" upload %d filters", count];
			[sentryState updateParameter:@"statusInfoAppend" withObject:str];
		}
	NS_HANDLER
		if (![data length]) {
			// empty root item
			[[filterTable nodeDictionary] removeAllObjects];
			// notify listeners
			[sentryState updateParameter:SS_filterTable withObject:SS_filterTable];
		}
		else {
			NSBeep();
			NSLog(@"SentryModel uploadFilterTable property list not recognized");
		}
	NS_ENDHANDLER
	[data release];
#else
	[[SentryController sharedInstance] sendURL:kKFTFilterUpload];
#endif
}

// ---------------------------------------------------------------------------
//	• uploadTriggerTable
// ---------------------------------------------------------------------------
- (void)uploadTriggerTable
{
	TriggerTable* table;
	// clear previous content
	table = [sentryState triggerTable];
	if (!table) [sentryState setTriggerTable:[[[TriggerTable alloc] init] autorelease]];
	[table removeAllObjects];
#if TEST_IN_CLIENT
	int result = KFT_triggerUpload();
	if (result) {
		NSString* str = [NSString stringWithFormat:@" upload %d triggers", result];
		[sentryState updateParameter:@"statusInfoAppend" withObject:str];
	}
#else
	// upload trigger tables
	[[SentryController sharedInstance] sendURL:kKFTTriggerUpload];	
#endif
}

// ---------------------------------------------------------------------------
//	• uploadInterfaceTable
// ---------------------------------------------------------------------------
- (void)uploadInterfaceTable
{
#if TEST_IN_CLIENT
	int result = KFT_interfaceUpload();
	if (result) {
		NSString* str = [NSString stringWithFormat:@" upload %d interface(s)", result];
		[sentryState updateParameter:@"statusInfoAppend" withObject:str];
	}
#else
	// Notice interface parameters are stored in the corresponding PROJECT_attach instance
	// so we can only read from those interfaces which are currently attached
	[[SentryController sharedInstance] sendURL:kKFTInterfaceUpload];
#endif

}

#ifdef IPNetRouter
// ---------------------------------------------------------------------------
//	• uploadNatTable
// ---------------------------------------------------------------------------
- (void)uploadNatTable
{
	NatTable* table;
	// clear previous content
	table = [sentryState natTable];
	if (!table) [sentryState setNatTable:[[[NatTable alloc] init] autorelease]];
	[table removeAllObjects];
#if TEST_IN_CLIENT
	int result = KFT_natUpload();
	if (result) {
		NSString* str = [NSString stringWithFormat:@" upload %d nat entries", result];
		[sentryState updateParameter:@"statusInfoAppend" withObject:str];
	}
#else
	// upload nat table
	[[SentryController sharedInstance] sendURL:kKFTNatUpload];	
#endif
}
// ---------------------------------------------------------------------------
//	• uploadPortMapTable
// ---------------------------------------------------------------------------
- (void)uploadPortMapTable
{
	PortMapTable* table;
	// clear previous content
	table = [sentryState portMapTable];
	[table removeAllObjectsToOldTree];
#if TEST_IN_CLIENT
	KFT_portMapUpload();
#else
	// upload port map table
	[[SentryController sharedInstance] sendURL:kKFTPortMapUpload];	
#endif
}

// ---------------------------------------------------------------------------
//	• updatePortMapTable:
// ---------------------------------------------------------------------------
- (void)updatePortMapTable:(id)object {
	// update any dynamic entries in the port map table
	InterfaceTable* interfaceT;
	InterfaceEntry* interfaceE = nil;
	PortMapTable* portMapT;
	PortMapEntry* portMapE;
	NSString* interfaceID;
	NSString* addressStr;
	NSRange range;
	int i, count;
	int changeCount = 0;
	
	interfaceT = [InterfaceTable sharedInstance];
	portMapT = [sentryState portMapTable];
	// walk the port map table
	count = [portMapT count];
	for (i=0; i<count; i++) {
		portMapE = [portMapT objectAtIndex:i];
		interfaceID = [portMapE dynamic];
		// is portMap entry dynamic?
		if (!interfaceID) continue;
		// do we already have matching interface entry?
		if (![[interfaceE interfaceID] isEqualTo:interfaceID]) {
			// look for corresponding interface
			interfaceE = [interfaceT entryForInterfaceID:interfaceID];
		}
		if (!interfaceE) continue;
		// get current IP address of interface
		addressStr = [interfaceE ifNet];
		range = [addressStr rangeOfString:@"/"];	// remove prefix length
		if (range.length) addressStr = [addressStr substringToIndex:range.location];
		// does portMap entry need update?
		if (![addressStr isEqualTo:[portMapE apparentAddress]]) {
			// update apparent address in port map entry
			[portMapE setApparentAddress:addressStr];
			changeCount++;
		}
	}
	if (changeCount) {  // any changes?
		// download modified table
		[self downloadPortMapTable];
		// notify listeners
		[sentryState updateParameter:SS_portMapTable withObject:SS_portMapTable];
	}
}

#endif

#pragma mark - CLIENT_TEST_SUPPORT -
// ---------------------------------------------------------------------------
//	• attachInterfaceEntry:
// ---------------------------------------------------------------------------
- (void)attachInterfaceEntry:(InterfaceEntry *)entry
{
	u_int8_t attachIndex;
	NSString *bsdName = [entry bsdName];
	// check if already attached
	attachIndex = KFT_attachIndexForName((char *)[bsdName UTF8String]);
	if (!attachIndex) {
		attachIndex = KFT_emptyAttachIndex();
		if (attachIndex) {
			bzero(&PROJECT_attach[attachIndex], sizeof(attach_t));
			// remember our attach index for convenience
			PROJECT_attach[attachIndex].attachIndex = attachIndex;
			// copy InterfaceEntry
			KFT_interfaceEntry_t kftInterfaceEntry;
			interfaceObjectToData(entry, &kftInterfaceEntry);
			memcpy(&PROJECT_attach[attachIndex].kftInterfaceEntry, &kftInterfaceEntry,
				sizeof(KFT_interfaceEntry_t));
			// mark entry as in use
			PROJECT_attach[attachIndex].filterID = attachIndex;
			PROJECT_attach[attachIndex].ifnet_ref = (ifnet_t)&PROJECT_attach[0];	// dummy that looks active
		}
	}
}

// ---------------------------------------------------------------------------
//	• detachInterfaceEntry:
// ---------------------------------------------------------------------------
- (void)detachInterfaceEntry:(InterfaceEntry *)entry
{
	u_int8_t attachIndex;
	NSString *bsdName = [entry bsdName];
	// check if already attached
	attachIndex = KFT_attachIndexForName((char *)[bsdName UTF8String]);
	if (attachIndex) {
		// remove it
		bzero(&PROJECT_attach[attachIndex], sizeof(attach_t));
	}
}

@end

#pragma mark - CLIENT_TEST_SUPPORT -
// ---------------------------------------------------------------------------
//	• logAttachTable:
// ---------------------------------------------------------------------------
void logAttachTable(attach_t* table)
{
    int i;
	InterfaceEntry* interfaceE;
	NSLog(@"Dumping PROJECT_attach table:");
	for (i=1; i<=kMaxAttach; i++) {
		// is entry in use
		if (table[i].filterID) {
			interfaceE = interfaceObjectFromData(&table[i].kftInterfaceEntry);
			NSLog(@"%@",[interfaceE description]);
		}
    }
}

// ---------------------------------------------------------------------------------
//	• PROJECT_modifyReadyPacket
// ---------------------------------------------------------------------------------
// Tiger: prepare packet to be modified by setting appropriate mbuf flags
// Panther: return 1 if outbound hardware TCP checksum is enabled
// (no easy way to "finalize" in Panther)
int PROJECT_modifyReadyPacket(KFT_packetData_t* packet)
{
	int returnValue = 0;
#if 0
	mbuf_t mbuf_ref;
#if TIGER
	if (packet->modifyReady == 0) {
		mbuf_ref = *(packet->mbuf_ptr);
		if (packet->direction == kDirectionInbound) {
			mbuf_inbound_modified(mbuf_ref);
		}
		else {
			mbuf_outbound_finalize(mbuf_ref, AF_INET, packet->ipOffset);
		}
		// remember what we did
		packet->modifyReady = 1;
	}
#else
	mbuf_ref = *(packet->mbuf_ptr);
	if (packet->direction == kDirectionInbound) {
		// invalidate HW generated checksum flags
		mbuf_ref->m_pkthdr.csum_data = 0;
		mbuf_ref->m_pkthdr.csum_flags = 0;
		//if ((mbuf_ref->m_pkthdr.csum_flags & CSUM_TCP_SUM16) &&
		//	(mbuf_ref->m_pkthdr.csum_flags & CSUM_DATA_VALID)) returnValue = 1;
	}
	else {
		if (mbuf_ref->m_pkthdr.csum_flags & CSUM_TCP_SUM16) returnValue = 1;
	}
#endif
#endif
	return returnValue;
}
