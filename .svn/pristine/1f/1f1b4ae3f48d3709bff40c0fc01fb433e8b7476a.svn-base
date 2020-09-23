//
//  DHCPAction.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Wed Nov 12 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//

#import "DHCPAction.h"
#import "DHCPState.h"
#import "DHCPServer.h"
#import "DHCPSupport.h"
#import "InterfaceTable.h"
#import "SystemConfiguration.h"
#import "IPNetMessage.h"
#import "IPUDPSocket.h"
#import "UDPServer.h"
#import "IPICMPSocket.h"
#import "ICMPController.h"
#import "ping.h"
#import <net/if.h>
#import <net/if_dl.h>
#import "IPValue.h"
#import "DHCPTypes.h"
#import "IPTypes.h"
#import "IPSupport.h"
#import "IPKSupport.h"
#import "DHCPSupport.h"
//#import "IPNetRouter_NKE.h"
//#import "kft.h"
#import "HardwareAddress.h"
#import "NSDate_Extensions.h"
#import "arp.h"
#import "ArpOutput.h"
#import "BPFTransmit.h"

#define kTimerInterval 10.0

// Private Methods
@interface DHCPAction (PrivateMethods)
// logistics
- (BOOL)updateParameterD:(NSString *)name withObject:(id)object;
- (void)sendParameterUpdates;
- (BOOL)startReceiving:(NSString *)socketName;
- (void)stopReceiving;
- (void)ntohDHCPMessage:(DHCPMessage_t*)msg;
- (void)htonDHCPMessage:(DHCPMessage_t*)msg;
- (void)htonDHCPOptions:(DHCPMessage_t*)msg size:(u_int16_t)inSize;
// Receive Network Data
- (void)receiveUDP:(IPNetMessage *)inMessage;
- (void)processRequest:(dhcp_request_t *)inRequest;
- (BOOL)updateLeaseBindingState:(u_int8_t)leaseState forRequest:(dhcp_request_t *)inRequest;
// Network Response
- (BOOL)buildResponse:(dhcp_response_t *)outResponse type:(u_int8_t)responseType forRequest:(dhcp_request_t *)inRequest;
- (void)putOptionToBuffer:(u_int8_t *)buffer offset:(u_int16_t *)ioOffset
	optionCode:(u_int8_t)optionCode optionLen:(u_int8_t)optionLen optionData:(u_int8_t *)optionData;
- (BOOL)putAddressListToBuffer:(u_int8_t *)buffer offset:(u_int16_t *)ioOffset
	optionCode:(u_int8_t)optionCode inList:(NSString *)inList;
- (BOOL)putAddressListToBufferN:(u_int8_t *)buffer offset:(u_int16_t *)ioOffset
	optionCode:(u_int8_t)optionCode inList:(NSString *)inList;
- (void)sendQResponse:(dhcp_response_t *)inResponse;
- (int)sendResponse:(dhcp_response_t *)inResponse;
- (int)sendPing:(u_int32_t)inPingAddress;
- (void)receiveICMP:(IPNetMessage *)inMessage;
// find info
- (BOOL)checkServerID:(u_int32_t)inServerID;
- (void)findDHCPOptionsForRequest:(dhcp_request_t *)inRequest start:(u_int32_t)start end:(u_int32_t)end;
- (DHCPStatusEntry *)findStatusForRequest:(dhcp_request_t *)inRequest;
- (DHCPStatusEntry *)findStatusForAddress:(u_int32_t)inLeaseAddr;
- (DHCPLeaseOptionsEntry *)findLeaseOptionsForRequest:(dhcp_request_t *)inRequest;
- (DHCPLeaseOptionsEntry *)findLeaseOptionsForAddress:(u_int32_t)inAddress;
- (DHCPStaticConfigEntry *)findStaticConfigForAddress:(u_int32_t)inAddress;
- (DHCPDynamicConfigEntry *)findDynamicConfigForAddress:(u_int32_t)inAddress;
- (BOOL)findLeaseAddressForRequest:(dhcp_request_t *)inRequest;
- (BOOL)findLeaseTimeForRequest:(dhcp_request_t *)inRequest;
- (u_int8_t)findRespondViaForResponse:(dhcp_response_t *)inResponse;
- (NSString *)substituteNameServers:(NSString *)inString  forRequest:(dhcp_request_t *)inRequest;
// DHCP Logging
- (void)logDHCPRequest:(dhcp_request_t *)inRequest;
- (void)logDHCPResponse:(dhcp_response_t *)inResponse;
- (void)logDHCPMessage:(DHCPMessage_t*)inMessage size:(u_int16_t)inSize;
- (int)logDHCPOptions:(DHCPMessage_t *)inMessage start:(u_int32_t)start end:(u_int32_t)end;
- (int)logDHCPOption:(u_int8_t)option length:(u_int8_t)len data:(u_int8_t *)data;
- (NSString *)stringForMessageType:(u_int8_t)inType;
@end


@implementation DHCPAction
// ---------------------------------------------------------------------------------
//	• sharedInstance
// ---------------------------------------------------------------------------------
+ (DHCPAction *) sharedInstance {
	static id sharedTask = nil;	
	if(sharedTask==nil) {
		sharedTask = [[DHCPAction alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		eventTimer = nil;
		messageQ = nil;
		mDataFlag = NO;
		
		mClient = nil;
		mServerSockfd = 0;
		mUDPSendSocket = nil;
		mBPFSenders = nil;
		mAbortFD = 0;
		delegate = nil;
		mResponseArray = [[NSMutableArray alloc] init];
		messageTypes = nil;
		// log message buffer
		mLogMessage = [NSMutableString stringWithCapacity:1024];
		[mLogMessage retain];
		// parameter updates buffer
		mParameterUpdates = [[NSMutableDictionary alloc] init];
		// network send buffer
        mSendBuf = [NSMutableData dataWithCapacity:2048];
        [mSendBuf retain];
		// DHCP state tables
		dhcpState = [[DHCPState alloc] initWithDefaults];
		[dhcpState setRecordChanges:NO];	// changes to active state are not doc changes
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
    // release any objects we allocated
	[eventTimer invalidate];   eventTimer = nil;
	[messageQ release]; messageQ = nil;

	[mClient setCallbackTarget:nil];
	[mClient release];			mClient = nil;
	mAbortFD = 0;
	[mUDPSendSocket release];		mUDPSendSocket = nil;
	[mBPFSenders release];		mBPFSenders = nil;
	[mResponseArray release];   mResponseArray = nil;
	[messageTypes release];		messageTypes = nil;
	[mLogMessage release];		mLogMessage = nil;
	[mParameterUpdates release]; mParameterUpdates = nil;
	[mSendBuf release];			mSendBuf = nil;
	[self setDelegate:nil];
	[dhcpState release];		dhcpState = nil;
    [super dealloc];
}

// accessors
- (DHCPState *)dhcpState { return dhcpState; }
- (void)setDhcpState:(DHCPState *)value {
	[value retain];
	[dhcpState release];
	dhcpState = value;
}
 
- (id)delegate { return delegate; }
- (void)setDelegate:(DHCPServer *)value {
	//[value retain];   // don't retain to avoid retain loop
	//[delegate release];
	delegate = value;
	// set delegate for DHCP state changes
	[dhcpState setDelegate:delegate];
}

// ---------------------------------------------------------------------------------
//	• startServing
// ---------------------------------------------------------------------------------
- (int) startServing {
	int value;
	int result = 0;
	do {
		// don't allow multiples
		if (([[dhcpState dhcpServerOn] intValue] == 0) || !mServerSockfd) {
			// Read saved DHCP Server status.
			[self readStatusTable];
			// get host DNS info from SCF if nothing was saved
			if (![dhcpState hostDNS]) {			
				NSString* serviceID;
				NSArray* serverList;
				NSString* value;
				// try first active interface or NAT interface to lookup corresponding Name Server
				serviceID = [[[InterfaceTable sharedInstance] entryForNat] serviceID];
				serverList = [[SystemConfiguration sharedInstance]
					service:serviceID dataForDictionaryName:@"DNS" key:@"ServerAddresses"];
				if (serverList) {
					value = [serverList componentsJoinedByString:@", "];
					// set corresponding state
					[dhcpState setHostDNS:value];
					break;
				}
				// use router address instead
				value = [[SystemConfiguration sharedInstance]
					service:serviceID dataForDictionaryName:@"IPv4" key:@"Router"];
				if (value) {
					// set corresponding state
					[dhcpState setHostDNS:value];
					break;
				}		
			}			
			// request NS info from client
			[delegate updateParameter:DS_updateHostDNS withObject:DS_updateHostDNS];
			// Make sure DHCP tables are loaded and initialized
			mLoopCount = 0;
			
			if (!mServerSockfd) {
				// create a DHCP Server socket to send and receive DHCP messages
				mServerSockfd = OpenRawSocket([NSArray arrayWithObject:@"-dhcpServer"]);
				// configure socket options for DHCP
				value = 1;
				result = setsockopt(mServerSockfd, SOL_SOCKET, SO_BROADCAST, &value, sizeof(int));
				if (result < 0) {
					result = errno;
					NSLog(@"%s", strerror(result));
					[mLogMessage appendFormat:@"%s", strerror(result)];
					break;
				}
				result = setsockopt(mServerSockfd, SOL_SOCKET, SO_NOSIGPIPE, &value, sizeof(int));
				if (result < 0) {
					result = errno;
					NSLog(@"%s", strerror(result));
					[mLogMessage appendFormat:@"%s", strerror(result)];
					break;
				}
				result = setsockopt(mServerSockfd, IPPROTO_IP, IP_RECVDSTADDR, &value, sizeof(int));
				if (result < 0) {
					result = errno;
					NSLog(@"%s", strerror(result));
					[mLogMessage appendFormat:@"%s", strerror(result)];
					break;
				}
				result = setsockopt(mServerSockfd, IPPROTO_IP, IP_RECVIF, &value, sizeof(int));
				if (result < 0) {
					result = errno;
					NSLog(@"%s", strerror(result));
					[mLogMessage appendFormat:@"%s", strerror(result)];
					break;
				}
			}
			// create a UDP receive thread
			[self startReceiving:[NSString stringWithFormat:@"%d",mServerSockfd]];
			// create UDP socket object for sending
			if (!mUDPSendSocket) mUDPSendSocket = [[IPUDPSocket alloc] initWithSocket:mServerSockfd];
			// create a dictionary to hold an BPF senders we need
			if (!mBPFSenders) mBPFSenders = [[NSMutableDictionary dictionaryWithCapacity:4] retain];
			
			// message Queue
			if (!messageQ) messageQ = [[NSMutableArray alloc] init];
			// register with ICMPController to receive ping responses
			// (use ICMPController for sending as well)
			[[ICMPController sharedInstance] addObserver:self
				withSelector:@selector(messageNotification:)];
			[[ICMPController sharedInstance] startReceiving];
			// Begin checking for DHCP events (base rate is every 10 seconds)
			eventTimer = [NSTimer scheduledTimerWithTimeInterval:kTimerInterval
				target:self
				selector:@selector(eventTimer:)
				userInfo:nil
				repeats:YES];					
			{   // record server is on
				NSNumber* num = [NSNumber numberWithInt:1];
				[dhcpState setDhcpServerOn:num];
				[delegate updateParameter:@"dhcpServerOn" withObject:num];
			}
			NSString* dateString = [[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"
				timeZone:nil locale:nil];	
			[mLogMessage appendFormat:@"\n%@ DHCP Server has started", dateString];
			// indicate logging level
			switch ([[dhcpState verboseLogging] intValue]) {
				case kDHCP_exceptionLogging:
					[mLogMessage appendString:@"\nBegin DHCP exception logging"];
					break;
				case kDHCP_summaryLogging:
					[mLogMessage appendString:@"\nBegin DHCP summary logging"];
					break;
				case kDHCP_verboseLogging:
					[mLogMessage appendString:@"\nBegin DHCP verbose logging"];
					break;
			}
			result = 0;
		}
		else {
			NSString* dateString = [[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"
				timeZone:nil locale:nil];	
			[mLogMessage appendFormat:@"\n%@ DHCP Server previously started", dateString];
		}
		[self sendParameterUpdates];
	} while (NO);
	return result;
}

// ---------------------------------------------------------------------------------
//	• stopServing
// ---------------------------------------------------------------------------------
- (int)stopServing {
	if ([[dhcpState dhcpServerOn] intValue]) {
		{   // record server is off so we don't try to restart any threads
			NSNumber* num = [NSNumber numberWithInt:0];
			[dhcpState setDhcpServerOn:num];
			[delegate updateParameter:@"dhcpServerOn" withObject:num];
		}
		// make sure receive socket is closed
		[self stopReceiving];
		// no longer want to receive ICMP
		[[ICMPController sharedInstance] removeObserver:self];
		// save DHCP Server status
		[self writeStatusTable];
		// no longer want to receive DHCP messages
		[mClient didUserAbort];	// reset last abort time
		[mClient abortWithTimeout:1.0];
		if (mAbortFD) {
			write(mAbortFD, "wakeup", 6);	// wakeup any select
			mAbortFD = 0;
			[NSThread  sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.4]];
		}
		// no longer checking for DHCP events
		[eventTimer invalidate];   eventTimer = nil;
		[messageQ release]; messageQ = nil;
		// release other objects we setup
		[mUDPSendSocket release];		mUDPSendSocket = nil;
		[mBPFSenders release];			mBPFSenders = nil;
		[mResponseArray removeAllObjects];
		// send any updates we've collected
		[self sendParameterUpdates];
	}
	return 0;
}

#pragma mark --- Logistics ---
// ---------------------------------------------------------------------------
//	• eventTimer:
// ---------------------------------------------------------------------------
// check DHCP state at regular intervals
- (void)eventTimer:(id)timer
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSDate*				currentTime;
	NSTimeInterval		currentTimeInterval;
	NSDate*				eventTime;
	NSDate*				nextTime = nil;
	NSEnumerator*		en;
	NSData*				responseEntry;
	dhcp_response_t*	dhcpResponse;
	DHCPStatusEntry*	statusEntry;
	IPNetMessage*		message = nil;
	int count;

	@try {
		// process received data (if any)
		do {
			@synchronized(messageQ) {
				// eventTimer entered, clear data flag so we'll be rescheduled if more data arrives
				mDataFlag = NO;
				count = [messageQ count];
				if (count) {
					message = [[messageQ objectAtIndex:0] retain];
					[messageQ removeObjectAtIndex:0];
					count -= 1;
				}
			}
			if (message) {
				[self receiveICMP:message];
				[message release]; message = nil;
			}
		} while (count);

		currentTimeInterval = [NSDate psInterval];
		currentTime = [NSDate dateWithTimeIntervalSince1970:currentTimeInterval];
		nextTime = [NSDate dateWithTimeIntervalSince1970:currentTimeInterval + kTimerInterval];
		// check response array
		en = [mResponseArray objectEnumerator];
		while (responseEntry = [en nextObject]) {
			dhcpResponse = (dhcp_response_t *)[responseEntry bytes];	
			// found a response entry from array
			if (dhcpResponse->responseState == kRSPing) {
				// response is waiting for ping
				// if waited 200ms, indicate timed out  (use 0.18 to undershoot our interval slightly)
				if ( (currentTimeInterval - dhcpResponse->timeStamp) >= 0.18 ) {
					dhcpResponse->responseState = kRSReady;
					if ([[dhcpState verboseLogging] intValue] >= kDHCP_verboseLogging) {
						[mLogMessage appendFormat:@"\rNo response to ping on: %@",stringForIP(dhcpResponse->yiaddr)];
					}
				}
				else {
					eventTime = [NSDate dateWithTimeIntervalSince1970:dhcpResponse->timeStamp+0.20];
					nextTime = [nextTime earlierDate:eventTime];
				}
			}
			// if response is ready, try to send it
			if (dhcpResponse->responseState == kRSReady) {
				if ([self sendResponse:dhcpResponse] > 0) {
					// response was sent, remove from array
					[mResponseArray removeObject:responseEntry];
				}
				// allow SendThread to run before trying next in array
			}
		}
		// check status array
		en = [[[dhcpState statusTable] tableArray] objectEnumerator];
		while (statusEntry = [en nextObject]) {
			// found a lease record
			switch ([[statusEntry leaseState] intValue]) {
			case kLeaseOffered:
				if ([currentTime timeIntervalSinceDate:[statusEntry lastUpdate]] > kLeaseOfferPeriod) {
					// offer has expired
					[statusEntry setLeaseState:[NSNumber numberWithInt:kLeaseExpired]];
					[statusEntry setLastUpdate:currentTime];
					// update display
					[statusEntry setAction:[NSNumber numberWithInt:kActionUpdate]];
					[self updateParameterD:[statusEntry key] withObject:statusEntry];
				}
				else {
					nextTime = [nextTime earlierDate:[[statusEntry lastUpdate] addTimeInterval:kLeaseOfferPeriod]];
				}
				break;
			case kLeaseBound:
			case kLeaseBootp:
				if ([currentTime timeIntervalSinceDate:[statusEntry expireTime]] > kLeaseGracePeriod) {
					// lease has expired
					[statusEntry setLeaseState:[NSNumber numberWithInt:kLeaseExpired]];
					[statusEntry setLastUpdate:currentTime];
					// update display
					[statusEntry setAction:[NSNumber numberWithInt:kActionUpdate]];
					[self updateParameterD:[statusEntry key] withObject:statusEntry];
				}
				else {
					nextTime = [nextTime earlierDate:[[statusEntry expireTime] addTimeInterval:kLeaseGracePeriod]];
				}
				break;
			case kLeaseInUse:
			case kLeaseDeclined:
				if ([currentTime timeIntervalSinceDate:[statusEntry lastUpdate]] > kLeaseReclaimPeriod) {
					// block has expired
					[statusEntry setLeaseState:[NSNumber numberWithInt:kLeaseExpired]];
					[statusEntry setLastUpdate:currentTime];
					// update display
					[statusEntry setAction:[NSNumber numberWithInt:kActionUpdate]];
					[self updateParameterD:[statusEntry key] withObject:statusEntry];
				}
				else {
					nextTime = [nextTime earlierDate:[[statusEntry lastUpdate] addTimeInterval:kLeaseReclaimPeriod]];
				}
				break;
			}
		}	// end for each lease record

		// reschedule eventTimer
		currentTime = [NSDate psDate];	// update for processing time
		if ([nextTime timeIntervalSinceDate:currentTime] < 0.10)	// half of ping interval
			nextTime = [currentTime addTimeInterval:0.10];	
		@synchronized(messageQ) {
			// if not already scheduled for pending data
			if (!mDataFlag) [eventTimer setFireDate:nextTime];
		}

		#if 0
			// break ourselves to test resume feature
			mLoopCount++;
			if (mLoopCount > 5) {
				// no longer checking for DHCP events
				[eventTimer invalidate];   eventTimer = nil;
				NSLog(@"Event timer loop has stopped");
			}
		#endif

		// log completed message if any and refresh display
		[self sendParameterUpdates];
		// commit status table updates to non-volatile storage
		[self writeStatusTable];
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSLog(@"DHCP Server exception during eventTimer");
	}
	[pool release];
}

// ===========================================================================
// Read and write status table (commit to non-volatile storage)
// ===========================================================================
// ---------------------------------------------------------------------------
//	• readStatusTable
// ---------------------------------------------------------------------------
- (BOOL)readStatusTable
{
	BOOL returnValue = NO;
	NSString* path;
	NSString* cpath;
    NSFileManager* fm;
    BOOL flag = YES;
	NSMutableDictionary* dataDictionary;
	NSDictionary* cd;
	NSArray* clusters;
	NSEnumerator* en;
	NSString* fileName;
	
	// get file destination
		// dhcpStatusTable in /Library/Application Support/Sustainable Softworks/
	path = @"/Library/Application Support/Sustainable Softworks";
	fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:path isDirectory:&flag]) {
		flag = [fm createDirectoryAtPath:path attributes:nil];
	}
		// create subdirectory to collect status clusters
	cpath = @"/Library/Application Support/Sustainable Softworks/dhcpStatus";
	if (![fm fileExistsAtPath:cpath isDirectory:&flag]) {
		flag = [fm createDirectoryAtPath:cpath attributes:nil];
	}		
	clusters = [fm directoryContentsAtPath:cpath];
	en = [clusters objectEnumerator];

	@try {
		// build dictionary from saved file
		path = @"/Library/Application Support/Sustainable Softworks/dhcpStatusTable";
		dataDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:path];
		// initialize dictionary to hold clusters info if needed
		if (!dataDictionary) dataDictionary = [NSMutableDictionary dictionary];
		// update with any clusters
		while (fileName = [en nextObject]) {
			path = [cpath stringByAppendingPathComponent:fileName];
			cd = [NSDictionary dictionaryWithContentsOfFile:path];
			if (cd) [dataDictionary addEntriesFromDictionary:cd];
		}
		returnValue = [[dhcpState statusTable] loadDictionaryOfDictionaries:dataDictionary forEntryClass:[DHCPStatusEntry class]];
		// update display to reflect what we read in
		[delegate updateParameter:DS_statusTableArray
			withObject:[[dhcpState statusTable] tableArray]];
		//NSLog(@"Reading DHCP Status Table from: %@",cpath);
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSLog(@"Exception while reading DHCP status table");
		[mLogMessage appendString:@"\rException while reading DHCP status table"];
		// log completed message
		[self sendParameterUpdates];
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• writeStatusTable
// ---------------------------------------------------------------------------
- (BOOL)writeStatusTable
{
	BOOL returnValue = NO;
	NSString* path;
    NSFileManager* fm;
    BOOL flag = YES;
	NSArray* tableArray;
	NSEnumerator* en;
	DHCPStatusEntry* statusEntry;
	
	// get file destination
	fm = [NSFileManager defaultManager];
		// dhcpStatusTable in /Library/Application Support/Sustainable Softworks/
	path = @"/Library/Application Support/Sustainable Softworks";
	if (![fm fileExistsAtPath:path isDirectory:&flag]) {
		flag = [fm createDirectoryAtPath:path attributes:nil];
	}		

	// walk status table to write out any pending updates
	tableArray = [[dhcpState statusTable] tableArray];
	en = [tableArray objectEnumerator];
	while (statusEntry = [en nextObject]) {
		if ([statusEntry action]) [self writeStatusEntry:[statusEntry keyInt]];
	}

	// remove old style dhcpStatusTable
	path = @"/Library/Application Support/Sustainable Softworks/dhcpStatusTable";
	if ([fm fileExistsAtPath:path]) [fm removeFileAtPath:path handler:nil];

	return returnValue;
}

// ---------------------------------------------------------------------------
//	• writeStatusEntry
// ---------------------------------------------------------------------------
- (BOOL)writeStatusEntry:(u_int32_t)leaseAddress
{
	BOOL returnValue = NO;
	NSString* path;
    NSFileManager* fm;
    BOOL flag = YES;
	NSMutableDictionary* cd;
	
	DHCPStatusTable* table;
	DHCPStatusEntry* entry;
	NSString* fileName;
	u_int32_t baseAddress;
	int i;
	
	// get file destination
	fm = [NSFileManager defaultManager];
		// dhcpStatusTable in /Library/Application Support/Sustainable Softworks/
	path = @"/Library/Application Support/Sustainable Softworks";
	if (![fm fileExistsAtPath:path isDirectory:&flag]) {
		flag = [fm createDirectoryAtPath:path attributes:nil];
	}
		// create subdirectory to collect status info
	path = @"/Library/Application Support/Sustainable Softworks/dhcpStatus";
	if (![fm fileExistsAtPath:path isDirectory:&flag]) {
		flag = [fm createDirectoryAtPath:path attributes:nil];
	}		
	baseAddress = leaseAddress & 0xFFFFFFF0;
	fileName = stringForIP(baseAddress);
		// convert "." to "-" for use in filename
		NSArray* array = [fileName componentsSeparatedByString:@"."];
		fileName = [array componentsJoinedByString:@"-"];
	path = [path stringByAppendingPathComponent:fileName];
	path = [path stringByAppendingPathExtension:@"plist"];

	// convert table cluster to dictionary of dictionaries
	table = [dhcpState statusTable];
	cd = [NSMutableDictionary dictionaryWithCapacity:16];
	u_int32_t address;
	for (i=0; i<16; i++) {
		address = baseAddress + i;
		entry = [self findStatusForAddress:address];
		if (entry) {
			if ([[entry action] intValue] == kActionDelete) {
				[table removeObjectForKey:[entry key]];
			}
			else {
				[cd setObject:[entry nodeDictionary] forKey:[entry key]];
				// note entry has been processed
				[entry setAction:nil];
			}
		}
	}
	if ([cd count]) {
		// save cluster dictionary to disk
		returnValue = [cd writeToFile:path atomically:YES];
	}
	else {
		returnValue = [fm removeFileAtPath:path handler:nil];
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• updateParameterD:withObject:
// ---------------------------------------------------------------------------
// collect parameter updates
- (BOOL)updateParameterD:(NSString *)name withObject:(id)object
{
	BOOL returnValue = NO;
	if (name && object) {
		[mParameterUpdates setObject:object forKey:name];
		returnValue = YES;
	}
	return returnValue;
}
// ---------------------------------------------------------------------------
//	• sendParameterUpdates
// ---------------------------------------------------------------------------
// send any updates we've collected
- (void)sendParameterUpdates
{
	// log completed message if any
	if ([mLogMessage length]) {
		[delegate updateParameter:DHCPLoggerNotification withObject:mLogMessage];
		[mLogMessage setString:@""];
	}
	if ([mParameterUpdates count]) {
		[delegate  updateParameterD:mParameterUpdates];
		[mParameterUpdates removeAllObjects];
		[delegate updateParameter:nil withObject:nil];
	}
}

// ---------------------------------------------------------------------------
//	• startReceiving
// ---------------------------------------------------------------------------
// Receive UDP Thread controller
- (BOOL)startReceiving:(NSString *)socketName {
    BOOL returnValue = NO;

	if (!mClient) {
		mClient = [[PsClient alloc] init];
		[mClient setCallbackTarget:self];
		[mClient setServerClass:[UDPServer class]];
	}
	if (![mClient isConnected]) [mClient createNewServer:[UDPServer class]];
	if ([mClient isConnected]) {
		// launch service
		[mClient startService:[NSString stringWithFormat:@"udp://%@",socketName] withObject:nil];
		returnValue = YES;
	}
	else [delegate updateParameter:@"statusInfo" withObject:@"Failure creating UDP server"];

	return returnValue;
}
// ---------------------------------------------------------------------------
//	• stopReceiving
// ---------------------------------------------------------------------------
// UDPServer has finished, used for DHCP receive has stopped or been killed
- (void)stopReceiving {
	if (mServerSockfd) {
		close(mServerSockfd);		// close socket we opened
		mServerSockfd = nil;

		NSString* dateString = [[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"
			timeZone:nil locale:nil];	
		[mLogMessage appendFormat:@"\n%@ DHCP Server stopping", dateString];
		[self sendParameterUpdates];
	}
}

// ---------------------------------------------------------------------------------
//	• receiveDictionary:
// ---------------------------------------------------------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// receive dictionary from server threads
{
	NSEnumerator* enumerator;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    id key;
	id object;

	if ([[dictionary objectForKey:PSAction] isEqualToString:PSServerFinishedNotification]) {
		if ([[dhcpState dhcpServerOn] intValue]) {
			// thread has exited due to an error, try to restart it
			mAbortFD = 0;		// don't try to abort since thread has already stopped
			[self stopServing];
			[self startServing];
		}
	}
	
	else if ([[dictionary objectForKey:PSAction] isEqualToString:PSReportErrorNotification]) {
		NSString* text;
		int code;
		text = [dictionary objectForKey:@"text"];
		code = [[dictionary objectForKey:@"code"] intValue];
		//[self updateParameterD:@"statusInfo" withObject:text];
		[mLogMessage appendFormat:@"\n%@",text];
	}
	else if (object = [dictionary objectForKey:PSAbortFD]) {
		mAbortFD = [(NSString *)object intValue];
	}
		
	else {
		enumerator = [dictionary keyEnumerator];
		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			if ([key isEqualToString:UDPMessageNotification]) {
				IPNetMessage* message;
				// dispatch message
				message = [dictionary objectForKey:key];
				[self receiveUDP:message];
			}	// if ([key isEqualToString:UDPMessageNotification])
			else {
				// just pass it on
				[self updateParameterD:key withObject:[dictionary objectForKey:key]];
				[self sendParameterUpdates];
			}
		}	// while ((key = [enumerator nextObject]))
	}
	[pool release];
}

// ---------------------------------------------------------------------------------
//	• messageNotification:
// ---------------------------------------------------------------------------------
- (void)messageNotification:(NSNotification *)aNotification {
	@try {
		[[self retain] autorelease];	// defensive, don't die while handling notification
		// receive ICMP message notification
		IPNetMessage* message;
		if (message = [[aNotification userInfo] objectForKey:ICMPMessageNotification]) {
			// add message to inputQ;
			@synchronized(messageQ) {
				[messageQ addObject:message];
				// if no previous data since evenTimer last entered
				if (!mDataFlag) {
					// schedule timer to process it
					[eventTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
					mDataFlag = YES;
				}
			}
		}
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSLog(@"DHCP Server exception during messageNotification");
	}
}
#pragma mark -- byte swap --
// ---------------------------------------------------------------------------------
//	• ntohDHCPMessage:
// ---------------------------------------------------------------------------------
- (void)ntohDHCPMessage:(DHCPMessage_t*)msg
{
	NTOHL(msg->xid);
	NTOHS(msg->secs);
	NTOHS(msg->flags);
	NTOHL(msg->ciaddr);
	NTOHL(msg->yiaddr);
	NTOHL(msg->siaddr);
	NTOHL(msg->giaddr);
}

// ---------------------------------------------------------------------------------
//	• htonDHCPMessage:
// ---------------------------------------------------------------------------------
- (void)htonDHCPMessage:(DHCPMessage_t*)msg
{
	HTONL(msg->xid);
	HTONS(msg->secs);
	HTONS(msg->flags);
	HTONL(msg->ciaddr);
	HTONL(msg->yiaddr);
	HTONL(msg->siaddr);
	HTONL(msg->giaddr);
}

// ---------------------------------------------------------------------------------
//	• htonDHCPOptions:
// ---------------------------------------------------------------------------------
- (void)htonDHCPOptions:(DHCPMessage_t*)msg size:(u_int16_t)inSize
{
	// get options
	u_int32_t	start, end;
	u_int8_t*	dp;
	start = 28 + 16 + 64 + 128;
	// check for magic cookie
	dp = (u_int8_t*)msg;
	if (*((u_int32_t*)&msg->options) == htonl(0x63825363)) {
		start += 4;
	}
	end = inSize;
	// Find options in message
	{
		u_int8_t	option;
		u_int8_t	len;
		u_int8_t	count, i;
		option = kOptionPad;

		while ((option != kOptionEnd) && (start < end)) {
			option = dp[start++];
			switch (option) {
				case kOptionPad:
					break;
				case kOptionEnd:
					break;
				case kOptionSubnetMask:
					len = dp[start++];
					HTONL(*(u_int32_t*)&dp[start]);
					start += len;
					break;
				case kOptionRouters:	// output only
					len = dp[start++];
					count = len/4;
					for (i=0; i<count; i++) {
						HTONL(*(u_int32_t*)&dp[start+(4*i)]);
					}
					start += len;
					break;
				case kOptionDomainServer:	// output only
					len = dp[start++];
					count = len/4;
					for (i=0; i<count; i++) {
						HTONL(*(u_int32_t*)&dp[start+(4*i)]);
					}
					start += len;
					break;
				case kOptionHostName:
					len = dp[start++];				
					start += len;
					break;
				case kOptionDomainName:
					len = dp[start++];				
					start += len;
					break;
				case kOptionAddressRequest:
					len = dp[start++];				
					HTONL(*(u_int32_t*)&dp[start]);
					start += len;
					break;
				case kOptionAddressTime:
					len = dp[start++];
					HTONL(*(u_int32_t*)&dp[start]);
					start += len;
					break;
				case kOptionOverload:
					len = dp[start++];
					start += len;
					break;
				case kOptionDHCPMessageType:
					len = dp[start++];
					start += len;
					break;
				case kOptionDHCPServerID:
					len = dp[start++];
					HTONL(*(u_int32_t*)&dp[start]);
					start += len;
					break;
				case kOptionParameterList:
					len = dp[start++];
					start += len;
					break;
				case kOptionDHCPMessage:
					len = dp[start++];				
					start += len;
					break;
				case kOptionDHCPMaxMsgSize:
					len = dp[start++];
					HTONS(*(u_int16_t*)&dp[start]);
					start += len;
					break;
				case kOptionRenewalTime:
					len = dp[start++];
					HTONL(*(u_int32_t*)&dp[start]);
					start += len;
					break;
				case kOptionRebindingTime:
					len = dp[start++];
					HTONL(*(u_int32_t*)&dp[start]);
					start += len;
					break;
				case kOptionClassID:
					len = dp[start++];
					start += len;
					break;
				case kOptionClientID:
					len = dp[start++];
					start += len;
					break;
				default:
					// Ignore unknown options since server doesn't re-examine them.
					// Just assume they are already in network byte order.
					len = dp[start++];
					start += len;
					break;
			}
		}
	}
}

#pragma mark --- Receive Network Data ---

// ---------------------------------------------------------------------------------
//	• receiveUDP:
// ---------------------------------------------------------------------------------
// extract basic network info and then process DHCP request
- (void)receiveUDP:(IPNetMessage *)inMessage
{
	dhcp_request_t  dhcpRequest;
	IPHost*			inRemoteAddress;

	// initialize dhcpRequest structure
	bzero(&dhcpRequest, sizeof(dhcp_request_t));

	// setup access to message data and addresses
	dhcpRequest.data = (u_int8_t*)[[inMessage data] bytes];
	dhcpRequest.size = [[inMessage data] length];
	dhcpRequest.offset = 0;
	// remote address
	inRemoteAddress = [inMessage fromHost];
	dhcpRequest.remoteAddr = [inRemoteAddress v4Address];
	dhcpRequest.remotePort = [inRemoteAddress port];
	// Get local interface and destination (IP_RECVIF, IP_RECVDSTADDR)
	do {
		u_int8_t* dp;
		int length;
		int offset = 0;
		struct cmsghdr *cmptr;
		
		dp = (u_int8_t*)[[inMessage control] bytes];
		length = [[inMessage control] length];
		while ( offset < length - sizeof(struct cmsghdr) ) {
			cmptr = (struct cmsghdr *)&dp[offset];
			offset += cmptr->cmsg_len;  // advance offset for next
			// look for option data
			if (cmptr->cmsg_level == IPPROTO_IP &&
				cmptr->cmsg_type == IP_RECVDSTADDR) {
				memcpy( &dhcpRequest.localTarget, CMSG_DATA(cmptr), sizeof(struct in_addr) );
				NTOHL(dhcpRequest.localTarget);
				continue;
			}
			if (cmptr->cmsg_level == IPPROTO_IP &&
				cmptr->cmsg_type == IP_RECVIF) {
				struct sockaddr_dl *sdl;
				NSString* bsdName;
				InterfaceEntry* entry = nil;
				NSArray* interfaceArray;
				DHCPLeaseOptionsEntry* leaseOptionsEntry = nil;
				int i, count;
				// get pointer to data link socket containging interface name and index
				sdl = (struct sockaddr_dl *) CMSG_DATA(cmptr);
				bsdName = [NSString stringWithCString:&sdl->sdl_data[0] length:sdl->sdl_nlen];
				[bsdName getCString:dhcpRequest.bsdName];
				// Notice there could be more than one address for this bsdName
				// look to see if there is a matching lease options entry
				interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
				count = [interfaceArray count];
				for (i=0; i<count; i++) {
					entry = [interfaceArray objectAtIndex:i];
					if (![[entry interfaceID] hasPrefix:bsdName]) continue;
					leaseOptionsEntry = [[dhcpState leaseOptionsTable] objectForKey:[entry ifNet]];
					if ([leaseOptionsEntry dhcpOn]) break;
				}
				if (!leaseOptionsEntry) entry = [[InterfaceTable sharedInstance] entryForInterfaceID:bsdName];
				netNumberForString([entry ifNet], &dhcpRequest.localAddr, &dhcpRequest.localMask);
				continue;
			}
		}
	} while (NO);

	// Process Request
	// make sure we catch any exceptions
	@try {
		[self processRequest:&dhcpRequest];
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSLog(@"DHCP Server exception during process request");
	}
	// send parameter updates
	[self sendParameterUpdates];
}


// ---------------------------------------------------------------------------
//		• ProcessRequest
// ---------------------------------------------------------------------------
//	Process DHCP request
- (void)processRequest:(dhcp_request_t *)inRequest
{
	BOOL					result;
	dhcp_response_t			dhcpResponse;
	DHCPMessage_t*			msg;
	u_int32_t				netInterface;
	BOOL					validRequest;
	DHCPLeaseOptionsEntry*  leaseOptionsEntry;
	DHCPStatusEntry*		statusEntry;
	IPValue*				ipValue;

	if ([[dhcpState verboseLogging] intValue] >= kDHCP_verboseLogging) {
		[mLogMessage appendFormat:@"\r\rDHCP message to %@ arrived on %s ",
			stringForIP(inRequest->localTarget), inRequest->bsdName];
	}
	// Make sure DHCP is enabled on the local interface that received
	// this request.  Save the corresponding netMask and netNumber.
	// Use giaddr as netInterface if specified.
	msg = (DHCPMessage_t*)inRequest->data;
	validRequest = NO;
	// ------------------
	// byte swap boundary
	// ------------------
	[self ntohDHCPMessage:msg];
	do {
		// find lease options entry for local interface
		leaseOptionsEntry = [[dhcpState leaseOptionsTable]
			objectForKey:stringForNetNumber(inRequest->localAddr, inRequest->localMask)];
		if (!leaseOptionsEntry) break;
		if (![leaseOptionsEntry dhcpOn]) break; // no record of this interface being DHCP enabled
		netInterface = inRequest->localAddr;
		// if request specifies a relay server, get corresponding entry
		if (msg->giaddr) {
			leaseOptionsEntry = [self findLeaseOptionsForAddress:msg->giaddr];
			if (!leaseOptionsEntry) break;
			if (![leaseOptionsEntry dhcpOn]) break; // no record of this interface being DHCP enabled
			netInterface = msg->giaddr;
		}
		ipValue = [[[IPValue alloc] init] autorelease];
		[ipValue setStringValue:[leaseOptionsEntry networkInterface]];
		inRequest->netMask = [ipValue mask];
		inRequest->netNumber = netInterface & inRequest->netMask;
		validRequest = YES;
	} while (NO);
	
	// switch on message type to build response
	// BOOTP request?
	if ((msg->op == kBootRequest) && (validRequest)) {
    	// get options
    	u_int32_t	start, end;
    	u_int8_t*	dp;
    	start = 28 + 16 + 64 + 128;
    	// check for magic cookie
    	dp = inRequest->data;
    	if (*((u_int32_t*)&msg->options) == htonl(0x63825363)) {
    		start += 4;
    	}
    	end = inRequest->size;
    	// Find options in message
    	[self findDHCPOptionsForRequest:inRequest start:start end:end];
    	// check for overloaded options
    	if (inRequest->overload.option) {
    		u_int8_t value;
    		value = dp[inRequest->overload.offset];
    		if (value & 1) {
    			// get options from "file"
    			start = 28 + 16 + 64;
    			end = start + 128;
    			[self findDHCPOptionsForRequest:inRequest start:start end:end];
    		}
    		if (value & 2) {
    			// get options from "sname"
    			start = 28 + 16;
    			end = start + 64;
    			[self findDHCPOptionsForRequest:inRequest start:start end:end];
    		}
    	}

		// Show user what we got
		[self logDHCPRequest:inRequest];

		// handle each DHCP message type as a separate case
		switch (inRequest->dhcpMessageType) {
			case kDHCPDiscover:
				// find a lease addr
				result = [self findLeaseAddressForRequest:inRequest];
				if (!result) {
					// remain silent if no lease is available
					//result = [self buildResponse:&dhcpResponse type:kDHCPNack forRequest:inRequest];
					//[self sendQResponse:&dhcpResponse];
					// tell user what happened
					[mLogMessage appendString:@"\rDHCPAction: no leases available to offer."];
					break;
				}
				// find lease time
				result = [self findLeaseTimeForRequest:inRequest];
				if (!result) {
					// remain silent if no lease is available
					//result = [self buildResponse:&dhcpResponse type:kDHCPNack forRequest:inRequest];
					//[self sendQResponse:&dhcpResponse];
					break;
				}
				// build response
				result = [self buildResponse:&dhcpResponse type:kDHCPOffer forRequest:inRequest];
				if (!result) break;
				// update status entry (lease binding)
				result = [self updateLeaseBindingState:kLeaseOffered forRequest:inRequest];
				if (!result) break;					
				// check if new assigned address and need to ping
					// get option setting
				if ((inRequest->needPing) && [[dhcpState pingCheck] intValue]) {
					dhcpResponse.responseState = kRSPing;
					// hold in response array until ready to send
					dhcpResponse.timeStamp = [NSDate psInterval];
//					mResponseArray->AddItem(&dhcpResponse, sizeof(dhcp_response_t));
					[mResponseArray addObject:[NSData dataWithBytes:&dhcpResponse length:sizeof(dhcp_response_t)]];
					[self sendPing:inRequest->yiaddr];
					// reschedule timer if needed to check for ping response
					if ([eventTimer isValid]) {
						NSDate* eventTime;
						eventTime = [NSDate dateWithTimeIntervalSince1970:dhcpResponse.timeStamp + 0.20];
						eventTime = [eventTime earlierDate:[eventTimer fireDate]];
						[eventTimer setFireDate:eventTime];
					}
					break;
				}
				[self sendQResponse:&dhcpResponse];
				break;
			case kDHCPRequest:
				// if serverID does not match, cancel offer if any and ignore
				if (![self checkServerID:inRequest->dhcpServerID]) {
					result = [self updateLeaseBindingState:kLeaseExpired forRequest:inRequest];
					[mLogMessage appendString:@"\rDHCPAction: Request with non-matching ServerID ignored."];
					break;
				}
				// if INIT-REBOOT and invalid request for this network
				do {
					// test for INIT-REBOOT state
					if ((inRequest->dhcpServerID != 0) ||
						(inRequest->addressRequest == 0)) break;	// work around bug in Mac client (ciaddr != 0)
						//(inRequest->addressRequest == 0) ||
						//(msg->ciaddr != 0)) break;
					// client is in INIT-REBOOT state
					// check that request address is valid for this network
					if (inRequest->netNumber != (inRequest->addressRequest & inRequest->netMask)) {
						// lease addr is not valid for this request
						validRequest = NO;
						result = [self buildResponse:&dhcpResponse type:kDHCPNack forRequest:inRequest];
						[self sendQResponse:&dhcpResponse];
						[mLogMessage appendFormat:@"\rDHCPAction: request addr %@ is not valid for this network.",stringForIP(inRequest->addressRequest)];
						break;
					}
				} while (NO);
				if (!validRequest) break;

				// check that we have a lease binding for this request
				statusEntry = [self findStatusForRequest:inRequest];
				if (!statusEntry) {
					// no previous binding for this request, remain silent
					[mLogMessage appendString:@"\rDHCPAction: no previous binding for this request."];
					break;
				}
				do {
					// find a lease addr
					result = [self findLeaseAddressForRequest:inRequest];
					if (!result)  {
						// no lease available for this request
						result = [self buildResponse:&dhcpResponse type:kDHCPNack forRequest:inRequest];
						[mLogMessage appendString:@"\rDHCPAction: no lease available for this request."];
						[self sendQResponse:&dhcpResponse];
						break;
					}
					// find lease time
					result = [self findLeaseTimeForRequest:inRequest];
					if (!result) {
						// lease has expired
						result = [self buildResponse:&dhcpResponse type:kDHCPNack forRequest:inRequest];	
						[mLogMessage appendString:@"\rDHCPAction: lease has expired."];
						[self sendQResponse:&dhcpResponse];
						break;
					}
					// build response
					result = [self buildResponse:&dhcpResponse type:kDHCPAck forRequest:inRequest];
					if (!result) break;
					// update status entry (lease binding)
					result = [self updateLeaseBindingState:kLeaseBound forRequest:inRequest];
					if (!result) break;
					// commit to non-volatile storage
					[self writeStatusEntry:[statusEntry keyInt]];
					// mark to refresh display
					[statusEntry setAction:[NSNumber numberWithInt:kActionUpdate]];
					[self updateParameterD:[statusEntry key] withObject:statusEntry];
					// send response
					[self sendQResponse:&dhcpResponse];
				} while (NO);
				break;
			case kDHCPDecline:
				// client has declined lease
				[self updateLeaseBindingState:kLeaseDeclined forRequest:inRequest];
				// tell user
				[mLogMessage appendFormat:@"\rClient has declined IP address: %@",
					stringForIP(inRequest->addressRequest)];
				break;
			case kDHCPRelease:
				// client is releasing lease
				[self updateLeaseBindingState:kLeaseReleased forRequest:inRequest];
				break;
			case kDHCPInform:
				// like Request, but omit address and lease time
				// build response
				result = [self buildResponse:&dhcpResponse type:kDHCPAck forRequest:inRequest];
				if (!result) break;
				[self sendQResponse:&dhcpResponse];
				break;
			case kDHCPBootp:		// BOOTP, no message type, handle like discover
				if ([[dhcpState ignoreBootp] intValue]) {
					if ([[dhcpState verboseLogging] intValue] > kDHCP_exceptionLogging)
						[mLogMessage appendString:@"\rBOOTP request ignored."];
					break;
				}
				// find a lease addr
				result = [self findLeaseAddressForRequest:inRequest];
				if (!result) break;
				// find lease time
				//result = [self findLeaseTimeForRequest:inRequest];
				//if (!result) break;
				inRequest->leaseTime = kLeaseReclaimPeriod;	// BOOTP has no time limit, use 60 days
				// build response
				result = [self buildResponse:&dhcpResponse type:kDHCPOffer forRequest:inRequest];
				if (!result) break;
				// update status entry (lease binding)
				result = [self updateLeaseBindingState:kLeaseBootp forRequest:inRequest];
				if (!result) break;					
				[self sendQResponse:&dhcpResponse];
				break;

		}	// end switch
	}	// end bootp request
}

// ---------------------------------------------------------------------------
//		• updateLeaseBindingState:forRequest
// ---------------------------------------------------------------------------
// Update entry in DHCP status table based on collected info and new state
- (BOOL)updateLeaseBindingState:(u_int8_t)leaseState forRequest:(dhcp_request_t *)inRequest
{
	DHCPMessage_t*		inMsg;
	u_int8_t*			dp;
	DHCPStatusEntry*	statusEntry = nil;
	NSDate*				currentTime;
	BOOL				result = NO;

	// Setup access to request data
	inMsg = (DHCPMessage_t*)inRequest->data;
	dp = inRequest->data;
	// get current time
	currentTime = [NSDate psDate];
	//NSLog([NSString stringWithFormat:@"\rupdateLeaseBindingState: %d",leaseState]);
	
	switch (leaseState) {
		case kLeaseOffered:
		case kLeaseBound:
		case kLeaseBootp:		
			// find status entry (lease binding)
			statusEntry = [self findStatusForAddress:inRequest->yiaddr];
			if (!statusEntry) {
				// if no previous entry, just create one
				statusEntry = [[[DHCPStatusEntry alloc] init] autorelease];
				// set lease addr
				[statusEntry setIpAddressInt:inRequest->yiaddr];
				[[dhcpState statusTable] setObject:statusEntry forKey:[statusEntry key]];
			}
			// set corresponding fields
				// hw addr
			[statusEntry setHardwareAddress:stringForHA16((HardwareAddress16_t*)inMsg->chaddr, inMsg->hlen)];
				// clientID
			//if (inRequest->clientID.option && inRequest->useClientID) {
			if (inRequest->clientID.option) {
				NSData* cid;
				cid = [NSData dataWithBytes:&dp[inRequest->clientID.offset] length:inRequest->clientID.len];
				[statusEntry setClientID:addPercentEscapes(cid)];
			}
				// expire time
			[statusEntry setExpireTime:[currentTime addTimeInterval:inRequest->leaseTime]];
				// last update time
			[statusEntry setLastUpdate:currentTime];
				// lease state
			[statusEntry setLeaseState:[NSNumber numberWithInt:leaseState]];
			result = YES;
			break;
		case kLeaseReleased:
			statusEntry = [self findStatusForRequest:inRequest];
			if (statusEntry) {
				// last update time				
				[statusEntry setLastUpdate:currentTime];
				// lease state
				[statusEntry setLeaseState:[NSNumber numberWithInt:leaseState]];
				result = YES;
			}
			break;
		case kLeaseExpired:
			// used to cancel offer if DHCPRequest for another server
			inRequest->addressRequest = 0;	// ignore request Addr
			statusEntry = [self findStatusForRequest:inRequest];
			if (statusEntry) {
				if ([[statusEntry leaseState] intValue] == kLeaseOffered) {
					// last update time
					[statusEntry setLastUpdate:currentTime];
					// lease state
					[statusEntry setLeaseState:[NSNumber numberWithInt:leaseState]];
					result = YES;
				}
			}
			break;
		case kLeaseDeclined:
			statusEntry = [self findStatusForRequest:inRequest];
			if (statusEntry) {
				// reset the Client_ID for this entry so the client who Declined
				// this lease will no longer match it.
				[statusEntry setClientID:nil];
				[statusEntry setHardwareAddress:nil];
				// last update time
				[statusEntry setLastUpdate:currentTime];
				// lease state
				[statusEntry setLeaseState:[NSNumber numberWithInt:leaseState]];
				result = YES;
			}
			break;
	}
	if (statusEntry) {
		// refresh display
		[statusEntry setAction:[NSNumber numberWithInt:kActionUpdate]];
		[self updateParameterD:[statusEntry key] withObject:statusEntry];
	}
	return result;
}


#pragma mark --- Network Response ---

// ---------------------------------------------------------------------------
//		• Build DHCP Response
// ---------------------------------------------------------------------------
//	Build specified DHCP response from collected information
- (BOOL)buildResponse:(dhcp_response_t *)outResponse type:(u_int8_t)responseType forRequest:(dhcp_request_t *)inRequest
{
	DHCPLeaseOptionsEntry* leaseOptionsEntry;
	DHCPServerOptionsEntry* serverOptionsEntry;
	DHCPMessage_t*			inMsg;
	DHCPMessage_t*			outMsg;
	IPValue*				ipValue = nil;
	NSString*				text =  nil;
	u_int32_t				mask;
	u_int8_t*				inDP;
	u_int8_t*				outDP;
	BOOL					result = NO;
	// remember which options we've seen
	BOOL seenSubnetMask = NO;
	BOOL seenRouters = NO;
	BOOL seenDomainServer = NO;
	BOOL seenDomainName = NO;

	// setup access to inRequest
	inMsg = (DHCPMessage_t*)inRequest->data;
	inDP = inRequest->data;
	outMsg = (DHCPMessage_t*)&outResponse->buf[0];
	outDP = &outResponse->buf[0];

	// initialize the response data structure
	bzero(outResponse, sizeof(dhcp_response_t));
		// set max len
	outResponse->maxLen = kMaxResponseLen;
		// use Max Message Size option if specified
	if (inRequest->dhcpMaxMsgSize.option) {
		outResponse->maxLen = *(u_int16_t*)&inDP[inRequest->dhcpMaxMsgSize.offset];
	}
		// set response ID for reference
	outResponse->xid = inMsg->xid;
		// copy ciaddr and localAddr for reference
	outResponse->ciaddr = inMsg->ciaddr;
	outResponse->localAddr = inRequest->localAddr;
	outResponse->localMask = inRequest->localMask;
	outResponse->remoteAddr = inRequest->remoteAddr;
	outResponse->leaseState = inRequest->leaseState;
		// remember message type
	outResponse->dhcpMessageType = responseType;
		// bsdName
	memcpy(outResponse->bsdName, inRequest->bsdName, kBSDNameLength);
	
	do {
		// begin loading response based on request
		// start with those parts that are message type independent
		outMsg->op		= kBootReply;
		outMsg->htype	= inMsg->htype;
		outMsg->hlen	= inMsg->hlen;
		outMsg->hops	= 0;
		outMsg->xid		= inMsg->xid;
		outMsg->secs	= 0;
		outMsg->ciaddr	= 0;
		if (responseType == kDHCPAck) outMsg->ciaddr = inMsg->ciaddr;
		outMsg->flags	= inMsg->flags;
		outMsg->giaddr	= inMsg->giaddr;
		memcpy(outMsg->chaddr, inMsg->chaddr, inMsg->hlen);
		//OTStrCopy(&outMsg-sname, &inMsg->sname);
		
		// begin setting options
		u_int16_t offset;
		offset = (u_int8_t*)&outMsg->options[0] - (u_int8_t*)&outMsg->op;
		// required options
			// magic cookie
		u_int32_t cookie = htonl(0x63825363);
		memcpy(&outDP[offset], &cookie, 4);
		offset += 4;
			// message type
		[self putOptionToBuffer:outDP offset:&offset
			optionCode:kOptionDHCPMessageType optionLen:1 optionData:&responseType];
			// server ID
		[self putOptionToBuffer:outDP offset:&offset
			optionCode:kOptionDHCPServerID optionLen:4 optionData:(u_int8_t*)&inRequest->localAddr];
		
		// load parts based on response type
		if (responseType == kDHCPNack) {
			// DHCPNAK
			outMsg->yiaddr = 0;
			outMsg->siaddr = 0;
		} else {
			if (inRequest->dhcpMessageType != kDHCPInform) {
				// DHCPOFFER or DHCPACK	
				// lease address
				outResponse->yiaddr = inRequest->yiaddr;
				outMsg->yiaddr = inRequest->yiaddr;
				outMsg->siaddr = 0;	// unknown
				// lease time
				[self putOptionToBuffer:outDP offset:&offset
					optionCode:kOptionAddressTime optionLen:4
					optionData:(u_int8_t*)&inRequest->leaseTime];
			}
			// get lease data entry
			leaseOptionsEntry = [self findLeaseOptionsForRequest:inRequest];
			if (!leaseOptionsEntry) {
				[mLogMessage appendString:@"\rDHCPAction::BuildResponse - no lease data"];
				break;
			}
			// additional options as requested then any defaults
			if (inRequest->parameterList.option) {
				u_int8_t len, i, option;
				len = inRequest->parameterList.len;
				for (i=0; i<len; i++) {
					option = inDP[inRequest->parameterList.offset + i];
					switch(option) {
						case kOptionSubnetMask:
							ipValue = [[[IPValue alloc] init] autorelease];
							[ipValue setStringValue:[leaseOptionsEntry networkInterface]];
							mask = [ipValue mask];
							[self putOptionToBuffer:outDP offset:&offset
								optionCode:option optionLen:4 optionData:(u_int8_t*)&mask];
							seenSubnetMask = YES;
							break;
						case kOptionRouters:
							[self putAddressListToBuffer:outDP offset:&offset
								optionCode:option inList:[leaseOptionsEntry router]];
							seenRouters = YES;
							break;
						case kOptionDomainServer:
							text = [self substituteNameServers:[leaseOptionsEntry nameServers] forRequest:inRequest];
							[self putAddressListToBuffer:outDP offset:&offset optionCode:option inList:text];
					
							seenDomainServer = YES;
							break;
						case kOptionDomainName:
							text = [leaseOptionsEntry searchDomains];
							if ([text length]) {
								[self putOptionToBuffer:outDP offset:&offset
									optionCode:option optionLen:[text length]
									optionData:(u_int8_t *)&[text cString][0] ];
//								PutOption(outDP, &offset, option,  nameLen, (u_int8_t*)&leaseOptionsEntry.domainNameStr[1]);
								seenDomainName = YES;
							}
							break;
						default:
						    // allow any additional options from server options table
							serverOptionsEntry = [[dhcpState serverOptionsTable] objectForKey:
								[NSString stringWithFormat:@"%d",option]];
							if (serverOptionsEntry) {
								text = [serverOptionsEntry dhcpOptionText];
								int optionType = [[serverOptionsEntry dhcpOptionType] intValue];
								if (optionType == kDhcpOptionTypeText) {
									[self putOptionToBuffer:outDP offset:&offset
										optionCode:option optionLen:[text length]
										optionData:(u_int8_t *)&[text cString][0] ];
								}
								else if (optionType == kDhcpOptionTypeIPAddress) {
									[self putAddressListToBufferN:outDP offset:&offset
										optionCode:option inList:text];
								}
							}
						    break;
					}
				}
			}
			// continue with any default options we haven't seen
			if (!seenSubnetMask) {
				ipValue = [[[IPValue alloc] init] autorelease];
				[ipValue setStringValue:[leaseOptionsEntry networkInterface]];
				mask = [ipValue mask];
				[self putOptionToBuffer:outDP offset:&offset
					optionCode:kOptionSubnetMask optionLen:4 optionData:(u_int8_t*)&mask];
			}
			if (!seenRouters) {
				[self putAddressListToBuffer:outDP offset:&offset
					optionCode:kOptionRouters inList:[leaseOptionsEntry router]];
			}
			if (!seenDomainServer) {
				text = [self substituteNameServers:[leaseOptionsEntry nameServers] forRequest:inRequest];
				[self putAddressListToBuffer:outDP offset:&offset optionCode:kOptionDomainServer inList:text];
			}
			if (!seenDomainName) {
				text = [leaseOptionsEntry searchDomains];
				if ([text length]) {
					[self putOptionToBuffer:outDP offset:&offset
						optionCode:kOptionDomainName optionLen:[text length]
						optionData:(u_int8_t *)&[text cString][0] ];
				}
			}
		}
		// if NAK or ACK include user message
		if (responseType == kDHCPNack) {
			text = [dhcpState notGrantedMessage];
			if ([text length]) {
				[self putOptionToBuffer:outDP offset:&offset
					optionCode:kOptionDHCPMessage optionLen:[text length]
					optionData:(u_int8_t *)&[text cString][0] ];
			}
		}
		else if (responseType == kDHCPAck) {
			text = [dhcpState grantedMessage];
			if ([text length]) {
				[self putOptionToBuffer:outDP offset:&offset
					optionCode:kOptionDHCPMessage optionLen:[text length]
					optionData:(u_int8_t *)&[text cString][0] ];
			}
		}
		// finish with "END" option
		outDP[offset++] = kOptionEnd;
		if ((offset & 0x0001)) outDP[offset++] = kOptionPad;	// pad (length=offset-1) to even number
		outDP[offset++] = kOptionPad;

		// find where to send response
		outResponse->respondVia = [self findRespondViaForResponse:outResponse];

		// record message length
		outResponse->dataLen = offset-1;
		result = YES;
	} while (NO);
	return result;
}


// ---------------------------------------------------------------------------
//		• PutOption
// ---------------------------------------------------------------------------
//	Put DHCP option in message, update offset to one past option
- (void)putOptionToBuffer:(u_int8_t *)buffer offset:(u_int16_t *)ioOffset
	optionCode:(u_int8_t)optionCode optionLen:(u_int8_t)optionLen optionData:(u_int8_t *)optionData
{
	u_int16_t offset;
	offset = *ioOffset;
	
	buffer[offset++] = optionCode;
	buffer[offset++] = optionLen;
	memcpy(&buffer[offset], optionData, optionLen);
	offset += optionLen;
	
	*ioOffset = offset;
}


// ---------------------------------------------------------------------------
//		• putAddressListToBuffer
// ---------------------------------------------------------------------------
//	Put text address list in message option
- (BOOL)putAddressListToBuffer:(u_int8_t *)buffer offset:(u_int16_t *)ioOffset
	optionCode:(u_int8_t)optionCode inList:(NSString *)inList
{
	BOOL			returnValue = NO;
	NSArray*		list;
	NSEnumerator*   en;
	NSString*		str;
	u_int16_t		offset;
	u_int32_t		address;
	
	// get NSArray of addresses
	list = [inList componentsSeparatedByString:@","];
	if ([list count]) {
		// begin writing out option
		offset = *ioOffset;
		buffer[offset++] = optionCode;
		buffer[offset++] = [list count]*4;
		// include addresses we fount
		en = [list objectEnumerator];
		while (str = [en nextObject]) {
			address = ipForString(str);
//			HTONL(address);
			memcpy(&buffer[offset], &address, 4);
			offset += 4;
			returnValue = YES;
		}
		*ioOffset = offset;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• putAddressListToBufferN
// ---------------------------------------------------------------------------
//	Put text address list in message option, use Network Byte Order (option not in htonDHCPOptions)
- (BOOL)putAddressListToBufferN:(u_int8_t *)buffer offset:(u_int16_t *)ioOffset
	optionCode:(u_int8_t)optionCode inList:(NSString *)inList
{
	BOOL			returnValue = NO;
	NSArray*		list;
	NSEnumerator*   en;
	NSString*		str;
	u_int16_t		offset;
	u_int32_t		address;
	
	// get NSArray of addresses
	list = [inList componentsSeparatedByString:@","];
	if ([list count]) {
		// begin writing out option
		offset = *ioOffset;
		buffer[offset++] = optionCode;
		buffer[offset++] = [list count]*4;
		// include addresses we fount
		en = [list objectEnumerator];
		while (str = [en nextObject]) {
			address = ipForString(str);
			HTONL(address);
			memcpy(&buffer[offset], &address, 4);
			offset += 4;
			returnValue = YES;
		}
		*ioOffset = offset;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• SendQResponse
// ---------------------------------------------------------------------------
//	Try to send response, add to response queue if SendThread is busy
- (void)sendQResponse:(dhcp_response_t *)inResponse
{
	// set response state
	inResponse->responseState = kRSReady;
	// try to send response
	if ([self sendResponse:inResponse] <= 0) {
		// hold in response array until ready to try again
		inResponse->timeStamp = [NSDate psInterval];
		[mResponseArray addObject:[NSData dataWithBytes:inResponse length:sizeof(dhcp_response_t)]];
	}
}

#define useBPF 1
// ---------------------------------------------------------------------------
//		• SendResponse
// ---------------------------------------------------------------------------
//	Send DHCP Response
//	Try to send response, return number of bytes sent, 0 if nothing sent, or -1 on error
- (int)sendResponse:(dhcp_response_t *)inResponse
{
	IPHost*		target;
	DHCPMessage_t*	msg;
	u_int32_t   address = 0;
	int			returnValue = 0;
	
	msg = (DHCPMessage_t*)inResponse->buf;
	// where to?
	target = [[[IPHost alloc] init] autorelease];
	[target setPort:kDHCPClientPort];
	switch (inResponse->respondVia) {
		case kViaUnicast:
			address = inResponse->ciaddr;
			break;
		case kViaBroadcast:
			// specify which interface to broadcast from with subnet broadcast address
			#if useBPF
				address = INADDR_BROADCAST;
			#else
				address = inResponse->localAddr | (kBroadcastAddr & ~inResponse->localMask);
			#endif
			break;
		case kViaHardwareUnicast:
			// if ethernet address is not zero
			if ( (msg->hlen == 6) &&
				( (*(u_int32_t*)&msg->chaddr[0] != 0) || (*(u_int16_t*)&msg->chaddr[4] != 0) )
				) {
#if !useBPF
				// stuff ARP cache
				int result;
				int argc;
				char* argv[6];
				argv[0] = "arp";	// path
				argv[1] = "arp";	// command
				argv[2] = "-s";
				argv[3] = (char *)[stringForIP(msg->yiaddr) cString];
				argv[4] = (char *)[stringForEA((EthernetAddress_t*)msg->chaddr) cString];
				argv[5] = "temp";
				argc = 6;
				optind = 2;		//  initialize for getopt
				// discard any previous output
				[[ArpOutput sharedInstance] setString:@""];
				// steal code from arp command (arp.c)
				result = psArpMain(argc, argv);
				if (result < 0) {
					// stuff ARP failed try to broadcast
					inResponse->respondVia = kViaBroadcast;
					address = kBroadcastAddr;
					break;
				}
#endif
				// then send it
				address = msg->yiaddr;
			} else {
				// otherwise try to broadcast
				inResponse->respondVia = kViaBroadcast;
				address = kBroadcastAddr;
			}
			break;
		case kViaRelayAgent:
			address = msg->giaddr;
			// we send to the server port on the Relay Agent per RFC 1541
			[target setPort:kDHCPServerPort];
			[mLogMessage appendFormat:@"\rRespond via Relay Agent on port: %d",kDHCPServerPort];
			break;
	}
	// set target address we determined
	[target setHAddress:address];
	// tell user what we're doing (before Byte Swap Boundary)
	[self logDHCPResponse:inResponse];
#if useBPF
	// send using BPF or socket according to respondVia
	if ((inResponse->respondVia == kViaBroadcast) || (inResponse->respondVia == kViaHardwareUnicast)) {
		// -- send using BPFTransmit
		ip_header_t* 	ip_header;
		udp_header_t* 	udp_header;
		UInt8*			dp;
		udp_pseudo_t	pseudo;
		int				clen;
		UInt16			sum;
		UInt16			totalLength;
		UInt16			udpLength;
		// setup access to send buffer
		ip_header = (ip_header_t*)&inResponse->headerBuf[0];
		dp = (UInt8*)ip_header;
		udp_header = (udp_header_t*)&dp[20];

		// initialize IP header
		ip_header->hlen = 0x45;
		ip_header->tos = 0;
		totalLength = 28 + inResponse->dataLen;
		ip_header->totalLength = totalLength;
		ip_header->identification = 0;
		ip_header->fragmentOffset = 0x0000;
		ip_header->ttl = 64;
		ip_header->protocol = IPPROTO_UDP;
		ip_header->checksum = 0;
		//ip_header->srcAddress = INADDR_ANY;
		ip_header->srcAddress = inResponse->localAddr;
		ip_header->dstAddress = [target v4Address];

		// 8 bytes UDP header
		udp_header->srcPort = kDHCPServerPort;
		udp_header->dstPort = kDHCPClientPort;
		udpLength = 8 + inResponse->dataLen;
		udp_header->messageLength = udpLength;
		udp_header->checksum = 0;
		// ------------------
		// byte swap boundary
		// ------------------
		KFT_htonDgram((u_int8_t*)ip_header, kOptionNone);
		[self htonDHCPMessage:msg];	// byte swap
		[self htonDHCPOptions:msg size:inResponse->dataLen];

		// calculate IP header checksum
		ip_header->checksum = IpSum((u_int16_t*)ip_header, (u_int16_t*)((UInt8*)ip_header + 20));
		HTONS(ip_header->checksum);
		// calculate UDP checksum
		pseudo.srcAddress	= ip_header->srcAddress;
		pseudo.dstAddress	= ip_header->dstAddress;
		pseudo.zero			= 0;
		pseudo.protocol		= ip_header->protocol;
		pseudo.length		= udp_header->messageLength;
		// UInt16 IpSum( UInt16* dataptr, UInt16* endptr)
		dp = (UInt8*)&pseudo.srcAddress;
		sum = IpSum((UInt16*)&dp[0], (UInt16*)&dp[12]);
		// UInt16 AddToSum( UInt16 oldSum, UInt16* dataPtr, UInt16* endPtr)
		dp = (UInt8*)udp_header;
		clen = udpLength;
		if (clen & 1) {
			dp[clen] = 0;   // pad for checksum computation
			clen += 1;
		}
		sum = AddToSum( sum, (UInt16*)&dp[0], (UInt16*)&dp[clen]);
		udp_header->checksum = htons(sum);
		// -- get BPFTransmit object
		NSString* bsdName = [NSString stringWithCString:inResponse->bsdName];
		BPFTransmit* bpfTransmit;
		bpfTransmit = [mBPFSenders objectForKey:bsdName];
		if (!bpfTransmit) {
			bpfTransmit = [[[BPFTransmit alloc] initWithName:bsdName type:ARPHRD_ETHER] autorelease];
			if (bpfTransmit) [mBPFSenders setObject:bpfTransmit forKey:bsdName];
		}
		// -- try to send packet
		if (inResponse->respondVia == kViaBroadcast) {
			returnValue = [bpfTransmit sendData:&inResponse->frameBuf[0]
				ipOffset:sizeof(inResponse->frameBuf) ipLen:totalLength
				hwDest:nil hwDestLen:0];
			if (returnValue == 0) returnValue = totalLength;
		}
		else if (inResponse->respondVia == kViaHardwareUnicast) {
			returnValue = [bpfTransmit sendData:&inResponse->frameBuf[0]
				ipOffset:sizeof(inResponse->frameBuf) ipLen:totalLength
				hwDest:msg->chaddr hwDestLen:msg->hlen];
			if (returnValue == 0) returnValue = totalLength;
		}
	}
	else
#endif
	{
		// send using normal UDP socket
		// ------------------
		// byte swap boundary
		// ------------------
		[self htonDHCPMessage:msg];	// byte swap
		[self htonDHCPOptions:msg size:inResponse->dataLen];
		// send it
		returnValue = [mUDPSendSocket sendTo:target
			data:[NSData dataWithBytes:&inResponse->buf[0] length:inResponse->dataLen]];
	}
	if (returnValue < 0) {
		int errno_save = errno;
		[mLogMessage appendFormat:@"\rDHCP send error: %s",strerror(errno_save)];
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• SendPing
// ---------------------------------------------------------------------------
- (int)sendPing:(u_int32_t)inPingAddress
{
    // setup to send packet
	IPHost* target;
    icmp_header_t*	icmp_header;
    UInt8*		data;
    SInt32		tSize, iSize;
    int			result = 0; // number of bytes sent
    
    do {
        // set destination
		target = [[[IPHost alloc] init] autorelease];
		[target setHAddress:inPingAddress];
		// setup access to send buffer
        if (!mSendBuf) break;
        [mSendBuf retain];
        icmp_header = [mSendBuf mutableBytes];
        data = (UInt8*)icmp_header;
        
        // determine packet size (must be an even number between 28 and 2048)
        tSize = 52;
        iSize = tSize - 20;	// icmp size less IP header
        // set buffer size
        [mSendBuf setLength:iSize];
        
        // Initialize ICMP header (8 bytes)
        icmp_header->type = ICMP_ECHO;	// 8=echo request
        icmp_header->code = 0;
        icmp_header->checksum = 0;
        icmp_header->identifier = htons(kDHCPServerSN);
        icmp_header->seqNumber = htons(kDHCPServerSN);
        
        // ICMP data
        memcpy((char*)&data[8], "¬©Sustainable Softworks ", 24);
        data[30] = 0;
        data[31] = 0;
        if (iSize > 32) {
                UInt16 i;
                for (i=32; i<iSize; i++) data[i] = i;
        }
        icmp_header->checksum = IpSum((UInt16*)&data[0], (UInt16*)&data[iSize]);
    
        // send data
        result = [[ICMPController sharedInstance] sendTo:target data:mSendBuf];
        if (result == 0) NSLog( NSLocalizedString(@"send failed",@"send failed") );
        [mSendBuf release];
    } while (NO);
	return result;
}

// ---------------------------------------------------------------------------------
//	• receiveICMP:
// ---------------------------------------------------------------------------------
// handle ping responses
- (void)receiveICMP:(IPNetMessage *)inMessage
{
    u_int32_t inDataSize;		// size of the data
    u_int8_t* dp;
	IPHost* inRemoteAddress;
    ip_header_t* ip_header;
    icmp_header_t* icmp_header;
	NSEnumerator* en;
	NSMutableData* data;
	dhcp_response_t* dhcpResponse;

    dp = (u_int8_t*)[[inMessage data] bytes];
    inDataSize = [[inMessage data] length];
	inRemoteAddress = [inMessage fromHost];
    // setup pointer to ip header
    ip_header = (ip_header_t*)dp;
    // setup pointer to icmp header
    icmp_header = (icmp_header_t*)&dp[(ip_header->hlen & 0x0F) * 4];
	
	// check for response to our own ping
	if ((icmp_header->type == kIcmpEchoReply) &&
		(icmp_header->seqNumber == kDHCPServerSN)) {
		// see if it matches a pending response
		en = [mResponseArray objectEnumerator];
		while (data = [en nextObject]) {
			dhcpResponse = (dhcp_response_t *)[data bytes];
			// found a response entry from array
			if (( dhcpResponse->responseState == kRSPing ) &&
				( dhcpResponse->yiaddr == [inRemoteAddress v4Address] )) {
				// response was waiting for this ping
				// look for corresponding status entry (lease binding)
				DHCPStatusEntry* statusEntry;
				statusEntry = [[dhcpState statusTable] objectForKeyInt:[inRemoteAddress v4Address]];
				if (statusEntry) {
					// update status entry to show address is in use
					[statusEntry setLeaseState:[NSNumber numberWithInt:kLeaseInUse]];
					// try to show the hardware address of the machine that responded
					
					// change the clientID to disassociate this entry
					// from the client that requested an IP address
					[statusEntry setClientID:@"*unknown*"];
					// refresh display
					[statusEntry setAction:[NSNumber numberWithInt:kActionUpdate]];
					[self updateParameterD:[statusEntry key] withObject:statusEntry];
				}
				// remove response from list since address is in use
				// assume client will retry DHCP discover
				[mResponseArray removeObject:data];
				[mLogMessage appendFormat:@"\rReceiveICMP - detected address already in use: ",[inRemoteAddress addressString]];
				break;
			}
		}   // while (data = [en nextObject])
	}
}

#pragma mark --- Find Info ---

// ---------------------------------------------------------------------------
//		• checkServerID
// ---------------------------------------------------------------------------
// Check that ServerID (if present) matches a DHCP enabled IP interface on this machine.
// Returns NO if no match found
- (BOOL)checkServerID:(u_int32_t)inServerID
{
	BOOL	returnValue = YES;
	if (inServerID) {
		if (![self findLeaseOptionsForAddress:inServerID]) returnValue = NO;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• findDHCPOptions
// ---------------------------------------------------------------------------
// identify common DHCP options and load descriptors in request structure (opcode,len,data).
// Swap bytes to host order in place for 2 and 4 byte options.
- (void)findDHCPOptionsForRequest:(dhcp_request_t *)inRequest start:(u_int32_t)start end:(u_int32_t)end
{
	u_int8_t*	dp;	
	u_int8_t	option;
	u_int8_t	len;
	
	dp = (u_int8_t*)inRequest->data;
	option = kOptionPad;

	while ((option != kOptionEnd) && (start < end)) {
		option = dp[start++];
		switch (option) {
			case kOptionPad:
				break;
			case kOptionEnd:
				break;
			case kOptionSubnetMask:
				len = dp[start++];
				NTOHL(*(u_int32_t*)&dp[start]);
				inRequest->subnetMask.option	= option;
				inRequest->subnetMask.len		= len;
				inRequest->subnetMask.offset	= start;
				start += len;
				break;
			case kOptionHostName:
				len = dp[start++];				
				inRequest->hostName.option = option;
				inRequest->hostName.len = len;
				inRequest->hostName.offset = start;
				start += len;
				break;
			case kOptionAddressRequest:
				len = dp[start++];				
				NTOHL(*(u_int32_t*)&dp[start]);
				inRequest->addressRequest = *(u_int32_t*)&dp[start];
				start += len;
				break;
			case kOptionAddressTime:
				len = dp[start++];
				NTOHL(*(u_int32_t*)&dp[start]);
				inRequest->addressTime.option = option;
				inRequest->addressTime.len = len;
				inRequest->addressTime.offset = start;
				start += len;
				break;
			case kOptionOverload:
				len = dp[start++];
				inRequest->overload.option	= option;
				inRequest->overload.len		= len;
				inRequest->overload.offset	= start;
				start += len;
				break;
			case kOptionDHCPMessageType:
				len = dp[start++];
				inRequest->dhcpMessageType = dp[start];
				start += len;
				break;
			case kOptionDHCPServerID:
				len = dp[start++];
				NTOHL(*(u_int32_t*)&dp[start]);
				inRequest->dhcpServerID = *(u_int32_t*)&dp[start];
				start += len;
				break;
			case kOptionParameterList:
				len = dp[start++];
				inRequest->parameterList.option	= option;
				inRequest->parameterList.len = len;
				inRequest->parameterList.offset	= start;				
				start += len;
				break;
			case kOptionDHCPMessage:
				len = dp[start++];				
				inRequest->dhcpMessage.option = option;
				inRequest->dhcpMessage.len = len;
				inRequest->dhcpMessage.offset = start;
				start += len;
				break;
			case kOptionDHCPMaxMsgSize:
				len = dp[start++];
				NTOHS(*(u_int16_t*)&dp[start]);
				inRequest->dhcpMaxMsgSize.option = option;
				inRequest->dhcpMaxMsgSize.len = len;
				inRequest->dhcpMaxMsgSize.offset = start;
				start += len;
				break;
			case kOptionRenewalTime:
				len = dp[start++];
				NTOHL(*(u_int32_t*)&dp[start]);
				inRequest->renewalTime.option = option;
				inRequest->renewalTime.len = len;
				inRequest->renewalTime.offset = start;
				start += len;
				break;
			case kOptionRebindingTime:
				len = dp[start++];
				NTOHL(*(u_int32_t*)&dp[start]);
				inRequest->rebindingTime.option = option;
				inRequest->rebindingTime.len = len;
				inRequest->rebindingTime.offset = start;
				start += len;
				break;
			case kOptionClassID:
				len = dp[start++];
				inRequest->classID.option	= option;
				inRequest->classID.len		= len;
				inRequest->classID.offset	= start;
				start += len;
				break;
			case kOptionClientID:
				len = dp[start++];
				inRequest->clientID.option	= option;
				inRequest->clientID.len		= len;
				inRequest->clientID.offset	= start;
				start += len;
				break;
			default:
				len = dp[start++];
				[mLogMessage appendString:[NSString stringWithFormat:
					@"\rFindOptions - Unrecognized DHCP option: %d",option]];
				start += len;
				break;
		}
	}
}

// ---------------------------------------------------------------------------
//		• findStatusForRequest (FindLeaseStatus)
// ---------------------------------------------------------------------------
// Search the DHCP status array to find the corresponding lease record
// if any.  Return nil if not found.
//
// Records are matched based on the unique lease identifier consisting of
// "client HW addr" or "clientID" and network number of the attached network.
// Notice it is possible for a single client to have more than one lease binding
// if it is moved from one network to another managed by the same DHCP server.
- (DHCPStatusEntry *)findStatusForRequest:(dhcp_request_t *)inRequest
{
	DHCPStatusEntry*	returnValue = nil;
	DHCPStatusEntry*	statusEntry;
	NSEnumerator*		en;
	u_int32_t			inLeaseAddr;
	NSData*				cid;
	NSString*			clientID = nil;
	DHCPMessage_t*		msg;
	u_int8_t*			dp;

	do {
		// get key from request
		msg = (DHCPMessage_t*)inRequest->data;
		dp = inRequest->data;
			// get client ID if any
		inRequest->useClientID = NO;
		if (inRequest->clientID.option) {
			cid = [NSData dataWithBytes: &dp[inRequest->clientID.offset] length:inRequest->clientID.len];
			clientID = addPercentEscapes(cid);
			// default to use clientID if present (otherwise use HW addr)
			inRequest->useClientID = YES;
		}
			// use requested IP addr if present
		inLeaseAddr = inRequest->addressRequest;
		
		// search DHCP status array
		en = [[[dhcpState statusTable] tableArray] objectEnumerator];
		while (statusEntry = [en nextObject]) {
			// for each lease record
			BOOL useClientID;
			NSString* str;
			// check clientID (if present) or HW addr
			if (clientID && (str = [statusEntry clientID])) {
				if (![str isEqualToString:clientID]) continue;
				useClientID = YES;
			}
			else {
				//if (![[inHardwareAddr stringValue] isEqualToString:[statusEntry hardwareAddress]]) continue;
				if (![statusEntry hardwareAddress]) continue;
					HardwareAddress16_t* ap = [statusEntry ha16];
					int hlen = [statusEntry hlen];
				if (memcmp(msg->chaddr, ap, hlen) != 0) continue;
				useClientID = NO;
			}
			// check if network number matches
			if (inRequest->netNumber != ([statusEntry ipAddressInt] & inRequest->netMask)) continue;
			// found a match
			returnValue = statusEntry;
			// override useClientID based on match we actually found
			inRequest->useClientID = useClientID;
			break;
		}
		
	} while (NO);	
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• findStatusForAddress (FindLeaseStatus)
// ---------------------------------------------------------------------------
// Search the DHCP status table to find a lease record with this address.
// Return zero if not found.
- (DHCPStatusEntry *)findStatusForAddress:(u_int32_t)inLeaseAddr
{	
	return [[dhcpState statusTable] objectForKeyInt:inLeaseAddr];
}

// ---------------------------------------------------------------------------
//		• findLeaseOptionsForRequest (FindLeaseData)
// ---------------------------------------------------------------------------
// Find lease options entry based on interface that received the request.
// Return nil if not found.
- (DHCPLeaseOptionsEntry *)findLeaseOptionsForRequest:(dhcp_request_t *)inRequest
{
	DHCPLeaseOptionsEntry*  returnValue = nil;
	DHCPLeaseOptionsEntry*  leaseOptionsEntry;
	DHCPMessage_t*			msg;

	do {
		// Make sure DHCP is enabled on the local interface that received
		// this request and find corresponding lease data
		msg = (DHCPMessage_t*)inRequest->data;
		// find lease options entry for local interface
		leaseOptionsEntry = [[dhcpState leaseOptionsTable]
			objectForKey:stringForNetNumber(inRequest->localAddr, inRequest->localMask)];
		if (!leaseOptionsEntry) break;
		if (![leaseOptionsEntry dhcpOn]) break; // no record of this interface being DHCP enabled
		// if request specifies a relay server, get corresponding entry
		if (msg->giaddr) {
			leaseOptionsEntry = [self findLeaseOptionsForAddress:msg->giaddr];
			if (!leaseOptionsEntry) break;
			if (![leaseOptionsEntry dhcpOn]) break; // no record of this interface being DHCP enabled
		}
		returnValue = leaseOptionsEntry;
	} while (NO);	
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• findLeaseOptionsForAddress (FindLeaseData)
// ---------------------------------------------------------------------------
// Find lease options entry for corresponding interface address.
// Return nil if not found.
- (DHCPLeaseOptionsEntry *)findLeaseOptionsForAddress:(u_int32_t)inAddress
{
	id returnValue = nil;
	NSEnumerator* en;
	DHCPLeaseOptionsEntry* entry;
	u_int32_t entryAddress;
	
	en = [[[dhcpState leaseOptionsTable] tableDictionary] objectEnumerator];
	while (entry = [en nextObject]) {
		entryAddress = ipForString([entry valueForKey:DS_networkInterface]);
		if (inAddress == entryAddress) {
			returnValue = entry;
			break;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• findStaticConfigForAddress (CheckStaticPool)
// ---------------------------------------------------------------------------
// Check for address in Static Config pool
// return nil if not found
- (DHCPStaticConfigEntry *)findStaticConfigForAddress:(u_int32_t)inAddress
{
	return [[dhcpState staticConfigTable] objectForKey:stringForIP(inAddress)];
}

// ---------------------------------------------------------------------------
//		• findDynamicConfigForAddress (CheckDynamicPool)
// ---------------------------------------------------------------------------
// Check for address in Dynamic pool
// return nil if not found
- (DHCPDynamicConfigEntry *)findDynamicConfigForAddress:(u_int32_t)inAddress
{
	DHCPDynamicConfigEntry* returnValue = nil;
	DHCPDynamicConfigEntry* dynamicEntry;
	NSArray* dynamicArray;
	NSEnumerator* en;
	
	if (inAddress) {
		dynamicArray = [[dhcpState dynamicConfigTable] tableArray];
		en = [dynamicArray objectEnumerator];
		while (dynamicEntry = [en nextObject]) {
			if ( inAddress < [dynamicEntry startingAddressInt] ) continue;
			if ( inAddress > [dynamicEntry endingAddressInt] ) continue;
			returnValue = dynamicEntry;
			break;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• findLeaseAddressForRequest (FindLeaseAddr)
// ---------------------------------------------------------------------------
// Find an available lease address if any for this request.
// If found, set yiaddr in request and return YES,
// otherwise return NO.
- (BOOL)findLeaseAddressForRequest:(dhcp_request_t *)inRequest
{
	BOOL					returnValue = NO;
	DHCPStatusEntry*		statusEntry;
	DHCPStaticConfigEntry*  staticEntry;
	DHCPDynamicConfigEntry* dynamicEntry;
	NSData*					cid;
	NSString*				clientID = nil;
	NSDate*					currentTime;
	NSArray*				tableArray;
	NSEnumerator*			en;
	u_int32_t				inLeaseAddr;
	DHCPMessage_t*			msg;
	u_int8_t*				dp;
	int						oldestUpdate;
	u_int32_t				oldestAddress;
	BOOL					inUse = NO;
	int						leaseState;

	do {
		// get key from request
		msg = (DHCPMessage_t*)inRequest->data;
		dp = inRequest->data;
			// get client ID if any
		inRequest->useClientID = NO;
		if (inRequest->clientID.option) {
			cid = [NSData dataWithBytes: &dp[inRequest->clientID.offset] length:inRequest->clientID.len];
			clientID = addPercentEscapes(cid);
			// default to use clientID if present
			inRequest->useClientID = YES;
		}
			// get requested IP addr if any
		inLeaseAddr = inRequest->addressRequest;
		
		// Get current time for calculating remaining lease time.
		currentTime = [NSDate psDate];
		
        //
		// (1) Do we have a static config for this request?
		// search DHCP static config array
			// if message type is DHCPRequest, only match existing lease bindings
		if (inRequest->dhcpMessageType != kDHCPRequest) {
			int found = 0;		
			// search DHCP static config array
			tableArray = [[dhcpState staticConfigTable] tableArray];
			en = [tableArray objectEnumerator];
			while (staticEntry = [en nextObject]) {
				// for each lease record
				BOOL useClientID;
				NSString* str;
				// check clientID (if present) or HW addr
				str = [staticEntry clientID];
				if ([str length] && [clientID length]) {
					if (![str isEqualToString:clientID]) continue;
					useClientID = YES;
				}
				else {
					//if (![[inHardwareAddr stringValue] isEqualToString:[staticEntry hardwareAddress]]) continue;
					HardwareAddress16_t* ap = [staticEntry ha16];
					int hlen = [staticEntry hlen];
					if (hlen == 0) continue;
					if (memcmp(msg->chaddr, ap, hlen) != 0) continue;
					useClientID = NO;
				}
				// check if network number matches
				if ( inRequest->netNumber == ([staticEntry ipAddressInt] & inRequest->netMask) ) {
					// found a match
					found = 1;
					// override useClientID based on match we actually found
					inRequest->useClientID = useClientID;
					break;
				}
				else {
					if ([staticEntry ipAddressInt] == 0) {	// lock out this client?
						found = -1;
						[mLogMessage appendString:@"\rDHCPAction: Static address=0, do not respond to this client."];
						break;
					}
					[mLogMessage appendString:@"\rDHCPAction: static config address is not valid for this interface."];
				}
			}   //while (staticEntry = [en nextObject])
	
			if (found == -1) break;
			if (found) {
				// found a static config, check lease addr is not in use
				statusEntry = [self findStatusForAddress:[staticEntry ipAddressInt]];
				if (statusEntry) {
					// found a lease record
					leaseState = [[statusEntry leaseState] intValue];
					if ((leaseState == kLeaseBound) ||
						(leaseState == kLeaseBootp)) {
						// does the clientID or chaddr match?
						BOOL match = NO;
						NSString* str;
						// check clientID (if present) or HW addr
						if ((str = [statusEntry clientID]) && clientID) {
							if ([str isEqualToString:clientID]) match = YES;
						}
						else {
							//if ([[inHardwareAddr stringValue] isEqualToString:[statusEntry hardwareAddress]]) match = YES;
							if ([statusEntry hardwareAddress]) {
									HardwareAddress16_t* ap = [statusEntry ha16];
									int hlen = [statusEntry hlen];
								if (memcmp(msg->chaddr, ap, hlen) == 0) match = YES;
							}
						}
						if (match) {
							// yes, we can use it
							inRequest->yiaddr = [staticEntry ipAddressInt];
							returnValue = YES;
							if ([[dhcpState verboseLogging] intValue] > kDHCP_verboseLogging) {
								[mLogMessage appendString:@"\rDHCPAction: matching static config."];
							}
							break;
						} else {
							[mLogMessage appendString:@"\rDHCPAction: static config address for this client is already bound to a different client."];
						}
					}
					else {
						// It's not bound so we can use it regardless of ClientID
						if ( (leaseState != kLeaseDeclined) || (leaseState != kLeaseInUse) ) {
							inRequest->yiaddr = [staticEntry ipAddressInt];
							if (msg->ciaddr != inRequest->yiaddr) inRequest->needPing = YES;
							returnValue = YES;
							if ([[dhcpState verboseLogging] intValue] > kDHCP_verboseLogging) {
								[mLogMessage appendString:@"\rDHCPAction: matching static config."];
							}
							break;
						}
					}
				}
				else {
					// no lease record so we can use it
					inRequest->yiaddr = [staticEntry ipAddressInt];
					if (msg->ciaddr != inRequest->yiaddr) inRequest->needPing = YES;
					returnValue = YES;
					if ([[dhcpState verboseLogging] intValue] > kDHCP_verboseLogging) {
						[mLogMessage appendString:@"\rDHCPAction: matching static config."];
					}
					break;
				}
			}   // if (found)
		}   //if (inRequest->dhcpMessageType != kDHCPRequest)
				
		// 
		// (2) Do we already have a lease binding for this request?
			// look for matching lease record
		statusEntry = [self findStatusForRequest:inRequest];
		if (statusEntry) {
			// clientID and network number matches
			// remember existing lease state
			inRequest->leaseState = [[statusEntry leaseState] intValue];
			switch (inRequest->leaseState) {
				case kLeaseBound:
					// if (dontRenew) break;
				case kLeaseBootp:
				case kLeaseOffered:
					// set your addr and return YES
					inRequest->yiaddr = [statusEntry ipAddressInt];
					// get remaining time on this lease for reference
					inRequest->leaseTime = [[statusEntry expireTime] timeIntervalSinceDate:currentTime];
					returnValue = YES;
					break;
				case kLeaseExpired:
				case kLeaseReleased:
					// did client request a different address?
					if ( inRequest->addressRequest != [statusEntry ipAddressInt] ) {
						// refresh display
						[statusEntry setAction:[NSNumber numberWithInt:kActionDelete]];
						[self updateParameterD:[statusEntry key] withObject:statusEntry];
					    // remove entry
						[self writeStatusEntry:[statusEntry keyInt]];
						[[dhcpState statusTable] removeObject:statusEntry];
					    break;
					}
					// lease has expired or been released, check if still valid
					dynamicEntry = [self findDynamicConfigForAddress:[statusEntry ipAddressInt]];
					if (dynamicEntry) {
						// set your addr
						inRequest->yiaddr = [statusEntry ipAddressInt];
						// get remaining time on this lease for reference
						inRequest->leaseTime = [[statusEntry expireTime] timeIntervalSinceDate:currentTime];
						// set to ping since it was released or expired
						if (msg->ciaddr != inRequest->yiaddr) inRequest->needPing = YES;
						returnValue = YES;
					} else {
						// refresh display
						[statusEntry setAction:[NSNumber numberWithInt:kActionDelete]];
						[self updateParameterD:[statusEntry key] withObject:statusEntry];
						// remove entry
						[self writeStatusEntry:[statusEntry keyInt]];
						[[dhcpState statusTable] removeObject:statusEntry];
					}
					break;
			}
			if (returnValue) break;	// return
		}

		// search on requestAddr alone
		statusEntry = [self findStatusForAddress:inLeaseAddr];
		if (statusEntry) {
			// we found a matching lease Addr, but clientID doesn't match
			// if lease is bound remember it's in use.
			leaseState = [[statusEntry leaseState] intValue];
			if ((leaseState == kLeaseBound) ||
				(leaseState == kLeaseBootp) ||
				(leaseState == kLeaseDeclined) ||
				(leaseState == kLeaseInUse)) {
				inUse = YES;
			}
		}
		// if message type is DHCPRequest, only match existing lease bindings
		if (inRequest->dhcpMessageType == kDHCPRequest) break;

		// 
		// (3) Do we have a dynamic address for this request?
		if (inRequest->dhcpMessageType == kDHCPBootp) {
			// check option setting
			if ([[dhcpState dynamicBootp] intValue]) {
				[mLogMessage appendString:@"\rWARNING: no static configuration found for BOOTP request."];
				[mLogMessage appendString:@"\r IPNetRouterX will try to assign a dynamic address,"];
				[mLogMessage appendString:@"\r the BOOTP client may not release this upon lease expiration."];
			}
			else {
				[mLogMessage appendString:@"\r No configuration found for BOOTP request."];
				break;
			}
		}
		// search DHCP dynamic config array
			// is there a request address that's not already bound?
		if (inLeaseAddr && !inUse) {
			// yes, see if we own it
			// search DHCP dynamic config array
			dynamicEntry = [self findDynamicConfigForAddress:inLeaseAddr];
			if (dynamicEntry) {
				// we own it, check for matching Network Interface
				//if (inRequest->netNumber == (dynamicCfgEntry.interfaceAddr & inRequest->netMask)) {
				if (inRequest->netNumber == netNumberForString([dynamicEntry networkInterface], nil, nil)) {
					inRequest->yiaddr = inLeaseAddr;
					if (msg->ciaddr != inRequest->yiaddr) inRequest->needPing = YES;
					returnValue = YES;
					break;
				}
			}
		}

		// no request addr or in use, look for a new addr
		// search DHCP dynamic config array
		oldestAddress = 0;
		oldestUpdate = 0;
		// for each dynamic config record
		tableArray = [[dhcpState dynamicConfigTable] tableArray];
		en = [tableArray objectEnumerator];
		while (dynamicEntry = [en nextObject]) {
			u_int32_t start, end;
			// check for matching interface
			if (  inRequest->netNumber != netNumberForString([dynamicEntry networkInterface], nil, nil) ) continue;
			// try each possible address
			start = [dynamicEntry startingAddressInt];
			end = [dynamicEntry endingAddressInt];
			if (start <= end) {
				u_int32_t leaseAddr;
				for (leaseAddr=start; leaseAddr<=end; leaseAddr++) {
					// check lease record
					statusEntry = [self findStatusForAddress:leaseAddr];
					if (statusEntry) {
						// found a lease record
						leaseState = [[statusEntry leaseState] intValue];
						if ((leaseState == kLeaseReleased) ||
							(leaseState == kLeaseExpired)) {
							// remember oldest released addr available
							int thisUpdate = [[statusEntry lastUpdate] timeIntervalSinceNow];							
							if (thisUpdate < oldestUpdate) {
								oldestUpdate = thisUpdate;
								oldestAddress = leaseAddr;
							}
						}
					} else {
						// no lease record
						// check that leaseAddr is valid for this network
						if (inRequest->netNumber != (leaseAddr & inRequest->netMask)) break;
						// check it's not a static config
						staticEntry = [self findStaticConfigForAddress:leaseAddr];
						if (staticEntry) continue;
						// use it
						inRequest->yiaddr = leaseAddr;
						if (msg->ciaddr != inRequest->yiaddr) inRequest->needPing = YES;
						returnValue = YES;
						break;							
					}
				}
				if (returnValue) break;
			}
		}
		if (returnValue) break;
		// We didn't find an address without a lease record
		// Use the oldest released, or offerred address we found
		if (oldestAddress) {
			inRequest->yiaddr = oldestAddress;
			if (msg->ciaddr != inRequest->yiaddr) inRequest->needPing = YES;
			returnValue = YES;
		}
	} while (NO);
	
	// if we got an address, return YES
	returnValue = (inRequest->yiaddr != 0);
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• FindLeaseTimeForRequest
// ---------------------------------------------------------------------------
// Find an appropriate lease time for this request
- (BOOL)findLeaseTimeForRequest:(dhcp_request_t *)inRequest
{
	BOOL returnValue = NO;
	DHCPLeaseOptionsEntry*  leaseOptionsEntry;
	DHCPMessage_t*			msg;
	u_int8_t*				dp;
	u_int32_t				inAddressTime=0;
	int defaultLeaseTime;
	int maxLeaseTime;

	do {
		// Make sure DHCP is enabled on the local interface that received
		// this request and find corresponding lease data
		msg = (DHCPMessage_t*)inRequest->data;
		dp = inRequest->data;
		// find lease options entry for local interface
		leaseOptionsEntry = [[dhcpState leaseOptionsTable]
			objectForKey:stringForNetNumber(inRequest->localAddr, inRequest->localMask)];
		if (!leaseOptionsEntry) break;
		if (![leaseOptionsEntry dhcpOn]) break; // no record of this interface being DHCP enabled
		// if request specifies a relay server, get corresponding entry
		if (msg->giaddr) {
			leaseOptionsEntry = [self findLeaseOptionsForAddress:msg->giaddr];
			if (!leaseOptionsEntry) break;
			if (![leaseOptionsEntry dhcpOn]) break; // no record of this interface being DHCP enabled
		}
		maxLeaseTime = [[leaseOptionsEntry maxLeaseTime] intValue];
		defaultLeaseTime = [[leaseOptionsEntry defaultLeaseTime] intValue];
		if (defaultLeaseTime > maxLeaseTime) defaultLeaseTime = maxLeaseTime;

		// Get requested addressTime if any
		if (inRequest->addressTime.option) {
			inAddressTime = *(u_int32_t*)&dp[inRequest->addressTime.offset];
			// is request acceptable?
			if (inAddressTime < 60) {   // smallest lease time is 1 minute
				inRequest->leaseTime = 60;
				returnValue = YES;
				break;
			}
			if (inAddressTime < maxLeaseTime) {
				// yes, use it
				inRequest->leaseTime = inAddressTime;
				returnValue = YES;
				break;
			} else {
				// use maximum time allowed
				inRequest->leaseTime = maxLeaseTime;	
				returnValue = YES;
				break;
			}
		}

		// no explicit request
		// client is in RENEWING or REBINDING state
		if ((inRequest->dhcpMessageType == kDHCPRequest) &&
			(inRequest->dhcpServerID == 0) &&
			(inRequest->addressRequest == 0) &&
			(msg->ciaddr == inRequest->yiaddr)) {
			// use default lease time
			inRequest->leaseTime = defaultLeaseTime;
			returnValue = YES;
			[mLogMessage appendString:@"\r RENEW or REBIND, lease time extended"];
			break;				
		}

		if (inRequest->dhcpMessageType == kDHCPDiscover) {
			if (((inRequest->leaseState == kLeaseBound) ||
				 (inRequest->leaseState == kLeaseOffered)) &&
				(inRequest->leaseTime)) {
				// use previously assigned expiration time or maximum allowed whichever is less
				// if previously assigned expiration time is less than 1 minute, use default
				if (inRequest->leaseTime < 60) inRequest->leaseTime = defaultLeaseTime;
				if (inRequest->leaseTime > maxLeaseTime) inRequest->leaseTime = maxLeaseTime;	
				returnValue = YES;
				break;
			}
			else {			
				// use default lease time
				inRequest->leaseTime = defaultLeaseTime;
				returnValue = YES;
				break;
			}	
		}

		// use remaining time if any (from previously bound or offered lease)
		if (inRequest->leaseTime) returnValue = YES;

	} while (NO);
	
	// return YES if we can assign a lease time
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• FindRespondViaForResponse
// ---------------------------------------------------------------------------
// Determine how we should send a response to this request
// Upon return set "respondVia" in inResponse
- (u_int8_t)findRespondViaForResponse:(dhcp_response_t *)inResponse
{
	DHCPMessage_t*	msg;
	u_int8_t		returnValue = kViaNone;
	
	do {
		// setup access to message data
		msg = (DHCPMessage_t*)inResponse->buf;

		// if giaddr is nonzero, send to relay agent
		if (msg->giaddr != 0) {
			returnValue = kViaRelayAgent;
			// if message type is NAK, set Broadcast flag in response
			if (inResponse->dhcpMessageType == kDHCPNack) {
				msg->flags |= kBroadcastFlag;
			}
			break;
		}

		// use broadcast if requested
		if (msg->flags & kBroadcastFlag) {
			returnValue = kViaBroadcast;
			break;
		}

		// giaddr=0; always broadcast NAKs
		if (inResponse->dhcpMessageType == kDHCPNack) {
			returnValue = kViaBroadcast;
			break;
		}

		// use ciaddr if present
		if (inResponse->ciaddr != 0) {
			returnValue = kViaUnicast;
			// Override if (ciaddr != yiaddr)
			// Defensive: some clients include a nonconforming ciaddr
			if (inResponse->ciaddr != inResponse->yiaddr) {
				returnValue = kViaBroadcast;
			}
			break;
		}
		// giaddr and ciaddr are 0
		// broadcast bit is not set
		
		// default to hardware unicast
		returnValue = kViaHardwareUnicast;		

		// if it didn't work the last time, try to broadcast
		if ((inResponse->leaseState == kLeaseOffered) &&
			(inResponse->dhcpMessageType == kDHCPOffer)) {
			// lease binding was previously offerred and not received
			// use broadcast to send subsequent offer
			returnValue = kViaBroadcast;
		}
		if (((inResponse->leaseState == kLeaseBound) || (inResponse->leaseState == kLeaseBootp)) &&
			(inResponse->dhcpMessageType == kDHCPAck)) {
			// lease is already in bound state and we're sending an Ack
			DHCPStatusEntry*	statusEntry;
			// find status entry (lease binding)
			statusEntry = [self findStatusForAddress:inResponse->yiaddr];
			if (statusEntry) {
				// check last update versus current time
				if ([[NSDate psDate] timeIntervalSinceDate:[statusEntry lastUpdate]] < 60) {
					// if last update was less than a minute ago
					// use broadcast to send subsequent ACK
					returnValue = kViaBroadcast;
				}
			}
		}
	} while (NO);	
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• substituteNameServers
// ---------------------------------------------------------------------------
// examine list of name servers to replace "0.0.0.0" with current name server
- (NSString *)substituteNameServers:(NSString *)inString forRequest:(dhcp_request_t *)inRequest
{
	NSString* returnValue = inString;
	NSMutableArray* serverIPs;
	NSString* hostDNS;
	NSString* localDNS;
	NSString* localAddr;
	int i, count;
	u_int32_t address;
	// gateway Name Servers
	hostDNS = [dhcpState hostDNS];
	// local caching DNS?
	localDNS = [dhcpState localDNS];
	localAddr = stringForIP(inRequest->localAddr);
	NSRange range = [localDNS rangeOfString:localAddr];
	if (range.length) {
		// yes, use gateway address
		hostDNS = localAddr;
	}
	// extract list of Name Servers and perform substitution
	serverIPs = [NSMutableArray arrayWithArray:[inString componentsSeparatedByString:@","]];
	count = [serverIPs count];
	if (!count) {
		// replace with NS we found if any
		if (hostDNS) returnValue = hostDNS;
	}
	else {
		for (i=count-1; i>=0; i--) {
			address = ipForString([serverIPs objectAtIndex:i]);
			if (address == 0) {
				// replace with NS we found if any
				if (hostDNS) [serverIPs replaceObjectAtIndex:i withObject:hostDNS];
				else [serverIPs removeObjectAtIndex:i];
				returnValue = [serverIPs componentsJoinedByString:@", "];
				break;
			}
		}
	}
	return returnValue;
}


#pragma mark --- DHCP Logging ---
// ---------------------------------------------------------------------------
//		• LogDHCPRequest
// ---------------------------------------------------------------------------
// Show DHCP request info in log window
- (void)logDHCPRequest:(dhcp_request_t *)inRequest
{
	NSString* dateString;
	dateString = [[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil];
	
	if ([[dhcpState verboseLogging] intValue] > kDHCP_exceptionLogging) {
		[mLogMessage appendFormat:@"\r%@ DHCP ", dateString];
		[mLogMessage appendString:[self stringForMessageType:inRequest->dhcpMessageType]];
		[mLogMessage appendString:@" arrived:"];
		// show address info
		[mLogMessage appendString:@"\r From remote host: "];
		[mLogMessage appendString:stringForIP(inRequest->remoteAddr)];
		if (inRequest->remotePort != 0) {
			[mLogMessage appendFormat:@":%@",stringForInt(inRequest->remotePort)];
		}
		[mLogMessage appendString:@" target: "];
		[mLogMessage appendString:stringForIP(inRequest->localTarget)];
		[mLogMessage appendString:@" received on: "];
		[mLogMessage appendString:stringForIP(inRequest->localAddr)];
		[mLogMessage appendFormat:@":%@",stringForInt(kDHCPServerPort)];
		// verbose logging?	
		if ([[dhcpState verboseLogging] intValue] >= kDHCP_verboseLogging) {
			// show message data
			[self logDHCPMessage:(DHCPMessage_t *)inRequest->data size:inRequest->size];
		}
		else if ([[dhcpState verboseLogging] intValue] >= kDHCP_summaryLogging) {
			// show requested address if any
			if (inRequest->addressRequest) {
				[mLogMessage appendFormat:@"\r request: %@", stringForIP(inRequest->addressRequest)];
			}
			// show clientID if any
			if (inRequest->clientID.option != 0) {
				[mLogMessage appendString:@"\r "];
				[self logDHCPOption:inRequest->clientID.option
					length:inRequest->clientID.len data:&inRequest->data[inRequest->clientID.offset]];
			}
			// show user message if any
			if (inRequest->dhcpMessage.option != 0) {
				[mLogMessage appendString:@"\r "];
				[self logDHCPOption:inRequest->dhcpMessage.option
					length:inRequest->dhcpMessage.len data:&inRequest->data[inRequest->dhcpMessage.offset]];
			}
		}
	}
}

// ---------------------------------------------------------------------------
//		• LogDHCPResponse
// ---------------------------------------------------------------------------
// Show DHCP response info in log window
- (void)logDHCPResponse:(dhcp_response_t *)inResponse
{
	if ([[dhcpState verboseLogging] intValue] > kDHCP_exceptionLogging) {
		DHCPMessage_t* msg;
		msg = (DHCPMessage_t *)inResponse->buf;
		if ([[dhcpState verboseLogging] intValue] >= kDHCP_verboseLogging) [mLogMessage appendString:@"\r"];
		[mLogMessage appendString:@"\rDHCP "];
		[mLogMessage appendString:[self stringForMessageType:inResponse->dhcpMessageType]];
		// show where sent
		switch (inResponse->respondVia) {
			case kViaUnicast:
				[mLogMessage appendString:@" unicast to: "];
				[mLogMessage appendString:stringForIP(inResponse->ciaddr)];
				[mLogMessage appendFormat:@":%@",stringForInt(kDHCPClientPort)];
				break;
			case kViaBroadcast:
				[mLogMessage appendString:@" broadcast"];
				break;
			case kViaHardwareUnicast:
				[mLogMessage appendString:@" hardware unicast to: "];
				[mLogMessage appendString:stringForIP(msg->yiaddr)];
				[mLogMessage appendString:@":"];
				[mLogMessage appendString:stringForInt(kDHCPClientPort)];
				break;
			case kViaRelayAgent:
				[mLogMessage appendString:@" relayed to: "];
				[mLogMessage appendString:stringForIP(msg->giaddr)];
				[mLogMessage appendString:@":"];
				[mLogMessage appendString:stringForInt(kDHCPServerPort)];
				break;
		}		
		if ([[dhcpState verboseLogging] intValue] >= kDHCP_verboseLogging) {
			// data length
			[mLogMessage appendString:@"\r Data length: "];
			[mLogMessage appendString:stringForInt(inResponse->dataLen)];
			// show message data
			[self logDHCPMessage:(DHCPMessage_t *)inResponse->buf size:inResponse->dataLen];
		}
		else {
			// show offered address (if any)
			if (inResponse->yiaddr) [mLogMessage appendFormat:@" (%@)", stringForIP(inResponse->yiaddr)];
		}
	}
}


// ---------------------------------------------------------------------------
//		• LogDHCPMessage
// ---------------------------------------------------------------------------
// Show DHCP message info in log window
- (void)logDHCPMessage:(DHCPMessage_t*)inMessage size:(u_int16_t)inSize
{
	u_int8_t	overload;

	// OP HTYPE HLEN HOPS
	[mLogMessage appendString:@"\r "];
	if (inMessage->op == kBootRequest) [mLogMessage appendString:@"OP=request"];
	if (inMessage->op == kBootReply) [mLogMessage appendString:@"OP=reply"];
	[mLogMessage appendString:@" HTYPE:"];
	[mLogMessage appendString:stringForInt(inMessage->htype)];
	[mLogMessage appendString:@" HLEN:"];
	[mLogMessage appendString:stringForInt(inMessage->hlen)];
	[mLogMessage appendString:@" HOPS:"];
	[mLogMessage appendString:stringForInt(inMessage->hops)];
	// TRANSACTION ID
	[mLogMessage appendString:@"\r TRANSACTION ID: "];
	[mLogMessage appendString:stringForHexInt32(inMessage->xid)];
	// SECONDS FLAGS
	[mLogMessage appendString:@"\r SECONDS: "];
	[mLogMessage appendString:stringForInt(inMessage->secs)];
	if (inMessage->flags & 0x8000) [mLogMessage appendString:@" FLAGS:broadcast"];
	else [mLogMessage appendString:@" FLAGS:none"];
	// CLIENT IP ADDRESS
	[mLogMessage appendString:@"\r Client IP Address: "];
	[mLogMessage appendString:stringForIP(inMessage->ciaddr)];
	// YOUR IP ADDRESS
	[mLogMessage appendString:@"\r Your IP Address: "];
	[mLogMessage appendString:stringForIP(inMessage->yiaddr)];
	// SERVER IP ADDRESS
	[mLogMessage appendString:@"\r Next Server IP Address: "];
	[mLogMessage appendString:stringForIP(inMessage->siaddr)];
	// ROUTER IP ADDRESS
	[mLogMessage appendString:@"\r Relay Agent IP Address: "];
	[mLogMessage appendString:stringForIP(inMessage->giaddr)];
	// CLIENT HARDWARE ADDRESS
	[mLogMessage appendString:@"\r Client Hardware Address: "];
	[mLogMessage appendString:stringForHA16((HardwareAddress16_t*)inMessage->chaddr, inMessage->hlen)];

	// Show options
	u_int32_t	start, end;
	start = 28 + 16 + 64 + 128;
	// check for magic cookie
	if (*((u_int32_t*)inMessage->options) == htonl(0x63825363)) {
		start += 4;
	}
	end = inSize;
	overload = [self logDHCPOptions:inMessage start:start end:end];
	if (overload & 1) {
		// get options from "file"
		start = 28 + 16 + 64;
		end = start + 128;
		[self logDHCPOptions:inMessage start:start end:end];	
	}
	if (overload & 2) {
		// get options from "sname"
		start = 28 + 16;
		end = start + 64;
		[self logDHCPOptions:inMessage start:start end:end];	
	}
	else {
		if (inMessage->sname[0] != 0) {
			[mLogMessage appendString:@"\r SERVER HOST NAME: "];
			[mLogMessage appendFormat:@"%s",inMessage->sname];
		}
	}
}

// ---------------------------------------------------------------------------
//		• LogDHCPOptions
// ---------------------------------------------------------------------------
// Show DHCP options info in log window
// return "Overload" option or zero if not present
- (int)logDHCPOptions:(DHCPMessage_t *)inMessage start:(u_int32_t)start end:(u_int32_t)end
{
	u_int8_t*	dp;	
	u_int8_t	option;
	u_int8_t	len;
	u_int8_t	value;
	u_int8_t	returnValue=0;
	
	dp = (u_int8_t*)inMessage;
	option = kOptionPad;

	while ((option != kOptionEnd) && (start < end)) {
		option = dp[start++];
		if ((option != kOptionPad) && (option != kOptionEnd)) {
			len = dp[start++];
			[mLogMessage appendString:@"\r"];
			value = [self logDHCPOption:option length:len data:&dp[start] ];
			if (value) returnValue = value;
			start += len;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• LogDHCPOption
// ---------------------------------------------------------------------------
// Show DHCP option in log window
// return "Overload" option or zero if not present
- (int)logDHCPOption:(u_int8_t)option length:(u_int8_t)len data:(u_int8_t *)data
{
	u_int8_t	value8;
	u_int16_t	value16;
	u_int32_t	value32;
	int	i;
	int	returnValue = 0;

	if (data) {
		value8  = *(u_int8_t*)data;
		value16 = *(u_int16_t*)data;
		value32 = *(u_int32_t*)data;
	} else {
		value8 = 0;
		value16 = 0;
		value32 = 0;
	}
	
	switch (option) {
		case kOptionPad:
			[mLogMessage appendString:@" optionPad"];
			break;
		case kOptionEnd:
			[mLogMessage appendString:@" optionEnd"];
			break;
		case kOptionSubnetMask:
			[mLogMessage appendString:@" OptionSubnetMask"];
			if (data) {
				[mLogMessage appendString:@": "];
				[mLogMessage appendString:stringForIP(value32)];
			}
			break;
		case kOptionRouters:
			[mLogMessage appendString:@" OptionRouters"];
			if (data) {
				[mLogMessage appendString:@": "];
				for (i=0; i<len; i+=4) {
					value32 = *(u_int32_t*)&data[i];
					[mLogMessage appendString:stringForIP(value32)];
					[mLogMessage appendString:@" "];
				}
			}
			break;
		case kOptionDomainServer:
			[mLogMessage appendString:@" OptionDomainServer"];
			if (data) {
				[mLogMessage appendString:@": "];
				for (i=0; i<len; i+=4) {
					value32 = *(u_int32_t*)&data[i];
					[mLogMessage appendString:stringForIP(value32)];
					[mLogMessage appendString:@" "];
				}
			}
			break;
		case kOptionHostName:
			[mLogMessage appendString:@" OptionHostName"];
			if (data) {
				[mLogMessage appendString:@": "];
				[mLogMessage appendString:[NSString stringWithCString:(char *)data length:len]];
			}
			break;
		case kOptionDomainName:
			[mLogMessage appendString:@" OptionDomainName"];
			if (data) {
				[mLogMessage appendString:@": "];
				[mLogMessage appendString:[NSString stringWithCString:(char *)data length:len]];
			}
			break;
		case kOptionAddressRequest:
			[mLogMessage appendString:@" OptionAddressRequest"];
			if (data) {
				[mLogMessage appendString:@": "];
				[mLogMessage appendString:stringForIP(value32)];
			}
			break;
		case kOptionAddressTime:
			[mLogMessage appendString:@" OptionAddressTime"];
			if (data) {
				[mLogMessage appendFormat:@": %d",value32];
			}
			break;
		case kOptionOverload:
			[mLogMessage appendString:@" OptionOverload"];
			returnValue = value8;
					break;
		case kOptionDHCPMessageType:
			[mLogMessage appendString:@" OptionMessageType: "];
			[mLogMessage appendString:[self stringForMessageType:value8]];
					break;
		case kOptionDHCPServerID:
			[mLogMessage appendString:@" OptionDHCPServerID"];
			if (data) {
				[mLogMessage appendString:@": "];
				[mLogMessage appendString:stringForIP(value32)];
			}
			break;
		case kOptionParameterList:
			{
				u_int8_t	listItem;
				[mLogMessage appendString:@" OptionParameterList: "];
				for (i=0; i<len; i++) {
					listItem = data[i];
					[mLogMessage appendString:[NSString stringWithFormat:@"\r  %d ",listItem]];
					[self logDHCPOption:listItem length:0 data:nil];
				}
			}
			break;
		case kOptionDHCPMessage:
			[mLogMessage appendString:@" OptionDHCPMessage"];
			if (data) {
				[mLogMessage appendString:@": "];
				[mLogMessage appendString:[NSString stringWithCString:(char *)data length:len]];
			}
			break;
		case kOptionDHCPMaxMsgSize:
			[mLogMessage appendString:@" OptionDHCPMaxMsgSize"];
			if (data) {
				[mLogMessage appendFormat:@": %d",value16];
			}
			break;
		case kOptionRenewalTime:
			[mLogMessage appendString:@" OptionRenewalTime"];
			if (value32) {
				[mLogMessage appendFormat:@": %d",value32];
			}
			break;
		case kOptionRebindingTime:
			[mLogMessage appendString:@" OptionRebindingTime"];
			if (data) {
				[mLogMessage appendFormat:@": %d",value32];
			}
			break;
		case kOptionClassID:
			[mLogMessage appendString:@" OptionClassID"];
			if (data) {
				[mLogMessage appendString:@": "];
				[mLogMessage appendString:[NSString stringWithCString:(char *)data length:len]];
			}
			break;
		case kOptionClientID:
			[mLogMessage appendString:@" OptionClientID"];
			if (data) {
				NSData* cData;
				[mLogMessage appendString:@": "];
				cData = [NSData dataWithBytes:data length:len];
				[mLogMessage appendString:addPercentEscapes(cData)];
			}
			break;
		default: {
			// Check of option is defined in Server Options table
			// Show the comment for that option if any
			// Use option type (if available) to display option data
			// Display option type, length, first 16 bytes.
			// If length is a multiple of 4, display as IPv4 address list,
			// otherwise dump as hex.
			// Assume unknown options are in network byte order
			DHCPServerOptionsEntry* serverOptionsEntry;
			NSString* text;
			NSNumber* num;
			int type;
			serverOptionsEntry = [[dhcpState serverOptionsTable] objectForKey:
				[NSString stringWithFormat:@"%d",option]];
			if (serverOptionsEntry) {
				[mLogMessage appendFormat:@" Locally defined server option: %d length: %d ", option, len];
				if (text = [serverOptionsEntry comment]) [mLogMessage appendString:text];
				if (num = [serverOptionsEntry dhcpOptionType]) {
					type = [num intValue];
					if (type == kDhcpOptionTypeText) {
						text = [NSString stringWithCString:(char*)data length:len];
						[mLogMessage appendFormat:@" value: %@",text];
					}
					if (type == kDhcpOptionTypeIPAddress) {
						int i;
						u_int32_t* dp = (u_int32_t*)data;
						int count = len/4;
						if (count) [mLogMessage appendString:@" value: "];
						for (i=0; i<count; i++) {
							value32 = dp[i];
							NTOHL(value32);
							[mLogMessage appendFormat:@"%@ ",stringForIP(value32)];
						}
					}
				}
			}
			else {
				[mLogMessage appendFormat:@" Unrecognized DHCP option: %d length: %d ", option, len];
				// if length is a multiple of 4, show as dotted quads
				if (len % 4 == 0) {
					int i;
					u_int32_t* dp = (u_int32_t*)data;
					int count = len/4;
					if (count > 4) count = 4;
					if (count) [mLogMessage appendString:@" value: "];
					for (i=0; i<count; i++) {
						value32 = dp[i];
						NTOHL(value32);
						[mLogMessage appendFormat:@"%@ ",stringForIP(value32)];
					}
				}
				else {
					// otherwise display as hex
					unsigned char buffer[64];	// message buffer
					PSData inBuf;
					// initialize buffer descriptor
					inBuf.bytes = &buffer[0];
					inBuf.length = sizeof(0);
					inBuf.bufferLength = 64;
					inBuf.offset = 0;	// leave room for message length, type
					// append logging info
					int i;
					int count = len;
					if (count > 16) count = 16;
					for (i=0; i<count; i++) {
						if (i%4 == 0) appendCString(&inBuf, " ");
						appendHexInt(&inBuf, data[i], 2, kOptionUpper);
					}
					text = [NSString stringWithCString:(char*)inBuf.bytes length:inBuf.length];
					[mLogMessage appendFormat:@" value: %@",text];					
				}
			}
		}
		break;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//		• stringForMessageType
// ---------------------------------------------------------------------------
- (NSString *)stringForMessageType:(u_int8_t)inType
{
	NSString* returnValue = nil;
	if (!messageTypes) {
		//const int16_t kDHCPBootp				= 0;
		//const int16_t kDHCPDiscover			= 1;
		//const int16_t kDHCPOffer				= 2;
		//const int16_t kDHCPRequest			= 3;
		//const int16_t kDHCPDecline			= 4;
		//const int16_t kDHCPAck				= 5;
		//const int16_t kDHCPNack				= 6;
		//const int16_t kDHCPRelease			= 7;
		//const int16_t kDHCPInform				= 8;
		messageTypes = [NSArray arrayWithObjects:
			@"BOOTP", @"DISCOVER", @"OFFER", @"REQUEST", @"DECLINE", @"ACK", @"NAK", @"RELEASE", @"INFORM", nil];
		[messageTypes retain];
	}
	if (inType < [messageTypes count]) returnValue = [messageTypes objectAtIndex:inType];
	else returnValue = [NSString stringWithFormat:@"%d",inType];
	return returnValue;
}

@end
