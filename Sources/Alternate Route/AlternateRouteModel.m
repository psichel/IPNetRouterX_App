//
//  AlternateRouteModel.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 1/4/07.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//

#include "Test_In_Client.h"
#import "AlternateRouteModel.h"
#import "SentryModel.h"
//#import "SentryState.h"
#import "DocumentSupport.h"
#import "AlternateRouteTable.h"
#import "AppDelegate.h"
#import "SystemConfiguration.h"
#import "IPSupport.h"
#import "HardwareAddress.h"
#import "ICMPController.h"
#import "PSSupport.h"
#import PS_TNKE_INCLUDE
#import "SentryController.h"
#import "SentryLogger.h"
#include <sys/syslog.h>
#if	TEST_IN_CLIENT
#import "kft.h"
#endif

// Globals
NSString *AlternateRouteNotification = @"AlternateRouteNotification";

@interface AlternateRouteModel (PrivateMethods)
- (NSMutableDictionary *)zoneNames;
- (void)setZoneNames:(NSMutableDictionary *)value;
@end

@implementation AlternateRouteModel

// ---------------------------------------------------------------------------------
//	� sharedInstance
// ---------------------------------------------------------------------------------
+ (AlternateRouteModel *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[AlternateRouteModel alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	� init and dealloc
// ---------------------------------------------------------------------------------
- (id) init {
    if (self = [super init]) {
		// instance vars
		sentryState = [[SentryModel sharedInstance] sentryState];
		alternateRouteTable = nil;
    }
    return self;
}

- (void)dealloc {
    [self setAlternateRouteTable:nil];
	[super dealloc];
}

#pragma mark -- save & restore --
// ---------------------------------------------------------------------------------
//	� loadModelFromSaveDictionary
// ---------------------------------------------------------------------------------
- (void)loadModelFromSaveDictionary:(NSDictionary *)saveDictionary
{
	id object;
	AlternateRouteTable *table;
	if (!alternateRouteTable) {
		table = [[[AlternateRouteTable alloc] init] autorelease];
		[self setAlternateRouteTable:table];
	}
	if (object = [saveDictionary objectForKey:kSentryDocument_alternateRouteArray]) {
		[alternateRouteTable loadArrayOfDictionaries:object];
	}
	// notify any listeners
	[self updateParameter:SS_alternateRouteTable withObject:SS_alternateRouteTable];
}

// ---------------------------------------------------------------------------------
//	� saveModelToSaveDictionary
// ---------------------------------------------------------------------------------
- (void)saveModelToSaveDictionary:(NSMutableDictionary *)saveDictionary
{
	[saveDictionary setValue:[alternateRouteTable arrayOfDictionaries]
		forKey:kSentryDocument_alternateRouteArray];
}


#pragma mark -- accessors --
// ---------------------------------------------------------------------------------
//	� alternateRouteTable
// ---------------------------------------------------------------------------------
- (AlternateRouteTable *)alternateRouteTable { return alternateRouteTable; }
- (void)setAlternateRouteTable:(AlternateRouteTable *)value {
	// if setting has changed
	if (value != alternateRouteTable) {
		// update model
		[value retain];
		[alternateRouteTable release];
		alternateRouteTable = value;
		// notify listeners
		[self updateParameter:SS_alternateRouteTable withObject:SS_alternateRouteTable];
	}
}


#pragma mark -- actions --
// ---------------------------------------------------------------------------
//	� alternateRouteSave
// ---------------------------------------------------------------------------
- (void)alternateRouteSave
{
	SentryState *documentState;
//	AlternateRouteTable *routeT;
	documentState = [[DocumentSupport sharedInstance] sentryState];
	// copy model settings to document
//	routeT = [[alternateRouteTable copy] autorelease];
//	[documentState setAlternateRouteTable:routeT];
	[self saveModelToSaveDictionary:[[DocumentSupport sharedInstance] saveDictionary]];
	
	[documentState setAutomaticFailover:[sentryState automaticFailover]];
	[documentState setLoadBalance:[sentryState loadBalance]];
	[documentState setSourceAwareRouting:[sentryState sourceAwareRouting]];
	// perform application save
	[[AppDelegate sharedInstance] saveDocument:self];
	[self updateParameter:@"statusInfo" withObject:@"Settings saved."];
}

// ---------------------------------------------------------------------------
//	� alternateRouteRevert
// ---------------------------------------------------------------------------
- (void)alternateRouteRevert
{
	SentryState *documentState;
//	AlternateRouteTable *routeT;
	documentState = [[DocumentSupport sharedInstance] sentryState];
	// copy document settings to model
//	routeT = [[[documentState alternateRouteTable] copy] autorelease];
//	[self setAlternateRouteTable:routeT];
	[self loadModelFromSaveDictionary:[[DocumentSupport sharedInstance] saveDictionary]];
	
	[sentryState setAutomaticFailover:[documentState automaticFailover]];
	[sentryState setLoadBalance:[documentState loadBalance]];
	[sentryState setSourceAwareRouting:[documentState sourceAwareRouting]];
}

// ---------------------------------------------------------------------------
//	� alternateRouteApply
// ---------------------------------------------------------------------------
// download table to NKE
- (void)alternateRouteApply
{
	int result;
	AlternateRouteTable* table;
	AlternateRouteEntry* entry;
	unsigned char buffer[kUpdateBufferSize];
	ipk_routeUpdate_t* message;
	int sizeLimit;
	int i, j;
	int count;

	// setup interface update message
	message = (ipk_routeUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kRouteUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(KFT_routeEntry_t);
	j = 0;
	// walk route table
	table = [self alternateRouteTable];
	count = [table count];
	for (i=0; i<count; i++) {
		entry = [table objectAtIndex:i];
		// if we found one
		if (entry) {
			// skip inactives
			if ([[entry enabled] intValue] == 0) continue;
			// add to update message
			//memcpy(&message->routeUpdate[j], foundEntry, sizeof(KFT_natEntry_t));
			result = alternateRouteObjectToData(entry, &message->routeUpdate[j]);
			if (result == 0) {
				//message->routeUpdate[j].flags = kNatFlagUpdate;
				message->length += sizeof(KFT_routeEntry_t);
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
	count = PROJECT_routeCount;
	#else
	count = [[SentryController sharedInstance] sendURL:kKFTAlternateRouteCount];
	#endif
	if (count > 0) {
		NSString* tString = [NSString stringWithFormat:@" download %d alternate routes",count];
		[self updateParameter:@"statusInfoAppend" withObject:tString];
	}
	// apply other settings
	sentryState = [[SentryModel sharedInstance] sentryState];
		// automaticFailover
	[[SentryModel sharedInstance] enableAutomaticFailover:[sentryState automaticFailover]];
		// loadBalance
	[[SentryModel sharedInstance] enableLoadBalance:[sentryState loadBalance]];
		// sourceAwareRouting
	[[SentryModel sharedInstance] enableSourceAwareRouting:[sentryState sourceAwareRouting]];
}


#pragma mark -- observer interface --
// ---------------------------------------------------------------------------------
//	� addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:AlternateRouteNotification 
    object:self];
}

// ---------------------------------------------------------------------------------
//	� removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:AlternateRouteNotification
        object:self];
}

// ---------------------------------------------------------------------------------
//	� updateParameter
// ---------------------------------------------------------------------------------
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
    NSDictionary* myDictionary;
	myDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:anObject, name, nil];
	// notify listeners with dictionary
	[[NSNotificationCenter defaultCenter]
		postNotificationName:AlternateRouteNotification
		object:self
		userInfo:myDictionary];		
	[myDictionary release];
	return YES;
}


#pragma mark -- receive data --
// ---------------------------------------------------------------------------------
//	� receiveRouteUpdate:
// ---------------------------------------------------------------------------------
- (void)receiveRouteUpdate:(NSData *)messageData
{
	ipk_routeUpdate_t* updateMessage;
	KFT_routeEntry_t* routeE;
	int j, length, howMany;
	AlternateRouteEntry *tableEntry;
	// update for current message
	updateMessage = (ipk_routeUpdate_t *)[messageData bytes];
	length = updateMessage->length;
	howMany = (length-8)/sizeof(KFT_routeEntry_t);
	for (j=0; j<howMany; j++) {
		// route entry
		routeE = &updateMessage->routeUpdate[j];
		// update stats in table
		tableEntry = [alternateRouteTable routeForGatewayIP:stringForIP(routeE->gatewayIP)];
		if (tableEntry) {
			[tableEntry setActiveConnections:[NSNumber numberWithInt:routeE->activeConnections]];
			[tableEntry setFailedConnections:[NSNumber numberWithInt:routeE->failedConnections]];
		}
	}
	// notify any listeners we have new data
	[self updateParameter:AR_routeEntry withObject:AR_routeEntry];
}


#pragma mark --- NSTableDataSource ---
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [alternateRouteTable count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	AlternateRouteEntry* routeE;
	routeE = [alternateRouteTable objectAtIndex:row];
	return [routeE valueForKey:[tableColumn identifier]];
}

// optional
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	AlternateRouteEntry* routeE;
	NSString* columnID;
	id oldValue;
	
	routeE = [alternateRouteTable objectAtIndex:row];
	columnID = [tableColumn identifier];
	oldValue = [routeE valueForKey:columnID];
	[[oldValue retain] autorelease];
	[routeE setValue:object forKey:columnID];
	// note if value has changed
	if (oldValue) {
		if ([(NSString *)object compare:oldValue] != NSOrderedSame)
			if ([columnID isEqualTo:AR_interface]) [self doInterface:object forRow:row];
			[self updateParameter:AR_routeEntry withObject:routeE];
	}
	else if (object) {
		if ([columnID isEqualTo:AR_interface]) [self doInterface:object forRow:row];
		[self updateParameter:AR_routeEntry withObject:routeE];
	}
}

- (void)doInterface:(NSString *)interface forRow:(int)row
{
	AlternateRouteEntry* routeE;
	NSString* gatewayIP;
	NSString* gatewayHA;
	NSString* serviceID;
	SystemConfiguration* scf = [SystemConfiguration sharedInstance];
	NSString* bsdName = bsdNameForTitle(interface);
	serviceID = [scf serviceIDForInterface:bsdName];
	// look for gatewayIP if any
	gatewayIP = [scf service:serviceID dataForDictionaryName:@"IPv4" key:@"Router"];
	routeE = [alternateRouteTable objectAtIndex:row];
	[routeE setGatewayIP:gatewayIP];
	// look for MAC address
	gatewayHA = hwAddressStringForIPString(gatewayIP);
	if (![gatewayHA length]) {
		// ping address to setup ARP cache
		[[ICMPController sharedInstance] sendPing:ipForString(gatewayIP)];
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
		// try again
		gatewayHA = hwAddressStringForIPString(gatewayIP);
	}
	[routeE setGatewayHA:gatewayHA];
}

@end
