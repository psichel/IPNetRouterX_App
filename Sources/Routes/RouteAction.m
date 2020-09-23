//
//  RouteAction.m
//  IPNetRouterX
//
//  Created by psichel on Wed Mar 05 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates reading the connection list in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
#import "RouteAction.h"
//#import <Foundation/Foundation.h>
#import "IPValue.h"
#import "RouteServer.h"
#import "RouteEntry.h"
#import "RouteTable.h"
#import "ArpEntry.h"
#import "ArpTable.h"
#import "AppSupport.h"
#import "PSURL.h"
#import "IPSupport.h"
#import "IPUDPSocket.h"
#import "HardwareAddress.h"
#import "RoutingSocket.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "SentryLogger.h"
#import "InterfaceTable.h"
#import "arp.h"
#import "ArpOutput.h"

#import "RouteSupport.h"

@interface RouteAction (PrivateMethods)
- (BOOL)setup;
- (NSData *)getParameter:(NSArray *)mibName;
- (NSString *)nameForIndex:(int)index;
- (int)indexForName:(NSString *)inName;
- (NSString *)hardwareAddressForName:(NSString *)inName;
@end

@implementation RouteAction
// ---------------------------------------------------------------------------------
//	• sharedInstance
// ---------------------------------------------------------------------------------
+ (RouteAction *) sharedInstance {
	static id sharedTask = nil;	
	if(sharedTask==nil) {
		sharedTask = [[RouteAction alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (RouteAction *)init {
    if (self = [super init]) {
        // initialize our instance variables
        mBuffer = nil;
        mBufferSize = 4096;
		mRoutingSocket = 0;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
    // clean-up when server is killed
	if (mRoutingSocket) close(mRoutingSocket);
	[mBuffer release];		mBuffer = nil;
	[super dealloc];
}

// ---------------------------------------------------------------------------------
//	• delegate
// ---------------------------------------------------------------------------------
- (id)delegate { return delegate; }
- (void)setDelegate:(id)value {
	//[value retain];
	//[delegate release];
	delegate = value;
}

#pragma mark -- route --
// ---------------------------------------------------------------------------------
//	• routeList:
// ---------------------------------------------------------------------------------
- (NSMutableArray *)routeList:(id)anObject
{
    NSArray* mibName;
    NSData* data;
    RouteEntry* entry=nil;
	u_int8_t* dp;
    int offset;
	u_int32_t destination;
	u_int32_t gateway;
	u_int32_t netmask;
	int index;
	NSMutableArray* routeArray = [NSMutableArray array];
	NSMutableDictionary* sdl_info = [NSMutableDictionary dictionary];

    do {
        // setup to access routing table
		if (![self setup]) break;
		// set mib name
		mibName = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:CTL_NET],
			[NSNumber numberWithInt:AF_ROUTE],
			[NSNumber numberWithInt:0],
			[NSNumber numberWithInt:AF_INET],
			[NSNumber numberWithInt:NET_RT_DUMP],
			[NSNumber numberWithInt:0],
			nil];

		data = [self getParameter:mibName];
		data = [data copy]; // copy buffer out so we can reuse getParameter
		dp = (u_int8_t*)[data bytes];
		offset = 0;
		
		// loop to extract RTM-GET messages that contain routing entries
		while (offset < [data length]) {
			// access message header and address structures
			struct rt_msghdr *rtm;
			struct sockaddr *sa, *rti_info[RTAX_MAX];
			rtm = (struct rt_msghdr *)&dp[offset];
			// ap points to first socket address structure
			sa = (struct sockaddr *) (rtm + 1);
			// advance for next RTM_GET
			offset += rtm->rtm_msglen;
			// confirm message type
			if (rtm->rtm_type != RTM_GET) continue;
			// get socket address structures
			get_rtaddrs(rtm->rtm_addrs, sa, rti_info);
			// build routes entry from socket addresses
			destination = 0;
			gateway = 0;
			netmask = 0;
			index = 0;
			entry = [[RouteEntry alloc] init];
			if ( (sa = rti_info[RTAX_NETMASK]) != NULL) {
				netmask = sock_mask(sa, sa->sa_len);
			}
			if ( (sa = rti_info[RTAX_DST]) != NULL) {
				destination = sock_host(sa, sa->sa_len);
				[entry setDestination:stringForNetNumber(destination, netmask)];
			}
			if ( (sa = rti_info[RTAX_GATEWAY]) != NULL) {
				if (sa->sa_family == AF_INET) {
					gateway = sock_host(sa, sa->sa_len);
					[entry setGateway:stringForIP(gateway)];
				}
				if (sa->sa_family == AF_LINK) {
					struct sockaddr_dl *sdl;
					sdl = (struct sockaddr_dl *)sa;
					index = sdl->sdl_index;
					[entry setGateway:[NSString stringWithFormat:@"link#%d",index]];
					// remember address to link entries to resolve names below
					[sdl_info setObject:[NSNumber numberWithInt:index] forKey:stringForIP(destination)];
				}
			}
			// skip these in routes display
			if (rtm->rtm_flags & RTF_LLINFO) continue;  // skip ARP cache entries
			if (rtm->rtm_flags & RTF_WASCLONED) continue;   // skip cloned routes			
			// determine route type
				// route types:
				// default - match any destination (destination = 0, mask = 0)
				// host - the destination is a complete host address (RTF_HOST,host number != 0)
				// direct - the destination is directly connected (rtm->rtm_flags != RTF_GATEWAY)
				// indirect - the route is to a gateway (router)  (rtm->rtm_flags = RTF_GATEWAY)
					// ARP cache entries have rtm->rtm_flags RTF_LLINFO
			if ((destination == 0) && (netmask == 0)) [entry setType:RE_typeDefault];
			else if (rtm->rtm_flags & RTF_HOST) [entry setType:RE_typeHost];
			else if (rtm->rtm_flags & RTF_GATEWAY) [entry setType:RE_typeIndirect];
			else  [entry setType:RE_typeDirect];
			
			// set attributes
			// rtm->rtm_flags RTF_STATIC manually added route does not expire
			if ((rtm->rtm_flags & RTF_UP) && (rtm->rtm_flags & RTF_STATIC))
				[entry setAttributes:[NSString stringWithFormat:@"%@ %@",RE_attributeUp,RE_attributeStatic]];
			else if (rtm->rtm_flags & RTF_UP) [entry setAttributes:RE_attributeUp];
			else if (rtm->rtm_flags & RTF_STATIC) [entry setAttributes:RE_attributeStatic];
			
			// look for interface name
			if (index) {
				[entry setInterface:[self nameForIndex:index]];
			}
			else {
				if ((gateway & 0xFF000000) == ipForString(@"127.0.0.0")) [entry setInterface:@"lo0"];
			}
			#if IPNetRouter
			// transfer previous parameters
			RouteEntry* previous = [[[[SentryModel sharedInstance] sentryState] routeTable] matchingRouteEntry:entry];
			if (previous) {
				// transfer extra fields
				[entry setComment:[previous comment]];
				[entry setRestore:[previous restore]];
			}
			#endif
			// update display
			[routeArray addObject:entry];
			[entry release];	entry = nil;
		}   // while (offset < [data length])
		// done getting routes
		// fill in any names we're missing from sdl_info we stored previously
		int i, count;
		NSNumber* num;
		count = [routeArray count];
		for (i=0; i<count; i++) {
			entry = [routeArray objectAtIndex:i];
			if (![entry interface]) {
				num = [sdl_info objectForKey:[entry gateway]];
				if (num) [entry setInterface:[self nameForIndex:[num intValue]]];
			}
		}
		// update table
		[delegate updateParameter:kRouteList withObject:routeArray];
		[data release];
    } while (false);
    return routeArray;
}

// ---------------------------------------------------------------------------------
//	• routeAdd:
// ---------------------------------------------------------------------------------
- (int)routeAdd:(id)anObject
{
	// setup to issue route command
	int returnValue = 0;
	BOOL toolExists;
	RouteEntry* entry = (RouteEntry *)anObject;
	NSRange range;
	NSString* path;
	NSMutableArray* args;
	NSString* type;
	NSString* gateway;
	u_int32_t address, mask;

	path = [AppSupport toolPathForName:@"RunRoute" fileExists:&toolExists];
	if (!toolExists) {
		NSLog(@"Helper tool RunRoute was not found at path: %@",path);
		return -1;
	}
	// setup args to route command
	args = [NSMutableArray array];
	[args addObject:@"-n"];
	[args addObject:@"add"];
	// modifiers (static...)
	range = [[entry attributes] rangeOfString:RE_attributeStatic];
	if (range.length) [args addObject:@"-static"];
	else [args addObject:@"-nostatic"];
	// set destination and gateway based on type
	type = [entry type];
		// destination
	netNumberForString([entry destination], &address, &mask);
	// default route?
	if ([type isEqualTo:RE_typeDefault]) {
		[args addObject:@"-net"];
		[args addObject:@"0.0.0.0"];
	}
	// host route?
	else if ([type isEqualTo:RE_typeHost]) {
		[args addObject:@"-host"];
		[args addObject:stringForIP(address)];
	}
	else {
		[args addObject:[entry destination]];
	}
		// gateway
	// direct route?
	gateway = [entry gateway];
	if ([gateway hasPrefix:@"link"] || ![gateway length]) {
		[args addObject:@"-interface"];
		[args addObject:[entry interface]];
	}
	else {
		// check if gateway is the IP of a local interface
		if ( ipForString(gateway) == ipForString(@"127.0.0.1") ) [args addObject:@"-interface"];
		else if ([[InterfaceTable sharedInstance] entryForAddress:gateway])
			[args addObject:@"-interface"];
		[args addObject:gateway];
	}
//NSLog(@"%@",[args description]);
	// issue command
	NSString* output = nil;
	returnValue = [AppSupport doTask:path arguments:args input:nil output:&output error:nil];
	//show results
	[[SentryLogger sharedInstance] logMessage:output];
	[delegate updateParameter:@"statusInfo" withObject:output];
	[self routeList:nil];
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	• routeDelete:
// ---------------------------------------------------------------------------------
- (int)routeDelete:(id)anObject
{
	// setup to issue route command
	int returnValue = 0;
	BOOL toolExists;
	RouteEntry* entry = (RouteEntry *)anObject;
	NSString* path;
	NSMutableArray* args;
	NSString* type;

	path = [AppSupport toolPathForName:@"RunRoute" fileExists:&toolExists];
	if (!toolExists) {
		NSLog(@"Helper tool RunRoute was not found at path: %@",path);
		return -1;
	}
	// setup args to route command
	args = [NSMutableArray array];
	[args addObject:@"-n"];
	[args addObject:@"delete"];

	// set destination based on type
	type = [entry type];
		// destination
	// host route?
	if ([type isEqualTo:RE_typeHost]) [args addObject:@"-host"];	
	[args addObject:[entry destination]];
#if 0
		// gateway
	// direct route?
	if ([type isEqualTo:RE_typeDirect] || [gateway hasPrefix:@"link"]) {
		[args addObject:@"-interface"];
		[args addObject:[entry interface]];
	}
	else {
		[args addObject:gateway];
	}
#endif
	// issue command
	NSString* output = nil;
	returnValue = [AppSupport doTask:path arguments:args input:nil output:&output error:nil];
	//show results
	[[SentryLogger sharedInstance] logMessage:output];
	[delegate updateParameter:@"statusInfo" withObject:output];
	[self routeList:nil];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• routeChange:
// ---------------------------------------------------------------------------------
- (int)routeChange:(id)anObject
{
	int returnValue = 0;
	BOOL toolExists;
	RouteEntry* entry = (RouteEntry *)anObject;
	NSRange range;
	// setup to issue route command
	NSString* path;
	NSMutableArray* args;
	NSString* type;

	path = [AppSupport toolPathForName:@"RunRoute" fileExists:&toolExists];
	if (!toolExists) {
		NSLog(@"Helper tool RunRoute was not found at path: %@",path);
		return -1;
	}
	// setup args to route command
	args = [NSMutableArray array];
	[args addObject:@"-n"];
	[args addObject:@"change"];
	// modifiers (static...)
	range = [[entry attributes] rangeOfString:RE_attributeStatic];
	if (range.length) [args addObject:@"-static"];
	else [args addObject:@"-nostatic"];
	// set destination and gateway based on type
	type = [entry type];
		// destination
	// host route?
	if ([type isEqualTo:RE_typeHost]) [args addObject:@"-host"];
	// default route?
	if ([type isEqualTo:RE_typeDefault]) {
		[args addObject:@"-net"];
		[args addObject:@"0.0.0.0"];
	}
	else {
		[args addObject:[entry destination]];
	}
		// gateway
	// direct route?
	if ([type isEqualTo:RE_typeDirect]) {
		[args addObject:@"-interface"];
		[args addObject:[entry interface]];
	}
	else {
		[args addObject:[entry gateway]];
	}

	// issue command
	NSString* output = nil;
	returnValue = [AppSupport doTask:path arguments:args input:nil output:&output error:nil];
	//show results
	[[SentryLogger sharedInstance] logMessage:output];
	[delegate updateParameter:@"statusInfo" withObject:output];
	[self routeList:nil];
	return returnValue;
}

#pragma mark -- arp --
// ---------------------------------------------------------------------------------
//	• arpList:
// ---------------------------------------------------------------------------------
- (NSMutableArray *)arpList:(id)anObject
{
    NSArray* mibName;
    NSData* data;
    ArpEntry* entry=nil;
	u_int8_t* dp;
    int offset;
	u_int32_t ipAddress;
	u_int32_t netmask;
	u_int16_t sin_other;
	int index;
	NSMutableArray* arpArray = [NSMutableArray array];

    do {
        // setup to access routing table
		if (![self setup]) break;
		// set mib name
		mibName = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:CTL_NET],
			[NSNumber numberWithInt:AF_ROUTE],
			[NSNumber numberWithInt:0],
			[NSNumber numberWithInt:AF_INET],
			[NSNumber numberWithInt:NET_RT_FLAGS],  // arp cache
			[NSNumber numberWithInt:RTF_LLINFO],
			nil];

		data = [self getParameter:mibName];
		data = [data copy]; // copy buffer out so we can reuse getParameter
		dp = (u_int8_t*)[data bytes];
		offset = 0;
		HardwareAddress* ha = [[[HardwareAddress alloc] init] autorelease];
		NSMutableString* aString = [[[NSMutableString alloc] init] autorelease];
		
		// loop to extract RTM-GET messages that contain arp entries
		while (offset < [data length]) {
			// access message header and address structures
			struct rt_msghdr *rtm;
			struct sockaddr *sa, *rti_info[RTAX_MAX];
			rtm = (struct rt_msghdr *)&dp[offset];
			// ap points to first socket address structure
			sa = (struct sockaddr *) (rtm + 1);
			// advance for next RTM_GET
			offset += rtm->rtm_msglen;
			// confirm message type
			if (rtm->rtm_type != RTM_GET) continue;
			// get socket address structures
			get_rtaddrs(rtm->rtm_addrs, sa, rti_info);
			// build arp entry from socket addresses
			ipAddress = 0;
			netmask = 0;
			sin_other = 0;
			index = 0;
			entry = [[ArpEntry alloc] init];
			if ( (sa = rti_info[RTAX_NETMASK]) != NULL) {
				netmask = sock_mask(sa, sa->sa_len);
			}
			if ( (sa = rti_info[RTAX_DST]) != NULL) {
				struct sockaddr_inarp *sarp;
				sarp = (struct sockaddr_inarp *)sa;
				ipAddress = sock_host(sa, sa->sa_len);	// sock_host does ntohl
				[entry setIpAddress:stringForIP(ipAddress)];
				sin_other = sarp->sin_other;
			}
			if ( (sa = rti_info[RTAX_GATEWAY]) != NULL) {
				if (sa->sa_family == AF_LINK) {
					struct sockaddr_dl *sdl;
					sdl = (struct sockaddr_dl *)sa;
					//NSLog(@"name len %d",sdl->sdl_nlen);
					//NSLog(@"hw address len %d",sdl->sdl_alen);
					if (sdl->sdl_alen == 6) {
						[ha setHardwareAddress:(EthernetAddress_t *)&sdl->sdl_data[sdl->sdl_nlen]];
						[entry setHwAddress:[ha stringValue]];
					}
					else continue;		// only show resolved entries
					// index
					index = sdl->sdl_index;
					[entry setInterface:[self nameForIndex:index]];
				}
			}
			
			// set attributes
			[aString setString:@""];
			if (rtm->rtm_rmx.rmx_expire == 0) [aString appendString:RE_attributePerm];
			if (netmask == 0xffffffff) [aString appendString:RE_attributePublish];
			if (sin_other & SIN_PROXY) [aString appendString:RE_attributeProxy];

			[entry setAttributes:[[aString copy] autorelease]];
			#if IPNetRouter
			// transfer previous parameters
			ArpEntry* previous = [[[[SentryModel sharedInstance] sentryState] arpTable] entryForIpAddress:[entry ipAddress]];
			if (previous) {
				// transfer extra fields
				[entry setComment:[previous comment]];
				[entry setRestore:[previous restore]];
			}
			#endif
			// update display
			[arpArray addObject:entry];
			[entry release];	entry = nil;
		}   // while (offset < [data length])
		// done getting arp entries
		// update table
		[delegate updateParameter:kArpList withObject:arpArray];
		[data release];
    } while (false);
    return arpArray;
}

// ---------------------------------------------------------------------------------
//	• arpAdd:
// ---------------------------------------------------------------------------------
- (int)arpAdd:(id)anObject
{
	ArpEntry* entry = (ArpEntry *)anObject;
	NSRange range;
	NSString* hardwareAddress;
	// setup to issue arp command
	int result;
	int argc;
	char* argv[7];

	argv[0] = "arp";	// path
	argv[1] = "arp";	// command
	argv[2] = "-s";
	argv[3] = (char *)[[entry ipAddress] UTF8String];
	hardwareAddress = [entry hwAddress];
	if (![hardwareAddress length]) hardwareAddress = [self hardwareAddressForName:[entry interface]];
	argv[4] = (char *)[hardwareAddress UTF8String];
	argc = 5;
	// attributes
	range = [[entry attributes] rangeOfString:RE_attributePerm];
	if (!range.length) {
		argv[argc++] = "temp";
	}
	range = [[entry attributes] rangeOfString:RE_attributePublish];
	BOOL publish = range.length;
	range = [[entry attributes] rangeOfString:RE_attributeProxy];
	BOOL proxy = range.length;
	if (publish || proxy) {
		argv[argc++] = "pub";	
	}
	if (proxy) {
		argv[argc++] = "only";	
	}

	argv[argc] = 0;	// arp requires this
	optind = 2;		//  initialize for getopt
	// discard any previous output
	[[ArpOutput sharedInstance] setString:@""];
	// steal code from arp command (arp.c)
	result = psArpMain(argc, argv);
	//show results
	[[SentryLogger sharedInstance] logMessage:[ArpOutput sharedInstance]];
	[delegate updateParameter:@"statusInfo" withObject:[ArpOutput sharedInstance]];
	[self arpList:nil];
	return result;
}

// ---------------------------------------------------------------------------------
//	• arpDelete:
// ---------------------------------------------------------------------------------
// anObject is a dictionary specifying the kURL, RE_ipAddress, RE_hwAddress,
// RE_AttributePerm, RE_AttributePublish, RE_AttributeProxy
- (int)arpDelete:(id)anObject
{
	// setup to issue arp command
	ArpEntry* entry = (ArpEntry *)anObject;
	int result;
	int argc;
	char* argv[7];

	argv[0] = "arp";	// path
	argv[1] = "arp";	// command
	argv[2] = "-d";
	argv[3] = (char *)[[entry ipAddress] UTF8String];
	argc = 4;
	argv[argc] = 0;	// arp requires this
	optind = 2;		//  initialize for getopt
	// discard any previous output
	[[ArpOutput sharedInstance] setString:@""];
	// steal code from arp command (arp.c)
	result = psArpMain(argc, argv);
	// show results
	[[SentryLogger sharedInstance] logMessage:[ArpOutput sharedInstance]];
	[delegate updateParameter:@"statusInfo" withObject:[ArpOutput sharedInstance]];
	[self arpList:nil];
	return result;
}

#pragma mark -- supporting functions --
// ---------------------------------------------------------------------------------
//	• setup
// ---------------------------------------------------------------------------------
- (BOOL)setup {
    BOOL result = YES;
    if (mBuffer == nil) {
        mBuffer = [NSMutableData dataWithCapacity:mBufferSize];
        if (mBuffer) [mBuffer retain];
    }
    else [mBuffer setLength:mBufferSize];
    if (mBuffer== nil) result = NO;
    return result;
}

// ---------------------------------------------------------------------------------
//	• getParameter:
// ---------------------------------------------------------------------------------
- (NSData *)getParameter:(NSArray *)mibName
// return sysctl data for corresponding mibName
// mibName is an array of NSNumber
// return nil on error
{
    NSData* returnValue = nil;
    int mib[16];
    size_t returnLen;
    int i, count;
    do {
        // load mib with names from array
        if (!mibName) break;	// no names given
        if ([mibName count] > 16) break;	// name overflow
        count = [mibName count];
		for (i=0; i<count; i++) {
            mib[i] = [(NSNumber *)[mibName objectAtIndex:i] intValue];
        }
        // reset buffer length
        [mBuffer setLength:mBufferSize];
        returnLen = mBufferSize;
        // call sysctl
        if (sysctl(mib, [mibName count], [mBuffer mutableBytes], &returnLen, nil, 0) < 0) {
            if (errno == ENOMEM) {
                // buffer too small
                // get size required
                returnLen = 0;
                sysctl(mib, [mibName count], nil, &returnLen, nil, 0);
                returnLen += 512;	// add some cushion
                if (returnLen < mBufferSize) break;
                // try to get a new buffer that size
                [mBuffer release];
                mBuffer = [NSMutableData dataWithCapacity:returnLen];
                if (mBuffer) {
                    [mBuffer retain];
                    mBufferSize = returnLen;
                    [mBuffer setLength:mBufferSize];
                }
                else break;
                // try our request again
                if (sysctl(mib, [mibName count],
                    [mBuffer mutableBytes], &returnLen, nil, 0) < 0) break;
            }
            else break;
        }
        // set size for the amount of data we got
        [mBuffer setLength:returnLen];
        // pass back resulting data
        returnValue = mBuffer;	// best performance for synchronous non-reentrant use
        //returnValue = [NSData dataWithData:mBuffer];
            // We could copy the NSMutableData received to an NSData so the result is immutable
            // and our mutable buffer can be re-used.  This is not re-entrant
            // since we don't allocate new mutable data on each call for performance.
    } while (false);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	• nameForIndex:
// ---------------------------------------------------------------------------------
- (NSString *)nameForIndex:(int)index
{
    NSString* returnValue = nil;
    NSArray* mibName;
    NSData* data;
	u_int8_t* dp;
    int offset;

    do {
		// set mib name to retrieve interface info
		mibName = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:CTL_NET],
			[NSNumber numberWithInt:AF_ROUTE],
			[NSNumber numberWithInt:0],
			[NSNumber numberWithInt:AF_INET],
			[NSNumber numberWithInt:NET_RT_IFLIST],
			[NSNumber numberWithInt:index],
			nil];

		data = [self getParameter:mibName];
		[data retain];
		dp = (u_int8_t*)[data bytes];
		offset = 0;
		
		// loop to extract RTM-GET messages that contain routing entries
		while (offset < [data length]) {
			// access message header and address structures
			struct if_msghdr *ifm;
			struct sockaddr_dl *sdl;
			ifm = (struct if_msghdr *)&dp[offset];
			// ap points to first socket address structure
			sdl = (struct sockaddr_dl *) (ifm + 1);
			// advance for next RTM_GET
			offset += ifm->ifm_msglen;
			// confirm message type
			if (ifm->ifm_type != RTM_IFINFO) continue;
			// confirm sdl type
			if (sdl->sdl_family != AF_LINK) continue;
			// get ifname
			if (sdl->sdl_nlen > 0) {
				returnValue = [[[NSString alloc] initWithBytes:&sdl->sdl_data[0] length:sdl->sdl_nlen encoding:NSUTF8StringEncoding] autorelease];
				break;
			}
		}
	} while (false);
	[data release];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• indexForName:
// ---------------------------------------------------------------------------------
- (int)indexForName:(NSString *)inName
{
    int returnValue = 0;
    NSArray* mibName;
    NSData* data;
	u_int8_t* dp;
    int offset;

    do {
		// set mib name to retrieve interface info
		mibName = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:CTL_NET],
			[NSNumber numberWithInt:AF_ROUTE],
			[NSNumber numberWithInt:0],
			[NSNumber numberWithInt:AF_INET],
			[NSNumber numberWithInt:NET_RT_IFLIST],
			[NSNumber numberWithInt:0],
			nil];

		data = [self getParameter:mibName];
		[data retain];
		dp = (u_int8_t*)[data bytes];
		offset = 0;
		
		// loop to extract RTM-GET messages that contain routing entries
		while (offset < [data length]) {
			// access message header and address structures
			struct if_msghdr *ifm;
			struct sockaddr_dl *sdl;
			ifm = (struct if_msghdr *)&dp[offset];
			// sdl points to first socket address structure
			sdl = (struct sockaddr_dl *) (ifm + 1);
			// advance for next RTM_GET
			offset += ifm->ifm_msglen;
			// confirm message type
			if (ifm->ifm_type != RTM_IFINFO) continue;
			// confirm sdl type
			if (sdl->sdl_family != AF_LINK) continue;
			// get ifname
			if (sdl->sdl_nlen > 0) {
				NSString* name;
				name = [[[NSString alloc] initWithBytes:&sdl->sdl_data[0] length:sdl->sdl_nlen encoding:NSUTF8StringEncoding] autorelease];
				// check if names match
				if ([name isEqualTo:inName]) {
					returnValue = sdl->sdl_index;
					break;
				}
			}
		}
	} while (false);
	[data release];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• hardwareAddressForName:
// ---------------------------------------------------------------------------------
- (NSString *)hardwareAddressForName:(NSString *)inName
{
    NSString* returnValue = nil;
    NSArray* mibName;
    NSData* data;
	u_int8_t* dp;
    int offset;

    do {
		// set mib name to retrieve interface info
		mibName = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:CTL_NET],
			[NSNumber numberWithInt:AF_ROUTE],
			[NSNumber numberWithInt:0],
			[NSNumber numberWithInt:AF_INET],
			[NSNumber numberWithInt:NET_RT_IFLIST],
			[NSNumber numberWithInt:0],
			nil];

		data = [self getParameter:mibName];
		[data retain];
		dp = (u_int8_t*)[data bytes];
		offset = 0;
		
		// loop to extract RTM-GET messages that contain routing entries
		while (offset < [data length]) {
			// access message header and address structures
			struct if_msghdr *ifm;
			struct sockaddr_dl *sdl;
			ifm = (struct if_msghdr *)&dp[offset];
			// sdl points to first socket address structure
			sdl = (struct sockaddr_dl *) (ifm + 1);
			// advance for next RTM_GET
			offset += ifm->ifm_msglen;
			// confirm message type
			if (ifm->ifm_type != RTM_IFINFO) continue;
			// confirm sdl type
			if (sdl->sdl_family != AF_LINK) continue;
			// get ifname
			if (sdl->sdl_nlen > 0) {
				NSString* name;
				name = [[[NSString alloc] initWithBytes:&sdl->sdl_data[0] length:sdl->sdl_nlen encoding:NSUTF8StringEncoding] autorelease];
				// check if names match
				if ([name isEqualTo:inName]) {
					if (sdl->sdl_alen == 6) {
						HardwareAddress* ha = [[[HardwareAddress alloc] init] autorelease];
						[ha setHardwareAddress:(EthernetAddress_t *)&sdl->sdl_data[sdl->sdl_nlen]];
						returnValue = [ha stringValue];
						break;
					}
				}
			}
		}
	} while (false);
	[data release];
	return returnValue;
}

@end


/* old RTM code for

// ---------------------------------------------------------------------------------
//	• arpAdd:
// ---------------------------------------------------------------------------------
- (int)arpAdd:(id)anObject
{
	int returnValue = 0;
	NSMutableData* data;
	u_int8_t* dp;
	// we'll use a message header and up to 3 socket address structures (RTA_DST, RTA_GATEWAY, RTA_NETMASK)
	struct rt_msghdr *rtm;
	struct sockaddr_inarp *sarp;
	struct sockaddr_dl *sdl;
	int len;
//	struct sockaddr *ap;
	HardwareAddress* ha;
	
	do {
		// make sure we have a routing socket
		if (mRoutingSocket <= 0) {
			mRoutingSocket = psGetRoutingSocket();
			if (mRoutingSocket <= 0) {
				[delegate updateParameter:@"statusInfo" withObject:@"arpDelete routing socket failure"];
				break;
			}
		}
		// setup data buffer
		data = [NSMutableData dataWithCapacity:500];
		
		// setup access to message areas
		dp = [data mutableBytes];
		rtm = (struct rt_msghdr *)&dp[0];
		
		// load message
		// rt_msghdr
		//len = sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp) +sizeof(struct sockaddr_dl) + sizeof(struct sockaddr);
		len = sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp) +sizeof(struct sockaddr_dl);
		bzero(&dp[0], len);
		rtm->rtm_msglen = len;
		rtm->rtm_type = RTM_ADD;
		rtm->rtm_flags |= (RTF_HOST | RTF_LLINFO);
		rtm->rtm_version = RTM_VERSION;
		rtm->rtm_seq = ++seq;
		// handle "Perm" flag
		if ([(NSDictionary *)anObject objectForKey:RE_attributePerm]) rtm->rtm_rmx.rmx_expire = 0;
		else {
			struct timeval tv;
			gettimeofday(&tv, 0);
			rtm->rtm_inits = RTV_EXPIRE;
			rtm->rtm_rmx.rmx_expire = tv.tv_sec + 20 * 60;
		}
		//rtm->rtm_addrs = RTA_DST | RTA_GATEWAY | RTA_NETMASK;
		rtm->rtm_addrs |= (RTA_DST | RTA_GATEWAY);

		// RTA_DST
		sarp = (struct sockaddr_inarp *)&dp[sizeof(struct rt_msghdr)];
		len = sizeof(struct sockaddr_inarp);
		sarp->sin_len = len;
		sarp->sin_family = AF_INET;
		sarp->sin_addr.s_addr = htonl(ipForString([anObject objectForKey:RE_ipAddress]));
		// published (proxy only)
		if ([(NSDictionary *)anObject objectForKey:RE_attributeProxyOnly]) {
			sarp->sin_other = SIN_PROXY;
		}
		
		// RTA_GATEWAY
		sdl = (struct sockaddr_dl *)&dp[sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp)];
		sdl->sdl_len = sizeof(struct sockaddr_dl);
		sdl->sdl_family = AF_LINK;
		sdl->sdl_nlen = 0;
		sdl->sdl_type = IFT_ETHER;
		sdl->sdl_index = 4;
		ha = [[[HardwareAddress alloc] init] autorelease];
		[ha setStringValue:[anObject objectForKey:RE_hwAddress]];
		[ha getHardwareAddress:(EthernetAddress_t *)&sdl->sdl_data[sdl->sdl_nlen]];
		sdl->sdl_alen = 6;

		// publish
		if ([(NSDictionary *)anObject objectForKey:RE_attributePublish]) {
			rtm->rtm_flags |= (RTF_ANNOUNCE | RTF_STATIC);
			rtm->rtm_flags &= ~RTF_HOST;
			// RTA_NETMASK
			rtm->rtm_addrs |= RTA_NETMASK;
			struct sockaddr_inarp *sin;
			ap = (struct sockaddr *)sdl;
			sin = (struct sockaddr_inarp *)NEXT_SA(ap);
			// use funky mask structure like sysctl
			sin->sin_len = 8;
			sin->sin_family = AF_INET;
			sin->sin_addr.s_addr = htonl(0xffffffff);
		}
		// send message to kernal
		returnValue = write(mRoutingSocket, (char *)rtm, rtm->rtm_msglen);
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• arpDelete:
// ---------------------------------------------------------------------------------
- (int)arpDelete:(id)anObject
{
	int returnValue = 0;
	NSMutableData* data;
	u_int8_t* dp;
	// we'll use a message header and up to 3 socket address structures (RTA_DST, RTA_GATEWAY, RTA_NETMASK)
	struct rt_msghdr *rtm;
	struct sockaddr_inarp *sarp;
	//struct sockaddr *sa;
//	struct sockaddr_dl *sdl;
	int len;
//	HardwareAddress* ha;
	
	do {
		// make sure we have a routing socket
		if (mRoutingSocket <= 0) {
			mRoutingSocket = psGetRoutingSocket();
			if (mRoutingSocket <= 0) {
				[delegate updateParameter:@"statusInfo" withObject:@"arpDelete routing socket failure"];
				break;
			}
		}
		// setup data buffer
		data = [NSMutableData dataWithCapacity:500];
		
		// setup access to message areas
		dp = [data mutableBytes];
		rtm = (struct rt_msghdr *)&dp[0];
		
		// load message
		// rt_msghdr
		//len = sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp) +sizeof(struct sockaddr_dl) + sizeof(struct sockaddr);
//		len = sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp) +sizeof(struct sockaddr_dl);
		len = sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp);
		bzero(&dp[0], len);
		rtm->rtm_msglen = len;
		rtm->rtm_type = RTM_DELETE;
		rtm->rtm_flags = RTF_HOST | RTF_LLINFO;
		rtm->rtm_version = RTM_VERSION;
		rtm->rtm_seq = ++seq;
		//rtm->rtm_addrs = RTA_DST | RTA_GATEWAY | RTA_NETMASK;
		rtm->rtm_addrs = RTA_DST | RTA_GATEWAY;

		// RTA_DST
		sarp = (struct sockaddr_inarp *)&dp[sizeof(struct rt_msghdr)];
		len = sizeof(struct sockaddr_inarp);
		sarp->sin_len = len;
		sarp->sin_family = AF_INET;
		sarp->sin_addr.s_addr = htonl(ipForString([anObject objectForKey:RE_ipAddress]));
#if 0		
		// RTA_GATEWAY
		sdl = (struct sockaddr_dl *)&dp[sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp)];
		sdl->sdl_len = sizeof(struct sockaddr_dl);
		sdl->sdl_family = AF_LINK;
		sdl->sdl_nlen = 0;
		ha = [[[HardwareAddress alloc] init] autorelease];
		[ha setStringValue:[anObject objectForKey:RE_hwAddress]];
		[ha getHardwareAddress:(EthernetAddress_t *)&sdl->sdl_data[sdl->sdl_nlen]];
		sdl->sdl_alen = 6;
#endif
#if 0
		// RTA_NETMASK
		sa = (struct sockaddr *)&dp[sizeof(struct rt_msghdr) + sizeof(struct sockaddr_inarp) + sizeof(struct sockaddr_dl)];
		// use funky mask structure like sysctl
		sa->sa_len = 8;
		sa->sa_family = AF_INET;
		sa->sa_data[2] = 0xff;
		sa->sa_data[3] = 0xff;
		sa->sa_data[4] = 0xff;
		sa->sa_data[5] = 0xff;
#endif
		// send message to kernal
		returnValue = write(mRoutingSocket, (char *)rtm, rtm->rtm_msglen);
	} while (false);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	• routeAdd:
// ---------------------------------------------------------------------------------
- (int)routeAdd:(id)anObject
{
	int returnValue = 0;
	NSMutableData* data;
	u_int8_t* dp;
	// we'll use a message header and up to 3 socket address structures (RTA_DST, RTA_GATEWAY, RTA_NETMASK)
	struct rt_msghdr *rtm;
	struct sockaddr_in *sa_dst;
	struct sockaddr_in *sa_gateway;
	struct sockaddr_in *sa_netmask;
	struct sockaddr_dl *sdl;
	struct sockaddr *ap;
	NSString* routeType;
	
	do {
		// make sure we have a routing socket
		if (mRoutingSocket <= 0) {
			mRoutingSocket = psGetRoutingSocket();
			if (mRoutingSocket <= 0) {
				[delegate updateParameter:@"statusInfo" withObject:@"arpDelete routing socket failure"];
				break;
			}
		}
		// setup data buffer
		data = [NSMutableData dataWithCapacity:255];
		
		// setup access to message areas
		dp = [data mutableBytes];
		rtm = (struct rt_msghdr *)&dp[0];
		ap = (struct sockaddr *)&dp[sizeof(struct rt_msghdr)];
		sa_dst = (struct sockaddr_in *)ap;
		
		// load message
		// rt_msghdr
		bzero(&dp[0], 255);
		rtm->rtm_msglen = sizeof(struct rt_msghdr);
		rtm->rtm_type = RTM_ADD;
		rtm->rtm_version = RTM_VERSION;
		rtm->rtm_seq = ++seq;
		// attributes
		rtm->rtm_flags |= RTF_UP;
		if ([anObject objectForKey:RE_attributeStatic]) rtm->rtm_flags |= RTF_STATIC;
		// handle each route type as a seprate case
		routeType = [(NSDictionary *)anObject objectForKey:RE_type];

		// Default Route
		if ([routeType isEqualTo:RE_typeDefault]) {
			// default - match any destination (destination = 0, mask = 0)
			rtm->rtm_flags |= RTF_GATEWAY;
			// RTA_DST
			rtm->rtm_addrs |= RTA_DST;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_dst->sin_len = sizeof(struct sockaddr_in);
			sa_dst->sin_family = AF_INET;
			sa_dst->sin_addr.s_addr = htonl(0);
			// RTA_GATEWAY
			rtm->rtm_addrs |= RTA_GATEWAY;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_gateway = (struct sockaddr_in *)NEXT_SA(ap);
			sa_dst->sin_len = sizeof(struct sockaddr_in);
			sa_dst->sin_family = AF_INET;
			sa_dst->sin_addr.s_addr = htonl(ipForString([anObject objectForKey:RE_gateway]));
			// RTA_NETMASK
			rtm->rtm_addrs |= RTA_NETMASK;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_netmask = (struct sockaddr_in *)NEXT_SA(ap);
			sa_netmask->sin_len = 8;
			sa_netmask->sin_family = AF_INET;
			sa_netmask->sin_addr.s_addr = htonl(0);
		}
		// Host Route
		else if ([routeType isEqualTo:RE_typeHost]) {
			// host - the destination is a complete host address (RTF_HOST,host number != 0)
			u_int32_t address, mask;
			netNumberForString([anObject objectForKey:RE_destination], &address, &mask);
			rtm->rtm_flags |= RTF_HOST | RTF_GATEWAY;
			// RTA_DST
			rtm->rtm_addrs |= RTA_DST;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_dst->sin_len = sizeof(struct sockaddr_in);
			sa_dst->sin_family = AF_INET;
			sa_dst->sin_addr.s_addr = htonl(address);
			// RTA_GATEWAY
			rtm->rtm_addrs |= RTA_GATEWAY;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_gateway = (struct sockaddr_in *)NEXT_SA(ap);
			sa_dst->sin_len = sizeof(struct sockaddr_in);
			sa_dst->sin_family = AF_INET;
			sa_dst->sin_addr.s_addr = htonl(ipForString([anObject objectForKey:RE_gateway]));
#if 0
			// mask is implied for host route
			// RTA_NETMASK
			rtm->rtm_addrs |= RTA_NETMASK;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_netmask = (struct sockaddr_in *)NEXT_SA(ap);
			sa_netmask->sin_len = 8;
			sa_netmask->sin_family = AF_INET;
			sa_netmask->sin_addr.s_addr = htonl(mask);
#endif
		}
		// Indirect Route
		else if ([routeType isEqualTo:RE_typeIndirect]) {
			// indirect - the route is to a gateway (router)  (rtm->rtm_flags = RTF_GATEWAY)
			u_int32_t address, mask;
			netNumberForString([anObject objectForKey:RE_destination], &address, &mask);
			rtm->rtm_flags |= RTF_GATEWAY;
			// RTA_DST
			rtm->rtm_addrs |= RTA_DST;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_dst->sin_len = sizeof(struct sockaddr_in);
			sa_dst->sin_family = AF_INET;
			sa_dst->sin_addr.s_addr = htonl(address);
			// RTA_GATEWAY
			rtm->rtm_addrs |= RTA_GATEWAY;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_gateway = (struct sockaddr_in *)NEXT_SA(ap);
			sa_dst->sin_len = sizeof(struct sockaddr_in);
			sa_dst->sin_family = AF_INET;
			sa_dst->sin_addr.s_addr = htonl(ipForString([anObject objectForKey:RE_gateway]));
			// RTA_NETMASK
			rtm->rtm_addrs |= RTA_NETMASK;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_netmask = (struct sockaddr_in *)NEXT_SA(ap);
			sa_netmask->sin_len = 8;
			sa_netmask->sin_family = AF_INET;
			sa_netmask->sin_addr.s_addr = htonl(mask);
		}
		// Direct Route
		else if ([routeType isEqualTo:RE_typeDirect]) {
			// direct - the destination is directly connected (rtm->rtm_flags != RTF_GATEWAY or HOST, sdl socket)
			u_int32_t address, mask;
			netNumberForString([anObject objectForKey:RE_destination], &address, &mask);
			//rtm->rtm_flags |= RTF_LLINFO;
			// RTA_DST
			rtm->rtm_addrs |= RTA_DST;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_dst->sin_len = sizeof(struct sockaddr_in);
			sa_dst->sin_family = AF_INET;
			sa_dst->sin_addr.s_addr = htonl(address);
			// RTA_GATEWAY
			rtm->rtm_addrs |= RTA_GATEWAY;
			rtm->rtm_msglen += sizeof(struct sockaddr_dl);
			sdl = (struct sockaddr_dl *)NEXT_SA(ap);
			sdl->sdl_len = sizeof(struct sockaddr_dl);
			sdl->sdl_family = AF_LINK;
			sdl->sdl_nlen = 0;
			sdl->sdl_type = IFT_ETHER;
			sdl->sdl_index = [self indexForName:[anObject objectForKey:RE_interface]];
#if 0
			HardwareAddress* ha;	
			ha = [[[HardwareAddress alloc] init] autorelease];
			[ha setStringValue:[anObject objectForKey:RE_hwAddress]];
			[ha getHardwareAddress:(EthernetAddress_t *)&sdl->sdl_data[sdl->sdl_nlen]];
			sdl->sdl_alen = 6;
#endif
			// RTA_NETMASK
			rtm->rtm_addrs |= RTA_NETMASK;
			rtm->rtm_msglen += sizeof(struct sockaddr_in);
			sa_netmask = (struct sockaddr_in *)NEXT_SA(ap);
			sa_netmask->sin_len = 8;
			sa_netmask->sin_family = AF_INET;
			sa_netmask->sin_addr.s_addr = htonl(mask);
		}
		// send message to kernal
		returnValue = write(mRoutingSocket, (char *)rtm, rtm->rtm_msglen);
		if (returnValue < 0) {
			int errno_save;
			errno_save = errno;
			NSLog(@"%s", strerror(errno_save));					
		}
	} while (false);
	return returnValue;
}

*/
/*
	// setup to issue route command
	int result;
	int argc;
	char* argv[10];
	argv[0] = "route";	// path
	argv[1] = "route";	// command
	argv[2] = "-n";
	argv[3] = "delete";
	argc = 4;
	if ([[anObject objectForKey:RE_type] isEqualTo:RE_typeHost]) argv[argc++] = "-host";
	// destination
	argv[argc++] = (char *)[[anObject objectForKey:RE_destination] UTF8String];
	// gateway
	argv[argc++] = (char *)[[anObject objectForKey:RE_gateway] UTF8String];
	
	argv[argc] = 0;	// defensive
	optind = 2;		//  initialize for getopt

	// discard any previous output
	[[RouteOutput sharedInstance] setString:@""];
	// steal code from arp command (arp.c)
	result = psRouteMain(argc, argv);
	if (result < 0) {
		[delegate updateParameter:@"statusInfo" withObject:[RouteOutput sharedInstance]];
	}
	return result;
*/

/*
	// setup to issue route command
	int result;
	int argc;
	char* argv[10];
	NSString* type;
	
	argv[0] = "route";	// path
	argv[1] = "route";	// command
	argv[2] = "-n";
	argc = 3;
	// add command
	argv[argc++] = "add";
	// modifiers (static...)
	if ([anObject objectForKey:RE_attributeStatic]) argv[argc++] = "-static";
	else argv[argc++] = "-nostatic";
	// set destination and gateway based on type
	type = [anObject objectForKey:RE_type];
		// destination
	// host route?
	if ([type isEqualTo:RE_typeHost]) argv[argc++] = "-host";
	// default route?
	if ([type isEqualTo:RE_typeDefault]) {
		argv[argc++] = "-net";
		argv[argc++] = (char *)"0.0.0.0";
	}
	else {
		argv[argc++] = (char *)[[anObject objectForKey:RE_destination] UTF8String];
	}
		// gateway
	// direct route?
	if ([type isEqualTo:RE_typeDirect]) {
		argv[argc++] = "-interface";
		argv[argc++] =  (char *)[[anObject objectForKey:RE_interface] UTF8String];
	}
	else {
		argv[argc++] = (char *)[[anObject objectForKey:RE_gateway] UTF8String];
	}
	
	argv[argc] = 0;	// defensive
	optind = 2;		//  initialize for getopt

	// discard any previous output
	[[RouteOutput sharedInstance] setString:@""];
	// steal code from arp command (arp.c)
	result = psRouteMain(argc, argv);
	if (result < 0) {
		[delegate updateParameter:@"statusInfo" withObject:[RouteOutput sharedInstance]];
	}
	return result;
*/
