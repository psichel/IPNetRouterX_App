//
//  TrafficDiscoveryModel.m
//  IPNetSentryX
//
//  Created by psichel on Tue Feb 28 2006.
//  Copyright (c) 2006 Sustainable Softworks. All rights reserved.
//
//	Encapsulate collecting traffic discovery info
//
#import "TrafficDiscoveryModel.h"
#import "TDEntry.h"
#import "TrafficDiscoveryWC.h"

#import "TrafficDiscoveryState.h"
#import "SentryLogger.h"
#import "IPValue.h"
#import "IPSupport.h"
#import "IPLookupController.h"
#import "PSHostDictionary.h"
#import "PSServiceDictionary.h"
#import <netinet/in_systm.h>
#import <netinet/in.h>
#import <netinet/ip.h>
#import <netinet/ip_icmp.h>

// Globals
NSString *TDNotification = @"TDNotification";
NSString *TDNewGroup = @"TDNewGroup";

// Private Methods
@interface TrafficDiscoveryModel (PrivateMethods)
- (BOOL)attachUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime;
- (BOOL)deviceUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime;
- (BOOL)serviceUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime;
- (BOOL)netflowUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime;
- (void)localNameStart;
- (void)localNameStop;
@end

@implementation TrafficDiscoveryModel
+ (TrafficDiscoveryModel *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[TrafficDiscoveryModel alloc] init];
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
			// track open TD info files: devices, services, attach
		openFilesDictionary = [[NSMutableDictionary alloc] init];
		if (!openFilesDictionary) return nil;
			// track sorted keys for each open file
		sortedKeysDictionary = [[NSMutableDictionary alloc] init];
		if (!sortedKeysDictionary) return nil;
		sortTableView = nil;
		sortDate = nil;
			// track files that have been written out (saved)
		savedFilesDictionary = [[NSMutableDictionary alloc] init];
		
		firstTime = nil;
		lastUpdateTime = nil;
		lastSaveTime = nil;
		eventTimer = nil;
		lookupController = nil;
		localNameCount = 0;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	� dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	// cancel trafficDiscovery timer
	[self timerStop];
	// release other objects
	[self setSortTableView:nil];
	[self setSortDate:nil];
	[self setFirstTime:nil];
	[self setLastUpdateTime:nil];
	[self setLastSaveTime:nil];
	// lookup controller
	[lookupController release]; lookupController = nil;
    // release collections we allocated
	[openFilesDictionary release]; openFilesDictionary = nil;
	[sortedKeysDictionary release]; sortedKeysDictionary = nil;
	[savedFilesDictionary release]; savedFilesDictionary = nil;
	[super dealloc];
}


#pragma mark -- accessor --
- (NSTableView*)sortTableView { return sortTableView; }
- (void)setSortTableView:(NSTableView*)value {
	[value retain];
	[sortTableView release];
	sortTableView = value;
}

- (NSCalendarDate*)sortDate { return sortDate; }
- (void)setSortDate:(NSCalendarDate*)value {
	[value retain];
	[sortDate release];
	sortDate = value;
}
- (NSCalendarDate*)firstTime { return firstTime; }
- (void)setFirstTime:(NSCalendarDate*)value {
	[value retain];
	[firstTime release];
	firstTime = value;
}

- (NSCalendarDate*)lastUpdateTime { return lastUpdateTime; }
- (void)setLastUpdateTime:(NSCalendarDate*)value {
	[value retain];
	[lastUpdateTime release];
	lastUpdateTime = value;
}

- (NSCalendarDate*)lastSaveTime { return lastSaveTime; }
- (void)setLastSaveTime:(NSCalendarDate*)value {
	[value retain];
	[lastSaveTime release];
	lastSaveTime = value;
}

#pragma mark -- receive data --
// ---------------------------------------------------------------------------------
//	� receiveTrafficUpdate:
// ---------------------------------------------------------------------------------
- (void)receiveTrafficUpdate:(NSData *)messageData
{
	{
		ipk_trafficUpdate_t* updateMessage;
		KFT_trafficEntry_t* tEntry;
		NSCalendarDate* trafficDiscoveryTime = lastUpdateTime;;
		int j, length, howMany;
		// update for current message
		updateMessage = (ipk_trafficUpdate_t *)[messageData bytes];
		length = updateMessage->length;
		howMany = (length-8)/sizeof(KFT_trafficEntry_t);
		for (j=0; j<howMany; j++) {
			tEntry = &updateMessage->trafficUpdate[j];
			trafficDiscoveryTime = [NSCalendarDate dateWithTimeIntervalSince1970:tEntry->trafficDiscoveryTime];
			// if nothing previosly saved, save at end of current interval
			if (!lastSaveTime) [self setLastSaveTime:[NSCalendarDate date]];
			// end of interval reached?
			//if ([trafficDiscoveryTime minuteOfHour] != [lastSaveTime minuteOfHour]) {
			if ([trafficDiscoveryTime dayOfYear] != [lastSaveTime dayOfYear]) {
				// any new updates to save?
				if ([lastUpdateTime timeIntervalSinceDate:lastSaveTime] > 0)
					// save previously recorded
					[self trafficDiscoverySaveForDate:lastUpdateTime];
					NSLog(@"Saving TrafficDiscovery data for date: %@",lastUpdateTime);
			}
			// any saved files we can close?
			if ([savedFilesDictionary count]) {
				NSString* fileName;
				NSCalendarDate* when;
				NSEnumerator* en = [savedFilesDictionary keyEnumerator];
				while (fileName = [en nextObject]) {
					when = [savedFilesDictionary objectForKey:fileName];
					if (-[when timeIntervalSinceNow] > 3600) {
						[openFilesDictionary removeObjectForKey:fileName];
						[savedFilesDictionary removeObjectForKey:fileName];
					}
				}
			}
			// record first time if needed
			if (!firstTime) [self setFirstTime:trafficDiscoveryTime];
			NS_DURING
				// record current sample data
				if (tEntry->attachInfo) {
					[self attachUpdate:tEntry forDate:trafficDiscoveryTime];
				}
				else {
					TrafficDiscoveryState* tds = [TrafficDiscoveryState sharedInstance];
					if ([[tds tdDevice] intValue]) [self deviceUpdate:tEntry forDate:trafficDiscoveryTime];
					if ([[tds tdService] intValue]) [self serviceUpdate:tEntry forDate:trafficDiscoveryTime];
					if ([[tds tdNetflow] intValue]) [self netflowUpdate:tEntry forDate:trafficDiscoveryTime];
				}
			NS_HANDLER
				NSLog(@"exception during receiveTrafficUpdate");
			NS_ENDHANDLER
		}
		// record lastUpdateTime
		if (howMany > 0) [self setLastUpdateTime:trafficDiscoveryTime];
		// last message of sequence?
		if (updateMessage->flags & kFlag_end) {
			// synchronize our own timer by setting fireDate
			if (eventTimer) {
				[eventTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:1.1]];
			}
			// notify any listeners traffic data has been updated
			[self updateParameter:@"dateField" withObject:trafficDiscoveryTime];
			[self updateParameter:TDNotification withObject:TDNotification];
		}
	}
}

// ---------------------------------------------------------------------------------
//	� attachUpdate
// ---------------------------------------------------------------------------------
- (BOOL)attachUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime
{
	BOOL returnValue = NO;
	NSString* fileName;
	NSMutableDictionary* plist;
	NSString* attachID;
	TDDayGroup* dayGroup;
	TDHourGroup* hourGroup;
	TDMinuteGroup* minuteGroup;

	do {		
		// get attach info
		fileName = fileNameWithDate(kFileAttach, trafficDiscoveryTime);
		plist = [openFilesDictionary objectForKey:fileName];
		if (!plist) {	// try to read it
			[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
			plist = [openFilesDictionary objectForKey:fileName];
		}
		if (!plist) {	// try to allocate it
			plist = [[[NSMutableDictionary alloc] init] autorelease];
			[openFilesDictionary setObject:plist forKey:fileName];
			if (!plist) break;
		}
		[self rememberUpdateToFile:fileName];
		// attach identification
		attachID = [NSString stringWithCString:tEntry->bsdName encoding:NSUTF8StringEncoding];
		// find corresponding group for entry
		dayGroup = [plist objectForKey:attachID];
		if (!dayGroup) {
			dayGroup = [[[TDDayGroup alloc] init] autorelease];
			if (!dayGroup) break;
			[dayGroup setName:attachID];
			[plist setObject:dayGroup forKey:attachID];	// dayGroup is retained
		}
		hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:YES];
		minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:YES];
		// add sample to minuteGroup
		[minuteGroup addSample:tEntry forDate:trafficDiscoveryTime];
		[dayGroup setLastTime:trafficDiscoveryTime];
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� deviceUpdate
// ---------------------------------------------------------------------------------
- (BOOL)deviceUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime
{
	BOOL returnValue = NO;
	NSString* deviceID;
	TDDayGroup* dayGroup;
	TDHourGroup* hourGroup;
	TDMinuteGroup* minuteGroup;
	NSString* fileName;
	NSMutableDictionary* plist;
	do {		
		// get device info
		fileName = fileNameWithDate(kFileDevice, trafficDiscoveryTime);
		plist = [openFilesDictionary objectForKey:fileName];
		if (!plist) {	// try to read it
			[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
			plist = [openFilesDictionary objectForKey:fileName];
		}
		if (!plist) {	// try to allocate it
			plist = [[[NSMutableDictionary alloc] init] autorelease];
			[openFilesDictionary setObject:plist forKey:fileName];
			if (!plist) break;
		}
		[self rememberUpdateToFile:fileName];
		// remote device identification
		deviceID = stringForIP(tEntry->remote.address);
		// find corresponding group for entry
		dayGroup = [plist objectForKey:deviceID];
		if (!dayGroup) {
			dayGroup = [[[TDDayGroup alloc] init] autorelease];
			if (!dayGroup) break;
			[dayGroup setIdentifier:deviceID];
			[plist setObject:dayGroup forKey:deviceID];	// dayGroup is retained
			// initialize dayGroup
			[dayGroup setBsdName:[NSString stringWithCString:tEntry->bsdName encoding:NSUTF8StringEncoding]];
			[dayGroup setLocalEP:0];
			[dayGroup setProtocol:tEntry->remote.protocol];
			[dayGroup setViewBy:kViewByDevice];
			[dayGroup setInfo:@""];
			// lookup device name
			NSString* deviceName;
			// Bonjour/Rendezvous local device?
			deviceName = [[PSHostDictionary sharedInstance] hostNameForAddress:deviceID];
			if (deviceName) {
				[dayGroup setName:[NSString stringWithFormat:@"%@.local",deviceName]];
			}
			else {
				// get a lookup controller if needed
				if (lookupController == nil) {
					lookupController = [[IPLookupController alloc] init];
					[lookupController setOption:kOption_resultOnly];
				}
				// request lookup
				NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
					deviceID,@"identifier",
					trafficDiscoveryTime,@"trafficDiscoveryTime",nil];		
				[lookupController lookup:deviceID callbackObject:self
					withSelector:@selector(lookupCompleted:)
					userInfo:aDictionary];
			}
			// re-index device keys for currently open file
			[sortedKeysDictionary removeObjectForKey:fileName];
		}
		hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:YES];
		minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:YES];
		// add sample to minuteGroup
		[minuteGroup addSample:tEntry forDate:trafficDiscoveryTime];
		[dayGroup setLastTime:trafficDiscoveryTime];
		
		// local device identification
		deviceID = stringForIP(tEntry->local.address);
		// find corresponding group for entry
		dayGroup = [plist objectForKey:deviceID];
		if (!dayGroup) {
			dayGroup = [[[TDDayGroup alloc] init] autorelease];
			if (!dayGroup) break;
			[dayGroup setIdentifier:deviceID];
			[plist setObject:dayGroup forKey:deviceID];
			// initialize dayGroup
			[dayGroup setBsdName:[NSString stringWithCString:tEntry->bsdName encoding:NSUTF8StringEncoding]];
			[dayGroup setLocalEP:1];
			[dayGroup setProtocol:tEntry->local.protocol];
			[dayGroup setViewBy:kViewByDevice];
			[dayGroup setInfo:@"local"];
			// lookup device name
			NSString* deviceName;
			// Bonjour/Rendezvous local device?
			deviceName = [[PSHostDictionary sharedInstance] hostNameForAddress:deviceID];
			if (deviceName) {
				[dayGroup setName:[NSString stringWithFormat:@"%@.local",deviceName]];
			}
			else {
				// get a lookup controller if needed
				if (lookupController == nil) {
					lookupController = [[IPLookupController alloc] init];
					[lookupController setOption:kOption_resultOnly];
				}
				// request lookup
				NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
					deviceID,@"identifier",
					trafficDiscoveryTime,@"trafficDiscoveryTime",nil];
				[lookupController lookup:deviceID callbackObject:self
					withSelector:@selector(lookupCompleted:)
					userInfo:aDictionary];
			}
			// re-index device keys for currently open file
			[sortedKeysDictionary removeObjectForKey:fileName];
		}
		hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:YES];
		minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:YES];
		// add sample to minuteGroup
		[minuteGroup addSample:tEntry forDate:trafficDiscoveryTime];
		[dayGroup setLastTime:trafficDiscoveryTime];
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� serviceUpdate
// ---------------------------------------------------------------------------------
- (BOOL)serviceUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime
{
	BOOL returnValue = NO;
	NSString* serviceID;
	TDDayGroup* dayGroup;
	TDHourGroup* hourGroup;
	TDMinuteGroup* minuteGroup;
	NSString* fileName;
	NSMutableDictionary* plist;
	BOOL validPorts = NO;
	do {		
		// get service info
		fileName = fileNameWithDate(kFileService, trafficDiscoveryTime);
		plist = [openFilesDictionary objectForKey:fileName];
		if (!plist) {	// try to read it
			[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
			plist = [openFilesDictionary objectForKey:fileName];
		}
		if (!plist) {	// try to allocate it
			plist = [[[NSMutableDictionary alloc] init] autorelease];
			[openFilesDictionary setObject:plist forKey:fileName];
			if (!plist) break;
		}
		[self rememberUpdateToFile:fileName];
		// remote service identification
		if (tEntry->remote.port < 32768) {
			// serviceID includes both protocol and port
			switch (tEntry->remote.protocol) {
				case IPPROTO_TCP:
					serviceID = [NSString stringWithFormat:@"tcp %d",tEntry->remote.port];
					validPorts = YES;
					break;
				case IPPROTO_UDP:
					serviceID = [NSString stringWithFormat:@"udp %d",tEntry->remote.port];
					validPorts = YES;
					break;
				case IPPROTO_ICMP:
					serviceID = [NSString stringWithFormat:@"icmp(%d,%d)",tEntry->icmpType,tEntry->icmpCode];
					break;
				case IPPROTO_IGMP:
					serviceID = [NSString stringWithFormat:@"igmp"];
					break;
				case IPPROTO_GRE:
					serviceID = [NSString stringWithFormat:@"gre"];
					break;
				default:
					serviceID = [NSString stringWithFormat:@"ip%d",tEntry->remote.protocol];
					break;
			}
			// find corresponding group for entry
			dayGroup = [plist objectForKey:serviceID];
			if (!dayGroup) {
				dayGroup = [[[TDDayGroup alloc] init] autorelease];
				if (!dayGroup) break;
				[dayGroup setIdentifier:serviceID];
				[plist setObject:dayGroup forKey:serviceID];	// dayGroup is retained
				// initialize dayGroup
				[dayGroup setBsdName:[NSString stringWithCString:tEntry->bsdName encoding:NSUTF8StringEncoding]];
				[dayGroup setLocalEP:0];
				[dayGroup setProtocol:tEntry->remote.protocol];
				[dayGroup setViewBy:kViewByService];
				// info
				if (validPorts && (tEntry->local.port == tEntry->remote.port)) [dayGroup setInfo:@"local"];
				else  [dayGroup setInfo:@""];
				// name
				NSString* serviceName = nil;
				int port = tEntry->remote.port;
				serviceName = [[PSServiceDictionary sharedInstance]
					serviceNameForPort:port protocol:tEntry->remote.protocol];
				if (!serviceName) {
					if (tEntry->remote.protocol == IPPROTO_ICMP) {
						int type = tEntry->icmpType;
						if (type == ICMP_ECHO) serviceName = @"echo request";
						else if (type == ICMP_ECHOREPLY) serviceName = @"echo reply";
						else if (type == ICMP_UNREACH) serviceName = @"unreachable";
						else if (type == ICMP_SOURCEQUENCH) serviceName = @"source quench";
						else if (type == ICMP_REDIRECT) serviceName = @"redirect";
						else if (type == ICMP_TIMXCEED) serviceName = @"time exceeded";
					}
					else {
						serviceName = serviceID;
					}
				}
				[dayGroup setName:serviceName];
				// re-index service keys for currently open file
				[sortedKeysDictionary removeObjectForKey:fileName];
			}
			hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:YES];
			minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:YES];
			// add sample to minuteGroup
			[minuteGroup addSample:tEntry forDate:trafficDiscoveryTime];
			[dayGroup setLastTime:trafficDiscoveryTime];
		}
		
		// local service identification
			// don't count the same traffic twice if local.port == remote.port
		if ((tEntry->local.port < 32768) && validPorts && (tEntry->local.port != tEntry->remote.port)) {
			// serviceID includes both protocol and port
			switch (tEntry->local.protocol) {
				case IPPROTO_TCP:
					serviceID = [NSString stringWithFormat:@"tcp %d",tEntry->local.port];
					break;
				case IPPROTO_UDP:
					serviceID = [NSString stringWithFormat:@"udp %d",tEntry->local.port];
					break;
				case IPPROTO_ICMP:
					serviceID = [NSString stringWithFormat:@"icmp(%d,%d)",tEntry->icmpType,tEntry->icmpCode];
					break;
				case IPPROTO_IGMP:
					serviceID = [NSString stringWithFormat:@"igmp"];
					break;
				case IPPROTO_GRE:
					serviceID = [NSString stringWithFormat:@"gre"];
					break;
				default:
					serviceID = [NSString stringWithFormat:@"ip%d",tEntry->local.protocol];
					break;
			}
			// find corresponding group for entry
			dayGroup = [plist objectForKey:serviceID];
			if (!dayGroup) {
				dayGroup = [[[TDDayGroup alloc] init] autorelease];
				if (!dayGroup) break;
				[dayGroup setIdentifier:serviceID];
				[plist setObject:dayGroup forKey:serviceID];
				// initialize dayGroup
				[dayGroup setBsdName:[NSString stringWithCString:tEntry->bsdName encoding:NSUTF8StringEncoding]];
				[dayGroup setLocalEP:1];
				[dayGroup setProtocol:tEntry->local.protocol];
				[dayGroup setViewBy:kViewByService];
				// info
				[dayGroup setInfo:@"local"];
				// name
				NSString* serviceName = nil;
				int port = tEntry->local.port;
				serviceName = [[PSServiceDictionary sharedInstance]
					serviceNameForPort:port protocol:tEntry->local.protocol];
				if (!serviceName) serviceName = serviceID;
				[dayGroup setName:serviceName];
				// re-index service keys for currently open file
				[sortedKeysDictionary removeObjectForKey:fileName];
			}
			hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:YES];
			minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:YES];
			// add sample to minuteGroup
			[minuteGroup addSample:tEntry forDate:trafficDiscoveryTime];
			[dayGroup setLastTime:trafficDiscoveryTime];
		}
	} while (false);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	� netflowUpdate
// ---------------------------------------------------------------------------------
- (BOOL)netflowUpdate:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime
{
	BOOL returnValue = NO;
	NSString* netflowID;
	TDDayGroup* dayGroup;
	TDHourGroup* hourGroup;
	TDMinuteGroup* minuteGroup;
	NSString* fileName;
	NSMutableDictionary* plist;
	do {		
		// get netflow info
		fileName = fileNameWithDate(kFileNetflow, trafficDiscoveryTime);
		plist = [openFilesDictionary objectForKey:fileName];
		if (!plist) {	// try to read it
			[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
			plist = [openFilesDictionary objectForKey:fileName];
		}
		if (!plist) {	// try to allocate it
			plist = [[[NSMutableDictionary alloc] init] autorelease];
			[openFilesDictionary setObject:plist forKey:fileName];
			if (!plist) break;
		}
		[self rememberUpdateToFile:fileName];
		// netflow identification includes both protocol and port information
		switch (tEntry->remote.protocol) {
			case IPPROTO_TCP:
				netflowID = [NSString stringWithFormat:@"%@:%d=>%@:%d tcp",
					stringForIP(tEntry->local.address),tEntry->local.port,
					stringForIP(tEntry->remote.address),tEntry->remote.port];
				break;
			case IPPROTO_UDP:
				netflowID = [NSString stringWithFormat:@"%@:%d=>%@:%d udp",
					stringForIP(tEntry->local.address),tEntry->local.port,
					stringForIP(tEntry->remote.address),tEntry->remote.port];
				break;
			case IPPROTO_ICMP:
				netflowID = [NSString stringWithFormat:@"%@=>%@ icmp(%d,%d)",
					stringForIP(tEntry->local.address),
					stringForIP(tEntry->remote.address),
					tEntry->icmpType, tEntry->icmpCode];
				break;
			case IPPROTO_IGMP:
				netflowID = [NSString stringWithFormat:@"%@=>%@ igmp",
					stringForIP(tEntry->local.address),
					stringForIP(tEntry->remote.address)];
				break;
			case IPPROTO_GRE:
				netflowID = [NSString stringWithFormat:@"%@=>%@ gre",
					stringForIP(tEntry->local.address),
					stringForIP(tEntry->remote.address)];
				break;
			default:
				netflowID = [NSString stringWithFormat:@"%@=>%@ ip%d",
					stringForIP(tEntry->local.address),
					stringForIP(tEntry->remote.address),
					tEntry->remote.protocol];
				break;
		}

		// find corresponding group for entry
		dayGroup = [plist objectForKey:netflowID];
		if (!dayGroup) {
			dayGroup = [[[TDDayGroup alloc] init] autorelease];
			if (!dayGroup) break;
			[dayGroup setIdentifier:netflowID];
			[plist setObject:dayGroup forKey:netflowID];	// dayGroup is retained
			// initialize dayGroup
			[dayGroup setBsdName:[NSString stringWithCString:tEntry->bsdName encoding:NSUTF8StringEncoding]];
			[dayGroup setLocalEP:0];
			int protocol = tEntry->remote.protocol;
			[dayGroup setProtocol:protocol];
			[dayGroup setViewBy:kViewByNetflow];
			// info
			if (protocol == IPPROTO_TCP) [dayGroup setInfo:@"tcp"];
			else if (protocol == IPPROTO_UDP) [dayGroup setInfo:@"udp"];
			else if (protocol == IPPROTO_ICMP) [dayGroup setInfo:@"icmp"];
			else if (protocol == IPPROTO_IGMP) [dayGroup setInfo:@"igmp"];
			else if (protocol == IPPROTO_GRE) [dayGroup setInfo:@"gre"];
			else [dayGroup setInfo:[NSString stringWithFormat:@"ip%d",protocol]];
			// name
			NSString* serviceName = nil;
			int port;
			if (tEntry->remote.port < 32768) port = tEntry->remote.port;
			else port = tEntry->local.port;
			serviceName = [[PSServiceDictionary sharedInstance]
				serviceNameForPort:port protocol:protocol];
			if (!serviceName) {
				if (protocol == IPPROTO_ICMP) {
					int type = tEntry->icmpType;
					if (type == ICMP_ECHO) serviceName = @"echo request";
					else if (type == ICMP_ECHOREPLY) serviceName = @"echo reply";
					else if (type == ICMP_UNREACH) serviceName = @"unreachable";
					else if (type == ICMP_SOURCEQUENCH) serviceName = @"source quench";
					else if (type == ICMP_REDIRECT) serviceName = @"redirect";
					else if (type == ICMP_TIMXCEED) serviceName = @"time exceeded";
				}
				else {
					if (protocol == IPPROTO_TCP) serviceName = [NSString stringWithFormat:@"tcp %d",port];
					else if (protocol == IPPROTO_UDP) serviceName = [NSString stringWithFormat:@"udp %d",port];
					else if (protocol == IPPROTO_IGMP) serviceName = @"igmp";
					else if (protocol == IPPROTO_GRE) serviceName = @"gre";
					//else returnValue = [NSString stringWithFormat:@"%d",port];
				}
			}
			[dayGroup setName:serviceName];
			// re-index netflow keys for currently open file
			[sortedKeysDictionary removeObjectForKey:fileName];
		}
		hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:YES];
		minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:YES];
		// add sample to minuteGroup
		[minuteGroup addSample:tEntry forDate:trafficDiscoveryTime];
		[dayGroup setLastTime:trafficDiscoveryTime];
	} while (false);
	return returnValue;
}

#pragma mark -- event notification --
// ---------------------------------------------------------------------------------
//	� enableTD
// ---------------------------------------------------------------------------------
- (void)enableTD:(BOOL)value
{
	if (value) {
		// start eventTimer to notify any listeners
		[self timerStart];
		[self localNameStart];
	}
	else {
		// disable eventTimer to notify any listeners
		[self timerStop];
		[self localNameStop];
	}
}

// ---------------------------------------------------------------------------------
//	� timerStart
// ---------------------------------------------------------------------------------
// start timer used to walk through recorded data or advance showDate when no
// activity is reported from NKE
- (void)timerStart
{
	if (!eventTimer) {
		eventTimer = [NSTimer
			scheduledTimerWithTimeInterval:1.0
			target:self
			selector:@selector(eventTimer:)
			userInfo:nil
			repeats:YES];
	}
}

// ---------------------------------------------------------------------------------
//	� timerStop
// ---------------------------------------------------------------------------------
- (void)timerStop
{
	// cancel eventTimer timer
	[eventTimer invalidate];	eventTimer= nil;
}

// ---------------------------------------------------------------------------------
//	� eventTimer
// ---------------------------------------------------------------------------------
- (void)eventTimer:(id)timer
{
	// notify any listeners traffic data has been updated
	[self updateParameter:@"eventTimer" withObject:@"eventTimer"];
	// local name resolving
	localNameCount++;
	if (localNameCount == 5) [self localNameStop];
}

// ---------------------------------------------------------------------------------
//	� localNameStart
// ---------------------------------------------------------------------------------
- (void)localNameStart
{
	localNameCount = 0;
	[[PSHostDictionary sharedInstance] startUpdate];
}
// ---------------------------------------------------------------------------------
//	� localNameStop
// ---------------------------------------------------------------------------------
- (void)localNameStop
{
	[[PSHostDictionary sharedInstance] stopUpdate];
}

// ---------------------------------------------------------------------------------
//	� addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:TDNotification 
    object:self];
	// start eventTimer to notify any observers
	[self timerStart];
	[self localNameStart];
}

// ---------------------------------------------------------------------------------
//	� removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:TDNotification
        object:self];
}

// ---------------------------------------------------------------------------------
//	� updateParameter
// ---------------------------------------------------------------------------------
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
    NSDictionary* myDictionary;
	if (name && anObject) {
		// notify listeners with dictionary
		myDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:anObject, name, nil];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TDNotification
			object:self
			userInfo:myDictionary];		
		[myDictionary release];
	}
	return YES;
}

#pragma mark -- file I/O --
// ---------------------------------------------------------------------------------
//	� trafficDiscoverySaveForDate
// ---------------------------------------------------------------------------------
// write out traffic discovery data for date
- (void)trafficDiscoverySaveForDate:(NSCalendarDate *)inDate
{
	NSString* fileName;
	NSMutableDictionary* plist;
	NSData* fileData;
	NSString* errorDescription = nil;
	NSString* str;
	NSCalendarDate* saveTime = [NSCalendarDate date];
	
	if (!inDate) inDate = lastUpdateTime;
	if (!inDate) return;
	// device info
	fileName = fileNameWithDate(kFileDevice, inDate);
		str = [NSString stringWithFormat:@"Saving %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	plist = [openFilesDictionary objectForKey:fileName];
	if ([plist count]) {
		NS_DURING
			plist = [self tdInfoDictionaryFromObject:plist];
			fileData = [NSPropertyListSerialization dataFromPropertyList:plist
				format:NSPropertyListBinaryFormat_v1_0
				errorDescription:&errorDescription];
			// write out trafficDiscovery info
			if (fileData) {
				if ([self writeToFile:fileData withName:fileName]) {
					// if write succeeded, add to list
					[savedFilesDictionary setObject:saveTime forKey:fileName];
				}
			}
			else if (errorDescription) NSLog(@"%@",errorDescription);
		NS_HANDLER
		NS_ENDHANDLER
	}
	// service info
	fileName = fileNameWithDate(kFileService, inDate);
		str = [NSString stringWithFormat:@"Saving %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	plist = [openFilesDictionary objectForKey:fileName];
	if ([plist count]) {
		NS_DURING
			plist = [self tdInfoDictionaryFromObject:plist];
			fileData = [NSPropertyListSerialization dataFromPropertyList:plist
				format:NSPropertyListBinaryFormat_v1_0
				errorDescription:&errorDescription];
			// write out trafficDiscovery info
			if (fileData) {
				if ([self writeToFile:fileData withName:fileName]) {
					// if write succeeded, add to list
					[savedFilesDictionary setObject:saveTime forKey:fileName];
				}
			}
			else if (errorDescription) NSLog(@"%@",errorDescription);
		NS_HANDLER
		NS_ENDHANDLER
	}
	// netflow info
	fileName = fileNameWithDate(kFileNetflow, inDate);
		str = [NSString stringWithFormat:@"Saving %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	plist = [openFilesDictionary objectForKey:fileName];
	if ([plist count]) {
		NS_DURING
			plist = [self tdInfoDictionaryFromObject:plist];
			fileData = [NSPropertyListSerialization dataFromPropertyList:plist
				format:NSPropertyListBinaryFormat_v1_0
				errorDescription:&errorDescription];
			// write out trafficDiscovery info
			if (fileData) {
				if ([self writeToFile:fileData withName:fileName]) {
					// if write succeeded, add to list
					[savedFilesDictionary setObject:saveTime forKey:fileName];
				}
			}
			else if (errorDescription) NSLog(@"%@",errorDescription);
		NS_HANDLER
		NS_ENDHANDLER
	}
	// attach info
	fileName = fileNameWithDate(kFileAttach, inDate);
		str = [NSString stringWithFormat:@"Saving %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	plist = [openFilesDictionary objectForKey:fileName];
	if ([plist count]) {
		NS_DURING
			plist = [self tdInfoDictionaryFromObject:plist];
			fileData = [NSPropertyListSerialization dataFromPropertyList:plist
				format:NSPropertyListBinaryFormat_v1_0
				errorDescription:&errorDescription];
			// write out trafficDiscovery info
			if (fileData) {
				if ([self writeToFile:fileData withName:fileName]) {
					// if write succeeded, add to list
					[savedFilesDictionary setObject:saveTime forKey:fileName];
				}
			}
			else if (errorDescription) NSLog(@"%@",errorDescription);
		NS_HANDLER
		NS_ENDHANDLER
	}
	// update for next time
	[self setLastSaveTime:saveTime];	// when the save occured vs what was saved
	[self updateParameter:@"statusInfo" withObject:@"Save done."];
}

// ---------------------------------------------------------------------------------
//	� trafficDiscoveryReadForDate
// ---------------------------------------------------------------------------------
// read traffic discovery data for date
- (void)trafficDiscoveryReadForDate:(NSCalendarDate *)inDate
{
	NSString* fileName;
	NSData* fileData;
	NSPropertyListFormat format;
	NSString* errorDescription;
	id plist;
	NSString* str;
	
	// device info
	fileName = fileNameWithDate(kFileDevice, inDate);
		str = [NSString stringWithFormat:@"Reading %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	fileData = [self readFromFile:fileName];
	if (fileData) {
		NS_DURING
			errorDescription = nil;
			plist = [NSPropertyListSerialization propertyListFromData:fileData
				mutabilityOption:kCFPropertyListMutableContainers
				format:&format
				errorDescription:&errorDescription];
			if (errorDescription) {
				NSLog(@"%@",errorDescription);
				[errorDescription release];
			}
			if (plist) {
				[openFilesDictionary setObject:[self tdInfoObjectFromDictionary:plist] forKey:fileName];
				[self rememberAccessToFile:fileName];
			}
		NS_HANDLER
		NS_ENDHANDLER
	}
	// service info
	fileName = fileNameWithDate(kFileService, inDate);
		str = [NSString stringWithFormat:@"Reading %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	fileData = [self readFromFile:fileName];
	if (fileData) {
		NS_DURING
			errorDescription = nil;
			plist = [NSPropertyListSerialization propertyListFromData:fileData
				mutabilityOption:kCFPropertyListMutableContainers
				format:&format
				errorDescription:&errorDescription];
			if (errorDescription) {
				NSLog(@"%@",errorDescription);
				[errorDescription release];
			}
			if (plist) {
				[openFilesDictionary setObject:[self tdInfoObjectFromDictionary:plist] forKey:fileName];
				[self rememberAccessToFile:fileName];
			}
		NS_HANDLER
		NS_ENDHANDLER
	}
	// netflow info
	fileName = fileNameWithDate(kFileNetflow, inDate);
		str = [NSString stringWithFormat:@"Reading %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	fileData = [self readFromFile:fileName];
	if (fileData) {
		NS_DURING
			errorDescription = nil;
			plist = [NSPropertyListSerialization propertyListFromData:fileData
				mutabilityOption:kCFPropertyListMutableContainers
				format:&format
				errorDescription:&errorDescription];
			if (errorDescription) {
				NSLog(@"%@",errorDescription);
				[errorDescription release];
			}
			if (plist) {
				[openFilesDictionary setObject:[self tdInfoObjectFromDictionary:plist] forKey:fileName];
				[self rememberAccessToFile:fileName];
			}
		NS_HANDLER
		NS_ENDHANDLER
	}
		
	// attach info
	fileName = fileNameWithDate(kFileAttach, inDate);
		str = [NSString stringWithFormat:@"Reading %@...",fileName];
		[self updateParameter:@"statusInfo" withObject:str];
	fileData = [self readFromFile:fileName];
	if (fileData) {
		NS_DURING
			errorDescription = nil;
			plist = [NSPropertyListSerialization propertyListFromData:fileData
				mutabilityOption:kCFPropertyListMutableContainers
				format:&format
				errorDescription:&errorDescription];
			if (errorDescription) {
				NSLog(@"%@",errorDescription);
				[errorDescription release];
			}
			if (plist) {
				[openFilesDictionary setObject:[self tdInfoObjectFromDictionary:plist] forKey:fileName];
				[self rememberAccessToFile:fileName];
			}
		NS_HANDLER
		NS_ENDHANDLER
	}
	[self updateParameter:@"statusInfo" withObject:@"Read done."];
}

// ---------------------------------------------------------------------------------
//	� writeToFile
// ---------------------------------------------------------------------------------
// write data to file in kDefaultLogPath = /Library/Logs/IPNetRouterX/
- (BOOL)writeToFile:(NSData *)inData withName:(NSString *)fileName
{
	NSString* filePath;
	NSString* dirPath;
	BOOL returnValue = NO;
	do {
		NSFileManager* fm = [NSFileManager defaultManager];
		dirPath = kDefaultLogPath;	// @"/Library/Logs/IPNetRouterX/"
		// does directory exist?
		if (![fm fileExistsAtPath:dirPath]) {
			// no, try to create directory
			if (![fm createDirectoryAtPath:dirPath attributes:nil]) {
				NSLog(@"TrafficDiscovery: unable to create directory at path: %@",dirPath);
				break;
			}
		}
		// keep TD logs in a separate folder
		dirPath = [dirPath stringByAppendingPathComponent:kTrafficDiscoveryPath];
		// does directory exist?
		if (![fm fileExistsAtPath:dirPath]) {
			// no, try to create directory
			if (![fm createDirectoryAtPath:dirPath attributes:nil]) {
				NSLog(@"TrafficDiscovery: unable to create directory at path: %@",dirPath);
				break;
			}
		}
		// have directory, write to file
		filePath = [dirPath stringByAppendingPathComponent:fileName];
		returnValue = [inData writeToFile:filePath atomically:YES];
		if (!returnValue)
			NSLog(@"TrafficDiscovery: unable to create file at path: %@",filePath);
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� readFromFile
// ---------------------------------------------------------------------------------
- (NSData *)readFromFile:(NSString *)fileName
{
	NSData* fileData = nil;
	NSString* filePath;
	NSString* dirPath;
	BOOL isDir;
	do {
		NSFileManager* fm = [NSFileManager defaultManager];
		dirPath = kDefaultLogPath;	// @"/Library/Logs/IPNetRouterX/"
		// look in separate TD logs folder
		dirPath = [dirPath stringByAppendingPathComponent:kTrafficDiscoveryPath];
		// check for directory
		if ([fm fileExistsAtPath:dirPath isDirectory:&isDir] && !isDir) {
			NSLog(@"TrafficDiscovery: unable to locate directory at path: %@",dirPath);
			break;
		}
		filePath = [dirPath stringByAppendingPathComponent:fileName];
		// does file exist?
		if (![fm fileExistsAtPath:filePath]) break;
		// read it
		fileData = [NSData dataWithContentsOfFile:filePath];
	} while (false);
	return fileData;
}

// ---------------------------------------------------------------------------------
//	� tdInfoDictionaryFromObject
// ---------------------------------------------------------------------------------
- (NSMutableDictionary *)tdInfoDictionaryFromObject:(NSMutableDictionary *)inValue
{
	NSMutableDictionary* outValue = [NSMutableDictionary dictionary];
	NSNumber* key;
	NSEnumerator* en = [inValue keyEnumerator];
	while (key = [en nextObject]) {
		[outValue setObject:[[inValue objectForKey:key] dictionary] forKey:key];
	}
	return outValue;
}

// ---------------------------------------------------------------------------------
//	� tdInfoObjectFromDictionary
// ---------------------------------------------------------------------------------
- (NSMutableDictionary *)tdInfoObjectFromDictionary:(NSMutableDictionary *)inValue
{
	NSMutableDictionary* outValue = [NSMutableDictionary dictionary];
	NSNumber* key;
	NSEnumerator* en = [inValue keyEnumerator];
	while (key = [en nextObject]) {
		[outValue setObject:[TDDayGroup objectFromDictionary:[inValue objectForKey:key]] forKey:key];
	}
	return outValue;
}

// ---------------------------------------------------------------------------------
//	� rememberAccessToFile
// ---------------------------------------------------------------------------------
// record last time file was accessed so we can close inactive files
- (void)rememberAccessToFile:(NSString *)name
{
	[savedFilesDictionary setObject:[NSCalendarDate date] forKey:name];

}

// ---------------------------------------------------------------------------------
//	� rememberUpdateToFile
// ---------------------------------------------------------------------------------
// if file is updated and needs to be saved, remove from savedList
- (void)rememberUpdateToFile:(NSString *)name
{
	[savedFilesDictionary removeObjectForKey:name];
}


#pragma mark -- NSTable data source --
// ---------------------------------------------------------------------------------
//	� numberOfRowsInTableView
// ---------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	int viewBy = [[tableView delegate] viewBy];
	NSCalendarDate* trafficDiscoveryTime = [[tableView delegate] showDate];
	NSMutableDictionary* plist;	
	NSString* filePrefix;
	NSString* fileName = nil;
	filePrefix = filePrefixForViewBy(viewBy);
	fileName = fileNameWithDate(filePrefix, trafficDiscoveryTime);
	plist = [openFilesDictionary objectForKey:fileName];
	if (plist) [self rememberAccessToFile:fileName];
	if (!plist) {	// try to read it
		[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
		plist = [openFilesDictionary objectForKey:fileName];
	}
	return [plist count];
}
// ---------------------------------------------------------------------------------
//	� tableView:objectValueForTableColumn:row:
// ---------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	NSString* returnValue = nil;
	NSCalendarDate* trafficDiscoveryTime;
	TDDayGroup* dayGroup;
	int viewBy;
	int interval;
	
	do {	
		// column requested
		NSString* cid = [tableColumn identifier];
		// time slot
		trafficDiscoveryTime = [[tableView delegate] showDate];
		// viewBy
		viewBy = [[tableView delegate] viewBy];
		// level in hierarchy
		interval = [[tableView delegate] interval];
		// find dayGroup for row
		dayGroup = [self dayGroupForDate:trafficDiscoveryTime tableView:tableView row:row];
		if (!dayGroup) {
			NSLog(@"TDM dayGroup is nil");
			break;
		}
		if ([cid isEqualTo:TDE_service]) {
			returnValue = [dayGroup identifier];
			break;
		}
		if ([cid isEqualTo:TDE_name]) {		
			returnValue = [dayGroup name];
			break;
		}
		if ([cid isEqualTo:TDE_info]) {
			returnValue = [dayGroup info];
			break;
		}
//		if ([cid isEqualTo:TDE_bsdName]) {
//			returnValue = [dayGroup bsdName];
//			break;
//		}
		if ([cid isEqualTo:TDE_lastTime]) {
			returnValue = [[dayGroup lastTime] descriptionWithCalendarFormat:@"%H:%M:%S"];
			break;
		}
		// find tdEntry
		TDEntry* tdEntry = [dayGroup tdEntryForDate:trafficDiscoveryTime interval:interval];
		returnValue = [tdEntry valueForKey:cid];
	} while (false);

	return returnValue;
}

#pragma mark -- DS support --
// ---------------------------------------------------------------------------------
//	� dayGroupForDate:tableView:row:
// ---------------------------------------------------------------------------------
- (TDDayGroup *)dayGroupForDate:(NSCalendarDate*)trafficDiscoveryTime tableView:(NSTableView*)tableView row:(int)row
{
	NSMutableDictionary* plist;
	NSMutableArray* sortedKeys;
	TDDayGroup* dayGroup = nil;
	NSString* identifier;
	
	do {
		int viewBy = [[tableView delegate] viewBy];
		NSString* filePrefix;
		NSString* fileName = nil;
		filePrefix = filePrefixForViewBy(viewBy);
		fileName = fileNameWithDate(filePrefix, trafficDiscoveryTime);
		plist = [openFilesDictionary objectForKey:fileName];
		if (plist) [self rememberAccessToFile:fileName];
		if (!plist) {	// try to read it
			[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
			plist = [openFilesDictionary objectForKey:fileName];
			if (!plist) break;
		}
		sortedKeys = [sortedKeysDictionary objectForKey:fileName];
		if (!sortedKeys) {
			// set tableView used to determine sort order (critical section)
			[self setSortTableView:tableView];
			[self setSortDate:trafficDiscoveryTime];
			sortedKeys = [[plist keysSortedByValueUsingSelector:@selector(compareTableViewRow:)] retain];
			[sortedKeysDictionary setObject:sortedKeys forKey:fileName];
			// notify any listeners traffic data has been updated
			[self updateParameter:TDNewGroup withObject:TDNewGroup];
			
		}
		if (row < [sortedKeys count]) {
			identifier = [sortedKeys objectAtIndex:row];
			dayGroup = [plist objectForKey:identifier];
		}
	} while (false);
	return dayGroup;
}

// ---------------------------------------------------------------------------------
//	� tdEntryForAttach:date:interval:
// ---------------------------------------------------------------------------------
- (TDEntry *)tdEntryForAttach:(NSString*)attachID
	date:(NSCalendarDate*)trafficDiscoveryTime
	interval:(int)interval
{
	TDEntry* tdEntry = nil;
	NSString* fileName;
	NSMutableDictionary* plist;
	TDDayGroup* dayGroup;
	TDHourGroup* hourGroup;
	TDMinuteGroup* minuteGroup;
	
	do {
		if (!attachID) break;
		// get attach info
		fileName = fileNameWithDate(kFileAttach, trafficDiscoveryTime);
		plist = [openFilesDictionary objectForKey:fileName];
		if (plist) [self rememberAccessToFile:fileName];
		if (!plist) {	// try to read it
			[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
			plist = [openFilesDictionary objectForKey:fileName];
		}
		// get dayGroup
		dayGroup = [plist objectForKey:attachID];
		if (interval == kIntervalSecond) {
			hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:NO];
			minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:NO];
			tdEntry = [minuteGroup tdEntryForIndex:[trafficDiscoveryTime secondOfMinute]];
		}
		else if (interval == kIntervalMinute) {
			hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:NO];
			tdEntry = [hourGroup tdEntryForIndex:[trafficDiscoveryTime minuteOfHour]];
		}
		else if (interval == kIntervalHour) {
			tdEntry = [dayGroup tdEntryForIndex:[trafficDiscoveryTime hourOfDay]];
		}
		else if (interval == kIntervalDay) {
			// replace with week group when ready
			tdEntry = [dayGroup tdEntryForIndex:[trafficDiscoveryTime hourOfDay]];
		}
		else if (interval == kIntervalRecent) {
			hourGroup = [dayGroup hourGroupForIndex:[trafficDiscoveryTime hourOfDay] allocate:NO];
			minuteGroup = [hourGroup minuteGroupForIndex:[trafficDiscoveryTime minuteOfHour] allocate:NO];
			tdEntry = [minuteGroup tdEntryRecentForIndex:[trafficDiscoveryTime secondOfMinute]];
		}
	} while (false);
	return tdEntry;
}

// ---------------------------------------------------------------------------------
//	� lookupCompleted
// ---------------------------------------------------------------------------------
// have a lookup result, update table
- (void)lookupCompleted:(NSNotification *)aNotification {
    NSString* identifier;
	NSCalendarDate* trafficDiscoveryTime;
    NSString* name;
	NSString* fileName;
	NSMutableDictionary* plist;
	TDDayGroup* dayGroup;
	// get identifier from user dictionary
    identifier = [[aNotification userInfo] objectForKey:@"identifier"];
	trafficDiscoveryTime = [[aNotification userInfo] objectForKey:@"trafficDiscoveryTime"];
	// get resulting name we looked up
    name = [[aNotification object] result];
	if ([name isEqualTo:NSLocalizedString(@"No name found",@"No name found")]) name = identifier;
	//NSLog(@" Lookup result: %@",name);
	// set name in corresponding dayGroup
	fileName = fileNameWithDate(kFileDevice, trafficDiscoveryTime);
	plist = [openFilesDictionary objectForKey:fileName];
	if (!plist) {	// try to read it
		[self trafficDiscoveryReadForDate:trafficDiscoveryTime];
		plist = [openFilesDictionary objectForKey:fileName];
	}
	[self rememberUpdateToFile:fileName];
	dayGroup = [plist objectForKey:identifier];
	[dayGroup setName:name];
	// notify listeners we have new data
	[self updateParameter:@"lookupComplete" withObject:@"lookupComplete"];
}

// ---------------------------------------------------------------------------------
//	� updateIndex()
// ---------------------------------------------------------------------------------
- (void)updateIndex:(NSString*)fileName
{
	// re-index keys for currently open file
	[sortedKeysDictionary removeObjectForKey:fileName];
}
@end


// ---------------------------------------------------------------------------------
//	� tdSecondsForInterval()
// ---------------------------------------------------------------------------------
int tdSecondsForInterval(int interval)
{
	int seconds = 0;
	if (interval == kIntervalSecond) {
		seconds = 1;
	}
	else if (interval == kIntervalMinute) {
		seconds = 60;
	}
	else if (interval == kIntervalHour) {
		seconds = 3600;
	}
	else if (interval == kIntervalDay) {
		seconds = 86400;
	}
	return seconds;
}

// ---------------------------------------------------------------------------------
//	� filePrefixForViewBy()
// ---------------------------------------------------------------------------------
NSString* filePrefixForViewBy(int viewBy)
{
	if (viewBy == kViewByDevice) return kFileDevice;
	else if (viewBy == kViewByService) return kFileService;
	else return kFileNetflow;
}

// ---------------------------------------------------------------------------------
//	� fileNameWithDate()
// ---------------------------------------------------------------------------------
NSString* fileNameWithDate(NSString* prefix, NSCalendarDate* inDate)
{
	NSString* dateString;
	NSString* fileName;
	
	dateString = [inDate descriptionWithCalendarFormat:@"%Y-%m-%d"];
	fileName = [NSString stringWithFormat:@"%@ %@.plist",prefix,dateString];
	return fileName;
}
