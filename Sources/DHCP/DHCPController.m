//
//  DHCPController.m
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  DHCP client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import "DHCPController.h"
#import "AppSupport.h"
#import "PsClient.h"
#import "DHCPLogger.h"
//#import "DHCPServer.h"
#import "DHCPSupport.h"
#import "PSServer.h"
#import "DHCPState.h"
#import "DocumentSupport.h"
// updateNameServer
#import "SentryModel.h"
#import "InterfaceTable.h"
#import "SystemConfiguration.h"
#import "NameServiceModel.h"
#import "NSDate_Extensions.h"
#import "DHCPServerWindowC.h"

@interface DHCPController (PrivateMethods)
- (void)updateNameServer;
@end

@implementation DHCPController

// ---------------------------------------------------------------------------------
//	¥ init and dealloc
// ---------------------------------------------------------------------------------
+ (DHCPController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[DHCPController allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

- (id) init {
    if (self = [super init]) {
		mClient = nil;
		dhcpState = [[DHCPState alloc] initWithDefaults];
			[dhcpState setRecordChanges:YES];
		callbackTarget = nil;
		dhcpLogger = [DHCPLogger sharedInstance];
		// interface table notifications are configured in SentryState setInterfaceTable
    }
    return self;
}

- (void)dealloc {
	// tell server to terminate
	[mClient startService:kServerTerminate withObject:nil];
	[mClient setCallbackTarget:nil];
    [mClient release];		mClient = nil;

	[self setDhcpState:nil];
	[self setCallbackTarget:nil];
    [super dealloc];
}


// ---------------------------------------------------------------------------------
//	¥ dhcpState
// ---------------------------------------------------------------------------------
- (DHCPState *)dhcpState { return dhcpState; }
- (void)setDhcpState:(DHCPState *)value {
	[value retain];
	[dhcpState release];
	dhcpState = value;
	// mark state as not yet applied
	[dhcpState setApplyPending:[NSNumber numberWithInt:1]];
	// tell window to reload
	[callbackTarget reloadControllerState];
}

// ---------------------------------------------------------------------------------
//	¥ callbackTarget
// ---------------------------------------------------------------------------------
- (id)callbackTarget { return callbackTarget; }
- (void)setCallbackTarget:(id)value {
	//[value retain];
	//[callbackTarget release];
	callbackTarget = value;
}

// ---------------------------------------------------------------------------------
//	¥ receiveNotification:
// ---------------------------------------------------------------------------------
// accept notifications from those we're observing
- (void)receiveNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary = [aNotification userInfo];
	if ([dictionary objectForKey:DS_updateHostDNS]) {
		[self updateNameServer];
	}
}

#pragma mark - talk to server
// ---------------------------------------------------------------------------------
//	¥ connectToExistingServer
// ---------------------------------------------------------------------------------
// Connect to DHCP Server launching it if needed
- (BOOL)connectToExistingServer:(int)limit showActive:(BOOL)doReport
{
	int i;
	id theProxy;

	do {
		if ([mClient isConnected]) {
			if (doReport) [self dhcpShowActive];
			break;
		}
		// release previous mClient since it is not connected
		[mClient release]; mClient = nil;
		// try connecting to server by name using DO 
		for (i=0; i<limit; i++) {
			// request proxy for remote server
			theProxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"sustworksDHCP" host:nil];
			// declare protocol for proxy
			[theProxy setProtocolForProxy:@protocol(ThreadFromController)];
			if (theProxy) {
				mClient = [[PsClient alloc] init];
				[mClient setRemoteServer:theProxy];
				[mClient setCallbackTarget:self];
				if (doReport) {
					// read server state
					[self dhcpShowActive];
					//[mClient startService:kServerShowActive withObject:nil];
					//[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1]];
				}
				break;
			}
			// pause briefly to allow DHCP Server task to start
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
		}
	} while (0);
	if (mClient) return (YES);
	else return (NO);
}


// ---------------------------------------------------------------------------------
//	¥ connectToServer
// ---------------------------------------------------------------------------------
// Connect to DHCP Server launching it if needed
- (BOOL)connectToServer
{
	BOOL toolExists;
	do {
		// try connecting to server by name using DO
		if ([self connectToExistingServer:2 showActive:YES]) break;

		// if server not found
		if (!mClient) {
			// create DHCP Server object running as a detached thread in a separate process
			NSString* path;
			NSMutableArray *args;
			// setup to run tool
			path = [AppSupport toolPathForName:@"DHCPServer_app" fileExists:&toolExists];
			if (!toolExists) break;
			//path = [path stringByAppendingPathComponent:@"/Contents/MacOS/DHCPServer"];
			args = [NSMutableArray arrayWithObjects:@"-dhcp", nil];
			@try {
				// create a task to run a unix tool and capture the output
				[NSTask launchedTaskWithLaunchPath:path arguments:args];
				// pause briefly to allow DHCP Server task to start
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
			}
			@catch( NSException *theException ) {
				//[theException printStackTrace];
				NSLog(@"DHCP Server failed during launch.");
			}

			// try connecting to server by name using DO
			[self connectToExistingServer:20 showActive:NO];

			if (!mClient) {
				NSLog(@"Failure creating DHCP server");
				// could try to kill previous server and relaunch it
			}
		}
	} while (0);
	if (mClient) return (YES);
	else return (NO);
}

// ---------------------------------------------------------------------------
//	¥ receiveDictionary:
// ---------------------------------------------------------------------------
// update parameters passed in dictionary
// Catch exceptions since this might be called by DO proxy.
- (void)receiveDictionary:(NSDictionary *)dictionary
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSEnumerator *en = [dictionary keyEnumerator];
	id key;
	id object;
	BOOL updateStatusTable = NO;	// update status table at end

	@try {
		do {
			if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
				[mClient release]; mClient = nil;
				break;
			}

			while ((key = [en nextObject])) { 
				// code that uses the returned key
				if (![key isKindOfClass:[NSString class]]) continue; 
				object = [dictionary objectForKey:key];
				if (([object isKindOfClass:[NSString class]]) &&
					([@"nil" isEqualTo:object])) object = nil;
				//NSLog(key);
				if ([key isEqualTo:DS_updateHostDNS]) {
					[self updateNameServer];
				}
				// logging
				if ([key isEqualTo:DHCPLoggerNotification]) {
					[dhcpLogger appendMessage:object];
				}
				// status table entry
				if ([object isKindOfClass:[DHCPStatusEntry class]]) {
					DHCPStatusEntry* entry = (DHCPStatusEntry *)object;
					int myAction = [[entry action] intValue];
					if (myAction == kActionUpdate) {
						[[dhcpState statusTable] setObject:entry forKeyInt:[entry keyInt]];
						//int index = [[dhcpState statusTable] setObject:entry forKeyInt:[entry keyInt]];
						//[callbackTarget statusScrollRowToVisible: index];
					}
					else if (myAction == kActionDelete) {
						[[dhcpState statusTable] removeObjectForKeyInt:[entry keyInt]];
					}
					updateStatusTable = YES;
					continue;
				}		
				// display active tables
				else if ([key isEqualTo:DS_statusTableArray]) {
					DHCPStatusTable* table = [dhcpState statusTable];
					[table setTableArray:object];
					[callbackTarget reloadStatusTable];
				}
				else if ([key isEqualTo:DS_staticConfigTableDictionary]) {
					[[dhcpState staticConfigTable] setTableDictionary:object];
					[callbackTarget reloadStaticConfigTable];
				}
				else if ([key isEqualTo:DS_dynamicConfigTableDictionary]) {
					[[dhcpState dynamicConfigTable] setTableDictionary:object];
					[callbackTarget reloadDynamicConfigTable];
				}
				else if ([key isEqualTo:DS_leaseOptionsTableDictionary]) {
					[[dhcpState leaseOptionsTable] setTableDictionary:object];
					[callbackTarget reloadLeaseOptionsTable];
				}
				else if ([key isEqualTo:DS_serverOptionsTableDictionary]) {
					[[dhcpState serverOptionsTable] setTableDictionary:object];
					[callbackTarget reloadServerOptionsTable];
				}			
				// individual states
				else if ([key isEqualTo:DS_dhcpServerOn]) {
					// record actual state from server
					[dhcpState setDhcpServerOn:object];
				}
			}
			// pass it on to delegate
			[callbackTarget receiveDictionary:dictionary];
		} while (0);
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSString* statusInfo = @"Exception during client receiveDictionary";
		NSLog(@"%@",statusInfo);
		[mClient updateParameter:@"statusInfo" withObject:statusInfo];
	}
	if (updateStatusTable) [callbackTarget reloadStatusTable];
    [pool release];
}

#pragma mark -- DHCP --

// ---------------------------------------------------------------------------
//	¥ dhcpServerOn
// ---------------------------------------------------------------------------
// Return NO if we encounter some exception.  Could not connect to server.
- (BOOL)dhcpServerOn:(BOOL)value
{
	BOOL returnValue = YES;
@try {
	if (value) {
#if 0
        // create DHCP Server object running as a detached thread
		if (!mClient) {
			mClient = [[PsClient alloc] init];
			[mClient setCallbackTarget:self];
			[mClient setServerClass:[DHCPServer class]];
		}
		if (![mClient isConnected]) [mClient createNewServer:[DHCPServer class]];
#else
		[self connectToServer];
#endif
		if ([mClient isConnected]) {
			// Apply current settings
			[self dhcpApply:nil];
			// turn server on
			[mClient startService:kServerStart withObject:nil];
			// give the server a chance to start before next request
			[NSThread  sleepUntilDate:[NSDate
				dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
			// request status update
			[self dhcpShowActive];
		}
	}
	else {
		// tell server to terminate and wait for PSServerFinishedNotification
		// if no server connection, look for existing server
		if (!mClient) [self connectToExistingServer:2 showActive:NO];
		// only startService if there is an existing connection (don't try to create one)
		if (mClient) {
			[mClient startService:kServerTerminate withObject:nil];
		}
		// do not attempt force quit because "remoteServer" may no longer be valid
	}
}
@catch( NSException *theException ) {
	// assume server went away, reset to start again
	[mClient release];	mClient = nil;
	returnValue = NO;
}
	return returnValue;
}

// ---------------------------------------------------------------------------
//	¥ abort
// ---------------------------------------------------------------------------
- (void)abort
{
	[mClient startService:kServerTerminate withObject:nil];
	[mClient setCallbackTarget:nil];
	[mClient release];		mClient = nil;
}

// ---------------------------------------------------------------------------
//	¥ dhcpApply:
// ---------------------------------------------------------------------------
// apply setting passed in, or previously read in DHCP state if dictionary is nil
- (void)dhcpApply:(NSDictionary *)setting
{
	if (setting) {
		[mClient startService:kServerApply withObject:setting];
	}
	else {
		NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:20];
//		DHCPState* dhcpState = [[DocumentSupport sharedInstance] dhcpState];
		id object;
		// tell server to apply new state	
		// statusTable (don't download)
		// static Config Table
		object = [[dhcpState staticConfigTable] tableDictionary];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_staticConfigTableDictionary];
		// 
		object = [[dhcpState dynamicConfigTable] tableDictionary];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_dynamicConfigTableDictionary];
		// 
		object = [[dhcpState leaseOptionsTable] tableDictionary];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_leaseOptionsTableDictionary];
		// 
		object = [[dhcpState serverOptionsTable] tableDictionary];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_serverOptionsTableDictionary];
		// 
		object = [dhcpState verboseLogging];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_verboseLogging];
		// 
		object = [dhcpState ignoreBootp];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_ignoreBootp];
		// 
		object = [dhcpState dynamicBootp];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_dynamicBootp];
		// 
		object = [dhcpState pingCheck];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_pingCheck];
		// 
		object = [dhcpState grantedMessage];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_grantedMessage];
		// 
		object = [dhcpState notGrantedMessage];
		if (!object) object = @"nil";
		[dictionary setObject:object forKey:DS_notGrantedMessage];

		[mClient startService:kServerApply withObject:dictionary];
		[dhcpState setApplyPending:[NSNumber numberWithInt:0]];
	}
}

// ---------------------------------------------------------------------------
//	¥ dhcpShowActive
// ---------------------------------------------------------------------------
- (void)dhcpShowActive
{
	NSDictionary* dictionary;
	// tell server to report state
	dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		DS_statusTableArray, DS_statusTableArray,
		DS_staticConfigTableDictionary, DS_staticConfigTableDictionary,
		DS_dynamicConfigTableDictionary, DS_dynamicConfigTableDictionary,
		DS_leaseOptionsTableDictionary, DS_leaseOptionsTableDictionary,
		DS_serverOptionsTableDictionary, DS_serverOptionsTableDictionary,
		DS_dhcpServerOn, DS_dhcpServerOn,
		DS_hostDNS, DS_hostDNS,
		DS_verboseLogging, DS_verboseLogging,
		DS_ignoreBootp, DS_ignoreBootp,
		DS_dynamicBootp, DS_dynamicBootp,
		DS_pingCheck, DS_pingCheck,
		DS_grantedMessage, DS_grantedMessage,
		DS_notGrantedMessage, DS_notGrantedMessage,
		nil];
	[mClient startService:kServerShowActive withObject:dictionary];
}

// ---------------------------------------------------------------------------
//	¥ writeStatus
// ---------------------------------------------------------------------------
- (void)writeStatus
{
	[mClient startService:kServerWriteStatus withObject:nil];
}

// ---------------------------------------------------------------------------
//		¥ updateNameServer
// ---------------------------------------------------------------------------
// update current name servers for gateway machine running IPNetRouterX
- (void)updateNameServer
{
	NSString* serviceID;
	NSArray* serverList;
	NSString* value;
	if ([mClient isConnected]) do {
		// update local caching Name Servers
		NSArray* enabledInternals = [[NameServiceModel sharedInstance] enabledInternals];
		NSString* localDNS = [enabledInternals componentsJoinedByString:@", "];
			// send value to controller
		NSDictionary* info = [NSDictionary dictionaryWithObject:localDNS forKey:DS_localDNS];
		[mClient startService:kServerApply withObject:info];
		
		// try first active interface or NAT interface to lookup corresponding Name Server
		serviceID = [[[InterfaceTable sharedInstance] entryForNat] serviceID];
		serverList = [[SystemConfiguration sharedInstance]
			service:serviceID dataForDictionaryName:@"DNS" key:@"ServerAddresses"];
		if (serverList) {
			value = [serverList componentsJoinedByString:@", "];
			// save in DHCP State
			[dhcpState setHostDNS:value];
			// send value to controller
			NSDictionary* info = [NSDictionary dictionaryWithObject:value forKey:DS_hostDNS];
			[mClient startService:kServerApply withObject:info];
			// tell user
			[callbackTarget receiveDictionary:info];
			[dhcpLogger appendMessage:
				[NSString stringWithFormat:@"\rDHCP Current name server: %@",value]];
			break;
		}
		// use router address instead
		value = [[SystemConfiguration sharedInstance]
			service:serviceID dataForDictionaryName:@"IPv4" key:@"Router"];
		if (value) {
			// save in DHCP State
			[dhcpState setHostDNS:value];
			// send value to controller
			NSDictionary* info = [NSDictionary dictionaryWithObject:value forKey:DS_hostDNS];
			[mClient startService:kServerApply withObject:info];
			// tell user
			[callbackTarget receiveDictionary:info];
			[dhcpLogger appendMessage:
				[NSString stringWithFormat:@"\rDHCP Using router address as name server: %@",value]];
			break;
		}		
		// give up
		[dhcpLogger appendMessage:@"\rDHCPController updateNameServer: no name servers found"];
	} while (false);
}

@end
