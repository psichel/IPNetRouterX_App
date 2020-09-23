//
//  SentryController.m
//  IPNetSentryX
//
//  Created by psichel on Mon Mar 25 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//

#include "Test_In_Client.h"
#import "SentryController.h"
#import "NKEController.h"
#import "SentryModel.h"
#import "FilterTable.h"
#import "TriggerTable.h"
#import "InterfaceTable.h"
#import "SentryDocument.h"
#import "PSPropertyValue.h"
#import "PSSharedDictionary.h"
#import "MyGrowlDelegate.h"
#import "IPSupport.h"
#import "PSURL.h"
#import "IPValue.h"
#import "IPValueFormatter.h"
#import "NSDate_Extensions.h"


#import "FilterEntry.h"
#import "InterfaceEntry.h"
#import "HardwareAddress.h"
#import "ICMPController.h"
//#import <sys/socket.h>
//#import <sys/socketvar.h>
//#import <arpa/inet.h>


#ifdef IPNetRouter
	#import "NatTable.h"
	#import "PortMapTable.h"
	#import "PortMapEntry.h"
	#import "AlternateRouteModel.h"
	#import "NameServiceModel.h"
#endif
#import PS_TNKE_INCLUDE
#import "IPNetMessage.h"
#import "SentryLogger.h"
#import "ConnectionLog.h"
#import "TrafficDiscoveryModel.h"
#import "DiagnosticModel.h"
//#import "UDPNotifications.h"
#import "UDPServer.h"
#import "PreferencesController.h"
#import "SendEmailController.h"
#import "SendEmailServer.h"
//#import "AlertPanelDelegate.h"
#import "URLAction.h"
#import "SentryTest.h"
#import "KEVController.h"
#include <sys/socket.h>
#import <net/if.h>		// KEV_DL_SUBCLASS
#import <netinet/in.h>
#import "kft.h"
#import "AppDelegate.h"
//#import "RouteAction.h"		// for automatic failover
#import "RouteEntry.h"
#import "SystemConfiguration.h"

// Globals
NSString *SentryControllerNotification = @"SentryControllerNotification";

// Module Wide storage
static int kft_indentCount = -1;			// for upload

// Private functions (forward declarations)
int readEntryToIndex(PSData* inBuf, PSData* outBuf, int* ioIndex);
int readPropertyValueToIndex(PSData* inBuf, PSData* outBuf, int index, PSRange* range);
int writeEntryAtIndex(PSData* inBuf, PSData* outBuf, int* ioIndex);
int writePropertyValueAtIndex(PSData* inBuf, PSData* outBuf, int index);

// Private Methods
@interface SentryController (PrivateMethods)
	// Send to NKE
- (int)kftFilterDownload:(NSString *)inURL;
- (int)kftReceiveMessage:(NSData *)inData;
- (int)kftFilterUpload:(NSString *)inURL;
- (int)kftTriggerUpload:(NSString *)inURL;
- (int)kftInterfaceUpload:(NSString *)inURL;
- (int)kftNatUpload:(NSString *)inURL;
- (int)kftPortMapUpload:(NSString *)inURL;
- (int)sentryOn:(NSString *)inURL;
- (int)sentryOff:(NSString *)inURL;
- (int)kftReset:(NSString *)inURL;
- (int)kftFilterCount:(NSString *)inURL;
- (int)kftTriggerCount:(NSString *)inURL;
- (int)kftInterfaceCount:(NSString *)inURL;
- (int)kftPortMapCount:(NSString *)inURL;
- (int)kftNatCount:(NSString *)inURL;
- (int)kftAlternateRouteCount:(NSString *)inURL;
- (int)kftSetTime:(NSString *)inURL;
- (int)kftSetFlags:(NSString *)inURL;
- (int)kftGetFlags:(NSString *)inURL;
- (int)kftDropResponse:(NSString *)inURL;
- (int)kftTriggerDuration:(NSString *)inURL;
- (int)kftTriggerAddress:(NSString *)inURL;
	// Receive from NKE
- (void)receiveFilterUpdate:(NSData *)messageData;
- (void)receiveTriggerUpdate:(NSData *)messageData;
- (void)receiveInterfaceUpdate:(NSData *)messageData;
- (void)receiveConnectionUpdate:(NSData *)messageData;
- (void)receiveSyncUpdate:(NSData *)messageData;
#ifdef IPNetRouter
- (void)receiveNatUpdate:(NSData *)messageData;
- (void)receivePortMapUpdate:(NSData *)messageData;
#endif
- (void)receiveFilterLog:(NSData *)messageData;
- (void)receiveFilterAlert:(NSData *)messageData;
- (void)receiveFilterEmail:(NSData *)messageData;
- (void)receiveFilterAppleScript:(NSData *)messageData;
- (void)receiveFilterURL:(NSData *)messageData;
@end


@implementation SentryController

+ (SentryController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[SentryController alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	� init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		nkeController = [NKEController sharedInstance];
		logger = [SentryLogger sharedInstance];
		trafficDiscoveryModel = [TrafficDiscoveryModel sharedInstance];
		mUpdateTimer = nil;
		previousMessage = nil;
		mAttachCount = 0;
		mWarnCount = 0;
		mSyncInterval = 0;
		// URL Action
		mURLClient = nil;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	� dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	// NKE server
	[self terminate];
	[previousMessage release]; previousMessage = nil;
	// URL action
	[mURLClient setCallbackTarget:nil];
	[mURLClient release];   mURLClient = nil;
	[super dealloc];
}


// ---------------------------------------------------------------------------------
//	� terminate
// ---------------------------------------------------------------------------------
// terminate server thread
- (void)terminate
{
	[self disconnect];
}

// ---------------------------------------------------------------------------------
//	� connect
// ---------------------------------------------------------------------------------
// Load NKE and establish controller socket connection
- (int)connect
{
    int returnValue;
	returnValue = [nkeController connectToNKEFrom:self];

	if (returnValue == 0) {
		// request to be notified of kernel events in case any more ports appear
		[[KEVController sharedInstance] addObserver:self withSelector:@selector(receiveNotification:)];
		[[KEVController sharedInstance] startReceiving];
	}

	return returnValue;
}


// ---------------------------------------------------------------------------------
//	� disconnect
// ---------------------------------------------------------------------------------
// release controller socket connection
- (int)disconnect
{
	int returnValue = 0;
	// cancel update timer
	[mUpdateTimer invalidate];	mUpdateTimer= nil;
	if ([nkeController isConnected]) {
		// no longer want kernel events
		[[KEVController sharedInstance] removeObserver:self];
		// tell server to stop
		returnValue = [nkeController disconnect];
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� insertNKE
// ---------------------------------------------------------------------------------
// initialize NKE time and drop response
// insert NKE in list of IP interfaces
//	� downloadInterfaceTable
// set KFT interface parameters for NAT and other features
// Notice interface parameters are stored in the corresponding PROJECT_attach
// instance so must be sent each time a new interface is attached.
// Notice there could be more than one interface for a single BSDname,
// so its important to copy only the NAT interface or first one.
- (BOOL)insertNKE
{
	BOOL returnValue = NO;
	int status;

	do {
		// set time in NKE
		status = [self sendURL:kKFTSetTime];
		if (status == -1) break;	// could not connect to NKE
		// set drop response in NKE
		{
			NSString* path;
			NSString* dataString = nil;
			path = [[NSBundle mainBundle] pathForResource:@"DropResponse" ofType:@"html"];
			if (path) dataString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
			if (dataString)	status = [self sendURL:[NSString stringWithFormat:@"%@%@",kKFTDropResponse,dataString]];
		}

		// attach NKE to each configured port
		[[SentryModel sharedInstance] downloadInterfaceTable];
		
		// kick off update timer if needed
		if (mAttachCount) {
			if (!mUpdateTimer) mUpdateTimer = [NSTimer
				scheduledTimerWithTimeInterval:(NSTimeInterval)2.5
				target:self
				selector:@selector(updateTimer:)
				userInfo:nil
				repeats:YES];
		}
		returnValue = YES;
	} while (0);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	� removeNKE
// ---------------------------------------------------------------------------------
- (void)removeNKE
{
	int status;
	InterfaceTable* table;
	NSArray* interfaceArray;
	InterfaceEntry* interfaceE;
	KFT_interfaceEntry_t kftInterfaceEntry;
    int count, i;
	
	if ([nkeController isConnected]) {		
		// get interface table
		table = [InterfaceTable sharedInstance];
		interfaceArray = [table interfaceArray];
	
		// detach NKE from each configured port
		count = [interfaceArray count];
		for (i=0; i<count; i++) {
			interfaceE = [interfaceArray objectAtIndex:i];
			// check if we should detach this interface
			if ([table isDetachEntry:interfaceE]) {
				interfaceObjectToData(interfaceE, &kftInterfaceEntry);
				//[self sendURL:[NSString stringWithFormat:@"%@%@",kSentryDetach,[interfaceE bsdName]]];
				status = [nkeController sentryDetach:&kftInterfaceEntry];
				// update local copy for client testing
				[table updateParameter:SA_detach withObject:interfaceE];
			}
		}
	}
	mAttachCount = 0;
}

#pragma mark --- Send to NKE ---


// ---------------------------------------------------------------------------------
//	� sendURL:withObject:
// ---------------------------------------------------------------------------------
- (int)sendURL:(NSString *)inURL
{
	return [self sendURL:inURL withObject:nil];
}

- (int)sendURL:(NSString *)inURL withObject:(id)anObject
{
	int result = 0;
	if (![nkeController isConnected]) [self connect];
	if ([nkeController isConnected]) {
		if ([inURL hasPrefix:kKFTFilterDownload]) result = [self kftFilterDownload:inURL];
		else if ([inURL hasPrefix:kKFTReceiveMessage]) result = [self kftReceiveMessage:anObject];
		else if ([inURL hasPrefix:kKFTFilterUpload]) result = [self kftFilterUpload:inURL];
		else if ([inURL hasPrefix:kKFTTriggerUpload]) result = [self kftTriggerUpload:inURL];
		else if ([inURL hasPrefix:kKFTInterfaceUpload]) result = [self kftInterfaceUpload:inURL];
		else if ([inURL hasPrefix:kKFTNatUpload]) result = [self kftNatUpload:inURL];
		else if ([inURL hasPrefix:kKFTPortMapUpload]) result = [self kftPortMapUpload:inURL];
		else if ([inURL hasPrefix:kSentryOn]) result = [self sentryOn:inURL];
		else if ([inURL hasPrefix:kSentryOff]) result = [self sentryOff:inURL];
		else if ([inURL hasPrefix:kKFTReset]) result = [self kftReset:inURL];
		else if ([inURL hasPrefix:kKFTFilterCount]) result = [self kftFilterCount:inURL];
		else if ([inURL hasPrefix:kKFTTriggerCount]) result = [self kftTriggerCount:inURL];
		else if ([inURL hasPrefix:kKFTInterfaceCount]) result = [self kftInterfaceCount:inURL];
		else if ([inURL hasPrefix:kKFTPortMapCount]) result = [self kftPortMapCount:inURL];
		else if ([inURL hasPrefix:kKFTNatCount]) result = [self kftNatCount:inURL];
		else if ([inURL hasPrefix:kKFTAlternateRouteCount]) result = [self kftAlternateRouteCount:inURL];
		else if ([inURL hasPrefix:kKFTSetTime]) result = [self kftSetTime:inURL];
		else if ([inURL hasPrefix:kKFTSetFlags]) result = [self kftSetFlags:inURL];
		else if ([inURL hasPrefix:kKFTGetFlags]) result = [self kftGetFlags:inURL];
		else if ([inURL hasPrefix:kKFTDropResponse]) result = [self kftDropResponse:inURL];	
		else if ([inURL hasPrefix:kTriggerDuration]) result = [self kftTriggerDuration:inURL];	
		else if ([inURL hasPrefix:kTriggerAddress]) result = [self kftTriggerAddress:inURL];	
		else {
			[nkeController updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Request not recognized",@"Request not recognized")];
			NSLog(@"%@",inURL);
		}
	}
	else {
		NSLog(@"sendURL: NKE not available to handle request.");
		result = -1;
	}
	return result;
}

// ---------------------------------------------------------------------------
//	� sendSync
// ---------------------------------------------------------------------------
// Request a sync message from NKE with passed in timeInterval to confirm
// position message stream.
- (int)sendSync:(NSTimeInterval)timeInterval
{
	int returnValue = 0;
	returnValue = [nkeController setOption:SO_SYNC param:&timeInterval size:sizeof(timeInterval)];
	if (returnValue) NSLog(@"sendSync result: %s",strerror(returnValue));
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� syncInterval
// ---------------------------------------------------------------------------------
// return last syncInterval received from NKE
// future version could request to wakeup or be notified when
- (NSTimeInterval)syncInterval
{
	return mSyncInterval;
}

#pragma mark - NKE State -

// ---------------------------------------------------------------------------
//	� sentryOn
// ---------------------------------------------------------------------------
- (int)sentryOn:(NSString *)inURL
{
    int returnValue = 0;       
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		returnValue = [nkeController setOption:SO_MONITOR_ON param:nil size:0];
		if (returnValue) {
			if (mWarnCount == 0) {
				if (returnValue == ENOENT) {
					[nkeController updateParameter:@"statusInfo" withObject:[NSString stringWithFormat:@"Sentry on warning: not attached to any interfaces"]];
				}
				else {
					[nkeController updateParameter:@"statusInfo"
						withObject:[NSString stringWithFormat:@"Sentry on failure: %s", strerror(returnValue)]];
				}
				mWarnCount++;
			}
		}
		else mWarnCount = 0;
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"Sentry on failed, not connected"];
	return returnValue;
}

- (int)attachCount { return mAttachCount; }
- (void)setAttachCount:(int)value { mAttachCount = value; }

// ---------------------------------------------------------------------------
//	� sentryOff
// ---------------------------------------------------------------------------
- (int)sentryOff:(NSString *)inURL
{
    int returnValue = 0;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		returnValue = [nkeController setOption:SO_MONITOR_OFF param:nil size:0];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Sentry off failure: %s", strerror(returnValue)]];
		}
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"Sentry off failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftReset
// ---------------------------------------------------------------------------
- (int)kftReset:(NSString *)inURL
{
    int returnValue = 0;       
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		returnValue = [nkeController setOption:SO_KFT_RESET param:nil size:0];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Sentry reset failure: %s", strerror(returnValue)]];
		}
		else [nkeController updateParameter:@"statusInfoAppend" withObject:@"  Reset OK"];
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftInit failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftFilterCount
// ---------------------------------------------------------------------------
- (int)kftFilterCount:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count;
	unsigned size;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		size = sizeof(count);
		returnValue = [nkeController getOption:SO_FILTER_COUNT param:&count size:(socklen_t*)&size];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Count failure: %s", strerror(returnValue)]];
		}
		else returnValue = count;
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftFilterCount failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftTriggerCount
// ---------------------------------------------------------------------------
- (int)kftTriggerCount:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count;
	unsigned size;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		size = sizeof(count);
		returnValue = [nkeController getOption:SO_TRIGGER_COUNT param:&count size:(socklen_t*)&size];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Count failure: %s", strerror(returnValue)]];
		}
		else returnValue = count;
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftTriggerCount failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftInterfaceCount
// ---------------------------------------------------------------------------
- (int)kftInterfaceCount:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count;
	unsigned size;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		size = sizeof(count);
		returnValue = [nkeController getOption:SO_INTERFACE_COUNT param:&count size:(socklen_t*)&size];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Count failure: %s", strerror(returnValue)]];
		}
		else returnValue = count;
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftInterfaceCount failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftPortMapCount
// ---------------------------------------------------------------------------
- (int)kftPortMapCount:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count;
	unsigned size;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		size = sizeof(count);
		returnValue = [nkeController getOption:SO_PORTMAP_COUNT param:&count size:(socklen_t*)&size];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Count failure: %s", strerror(returnValue)]];
		}
		else returnValue = count;
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftPortMapCount failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftNatCount
// ---------------------------------------------------------------------------
- (int)kftNatCount:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count;
	unsigned size;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		size = sizeof(count);
		returnValue = [nkeController getOption:SO_NAT_COUNT param:&count size:(socklen_t*)&size];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Count failure: %s", strerror(returnValue)]];
		}
		else returnValue = count;
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftNatCount failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftAlternateRouteCount
// ---------------------------------------------------------------------------
- (int)kftAlternateRouteCount:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count;
	unsigned size;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		size = sizeof(count);
		returnValue = [nkeController getOption:SO_ROUTE_COUNT param:&count size:(socklen_t*)&size];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Count failure: %s", strerror(returnValue)]];
		}
		else returnValue = count;
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftAlternateRouteCount failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftSetTime
// ---------------------------------------------------------------------------
- (int)kftSetTime:(NSString *)inURL
{
    int returnValue = 0;
	NSCalendarDate* cd;
	sopt_timeParam_t timeParam;
       
    do {
        // check control channel to NKE
         if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftSetTime failed, not connected"];
			break;
		}
		// gather information
		cd = [NSCalendarDate calendarDate];
		timeParam.timeStamp = (int)[NSDate psInterval];
		timeParam.day = [cd dayOfWeek];
		timeParam.secondOfDay = [cd hourOfDay]*3600 + [cd minuteOfHour]*60 + [cd secondOfMinute];
		// and send to NKE
		returnValue = [nkeController setOption:SO_SET_TIME param:&timeParam size:sizeof(timeParam)];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set Time failure: %s", strerror(returnValue)]];
		}
		else [nkeController updateParameter:@"statusInfoAppend" withObject:@"  Set Time"];
	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftSetFlags
// ---------------------------------------------------------------------------
- (int)kftSetFlags:(NSString *)inURL
{
    int returnValue = -1;
	PSURL* url;
	NSString* str;
	sopt_flagsParam_t flagsParam;
       
    do {
        // check control channel to NKE
         if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftSetFlags failed, not connected"];
			break;
		}
		// gather information
		// extract values from URL string
		url = [PSURL urlWithString:inURL];
		flagsParam.flags = 0;
		flagsParam.mask = 0;
		// automaticFailover
		if ((str = [url paramValueForKey:kFlagId_automaticFailover])) {
			if ([str intValue]) flagsParam.flags |= kFlag_failover;
			flagsParam.mask |= kFlag_failover;
		}
		// loadBalance
		if ((str = [url paramValueForKey:kFlagId_loadBalance])) {
			if ([str intValue]) flagsParam.flags |= kFlag_loadBalance;
			flagsParam.mask |= kFlag_loadBalance;
		}
		// source aware routing
		if ((str = [url paramValueForKey:kFlagId_sourceAwareRouting])) {
			if ([str intValue]) flagsParam.flags |= kFlag_sourceAwareRouting;
			flagsParam.mask |= kFlag_sourceAwareRouting;
		}
		// port map logging
		if ((str = [url paramValueForKey:kFlagId_portMapLogging])) {
			if ([str intValue]) flagsParam.flags |= kFlag_portMapLogging;
			flagsParam.mask |= kFlag_portMapLogging;
		}
		// unregisteredOnly
		if ((str = [url paramValueForKey:kFlagId_unregisteredOnly])) {
			if ([str intValue]) flagsParam.flags |= kFlag_unregisteredOnly;
			flagsParam.mask |= kFlag_unregisteredOnly;
		}
		// block IPv6
		if ((str = [url paramValueForKey:kFlagId_blockIPv6])) {
			if ([str intValue]) flagsParam.flags |= kFlag_blockIPv6;
			flagsParam.mask |= kFlag_blockIPv6;
		}
		// traffic discovery
		if ((str = [url paramValueForKey:kFlagId_trafficDiscovery])) {
			if ([str intValue]) flagsParam.flags |= kFlag_trafficDiscovery;
			flagsParam.mask |= kFlag_trafficDiscovery;
		}
		// memStats
		if ((str = [url paramValueForKey:kFlagId_memStats])) {
			if ([str intValue]) flagsParam.flags |= kFlag_memStats;
			flagsParam.mask |= kFlag_memStats;
		}
		// set flags in NKE
		returnValue = [nkeController setOption:SO_SET_FLAGS param:&flagsParam size:sizeof(flagsParam)];
		// report result
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set Flags failure: %s", strerror(returnValue)]];
		}
	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftGetFlags
// ---------------------------------------------------------------------------
- (int)kftGetFlags:(NSString *)inURL
{
    int returnValue = -1;
	PSURL* url;
	sopt_flagsParam_t flagsParam;
       
    do {
        // check control channel to NKE
         if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftGetFlags failed, not connected"];
			break;
		}
		// get flags in NKE
		unsigned size = sizeof(sopt_flagsParam_t);
		bzero(&flagsParam, size);
		returnValue = [nkeController getOption:SO_GET_FLAGS param:&flagsParam size:&size];
		// report result
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set Flags failure: %s", strerror(returnValue)]];
		}
		else {
			// build URL from flag values retrieved
			url = [PSURL urlWithString:inURL];
			// automaticFailover
			if (flagsParam.flags & kFlag_failover)
				[url setParamValue:@"1" forKey:kFlagId_automaticFailover];
			else
				[url setParamValue:@"0" forKey:kFlagId_automaticFailover];
			// loadBalance
			if (flagsParam.flags & kFlag_loadBalance)
				[url setParamValue:@"1" forKey:kFlagId_loadBalance];
			else
				[url setParamValue:@"0" forKey:kFlagId_loadBalance];
			// sourceAwareRouting
			if (flagsParam.flags & kFlag_sourceAwareRouting)
				[url setParamValue:@"1" forKey:kFlagId_sourceAwareRouting];
			else
				[url setParamValue:@"0" forKey:kFlagId_sourceAwareRouting];

			// portMapLogging
			if (flagsParam.flags & kFlag_portMapLogging)
				[url setParamValue:@"1" forKey:kFlagId_portMapLogging];
			else
				[url setParamValue:@"0" forKey:kFlagId_portMapLogging];
			// unregisteredOnly
			if (flagsParam.flags & kFlag_unregisteredOnly)
				[url setParamValue:@"1" forKey:kFlagId_unregisteredOnly];
			else
				[url setParamValue:@"0" forKey:kFlagId_unregisteredOnly];
			// blockIPv6
			if (flagsParam.flags & kFlag_blockIPv6)
				[url setParamValue:@"1" forKey:kFlagId_blockIPv6];
			else
				[url setParamValue:@"0" forKey:kFlagId_blockIPv6];
			// trafficDiscovery
			if (flagsParam.flags & kFlag_trafficDiscovery)
				[url setParamValue:@"1" forKey:kFlagId_trafficDiscovery];
			else
				[url setParamValue:@"0" forKey:kFlagId_trafficDiscovery];
			// memStats
			if (flagsParam.flags & kFlag_memStats)
				[url setParamValue:@"1" forKey:kFlagId_memStats];
			else
				[url setParamValue:@"0" forKey:kFlagId_memStats];
			// report information we got
			[nkeController updateParameter:kKFTGetFlags withObject:[url stringValue]];
		}
	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftDropResponse
// ---------------------------------------------------------------------------
- (int)kftDropResponse:(NSString *)inURL
{
    int returnValue = -1;
	NSRange range;
    NSString* dataString;
	NSData* data;
       
    do {
        // check control channel to NKE
         if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftDropResponse failed, not connected"];
			break;
		}
		// get requested data
		range = [inURL rangeOfString:@":"];
		dataString = [inURL substringFromIndex:range.location+1];
		data = [dataString dataUsingEncoding:NSASCIIStringEncoding];
        returnValue = [nkeController setOption:SO_DROP_RESPONSE param:(void *)[data bytes] size:[data length]];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set Drop Response failure: %s", strerror(returnValue)]];
		}
//		else [nkeController updateParameter:@"statusInfoAppend" withObject:@" Set Drop Response OK"];
	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftTriggerDuration
// ---------------------------------------------------------------------------
// triggerDuration:n
- (int)kftTriggerDuration:(NSString *)inURL
{
    int returnValue = 0;
	NSRange range;
	NSString* str;
	unsigned long expiration;
	unsigned size;
	do {
		// extract value from URL string
		range = [inURL rangeOfString:@":"];
		if (range.length) str = [inURL substringFromIndex:range.location+1];
		else break;
		range = [str rangeOfString:@"("];
		if (range.length) str = [str substringToIndex:range.location];
		range = [str rangeOfString:@" "];
		if (range.length) str = [str substringToIndex:range.location];
		expiration = [str intValue];
		// check control channel to NKE
		if ([nkeController isConnected]) {
			// send command to NKE
			size = sizeof(expiration);
			returnValue = [nkeController setOption:SO_TRIGGER_DURATION param:&expiration size:size];
			if (returnValue) {
				[nkeController updateParameter:@"statusInfo"
					withObject:[NSString stringWithFormat:@"Set trigger duration failure: %s", strerror(returnValue)]];
			}
			else returnValue = expiration;
		}
		else [nkeController updateParameter:@"statusInfo" withObject:@"kftTriggerDuration failed, not connected"];
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftTriggerAddress
// ---------------------------------------------------------------------------
// triggerAddress:addr1:type1,addr2:type2,...
// return how many addresses we removed
- (int)kftTriggerAddress:(NSString *)inURL
{
    int returnValue = 0;
	NSRange range;
	NSArray* arrayOfStrings;
	NSEnumerator* en;
	NSString* str;
	KFT_triggerKey_t value[60];
	IPValue* ipValue = [[[IPValue alloc] init] autorelease];
	unsigned size;
	int i;
	do {
		// check connection
		if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftTriggerAddress failed, not connected"];
			break;
		}
		// extract value from URL string
		range = [inURL rangeOfString:@":"];
		if (range.length) str = [inURL substringFromIndex:range.location+1];
		else break;
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
				size = i * 2 * sizeof(u_int32_t);
				i = 0;
				// send command to NKE
				returnValue = [nkeController setOption:SO_TRIGGER_ADDRESS param:&value size:size];
				if (returnValue) {
					[nkeController updateParameter:@"statusInfo"
						withObject:[NSString stringWithFormat:@"Trigger Address failure: %s",
							strerror(returnValue)]];
					break;
				}
				returnValue += value[0].address;
			}
		}
		// any more to delete?
		if (i) {
			size = i * 2 * sizeof(u_int32_t);
			// send command to NKE
			returnValue = [nkeController setOption:SO_TRIGGER_ADDRESS param:&value size:size];
			if (returnValue) {
				[nkeController updateParameter:@"statusInfo"
					withObject:[NSString stringWithFormat:@"Trigger Address failure: %s",
						strerror(returnValue)]];
			}
			else returnValue += value[0].address; 
		}
	} while (false);
	return returnValue;
}

#pragma mark - Download -

// ---------------------------------------------------------------------------
//	� kftFilterDownload:
// ---------------------------------------------------------------------------
- (int)kftFilterDownload:(NSString *)inURL
{
    int returnValue = 0;
	NSRange range;
    NSString* dataString;
	NSData* data;
       
    do {
        // check control channel to NKE
         if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftDownload failed, not connected"];
			break;
		}
		// get filter data
		range = [inURL rangeOfString:@":"];
		dataString = [inURL substringFromIndex:range.location+1];
		data = [dataString dataUsingEncoding:NSASCIIStringEncoding];
		{
			// convert from plist to table form
			PSData inBuf;
			inBuf.bytes = (u_int8_t*)[data bytes];
			inBuf.length = [data length];
			inBuf.bufferLength = [data length];
			inBuf.offset = 0;
			returnValue = filterText2Table(&inBuf, &kft_filterTableD);
		}
		// send to NKE
        returnValue = [nkeController setOption:SO_FILTER_DOWNLOAD
			param:(void *)kft_filterTableD.bytes size:kft_filterTableD.length];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Download failure: %s", strerror(returnValue)]];
			NSLog(@"Download failed, filter table length: %d",kft_filterTableD.length);
		}
	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftReceiveMessage:
// ---------------------------------------------------------------------------
- (int)kftReceiveMessage:(NSData *)inData
{
	int returnValue = 0;
    do {
        // check control channel to NKE
         if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftReceiveMessage failed, not connected"];
			break;
		}
		returnValue = [nkeController setOption:SO_IPK_MESSAGE param:(void *)[inData bytes] size:[inData length]];
	} while (FALSE);
	return returnValue;
}

#pragma mark - Upload -
// ---------------------------------------------------------------------------
//	� kftUpload
// ---------------------------------------------------------------------------
- (int)kftFilterUpload:(NSString *)inURL;
{
    int returnValue = 0;
	int count;
	unsigned size;
	NSMutableData* ioData;
	do {
		// check control channel to NKE
		if (![nkeController isConnected]) {
			[nkeController updateParameter:@"statusInfo" withObject:@"kftUpload failed, not connected"];
			break;
		}
		// set data length of receive buffer
		kft_filterTableD.length = kft_filterTableD.bufferLength;
		// send command to NKE
		returnValue = [nkeController getOption:SO_FILTER_UPLOAD
			param:(void *)kft_filterTableD.bytes size:(socklen_t*)&kft_filterTableD.length];
		if (returnValue) {
			[nkeController updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Upload failure: %s", strerror(returnValue)]];
			break;
		}
		// calculate how many we got
		count = kft_filterTableD.offset = kft_filterTableD.length / sizeof(KFT_filterEntry_t);
		size = KFT_filterEntry_size * count;
		// allocate buffer to receive filter data
		ioData = [NSMutableData dataWithCapacity:size];
		if (!ioData) {
			[nkeController updateParameter:@"statusInfo" withObject:@"Upload allocation failure"];
			break;
		}
		[ioData setLength:size];
		{
			// convert from table to plist form
			PSData outBuf;
			outBuf.bytes = (u_int8_t*)[ioData bytes];
			outBuf.length = 0;
			outBuf.bufferLength = [ioData length];
			outBuf.offset = 0;
			returnValue = filterTable2Text(&kft_filterTableD, &outBuf);
			[ioData setLength:outBuf.length];
		}
		// set returned length
		[nkeController updateParameter:@"kftUpload" withObject:ioData];
		// report what we got
		NSString* str = [NSString stringWithFormat:@" upload %d filters", count];
		[nkeController updateParameter:@"statusInfoAppend" withObject:str];
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftTriggerUpload
// ---------------------------------------------------------------------------
- (int)kftTriggerUpload:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count = 0;
	NSString* str;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		unsigned size = sizeof(count);
		returnValue = [nkeController getOption:SO_TRIGGER_UPLOAD param:&count size:&size];
		if (returnValue) {
			str = [NSString stringWithFormat:@"kftTriggerUpload failure: %s", strerror(returnValue)];
			[nkeController updateParameter:@"statusInfo" withObject:str];
		}
		else {
			str = [NSString stringWithFormat:@" upload %lu triggers", count];
			[nkeController updateParameter:@"statusInfoAppend" withObject:str];
		}
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftTriggerUpload failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftInterfaceUpload
// ---------------------------------------------------------------------------
- (int)kftInterfaceUpload:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count = 0;
	NSString* str;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		unsigned size = sizeof(count);
		returnValue = [nkeController getOption:SO_INTERFACE_UPLOAD param:&count size:&size];
		if (returnValue) {
			str = [NSString stringWithFormat:@"kftInterfaceUpload failure: %s", strerror(returnValue)];
			[nkeController updateParameter:@"statusInfo" withObject:str];
		}
		else {
			str = [NSString stringWithFormat:@" upload %lu interface(s)", count];
			[nkeController updateParameter:@"statusInfoAppend" withObject:str];
		}
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftInterfaceUpload failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftNatUpload
// ---------------------------------------------------------------------------
- (int)kftNatUpload:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count = 0;
	NSString* str;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		unsigned size = sizeof(count);
		returnValue = [nkeController getOption:SO_NAT_UPLOAD param:&count size:&size];
		if (returnValue) {
			str = [NSString stringWithFormat:@"kftNatUpload failure: %s", strerror(returnValue)];
			[nkeController updateParameter:@"statusInfo" withObject:str];
		}
		else if (count) {
			str = [NSString stringWithFormat:@" upload %lu nat", count];
			[nkeController updateParameter:@"statusInfoAppend" withObject:str];
		}
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftNatUpload failed, not connected"];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	� kftPortMapUpload
// ---------------------------------------------------------------------------
- (int)kftPortMapUpload:(NSString *)inURL
{
    int returnValue = 0;
	unsigned long count = 0;
	NSString* str;
	// check control channel to NKE
	if ([nkeController isConnected]) {
		// send command to NKE
		unsigned size = sizeof(count);
		returnValue = [nkeController getOption:SO_PORTMAP_UPLOAD param:&count size:&size];
		if (returnValue) {
			str = [NSString stringWithFormat:@"kftPortMapUpload failure: %s", strerror(returnValue)];
			[nkeController updateParameter:@"statusInfo" withObject:str];
		}
		else if (count) {
			str = [NSString stringWithFormat:@" upload %lu port maps", count];
			[nkeController updateParameter:@"statusInfoAppend" withObject:str];
		}
	}
	else [nkeController updateParameter:@"statusInfo" withObject:@"kftPortMapUpload failed, not connected"];
	return returnValue;
}


#pragma mark --- Receive from NKE ---

// ---------------------------------------------------------------------------
//	� updateTimer:
// ---------------------------------------------------------------------------
// Tell module we want more updates if firewall enabled
// Normally repeats every 5 seconds
- (void)updateTimer:(id)timer
{
	if ([[ [[SentryModel sharedInstance] sentryState] firewallOn] intValue]) {
		// could check if we are attached to any interfaces
		#if !TEST_IN_CLIENT
			[self sendURL:kSentryOn];
		#endif
	}
}


//
// -- <ControllerFromThread> --
//
// ---------------------------------------------------------------------------------
//	� receiveNotification:
// ---------------------------------------------------------------------------------
- (void)receiveNotification:(NSNotification *)aNotification
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSDictionary* dictionary = [aNotification userInfo];
	NSEnumerator* enumerator;
    id key;
	NSString* logText;
	KFT_interfaceEntry_t kftInterfaceEntry;
	int status;
    
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	InterfaceTable* interfaceT = [InterfaceTable sharedInstance]; 
	// handle kernel event messages to recognize when dlil attaches an interface like ppp0 
	if ([[aNotification name] isEqualTo:KEVMessageNotification]) do {
		if (![nkeController isConnected]) break;
		enumerator = [dictionary keyEnumerator];
		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			else if ([key isEqualTo:UDPMessageNotification]) {
				IPNetMessage* message;
				struct kern_event_msg *event;
				struct net_event_data *eventData;
				NSString* bsdName;
				// extract event code and bsdName from kernel event message
				message = [dictionary objectForKey:key];
				event = (struct kern_event_msg *)[[message data] bytes];
				if (event->kev_class == KEV_NETWORK_CLASS) {
					//NSLog(@"received kernel event with code %d", event->event_code);
					eventData = (struct net_event_data *)event->event_data;
					bsdName = [NSString stringWithFormat:@"%s%d",eventData->if_name, eventData->if_unit];
					if ((event->event_code == KEV_DL_IF_ATTACHED) ||
						(event->event_code == KEV_DL_LINK_ON)) {
						// data link was attached, check if we should attach NKE
						InterfaceEntry *entry = [interfaceT entryForInterfaceID:bsdName];
						if ([interfaceT isAttachEntry:entry]) {
							// insert NKE for corresponding link
							interfaceObjectToData(entry, &kftInterfaceEntry);
							// detach first to clear any stale attachment
							//status = [nkeController sentryDetach:&kftInterfaceEntry];
							status = [nkeController sentryAttach:&kftInterfaceEntry];
							//[self sendURL:[NSString stringWithFormat:@"%@%@",kSentryDetach,bsdName]];
							//[self sendURL:[NSString stringWithFormat:@"%@%@",kSentryAttach,bsdName]];
							// log it
							if (event->event_code == KEV_DL_LINK_ON)
								 logText = [NSString stringWithFormat:@" KEV_DL_LINK_ON %@", bsdName];
							else logText = [NSString stringWithFormat:@" KEV_DL_IF_ATTACHED %@", bsdName];
							//[logger logMessage:logText];
							[sentryState updateParameter:@"statusInfo" withObject:logText];
						}
						#if IPNetRouter
						// show named state
						NameServiceModel *nameServiceModel = [NameServiceModel sharedInstance];
						if ([[nameServiceModel nameServiceOn] intValue]) [nameServiceModel serverState];
						#endif
					}
					else if ((event->event_code == KEV_DL_IF_DETACHING) ||
							 (event->event_code == KEV_DL_LINK_OFF)) {
						// data link is detaching
						InterfaceEntry *entry = [interfaceT entryForInterfaceID:bsdName];
						// check if we should remove NKE for corresponding link
						if ([interfaceT isDetachEntry:entry]) {						
							interfaceObjectToData(entry, &kftInterfaceEntry);
							status = [nkeController sentryDetach:&kftInterfaceEntry];
							//[self sendURL:[NSString stringWithFormat:@"%@%@",kSentryDetach,bsdName]];
							// log it
							if (event->event_code == KEV_DL_LINK_OFF)
								 logText = [NSString stringWithFormat:@" KEV_DL_LINK_OFF %@", bsdName];
							else logText = [NSString stringWithFormat:@" KEV_DL_IF_DETACHING %@", bsdName];
							//[logger logMessage:logText];
							[sentryState updateParameter:@"statusInfo" withObject:logText];
						}
					}
				}
			}	// if ([key isEqualTo:UDPMessageNotification])
		}	// while ((key = [enumerator nextObject]))
	} while (false);	// if ([[aNotification name] isEqualTo:KEVMessageNotification]) do {

	else {
		// pass on any KEVControllerNotification
		[[SentryModel sharedInstance] receiveNotification:aNotification];
	}
    [pool release];
}


// ---------------------------------------------------------------------------------
//	� receiveDictionary:
// ---------------------------------------------------------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSEnumerator* enumerator;
    id key;

	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	
	if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
		// release DO clients
		// so we can get new ones
		[self disconnect];
	}
	
	if ([[dictionary objectForKey:PSAction] isEqualTo:PSReportErrorNotification]) {
		int code;
		code = [[dictionary objectForKey:@"code"] intValue];
		if (code == ENOENT) {
			// cancel update timer
//			[mUpdateTimer invalidate];	mUpdateTimer= nil;
// don't cancel on wake from sleep unless you have a plan to resume
		}
	}
	else {
		enumerator = [dictionary keyEnumerator];
		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			if ([key isEqualTo:UDPMessageNotification]) {
				IPNetMessage* message;
				ipk_message_t* ipkMessage;
				// dispatch message
				message = [dictionary objectForKey:key];
				ipkMessage = (ipk_message_t *)[[message data] bytes];
				
				switch (ipkMessage->type) {
				case kFilterUpdate:
					[self receiveFilterUpdate:[message data]];
					// remember previous message
					[message retain];
					[previousMessage release];
					previousMessage = message;
					break;
				case kTriggerUpdate:
					[self receiveTriggerUpdate:[message data]];
					break;
				case kInterfaceUpdate:
					[self receiveInterfaceUpdate:[message data]];
					break;
				case kConnectionUpdate:
					[self receiveConnectionUpdate:[message data]];
					break;
				case kTrafficUpdate:
					[trafficDiscoveryModel receiveTrafficUpdate:[message data]];
					break;
				case kSyncUpdate:
					[self receiveSyncUpdate:[message data]];
					break;
#ifdef IPNetRouter
				case kNatUpdate:
					[self receiveNatUpdate:[message data]];
					break;
				case kPortMapUpdate:
					[self receivePortMapUpdate:[message data]];
					break;
				case kRouteUpdate:
					[[AlternateRouteModel sharedInstance] receiveRouteUpdate:[message data]];
					break;
#endif
				case kFilterLog:
					[self receiveFilterLog:[message data]];
					break;
				case kFilterAlert:
					[self receiveFilterAlert:[message data]];
					break;
				case kFilterEmail:
					[self receiveFilterEmail:[message data]];
					break;
				case kFilterAppleScript:
					[self receiveFilterAppleScript:[message data]];
					break;
				case kFilterURL:
					[self receiveFilterURL:[message data]];
					break;
				case kMemStatUpdate:
					[[DiagnosticModel sharedInstance] receiveMemStatUpdate:[message data]];
					break;
				default:
					// notify listeners with any other message received
					[sentryState updateParameter:UDPMessageNotification withObject:message];
					break;
				}
			}	// if ([key isEqualTo:UDPMessageNotification])
			// kftUpload
			else if ([key isEqualTo:@"kftUpload"]) {
				id plist;
				FilterEntry* pasteItem;
				NSString* dataString;
				NSData* data;
				data = [dictionary objectForKey:key];
				dataString = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
				//NSLog(@"data length: %d, string length: %d",[data length], [dataString length]);
				if ([data length]) {
					NS_DURING
						plist = [dataString propertyList];
						if ([plist isKindOfClass:[NSDictionary class]]) {
							pasteItem = treeFromDictionary(plist);
							// replace contents of root item with upload data
							FilterTable* filterTable;
							if ((filterTable = [sentryState filterTable])) {
								[filterTable setNodeDictionary:[pasteItem nodeDictionary]];
								// update outline view
								[sentryState updateParameter:SS_filterTable withObject:SS_filterTable];
								// restore expanded state
								[sentryState updateParameter:SS_filterExpanded withObject:filterTable];
							}
						}
					NS_HANDLER
						NSBeep();
						NSLog(@"SentryController kftupload property list not recognized");
					NS_ENDHANDLER
				}
			}
			else {
				// notify listeners with any other message received
				[[NSNotificationCenter defaultCenter]
					postNotificationName:SentryControllerNotification
					object:self
					userInfo:dictionary];
				// log statusInfo messages
				if ([key isEqualTo:@"statusInfo"] || [key isEqualTo:@"statusInfoAppend"]) {
					[logger logMessage:[dictionary description]];
					if (gStartupItem) NSLog(@"%@",[dictionary objectForKey:key]);
				}
			}
		}	// while ((key = [enumerator nextObject]))
	}
	[pool release];
}

// ---------------------------------------------------------------------------------
//	� receiveFilterUpdate:
// ---------------------------------------------------------------------------------
- (void)receiveFilterUpdate:(NSData *)messageData
{
	ipk_filterUpdate_t* updateMessage;
	int j, length, howMany;
	FilterTable* filterTable;
	
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	filterTable = [sentryState filterTable];
	if (filterTable) {
		// check for previous message to remove delta's
		if (previousMessage) {
			updateMessage = (ipk_filterUpdate_t *)[[previousMessage data] bytes];
			length = updateMessage->length;
			howMany = (length-8)/sizeof(ipk_countUpdate_t);
			for (j=0; j<howMany; j++) {
				int index;
				FilterEntry* entry;
				index = updateMessage->countUpdate[j].index;
				// find corresponding tree node and update count
				entry = [filterTable nodeForIndex:index];
				[entry setMatchDelta:nil];
				[entry setByteDelta:nil];
				[sentryState updateParameter:SS_filterItem withObject:entry];
			}
		}
		// update for current message
		updateMessage = (ipk_filterUpdate_t *)[messageData bytes];
		length = updateMessage->length;
		howMany = (length-8)/sizeof(ipk_countUpdate_t);
		for (j=0; j<howMany; j++) {
			int index;
			FilterEntry* entry;
			index = updateMessage->countUpdate[j].index;
			// find corresponding tree node and update counts
			entry = [filterTable nodeForIndex:index];
			if (updateMessage->countUpdate[j].match.count) {
				[entry setLastTime:[NSNumber numberWithUnsignedInt:updateMessage->countUpdate[j].lastTime]];
				[entry setMatchCount:[NSNumber numberWithLongLong:updateMessage->countUpdate[j].match.count]];
				[entry setMatchDelta:[NSNumber numberWithLongLong:updateMessage->countUpdate[j].match.delta]];
			}
			else {
				[entry setLastTime:nil];
				[entry setMatchCount:nil];
				[entry setMatchDelta:nil];
			}
			if (updateMessage->countUpdate[j].byte.count) {
				[entry setByteCount:[NSNumber numberWithLongLong:updateMessage->countUpdate[j].byte.count]];
				[entry setByteDelta:[NSNumber numberWithLongLong:updateMessage->countUpdate[j].byte.delta]];
			}
			else {
				[entry setByteCount:nil];
				[entry setByteDelta:nil];
			}
			[sentryState updateParameter:SS_filterItem withObject:entry];
		}
	}	// if (filterTable)
}

// ---------------------------------------------------------------------------------
//	� receiveTriggerUpdate:
// ---------------------------------------------------------------------------------
- (void)receiveTriggerUpdate:(NSData *)messageData
{
	ipk_triggerUpdate_t* updateMessage;
	int j, length, howMany;
	TriggerTable* triggerTable;
	TriggerEntry* entry;
	
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	triggerTable = [sentryState triggerTable];
	if (triggerTable) {
		// update for current message
		updateMessage = (ipk_triggerUpdate_t *)[messageData bytes];
		length = updateMessage->length;
		howMany = (length-8)/sizeof(KFT_triggerEntry_t);
		for (j=0; j<howMany; j++) {
			// build trigger entry from message
			entry = triggerObjectFromData(&updateMessage->triggerUpdate[j]);
			if (!entry) continue;
			// check flags for requested action
			if (updateMessage->triggerUpdate[j].flags & kTriggerFlagDelete) {
				[triggerTable removeObject:entry];
			}
			else if (updateMessage->triggerUpdate[j].flags & kTriggerFlagUpdate) {
				[triggerTable insertObject:entry];
			}
		}
		// notify listeners table data has changed
		[sentryState updateParameter:SS_triggerTable withObject:SS_triggerTable];
	}	// if (triggerTable)
}

// ---------------------------------------------------------------------------------
//	� receiveInterfaceUpdate:
// ---------------------------------------------------------------------------------
// log what we get to confirm configuration
- (void)receiveInterfaceUpdate:(NSData *)messageData
{
	ipk_interfaceUpdate_t* updateMessage;
	int j, length;
	int howMany = 0;
	InterfaceTable* interfaceTable;

	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	interfaceTable = [InterfaceTable sharedInstance];
	if (interfaceTable) {
		// update for current message
		updateMessage = (ipk_interfaceUpdate_t *)[messageData bytes];
		length = updateMessage->length;
		howMany = (length-8)/sizeof(KFT_interfaceEntry_t);
		for (j=0; j<howMany; j++) {
			// get interface entry from message
			InterfaceEntry* interfaceE;
			InterfaceEntry* tableE;
			interfaceE = interfaceObjectFromData(&updateMessage->interfaceUpdate[j]);
			[logger logMessage:[interfaceE description]];
			// update interface table with entry
				// look for corresponding table entry with same serviceID
			tableE = [interfaceTable entryForServiceID:[interfaceE serviceID]];
			if (tableE) {
				// found a matching entry, replace it
					// preserve full interface name
				[interfaceE setInterfaceName:[tableE interfaceName]];
				[interfaceE setInterfaceID:[tableE interfaceID]];
					// replace node dictionary to update entry contents
				[tableE setNodeDictionary:[interfaceE nodeDictionary]];
			}
			else [[interfaceTable interfaceArray] addObject:interfaceE];
			// update implicit fields from entry
			if ([[interfaceE natOn] intValue]) {
				[sentryState setExcludeNet:[interfaceE excludeNet]];
				[sentryState setExposedHost:[interfaceE exposedHost]];
				[sentryState setExposedHostSelection:[interfaceE exposedHostSelection]];
			}
		}
		// notify listeners table data has changed
		[sentryState updateParameter:SS_interfaceTable withObject:SS_interfaceTable];
		// refresh implicit fields in case user has modified them
		[sentryState updateParameter:SS_excludeNet withObject:[sentryState excludeNet]];
		[sentryState updateParameter:SS_exposedHost withObject:[sentryState exposedHost]];
		[sentryState updateParameter:SS_exposedHostSelection withObject:[sentryState exposedHostSelection]];
	}	// if (interfaceTable)
	
	// if NKE is attached to any interfaces (howMany > 0)
	if (howMany) {
		// update firewallOn state
		[sentryState setFirewallOn:[NSNumber numberWithInt:1]];
	}
	else {
		[sentryState setFirewallOn:[NSNumber numberWithInt:0]];
	}
}

// ---------------------------------------------------------------------------------
//	� receiveConnectionUpdate:
// ---------------------------------------------------------------------------------
- (void)receiveConnectionUpdate:(NSData *)messageData
{
	if ([[[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_connectionLogging] intValue]) {
		ipk_connectionUpdate_t* updateMessage;
		int j, length, howMany;
		// update for current message
		updateMessage = (ipk_connectionUpdate_t *)[messageData bytes];
		length = updateMessage->length;
		howMany = (length-8)/sizeof(KFT_connectionEntry_t);
		for (j=0; j<howMany; j++) {
			// log each connection entry
			NSDictionary* connectionEntry;
			NSString* protocolStr;
			NSString* flagsStr = @"";
			IPValue* remote;
			IPValue* local;
			int protocol;
			int flags;
			// protocol
			protocol = updateMessage->connectionUpdate[j].local.protocol;
			if (protocol == IPPROTO_TCP) protocolStr = @"TCP";
			else if (protocol == IPPROTO_UDP) protocolStr = @"UDP";
			else if (protocol == IPPROTO_ICMP) {
				protocolStr = [NSString stringWithFormat:@"ICMP:%d,%d",
					updateMessage->connectionUpdate[j].remote.port,
					updateMessage->connectionUpdate[j].local.port];
				protocolStr = [[SentryLogger sharedInstance] formatProtocol:protocolStr];
			}
			else protocolStr = [NSString stringWithFormat:@"%d",protocol];
			// flags
			flags = updateMessage->connectionUpdate[j].flags;
			if (flags & kConnectionFlagDelete) flagsStr = @"delete";
			else if (flags & kConnectionFlagUpdate) flagsStr = @"update";
			// remote and local endpoint
			remote = [[[IPValue alloc] init] autorelease];
			local = [[[IPValue alloc] init] autorelease];
			[remote setIpAddress:updateMessage->connectionUpdate[j].remote.address];
			[local setIpAddress:updateMessage->connectionUpdate[j].local.address];
			if ((protocol == IPPROTO_UDP) || (protocol == IPPROTO_TCP)) {
				[remote setStartPort:updateMessage->connectionUpdate[j].remote.port];
				[local setStartPort:updateMessage->connectionUpdate[j].local.port];
			}
			// build dictionary entry for connection
			connectionEntry = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSDate dateWithTimeIntervalSince1970:updateMessage->connectionUpdate[j].firstTime], @"firstTime",
				[NSDate dateWithTimeIntervalSince1970:updateMessage->connectionUpdate[j].lastTime], @"lastTime",
				protocolStr, @"protocol",
				flagsStr, @"flags",
				[remote stringValueForProtocol:protocol], @"remoteEndpoint",
				[local stringValueForProtocol:protocol], @"localEndpoint",
				[NSString stringWithFormat:@"%d",updateMessage->connectionUpdate[j].dataIn.count], @"dataIn",
				[NSString stringWithFormat:@"%d",updateMessage->connectionUpdate[j].dataOut.count], @"dataOut",
				nil];
			[[ConnectionLog sharedInstance] connectionLogAppend:connectionEntry];
		}
	}
}

// ---------------------------------------------------------------------------------
//	� receiveSyncUpdate:
// ---------------------------------------------------------------------------------
//	record last syncInterval received from NKE
- (void)receiveSyncUpdate:(NSData *)messageData
{
	ipk_syncUpdate_t* updateMessage;
	
	// update for current message
	updateMessage = (ipk_syncUpdate_t *)[messageData bytes];
	mSyncInterval = updateMessage->timeInterval;
}

#ifdef IPNetRouter
// ---------------------------------------------------------------------------------
//	� receiveNatUpdate:
// ---------------------------------------------------------------------------------
- (void)receiveNatUpdate:(NSData *)messageData
{
	ipk_natUpdate_t* updateMessage;
	int j, length, howMany;
	NatTable* natTable;
	NatEntry* entry;
	
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	natTable = [sentryState natTable];
	if (natTable) {
		// update for current message
		updateMessage = (ipk_natUpdate_t *)[messageData bytes];
		length = updateMessage->length;
		howMany = (length-8)/sizeof(KFT_natEntry_t);
		for (j=0; j<howMany; j++) {
			// build nat entry from message
			entry = natObjectFromData(&updateMessage->natUpdate[j]);
			if (!entry) continue;
			// check flags for requested action
			if (updateMessage->natUpdate[j].flags & kNatFlagDelete) {
				[natTable removeObject:entry];
			}
			else if (updateMessage->natUpdate[j].flags & kNatFlagUpdate) {
				[natTable insertObject:entry];
				// testing nat table
				//NSString* str = [NSString stringWithFormat:@"\n%@",[entry description]];
				//[[SentryLogger sharedInstance] appendMessage:str];
			}
		}
		// notify listeners table data has changed
		[sentryState updateParameter:SS_natTable withObject:SS_natTable];
	}	// if (natTable)
}

// ---------------------------------------------------------------------------------
//	� receivePortMapUpdate:
// ---------------------------------------------------------------------------------
- (void)receivePortMapUpdate:(NSData *)messageData
{
	ipk_natUpdate_t* updateMessage;
	int j, length, howMany;
	PortMapTable* portMapTable;
	PortMapEntry* entry;
	
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	portMapTable = [sentryState portMapTable];
	if (portMapTable) {
		// update for current message
		updateMessage = (ipk_natUpdate_t *)[messageData bytes];
		length = updateMessage->length;
		howMany = (length-8)/sizeof(KFT_natEntry_t);
		for (j=0; j<howMany; j++) {
			// build nat entry from message
			entry = portMapObjectFromData(&updateMessage->natUpdate[j]);
			if (!entry) continue;
			// check flags for requested action
			if (updateMessage->natUpdate[j].flags & kNatFlagDelete) {
				[portMapTable removeObject:entry];
			}
			else if (updateMessage->natUpdate[j].flags & kNatFlagUpdate) {
				[portMapTable insertObject:entry];
			}
		}
		// notify listeners table data has changed
		[sentryState updateParameter:SS_portMapTable withObject:SS_portMapTable];
	}	// if (portMapTable)
}
#endif

// ---------------------------------------------------------------------------------
//	� receiveFilterLog:
// ---------------------------------------------------------------------------------
- (void)receiveFilterLog:(NSData *)messageData
{
	ipk_filterLog_t* logMessage;
	NSString* messageText;
    
	logMessage = (ipk_filterLog_t*)[messageData bytes];
	messageText = [[[NSString alloc] initWithBytes:&logMessage->text[0]
		length:[messageData length]-sizeof(ipk_message_t) encoding:NSUTF8StringEncoding] autorelease];
	[logger logMessage:messageText];					
}

// ---------------------------------------------------------------------------------
//	� receiveFilterAlert:
// ---------------------------------------------------------------------------------
- (void)receiveFilterAlert:(NSData *)messageData
{
	ipk_filterLog_t* logMessage;
	NSString* messageText;
    
	logMessage = (ipk_filterLog_t*)[messageData bytes];
	messageText = [[[NSString alloc] initWithBytes:&logMessage->text[0]
		length:[messageData length]-sizeof(ipk_message_t) encoding:NSUTF8StringEncoding] autorelease];
	[logger logMessage:messageText];
	// convert to dictionary and show alert
	if ([messageText hasPrefix:@"{"]) {
		NSDictionary* logDictionary;
		NSMutableString* alertStr;
		NSString* str;
		NSString* alertAddress = nil;
		NS_DURING
			logDictionary = [messageText propertyList];
			alertStr = [[[NSMutableString alloc] init] autorelease];
			// action
			if ((str = [logDictionary objectForKey:@"action"]))
				[alertStr appendString:str];
			// rule
			[alertStr appendString:@" rule "];
			if ((str = [logDictionary objectForKey:@"rule"]))
				[alertStr appendString:str];
			// protocol
			[alertStr appendString:@"\n"];
			if ((str = [logDictionary objectForKey:@"protocol"]))
				[alertStr appendString:str];
			// source
			[alertStr appendString:@" "];
			if ((str = [logDictionary objectForKey:@"source"])) {
				[alertStr appendString:str];
				saveAddressOrName(str);
				alertAddress = stringForIP(ipForString(str));
			}
			// destination
			[alertStr appendString:@" --> "];
			if ((str = [logDictionary objectForKey:@"destination"]))
				[alertStr appendString:str];
			// parameter
			if ((str = [logDictionary objectForKey:@"parameter"])) {
				[alertStr appendString:@"\n"];
				[alertStr appendString:str];
			}
			// build growl notification dictionary
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
				@"IPNetSentryX Security Alert", GROWL_NOTIFICATION_TITLE,
				alertStr, GROWL_NOTIFICATION_DESCRIPTION,
				kTriggerAlert, GROWL_NOTIFICATION_NAME,
				[NSNumber numberWithInt:0], GROWL_NOTIFICATION_PRIORITY,
				[NSNumber numberWithInt:0], GROWL_NOTIFICATION_STICKY,
				kTriggerAlert, GROWL_NOTIFICATION_CLICK_CONTEXT,
				kTriggerAlert, GROWL_NOTIFICATION_IDENTIFIER,
				alertAddress, kTriggerAlertAddress,
				@"IPNetRouterX", GROWL_APP_NAME,
				nil];
			// if alerts not disabled
			if (![[[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_disableAlerts] intValue] &&
				!gStartupItem) {
				// send it
				[[MyGrowlDelegate sharedInstance] notifyWithDictionary:userInfo];
			}
		NS_HANDLER
			NSLog(@"Exception during SentryController.m -receiveFilterAlert");
		NS_ENDHANDLER
		// show alert
	}
}

// ---------------------------------------------------------------------------------
//	� receiveFilterEmail:
// ---------------------------------------------------------------------------------
- (void)receiveFilterEmail:(NSData *)messageData
{
	ipk_filterLog_t* logMessage;
	NSString* messageText;
	NSString* logText;
    
	logMessage = (ipk_filterLog_t*)[messageData bytes];
	messageText = [[[NSString alloc] initWithBytes:&logMessage->text[0]
		length:[messageData length]-sizeof(ipk_message_t) encoding:NSUTF8StringEncoding] autorelease];
	[logger logMessage:messageText];	// add to log file
	logText = [logger formatLogMessage:messageText];	// format for Email
	// retrieve message dictionary
	if ([messageText hasPrefix:@"{"]) {
		NSDictionary* logDictionary;
		NSString* mailToAddress;
		NSString* emailFromField;
		NSString* emailNameField;
		NSString* inSubject;
		NSRange range;
		// convert to dictionary
		logDictionary = [messageText propertyList];
		mailToAddress = [logDictionary objectForKey:@"parameter"];
		range.length = 0;
		if (mailToAddress) range = [mailToAddress rangeOfString:@"@"];
		if (!range.length) mailToAddress = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_emailToField];
		emailFromField = [[[AppDelegate sharedInstance] prefs]
			objectForKey:kPreferences_emailFromField];
		emailNameField = [[[AppDelegate sharedInstance] prefs]
			objectForKey:kPreferences_emailNameField];
		if (emailFromField && emailNameField) {
			emailFromField = [NSString stringWithFormat:@"%@ <%@>",emailNameField,emailFromField];
		}

		#ifdef IPNetRouter
			inSubject = @"--- IPNetRouter Security Alert ---";
		#else
			inSubject = @"--- IPNetSentry Security Alert ---";
		#endif
		// create server as thread object if needed
		{
			// build message dictionary
			NSMutableDictionary* message = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				inSubject,@"Subject",
				mailToAddress,@"To",
				[[NSDate psDate] description],@"Date",
				logText, @"Body",
				nil];
			if (emailFromField) [message setObject:emailFromField forKey:@"From"];
			// create server if needed
			SendEmailController* controller = [SendEmailController sharedInstance];
			//[controller setCallbackTarget:self];
			[controller startService:kSendEmail withObject:message];
		}
	}
}

// ---------------------------------------------------------------------------------
//	� receiveFilterAppleScript:
// ---------------------------------------------------------------------------------
- (void)receiveFilterAppleScript:(NSData *)messageData
{
	ipk_filterLog_t* logMessage;
	NSString* messageText;
    
	logMessage = (ipk_filterLog_t*)[messageData bytes];
	messageText = [[[NSString alloc] initWithBytes:&logMessage->text[0]
		length:[messageData length]-sizeof(ipk_message_t) encoding:NSUTF8StringEncoding] autorelease];
	[logger logMessage:messageText];					
	// retrieve message dictionary
	if ([messageText hasPrefix:@"{"]) {
		NSDictionary* logDictionary;
		NSString* filename;
		NSString* path;
		NSAppleEventDescriptor* ae;
		// convert to dictionary
		NS_DURING
			do {
				NSAppleScript* script;
				NSURL* url;
				path = [[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_appleScriptFile];
				if ([path length] == 0) {
					NSLog(@"Detected filter action 'Perform AppleScript' with no script file specified.");
					break;
				}
				logDictionary = [messageText propertyList];
				filename = [logDictionary objectForKey:@"parameter"];
				if (filename) {
					path = [path stringByDeletingLastPathComponent];
					path = [path stringByAppendingPathComponent:filename];
				}
				url = [NSURL fileURLWithPath:path];
				script = [[NSAppleScript alloc] initWithContentsOfURL:url error:&logDictionary];
				if (!script) [[SentryLogger sharedInstance] appendMessage:[logDictionary description]];
				else {
					ae = [script executeAndReturnError:&logDictionary];
					if (!ae) [[SentryLogger sharedInstance] appendMessage:[logDictionary description]];
				}
			} while (0);
		NS_HANDLER
			NSLog(@"Exception during SentryController.m receiveFilterAppleScript");
		NS_ENDHANDLER
	}
}

// ---------------------------------------------------------------------------------
//	� receiveFilterURL:
// ---------------------------------------------------------------------------------
- (void)receiveFilterURL:(NSData *)messageData
{
	ipk_filterLog_t* logMessage;
	NSString* messageText;
    
	logMessage = (ipk_filterLog_t*)[messageData bytes];
	messageText = [[[NSString alloc] initWithBytes:&logMessage->text[0]
		length:[messageData length]-sizeof(ipk_message_t) encoding:NSUTF8StringEncoding] autorelease];
	// don't log periodic URL messages
	//[logger logMessage:messageText];
	// retrieve message dictionary
	if ([messageText hasPrefix:@"{"]) {
		NSDictionary* logDictionary;
		NSString* urlString;
		// convert to dictionary
		NS_DURING
			logDictionary = [messageText propertyList];
			urlString = [logDictionary objectForKey:@"parameter"];
			// get DO client and server if needed
			if (!mURLClient) {
				mURLClient = [[PsClient alloc] init];
				[mURLClient setCallbackTarget:self];
				[mURLClient setServerClass:[URLAction class]];
				[mURLClient createNewServer:[URLAction class]];
			}
			// request corresponding URL
			[mURLClient startService:urlString withObject:nil];
		NS_HANDLER
			NSLog(@"Exception during SentryController.m receiveFilterURL");
		NS_ENDHANDLER
	}
}
@end


#pragma mark --- NKE_TEST_IN_CLIENT ---
void testMessageFromClient(ipk_message_t* message);
// ---------------------------------------------------------------------------------
//	� testMessageFromClient()
// ---------------------------------------------------------------------------------
void testMessageFromClient(ipk_message_t* message)
{
	NSMutableData* data;
	IPNetMessage* netMessage;
	
	data = [NSMutableData dataWithBytes:message length:message->length];
	netMessage = [[[IPNetMessage alloc] init] autorelease];
	[netMessage setData:data];
	[[SentryController sharedInstance] receiveDictionary:
		[NSDictionary dictionaryWithObject:netMessage forKey:UDPMessageNotification]];
}

#pragma mark - Download Conversion -

// ---------------------------------------------------------------------------------
//	� filterText2Table()
// ---------------------------------------------------------------------------------
// Parse NeXT format property list to load filter table
// Each filter entry is represented as a dictionary
// Return: number of top level entries read
// array ->      (value,value,value)
// dictionary -> { key = value; key = value; key = value}
// quoted value -> "some value"
int filterText2Table(PSData* inBuf, PSData* outBuf)
{
	int returnValue = 0;
	PSRange range;
	int index;
	inBuf->offset = 0;		// start of buffer and filter table
	index = 0;
	outBuf->offset = 0;		// kft_filterNextEntry

	// re-init filter table
	//KFT_filterInit();
	// scan input for tokens indicating a filter entry dictionary
	while (inBuf->offset < inBuf->length) {
		nextToken(inBuf, &range);
		if (range.length == 0) break;	// end of data
		// start of dictionary?
		if (inBuf->bytes[range.location] == '{') {
			readEntryToIndex(inBuf, outBuf, &index);
			returnValue += 1;
		}
		// ignore other tokens used for house keeping (,)
	}
	// calculate length of converted table entries
	outBuf->length = outBuf->offset * sizeof(KFT_filterEntry_t);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� readEntryToIndex()
// ---------------------------------------------------------------------------------
//	Caller has detected start of FE dictionary, read into filter table at index
//	Output: >0=success, -1=error
int readEntryToIndex(PSData* inBuf, PSData* outBuf, int* ioIndex)
{
	KFT_filterEntry_t* table;
	KFT_filterEntry_t* entry;
	PSRange range;	
	int myIndex;
	int childIndex;
	int end;
	int returnValue = -1;
	
	myIndex = *ioIndex;	// keep a local copy
	*ioIndex += 1;		// increment for next
	if (*ioIndex > outBuf->offset) outBuf->offset = *ioIndex;
	
	// clear out any previous junk
	table = (KFT_filterEntry_t *)outBuf->bytes;
	entry = &table[myIndex];
	bzero(entry, sizeof(KFT_filterEntry_t));
	entry->parameterStart = kPropertySize-1;
	// initialize node count
	entry->nodeCount = 1;

	// scan input for tokens that make up a filter entry
	while (inBuf->offset < inBuf->length) {
		nextToken(inBuf, &range);
		if (range.length == 0) break;	// end of data
		// we expect to see dictionary entries of the form:
		//		key = value;
		//		children = ({entry},{entry});
		
		// } indicates end of dictionary, return to caller
		if (inBuf->bytes[range.location] == '}') break;
		
		// examine key
		do {
			if (memcmp("children", &inBuf->bytes[range.location], range.length) == 0) {
				// try to read children recursively (if any)
				nextToken(inBuf, &range);
				if (inBuf->bytes[range.location] != '=') break;
				nextToken(inBuf, &range);
				if (inBuf->bytes[range.location] != '(') break;
				while (*ioIndex < KFT_filterTableSize) {		// room in table
					nextToken(inBuf, &range);
					if (range.length == 0) break;	// not end of data
					if (inBuf->bytes[range.location] == ')') break;
					// start of dictionary?
					if (inBuf->bytes[range.location] == '{') {
						// read child entry
						childIndex = *ioIndex;
						readEntryToIndex(inBuf, outBuf, ioIndex);
						table[childIndex].parentIndex = myIndex;
						nextToken(inBuf, &range);
						if (inBuf->bytes[range.location] != ',') break;
					}
				}
				// update node count based on number of children read
				entry->nodeCount = *ioIndex - myIndex;
			}
			else if (memcmp("enabled", &inBuf->bytes[range.location], range.length) == 0) {
				entry->enabled = intParamValue(inBuf);
			}
			else if (memcmp("filterAction", &inBuf->bytes[range.location], range.length) == 0) {
				entry->filterAction = intParamValue(inBuf);
			}
			else if (memcmp("expandedState", &inBuf->bytes[range.location], range.length) == 0) {
				entry->expandedState = intParamValue(inBuf);
			}
			else if (memcmp("nodeNumber", &inBuf->bytes[range.location], range.length) == 0) {
				// skip =
				nextToken(inBuf, &range);
				if (inBuf->bytes[range.location] != '=') break;
				// get node number string
				nextToken(inBuf, &range);
				// save as PString
				entry->nodeNumber[0] = range.length;
				if (range.length < 16) memcpy(&entry->nodeNumber[1],
					&inBuf->bytes[range.location], range.length);
			}
			else if (memcmp("nodeName", &inBuf->bytes[range.location], range.length) == 0) {
				// skip =
				nextToken(inBuf, &range);
				if (inBuf->bytes[range.location] != '=') break;
				// get node name string
				nextToken(inBuf, &range);
				// save up to 31 characters
				if (range.length > 31) range.length = 31;
				// save as PString
				entry->nodeName[0] = range.length;
				memcpy(&entry->nodeName[1],
					&inBuf->bytes[range.location], range.length);
			}
			else if (memcmp("property", &inBuf->bytes[range.location], range.length) == 0) {
				entry->property = intParamValue(inBuf);
			}
			else if (memcmp("relation", &inBuf->bytes[range.location], range.length) == 0) {
				entry->relation = intParamValue(inBuf);
			}
			else if (memcmp("propertyValue", &inBuf->bytes[range.location], range.length) == 0) {
				// skip =
				nextToken(inBuf, &range);
				if (inBuf->bytes[range.location] != '=') break;
				// get property value string
				nextToken(inBuf, &range);
				// convert into table entry
				readPropertyValueToIndex(inBuf, outBuf, myIndex, &range);
			}
			// parameter grows from far end of property buffer
			else if (memcmp("parameter", &inBuf->bytes[range.location], range.length) == 0) {
				// skip =
				nextToken(inBuf, &range);
				if (inBuf->bytes[range.location] != '=') break;
				// get parameter string
				nextToken(inBuf, &range);
				// save up to max characters
				int max = kPropertySize - kPropertyReserve;
				if (entry->propertyEnd > kPropertyReserve)
					max = kPropertySize - entry->propertyEnd;
				if (range.length >= max) range.length = max-1;
				// save as PString
				int parameterStart = kPropertySize - (range.length + 1);
				entry->parameterStart = parameterStart;
				entry->propertyValue[parameterStart] = range.length;
				memcpy(&entry->propertyValue[parameterStart+1],
					&inBuf->bytes[range.location], range.length);
				// Convert common parameters
				if ((entry->filterAction == kActionRateLimitIn) ||
					(entry->filterAction == kActionRateLimitOut)) {
					// convert to int for rate limit
					entry->rateLimit = intValueWithFraction(inBuf, &range);
				}
				else if (entry->filterAction == kActionRouteTo) {
					// convert to IP address x.x.x.x for route To
					u_int8_t* dp8;
					dp8 = (u_int8_t*)&entry->routeNextHop;
					entry->routeNextHop = 0;
					dp8[0] = intValue(inBuf, &range);
					if (!skipByte(inBuf, &range, '.')) break;
					dp8[1] = intValue(inBuf, &range);
					if (!skipByte(inBuf, &range, '.')) break;
					dp8[2] = intValue(inBuf, &range);
					if (!skipByte(inBuf, &range, '.')) break;
					dp8[3] = intValue(inBuf, &range);
					// have IP in network byte order
					entry->routeNextHop = ntohl(entry->routeNextHop);
					// ping address to setup ARP cache
					//[[ICMPController sharedInstance] sendPing:entry->routeNextHop];
					// use ARP to find hardware address
					int retryLimit = 3;
					u_int8_t len = 8;
					int result;
					result = hwAddressForIP(entry->routeNextHop, entry->routeHardwareAddress, &len);
					while ((result != 0) && (retryLimit-- > 0)) {
						// ping address to setup ARP cache
						[[ICMPController sharedInstance] sendPing:entry->routeNextHop];
						[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
						result = hwAddressForIP(entry->routeNextHop, entry->routeHardwareAddress, &len);
					}
					if (result == 0) {
						u_int8_t* ha = entry->routeHardwareAddress;
						NSString* hwString = [NSString stringWithFormat:
							@"%02X:%02X:%02X:%02X:%02X:%02X",
							ha[0],ha[1],ha[2],ha[3],ha[4],ha[5]];
						NSString* str = [NSString stringWithFormat:@"Route to %@ resolved to %@",
							stringForIP(entry->routeNextHop), hwString];
						[[NKEController sharedInstance] updateParameter:@"statusInfo" withObject:str];
					}
					else {
						NSString* str = [NSString stringWithFormat:@"Route to %@ failed to resolve hardware address",
							stringForIP(entry->routeNextHop)];
						[[NKEController sharedInstance] updateParameter:@"statusInfo" withObject:str];
					}
				}
			}
			else if (memcmp("lastTime", &inBuf->bytes[range.location], range.length) == 0) {
				entry->lastTime = intParamValue(inBuf);
			}
			else if (memcmp("matchCount", &inBuf->bytes[range.location], range.length) == 0) {
				entry->match.count = int64ParamValue(inBuf);
			}
			else if (memcmp("byteCount", &inBuf->bytes[range.location], range.length) == 0) {
				entry->byte.count = int64ParamValue(inBuf);
			}
		} while (FALSE);	// end examine key
		
		// check for (or skip to) terminating ;
		end = findByte(inBuf, ';');
		if (end < 0) break;
		inBuf->offset = end + 1;
		returnValue = inBuf->offset;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� readPropertyValueToIndex()
// ---------------------------------------------------------------------------------
// read property value to table entry[index] based on property
// 0=success
//
// PropertyValue is stored from the beginning of the buffer.
// Parameter is stored from the end of the buffer.
// We reserve kPropertyReserve = 32 bytes minimum if other is not yet known.
// Record how much we used by setting kft_filterTable[index].propertyEnd to
// index of next free byte in propertyValue buffer.
int readPropertyValueToIndex(PSData* inBuf, PSData* outBuf, int index, PSRange* range)
{
	KFT_filterEntry_t* table;
	u_int8_t* dp8;
	u_int16_t* dp16;
	u_int32_t* dp32;
	int64_t* dp64;
	int i, j;
	int max;
	int returnValue = 0;
	
	table = (KFT_filterEntry_t *)outBuf->bytes;
	dp8 = &table[index].propertyValue[0];
	dp16 = (u_int16_t*)dp8;
	dp32 = (u_int32_t*)dp8;
	dp64 = (int64_t*)dp8;
	if (table[index].property < kFilter__2) {
		if (table[index].property < kFilter__1) {
			switch(table[index].property) {
				case kFilterAny:
				case kFilterNone:
					// consume one byte to indicate property size is known
					table[index].propertyEnd = 1;
					break;
				case kFilterDirection:
					if (memcmp("inbound", &inBuf->bytes[range->location], range->length) == 0)
						dp8[0] = kDirectionInbound;
					else dp8[0] = kDirectionOutbound;
					table[index].propertyEnd = 1;
					break;
				case kFilterInterface:
					dp8[0] = 0;	// default to empty
					// check for old style name for lo0
					if ((inBuf->bytes[range->location] == 'l') &&
						(inBuf->bytes[range->location+1] == 'o') &&
						(inBuf->bytes[range->location+2] == '0')) {
						range->length = 3;
						dp8[0] = range->length;
						memcpy(&dp8[1], &inBuf->bytes[range->location], range->length);
						dp8[1+range->length] = 0;   // null terminate
						table[index].propertyEnd = range->length + 2;
						break;
					}
					// check for old style name for en0
					if ((inBuf->bytes[range->location] == 'e') &&
						(inBuf->bytes[range->location+1] == 'n') &&
						(inBuf->bytes[range->location+2] == '0')) {
						range->length = 3;
						dp8[0] = range->length;
						memcpy(&dp8[1], &inBuf->bytes[range->location], range->length);
						dp8[1+range->length] = 0;   // null terminate
						table[index].propertyEnd = range->length + 2;
						break;
					}
					// check for internal/external
					if (memcmp(&inBuf->bytes[range->location],"internal",8) == 0) {
						dp8[0] = 1;	// len 1
						dp8[1] = kInterfaceInternal;
						table[index].propertyEnd = 4;
						break;
					}
					if (memcmp(&inBuf->bytes[range->location],"external",8) == 0) {
						dp8[0] = 1;
						dp8[1] = kInterfaceExternal;
						table[index].propertyEnd = 4;
						break;
					}
					// extract BSD name
					j = inBuf->offset;	// save previous offset
					inBuf->offset = range->location;	// start of token
					// look for "("
					i = findByteInRange(inBuf, range, '(');
					while (i>0) {
						range->location += 1;   // skip (
						range->length -= 1;
						inBuf->offset = range->location;
						i = findByteInRange(inBuf, range, '(');
					}
					i = findEndOfToken(inBuf);
					range->length = i - range->location;
					inBuf->offset = j;	// restore previous offset
					// save as PString (valid names are 8 chars or less)
					if (range->length < kBSDNameLength) {
						dp8[0] = range->length;
						memcpy(&dp8[1], &inBuf->bytes[range->location], range->length);
						dp8[1+range->length] = 0;   // null terminate
						table[index].propertyEnd = range->length + 2;
					}
					break;
				case kFilterInclude:
					if (memcmp("trigger", &inBuf->bytes[range->location], range->length) == 0)
						dp8[0] = kIncludeTrigger;
					else if (memcmp("address", &inBuf->bytes[range->location], range->length) == 0)
						dp8[0] = kIncludeAddress;
					else if (memcmp("authorize", &inBuf->bytes[range->location], range->length) == 0)
						dp8[0] = kIncludeAuthorize;
					else if (memcmp("invalid", &inBuf->bytes[range->location], range->length) == 0)
						dp8[0] = kIncludeInvalid;
					else if (memcmp("state", &inBuf->bytes[range->location], range->length) == 0)
						dp8[0] = kIncludeState;
					table[index].propertyEnd = 1;
					break;
				case kFilterSourceMACAddress:
				case kFilterDestMACAddress:
					dp32[0] = 0;	// default
					dp32[1] = 0;
					// xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx
					dp8[0] = intHexValue(inBuf, range);
					if (!skipByte(inBuf, range, ':') && !skipByte(inBuf, range, '-')) break;
					dp8[1] = intHexValue(inBuf, range);
					if (!skipByte(inBuf, range, ':') && !skipByte(inBuf, range, '-')) break;
					dp8[2] = intHexValue(inBuf, range);
					if (!skipByte(inBuf, range, ':') && !skipByte(inBuf, range, '-')) break;
					dp8[3] = intHexValue(inBuf, range);
					if (!skipByte(inBuf, range, ':') && !skipByte(inBuf, range, '-')) break;
					dp8[4] = intHexValue(inBuf, range);
					if (!skipByte(inBuf, range, ':') && !skipByte(inBuf, range, '-')) break;
					dp8[5] = intHexValue(inBuf, range);
					table[index].propertyEnd = 8;
					break;
			}
		}	// < kFilter__1
		else {
			switch(table[index].property) {
				case kFilterSourceNet:
				case kFilterDestNet: {
					//dp32[0] = 0;	// ipAddress
					//dp32[1] = 0;	// endOffset
					NSString* propertyStr = [[[NSString alloc] initWithBytes:(char *)&inBuf->bytes[range->location] length:range->length encoding:NSUTF8StringEncoding] autorelease];
					IPValue* ipValue = [[[IPValue alloc] init] autorelease];
					[ipValue setStringValue:propertyStr];
					dp32[0] = [ipValue startOfRange];
					dp32[1] = [ipValue endOffset];
					table[index].propertyEnd = 8;
					//NSLog(@"Str=%@ startOfRange=%@ endOffset=%d",propertyStr, stringForIP(dp32[0]), dp32[1]);
					break;
					//NSLog(propertyStr);
						// default
					// x.x.x.x/prefix_len
					dp8[0] = intValue(inBuf, range);
					if (!skipByte(inBuf, range, '.')) break;
					dp8[1] = intValue(inBuf, range);
					if (!skipByte(inBuf, range, '.')) break;
					dp8[2] = intValue(inBuf, range);
					if (!skipByte(inBuf, range, '.')) break;
					dp8[3] = intValue(inBuf, range);
					dp32[0] = ntohl(dp32[0]);
					i = 32;	// default prefix length
					if (skipByte(inBuf, range, '/')) i = intValue(inBuf, range);
					if (i > 32) i = 32;
					// set netmask
					dp32[1] = 0xffffffff << (32 - i);
					table[index].propertyEnd = 8;
					break;
				}
				case kFilterProtocol:
					dp8[0] = intValue(inBuf, range);
					table[index].propertyEnd = 1;
					break;		
				case kFilterIPFragmentOffset:
					dp16[0] = intValue(inBuf, range);
					// default ending offset
					dp16[1] = 0;
					// fragment range?
					if (skipByte(inBuf, range, '-')) {
						// get ending offset
						dp16[1] = intValue(inBuf, range);
					}
					table[index].propertyEnd = 4;
					break;		
				case kFilterIPOptions:
					// save options as null terminated list of integers
					i = 0;
					dp8[i++] = intValue(inBuf, range);
					while (skipByte(inBuf, range, ',')) dp8[i++] = intValue(inBuf, range);
					dp8[i++] = 0;
					table[index].propertyEnd = i;
					break;		
				case kFilterICMPType:
				case kFilterICMPCode:
					dp8[0] = intValue(inBuf, range);
					table[index].propertyEnd = 1;
					break;
			}
		}
	}	// < kFilter__2
	else {
		if (table[index].property < kFilter__3) {
			switch(table[index].property) {
				case kFilterTCPHeaderFlags:
					// save as 8-bit ON mask and OFF mask
					do {
						int flag;
						if (!skipByte(inBuf, range, '-')) {
							flag = tcpHeaderFlagValue(inBuf, range);
							if (flag) dp8[0] |= flag;
							else break;
						}
						else {
							flag = tcpHeaderFlagValue(inBuf, range);
							if (flag) dp8[1] |= flag;
							else break;
						}
					} while (skipByte(inBuf, range, ','));
					table[index].propertyEnd = 2;
					break;
				case kFilterTCPOptions:
					// save options as null terminated list of integers
					i = 0;
					dp8[i++] = intValue(inBuf, range);
					while (skipByte(inBuf, range, ',')) dp8[i++] = intValue(inBuf, range);
					dp8[i++] = 0;
					table[index].propertyEnd = i;
					break;		
				case kFilterSourcePort:
				case kFilterDestPort:
					// get starting port
					dp16[0] = intValue(inBuf, range);
					// default ending port
					dp16[1] = 0;
					// port range?
					if (skipByte(inBuf, range, '-')) {
						// get ending port
						dp16[1] = intValue(inBuf, range);
					}
					table[index].propertyEnd = 4;
					break;
				case kFilterDataContent:
				{
					// setup contentSpec
					KFT_contentSpec_t* content;
					content = (KFT_contentSpec_t *)dp8;
					content->searchOffset = 0;	// default search area
					content->searchLength = kContent_searchLength;
					content->searchDelimiter = 0;
					content->flags = 0;
					// check for [offset:length]
					if (skipByte(inBuf, range, '[')) {
						if (skipByte(inBuf, range, '+')) content->flags = kContentFlag_relativePlus;
						else if (skipByte(inBuf, range, '-')) content->flags = kContentFlag_relativeMinus;
						content->searchOffset = intValue(inBuf, range);
						if (skipByte(inBuf, range, ':') || skipByte(inBuf, range, ',')) {
							content->searchLength = intValue(inBuf, range);
						}
						if (skipByte(inBuf, range, ':') || skipByte(inBuf, range, ',')) {
							content->searchDelimiter = intValue(inBuf, range);
							content->flags |= kContentFlag_useDelimiter;
						}
						skipByte(inBuf, range, ']');
					}
					// determine max chars
					max = table[index].parameterStart;
					if (!max) max = kPropertySize - kPropertyReserve;
					max -= sizeof(KFT_contentSpec_t); 
					// save match text as content->data
					i = range->length;
					if (i >= max) i = max - 1;	// truncate if needed
					content->length = i;
					memcpy(&content->data[0], &inBuf->bytes[range->location], i);
					content->dataPtr = &content->data[0];	// must reset pointer after table is copied to NKE!
					decodeContent(content);
					table[index].propertyEnd = content->length + sizeof(KFT_contentSpec_t);
					break;
				}
				case kFilterURLKeyword:
					// determine max chars
					max = table[index].parameterStart;
					if (!max) max = kPropertySize - kPropertyReserve;
					// save URL keyword as Pstring
					i = range->length;
					if (i >= max) i = max - 1;	// truncate if needed
					dp8[0] = i;
					memcpy(&dp8[1], &inBuf->bytes[range->location], i);
					table[index].propertyEnd = i + 1;
					break;
			}
		}	// < kFilter__3
		else {
			switch(table[index].property) {
				case kFilterTimeOfDay:
					// hh:mm or hh:mm-hh:mm
					dp8[2] = 0xFF;
					dp8[3] = 0;
					dp8[0] = intValue(inBuf, range);
					if (skipByte(inBuf, range, ':')) dp8[1] = intValue(inBuf, range);
					skipByte(inBuf, range, '-');
					dp8[2] = intValue(inBuf, range);
					if (skipByte(inBuf, range, ':')) dp8[3] = intValue(inBuf, range);
					table[index].propertyEnd = 4;
					break;
				case kFilterDayOfWeek:
					// n or n-m
					dp8[1] = 0xFF;
					dp8[0] = intValue(inBuf, range);
					if (skipByte(inBuf, range, '-')) {
						dp8[1] = intValue(inBuf, range);
					}
					table[index].propertyEnd = 2;
					break;
				case kFilterDateAndTime:
				case kFilterIdleSeconds:
				case kFilterParentIdleSeconds:
					dp32[0] = intValue(inBuf, range);
					table[index].propertyEnd = 4;
					break;				
				case kFilterParentMatchCount:
				case kFilterParentMatchRate:
				case kFilterParentByteCount:
					dp64[0] = int64Value(inBuf, range);
					table[index].propertyEnd = 8;
					break;				
			}
		}	// !< kFilter__3
	}	// !< kFilter__2
	return returnValue;
}


#pragma mark - Upload Conversion -


// ---------------------------------------------------------------------------------
//	� filterTable2Text()
// ---------------------------------------------------------------------------------
// build NeXT format property list from filter table and return in supplied PSData
int filterTable2Text(PSData* inBuf, PSData* outBuf)
{
	int returnValue = 0;
	int i;
	// initialize buffer
	outBuf->offset = 0;
	outBuf->length = 0;
	// initialize indent
	kft_indentCount = -1;
/*
	// start of list
	appendCString(outBuf, "\n(");
	// for each table row
	for (i=0; i<inBuf->offset; i++) {
		writeEntryAtIndex(outBuf, &i);
		// list separator
		if (i < inBuf->offset) appendCString(outBuf, ",");
	}
	// end of list
	appendCString(outBuf, "\n)");
*/
	// assume first entry is root dictionary
	i = 0;
	writeEntryAtIndex(inBuf, outBuf, &i);
	// null terminate end of UTF8 string
	outBuf->bytes[outBuf->offset] = 0;
	
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� writeEntryAtIndex()
// ---------------------------------------------------------------------------------
// write out entry as dictionary
int writeEntryAtIndex(PSData* inBuf, PSData* outBuf, int* ioIndex)
{
	KFT_filterEntry_t* table;
	KFT_filterEntry_t* entry;
	int returnValue = 0;
	int count;
	int myIndex;
	
	myIndex = *ioIndex;	// keep a local copy
	*ioIndex += 1;		// increment for next
	
	table = (KFT_filterEntry_t *)inBuf->bytes;
	entry = &table[myIndex];
	kft_indentCount++;
	// start of dictionary
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "{");
	// dictionary elements
		// � children
	// total nodes for this entry
	count = entry->nodeCount;
	if (count > 1) {
		// do list of children
		appendCString(outBuf, "\n");
		appendTabs(outBuf, kft_indentCount);
		appendCString(outBuf, "children = (");
		while (*ioIndex < myIndex+count) {
			// insert list separator before all but first
			if (*ioIndex > myIndex+1) appendCString(outBuf, ",");
			// handle each child recursively
			writeEntryAtIndex(inBuf, outBuf, ioIndex);
		}
		appendCString(outBuf, "\n");
		appendTabs(outBuf, kft_indentCount);
		appendCString(outBuf, ");");
	}
		// � enabled
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "enabled = ");
	appendInt(outBuf, (int)entry->enabled);
	appendCString(outBuf, ";");
		// � filterAction
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "filterAction = ");
	appendInt(outBuf, (int)entry->filterAction);
	appendCString(outBuf, ";");
		// � expandedState
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "expandedState = ");
	appendInt(outBuf, (int)entry->expandedState);
	appendCString(outBuf, ";");
		// � nodeCount
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "nodeCount = ");
	appendInt(outBuf, (int)entry->nodeCount);
	appendCString(outBuf, ";");
		// � nodeNumber
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "nodeNumber = ");
	appendCString(outBuf, "\"");
	appendPString(outBuf, entry->nodeNumber);
	appendCString(outBuf, "\";");
		// � nodeName
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "nodeName = ");
	appendCString(outBuf, "\"");
	appendPString(outBuf, entry->nodeName);
	appendCString(outBuf, "\";");
		// � property
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "property = ");
	appendInt(outBuf, (int)entry->property);
	appendCString(outBuf, ";");
		// � propertyValue
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "propertyValue = ");
	appendCString(outBuf, "\"");
	writePropertyValueAtIndex(inBuf, outBuf, myIndex);
	appendCString(outBuf, "\";");
		// � relation
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "relation = ");
	appendInt(outBuf, (int)entry->relation);
	appendCString(outBuf, ";");
		// � parameter
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "parameter = ");
	appendCString(outBuf, "\"");
	int parameterStart = entry->parameterStart;
	appendPString(outBuf, &entry->propertyValue[parameterStart]);
	appendCString(outBuf, "\";");
		// � matchCount
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "matchCount = ");
	appendInt64(outBuf, (int)entry->match.count);
	appendCString(outBuf, ";");
		// � byteCount
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "byteCount = ");
	appendInt64(outBuf, (int)entry->byte.count);
	appendCString(outBuf, ";");
	
	// end of dictionary
	appendCString(outBuf, "\n");
	appendTabs(outBuf, kft_indentCount);
	appendCString(outBuf, "}");
	// update indent count
	kft_indentCount--;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� writePropertyValueAtIndex()
// ---------------------------------------------------------------------------------
// write property value
// 0 = success
int writePropertyValueAtIndex(PSData* inBuf, PSData* outBuf, int index)
{
	KFT_filterEntry_t* table;
	u_int8_t* dp8;
	u_int16_t* dp16;
	u_int32_t* dp32;
	int64_t* dp64;
	int i;
	int returnValue = 0;
	
	table = (KFT_filterEntry_t *)inBuf->bytes;
	dp8 = &table[index].propertyValue[0];
	dp16 = (u_int16_t*)dp8;
	dp32 = (u_int32_t*)dp8;
	dp64 = (int64_t*)dp8;
	if (table[index].property < kFilter__2) {
		if (table[index].property < kFilter__1) {
			switch(table[index].property) {
				case kFilterAny:
				case kFilterNone:
					// empty string
					break;
				case kFilterDirection:
					if (dp8[0] == kDirectionInbound) appendCString(outBuf, "inbound");
					else if (dp8[0] == kDirectionOutbound) appendCString(outBuf, "outbound");
					break;
				case kFilterInterface:
					// check for internal/external
					if (dp8[0] == 1) {
						if (dp8[1] == kInterfaceInternal) appendCString(outBuf, "internal");
						else if (dp8[1] == kInterfaceExternal) appendCString(outBuf, "external");
						break;
					}
					// write bsdName
					appendPString(outBuf, &dp8[0]);
					break;
				case kFilterInclude:
					if (dp8[0] == kIncludeTrigger) appendCString(outBuf, "trigger");
					else if (dp8[0] == kIncludeAddress) appendCString(outBuf, "address");
					else if (dp8[0] == kIncludeAuthorize) appendCString(outBuf, "authorize");
					else if (dp8[0] == kIncludeInvalid) appendCString(outBuf, "invalid");
					else if (dp8[0] == kIncludeState) appendCString(outBuf, "state");
					break;
				case kFilterSourceMACAddress:
				case kFilterDestMACAddress:
					// output MAC address xx:xx:xx:xx:xx:xx
					appendHexInt(outBuf, (int)dp8[0], 2, kOptionDefault);
					appendCString(outBuf, ":");
					appendHexInt(outBuf, (int)dp8[1], 2, kOptionDefault);
					appendCString(outBuf, ":");
					appendHexInt(outBuf, (int)dp8[2], 2, kOptionDefault);
					appendCString(outBuf, ":");
					appendHexInt(outBuf, (int)dp8[3], 2, kOptionDefault);
					appendCString(outBuf, ":");
					appendHexInt(outBuf, (int)dp8[4], 2, kOptionDefault);
					appendCString(outBuf, ":");
					appendHexInt(outBuf, (int)dp8[5], 2, kOptionDefault);
					break;
			}
		}	// < kFilter__1
		else {
			switch(table[index].property) {
				case kFilterSourceNet:
				case kFilterDestNet: {
					int endOffset = dp32[1];
					if (endOffset == 0) appendIP(outBuf, dp32[0]);
					else {
						int count = 0;
						while (endOffset & 1) {
							count++;
							endOffset >>=1;
						}
						if (endOffset == 0) {
							appendIP(outBuf, dp32[0]);
							appendCString(outBuf, "/");
							appendInt(outBuf, 32-count);
						}
						else {
							appendIP(outBuf, dp32[0]);
							appendCString(outBuf, "-");
							appendIP(outBuf, (dp32[0]+dp32[1]) );
						}
					}
					break;
				}
				case kFilterProtocol:
					appendInt(outBuf, dp8[0]);
					break;		
				case kFilterIPFragmentOffset:
					appendInt(outBuf, dp16[0]);
					if (dp16[1]) {
						appendCString(outBuf, "-");
						appendInt(outBuf, dp16[1]);
					}
					break;		
				case kFilterIPOptions:
					// saved as null terminated list of integers
					i = 0;
					while (dp8[i]) {
						if (appendInt(outBuf, dp8[i++]) < 0) break;
						if (dp8[i]) appendCString(outBuf, ",");
					}
					break;		
				case kFilterICMPType:
				case kFilterICMPCode:
					appendInt(outBuf, dp8[0]);
					break;
			}
		}
	}	// < kFilter__2
	else {
		if (table[index].property < kFilter__3) {
			switch(table[index].property) {
				case kFilterTCPHeaderFlags:
					// saved as 8-bit ON mask and OFF mask
					tcpHeaderFlagString(outBuf, dp8[0], dp8[1]);
					break;
				case kFilterTCPOptions:
					// saved as null terminated list of integers
					i = 0;
					while (dp8[i]) {
						if (appendInt(outBuf, dp8[i++]) < 0) break;
						if (dp8[i]) appendCString(outBuf, ",");
					}
					break;		
				case kFilterSourcePort:
				case kFilterDestPort:
					appendInt(outBuf, dp16[0]);
					if (dp16[1]) {
						appendCString(outBuf, "-");
						appendInt(outBuf, dp16[1]);
					}
					break;
				case kFilterDataContent:
				{
					KFT_contentSpec_t* content;
					content = (KFT_contentSpec_t *)dp8;
					// 16-bit search offset, 16-bit search length, 8-bit search delimiter, 8-bit flags, pstring to match
					if ((content->searchOffset != 0) ||
						(content->searchLength != kContent_searchLength) ||
						(content->searchDelimiter != 0)) {
						appendCString(outBuf, "[");
						if (content->flags & kContentFlag_relativePlus) appendCString(outBuf, "+");
						else if (content->flags & kContentFlag_relativeMinus) appendCString(outBuf, "-");
						appendInt(outBuf, content->searchOffset);
						appendCString(outBuf, ":");
						appendInt(outBuf, content->searchLength);
						if (content->flags & kContentFlag_useDelimiter) {
							appendCString(outBuf, ":");
							appendInt(outBuf, content->searchDelimiter);					
						}
						appendCString(outBuf, "]");
					}
					//returnValue = appendPString(outBuf, &content->length);
					// reset pointer since table was copied from NKE
					content->dataPtr = &content->data[0];
					returnValue = encodeContent(outBuf, content);
					break;
				}
				case kFilterURLKeyword:
					// saved URL keyword as Pstring
					returnValue = appendPString(outBuf, &dp8[0]);
					break;
			}
		}	// < kFilter__3
		else {
			switch(table[index].property) {
				case kFilterTimeOfDay:
					// hh:mm or hh:mm-hh:mm  (FF for not a range)
					appendInt(outBuf, dp8[0]);
					appendCString(outBuf, ":");
					appendInt(outBuf, dp8[1]);
					if (dp8[2] <= 24) {
						appendCString(outBuf, "-");
						appendInt(outBuf, dp8[2]);
						appendCString(outBuf, ":");
						appendInt(outBuf, dp8[3]);
					}
					break;
				case kFilterDayOfWeek:
					// n or n-m  (FF for not a range)
					appendInt(outBuf, dp8[0]);
					if (dp8[1] <= 7) {
						appendCString(outBuf, "-");
						appendInt(outBuf, dp8[1]);
					}
					break;
				case kFilterDateAndTime:
				case kFilterIdleSeconds:
				case kFilterParentIdleSeconds:
					appendInt(outBuf, dp32[0]);
					break;
				case kFilterParentMatchCount:
				case kFilterParentMatchRate:
				case kFilterParentByteCount:
					appendInt64(outBuf, dp64[0]);
					break;
			}
		}	// !< kFilter__3
	}	// !< kFilter__2
	return returnValue;
}
