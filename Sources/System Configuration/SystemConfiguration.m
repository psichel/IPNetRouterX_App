//
//  SystemConfiguration.m
//  IPNetMonitorX, IPNetRouterX, IPNetSentryX, IPNetTunerX
//
//  Created by Peter Sichel on Tue Jan 15 2002.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//	Access system configuration APIs
//	XML file /var/db/SystemConfiguration/preferences.xml
//
//	NetworkServices
//		0	(ServiceID)
//		1
//		2
//			DNS
//              ServerAddress
//					(array of strings)
//          IPv4
//				Addresses
//					(array of strings)
//				ConfigMethod
//			Interface
//				DeviceName
//					(en0,...)
//				UserDefinedName
//
//
// # finding current configuration data
//
// Setup:/Network/Global/IPv4/ServiceOrder
//		(Array of serviceIDs)
//
// Setup:/Network/Service/<serviceID>/__LINK__
//		(key to corresponding service: "NetworkServices/0")
//
// # designating service as inactive
//		<key>__INACTIVE__</key>
//		<integer>1</integer>

//CFStringRef
//SCNetworkInterfaceGetLocalizedDisplayName	(SCNetworkInterfaceRef		interface)
//AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER;


#if !BUILD_AS_HELPER_TOOL 
#import "AppDelegate.h"
#endif
#import "SystemConfiguration.h"
#import "IPValue.h"
#import "IPSupport.h"
#import "HardwareAddress.h"
//#import "RouteSupport.h"
#import <SystemConfiguration/SCDynamicStoreCopyDHCPInfo.h>
#import "unp.h"
#import "dhcp.h"
// sysctl support
#import <sys/param.h>
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <net/route.h>
#import <net/if_arp.h>
#import <net/if_dl.h>
#import <net/if.h>
#import <netinet/in.h>
#import <netinet/if_ether.h>
#include <net/if_types.h>

// Globals
NSString* SystemConfigurationNotification = @"SystemConfigurationNotification";

// forward declaration
static OSStatus CreateIPAddressListChangeCallbackSCF(
                        SCDynamicStoreCallBack callback,
                        void *contextPtr,
                        SCDynamicStoreRef *storeRef,
                        CFRunLoopSourceRef *sourceRef);

void myDynamicStoreCallback (
					SCDynamicStoreRef	store,
					CFArrayRef		changedKeys,
					void			*info
					);

void get_rtaddrs(int addrs, struct sockaddr *sa, struct sockaddr **rti_info);

// Private Methods
@interface SystemConfiguration (PrivateMethods)
- (NSString *)bsdNameForServiceID:(NSString *)serviceID;
@end

@implementation SystemConfiguration
+ (SystemConfiguration *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[SystemConfiguration allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

- (id)init {
    if (self = [super init]) {
		// initialize our instance variables
		// setup to be called back when IPv4 configuration changes
		storeRef = nil;
		sourceRef = nil;
		int result = CreateIPAddressListChangeCallbackSCF(myDynamicStoreCallback, nil, &storeRef, &sourceRef);
		if (result == 0) {
			//CF_EXPORT void CFRunLoopAddSource(CFRunLoopRef rl, CFRunLoopSourceRef source, CFStringRef mode);
			CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], sourceRef, (CFStringRef)NSDefaultRunLoopMode);
		}
		interfaceIDs = [[NSMutableDictionary alloc] initWithCapacity:16];
		purgeInterfaceIDs = YES;
    }
    return self;
}
- (void)dealloc {
	[interfaceIDs release];		interfaceIDs = nil;
	[super dealloc];
}


#pragma mark -- sets --
// ---------------------------------------------------------------------------------
//	¥ setsDictionary
// ---------------------------------------------------------------------------------
- (NSDictionary *)setsDictionary
{
	NSDictionary* returnValue = nil;
	SCPreferencesRef preferencesRef = nil;

    do {
        // open a session to default system configuration preferences
        preferencesRef = SCPreferencesCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil);	// prefsID
        if (preferencesRef == nil) break;

		// get dictionary
		returnValue = (NSDictionary *)SCPreferencesGetValue(preferencesRef, kSCPrefSets);
		[[returnValue retain] autorelease];
	} while (false);
	if (preferencesRef) CFRelease(preferencesRef);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ currentSet
// ---------------------------------------------------------------------------------
- (NSString *)currentSet
{
	NSString* returnValue = nil;
	SCPreferencesRef preferencesRef = nil;

    do {
        // open a session to default system configuration preferences
        preferencesRef = SCPreferencesCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil);	// prefsID
        if (preferencesRef == nil) break;

		// get dictionary
		returnValue = (NSString *)SCPreferencesGetValue(preferencesRef, kSCPrefCurrentSet);
		NSRange range = [returnValue rangeOfString:@"/Sets/"];
		if (range.length) returnValue = [returnValue substringFromIndex:range.length];
		[[returnValue retain] autorelease];
	} while (false);
	if (preferencesRef) CFRelease(preferencesRef);
    return returnValue;
}



#pragma mark -- enumerate interfaces --
// ---------------------------------------------------------------------------------
//	¥ interfaceIDs
// ---------------------------------------------------------------------------------
- (NSMutableDictionary *)interfaceIDs
{
	return interfaceIDs;
}

- (void)purgeInterfaceIDs {
	purgeInterfaceIDs = YES;
}

// ---------------------------------------------------------------------------------
//	¥ currentInterfaceTitles
// ---------------------------------------------------------------------------------
- (NSArray *)currentInterfaceTitles
{
	return [self interfaceTitlesAndServiceIDs:nil];
}

// ---------------------------------------------------------------------------------
//	¥ interfaceTitlesAndServiceIDs
// ---------------------------------------------------------------------------------
- (NSArray *)interfaceTitlesAndServiceIDs:(NSArray **)outServiceIDs
{
    NSArray* returnValue = nil;
    SCDynamicStoreRef dynamicStoreRef = nil;
    NSMutableArray* interfaceTitles;
	NSMutableArray* serviceIDs;
	NSMutableArray* deviceNames;
	NSMutableArray* userNames;
    NSString* key;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    NSDictionary* interfaceDictionary;
    NSArray* serviceOrder;
    NSEnumerator* en;
    NSString* serviceID;
    NSString* deviceName;
	NSString* userName;
	NSString* type;
	int pppIndex = 0;
	int i, j, count;
    
	// get interfaces from SCF
    interfaceTitles = [[NSMutableArray alloc] init];
	serviceIDs = [[NSMutableArray alloc] init];
    deviceNames= [[NSMutableArray alloc] init];
	userNames = [[NSMutableArray alloc] init];
    do {
        // open a session to default system configuration dynamic store
        dynamicStoreRef = SCDynamicStoreCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil,	// callout
            nil);	// *context
        if (dynamicStoreRef == nil) break;
        // get current set of serviceIDs
        key = @"Setup:/Network/Global/IPv4";
        propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
        if (propertyListRef == nil) break;
        propertyList = (NSDictionary *)propertyListRef;
        [propertyList autorelease];
        serviceOrder = [propertyList objectForKey:@"ServiceOrder"];
        // for each serviceID
        en = [serviceOrder objectEnumerator];
        while ((serviceID = [en nextObject])) {
            // get interface dictionary
            key = [NSString
                stringWithFormat:@"Setup:/Network/Service/%@/Interface",serviceID];
            propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
            if (propertyListRef == nil) continue;
            interfaceDictionary = (NSDictionary *)propertyListRef;
            [interfaceDictionary autorelease];
			type = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceType];
			if ([type isEqualTo:(NSString *)kSCValNetInterfaceTypePPP]) {
				#if 1
					//NSString* subType;
					//subType = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceSubType];
					// "PPPSerial"
					// create a valid BSD name using our best guess!
					deviceName = [NSString stringWithFormat:@"%@%d",kPPPBSDName,pppIndex];
					userName = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceDeviceName];
					if (!userName) userName = kSCNotAvailable;
					// "modem"
					[serviceIDs addObject:serviceID];
					[deviceNames addObject:deviceName];
					[userNames addObject:userName];
					pppIndex += 1;
				#else
					// add ppp as a special case
					if (!pppIndex) {
						[serviceIDs addObject:serviceID];
						[deviceNames addObject:[NSString stringWithFormat:@"%@%d",kPPPBSDName,pppIndex]];
						[userNames addObject:kPPPUserName];
					}
					pppIndex += 1;				
				#endif
				continue;
			}
            deviceName = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceDeviceName];
			userName = [interfaceDictionary objectForKey:(NSString *)kSCPropUserDefinedName];
            // add corresponding title to list
			if (deviceName == nil) deviceName = kSCNotAvailable;
			if (userName == nil) userName = kSCNotAvailable;
			[serviceIDs addObject:serviceID];
			[deviceNames addObject:deviceName];
			[userNames addObject:userName];
        }
    } while (false);

	// check for BSD devices not registered with SCF
	{
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
			
			// loop to extract RTM-INFO and RTM_NEWADDR messages
			while (offset < [data length]) {
				// access message header and address structures
				struct if_msghdr *ifm;
				struct sockaddr_dl *sdl;
				ifm = (struct if_msghdr *)&dp[offset];
				// ap points to first socket address structure
				sdl = (struct sockaddr_dl *) (ifm + 1);
				// advance for next
				offset += ifm->ifm_msglen;
				// confirm message type
				if (ifm->ifm_type != RTM_IFINFO) continue;
				// confirm sdl type
				if (sdl->sdl_family != AF_LINK) continue;
				// could confirm interface is up
				// but we want to detect inactive tun/tap devices before VPN is configured
				//if ((ifm->ifm_flags & IFF_UP) == 0) continue;
				// get ifname
				if (sdl->sdl_nlen > 0) {
					deviceName = [[[NSString alloc] initWithBytes:&sdl->sdl_data[0] length:sdl->sdl_nlen encoding:NSUTF8StringEncoding] autorelease];
					// check if we already have it
					if ([deviceNames indexOfObject:deviceName] == NSNotFound) {
						serviceID = [NSString stringWithFormat:@"=%@",deviceName];
						if ([deviceName isEqualTo:kLoopbackBSDName]) userName = kLoopbackUserName;
						else if ([deviceName hasPrefix:kTunnelBSDName]) userName = kTunnelUserName;
						else userName = @"BSD Interface";
						// add to list
						[serviceIDs addObject:serviceID];
						[deviceNames addObject:deviceName];
						[userNames addObject:userName];
					}
				}
			}
		} while (false);
		[data release];
	}
	
	// Update dictionary of interfaceIDs
	NSArray* list;
	if (purgeInterfaceIDs) {
		purgeInterfaceIDs = NO;
		// - Remove previous mapping in case any are stale entries
		[interfaceIDs removeAllObjects];
	}
	// - Create new entries as needed
	//   For each serviceID in list, lookup corresponding interfaceID
	count = [serviceIDs count];
	for (i=0; i<count; i++) {
		NSString* interfaceID;
		serviceID = [serviceIDs objectAtIndex:i];
		interfaceID = [interfaceIDs objectForKey:serviceID];
		if (!interfaceID) {
			// If not found, test each available slot to find next available
			deviceName = [deviceNames objectAtIndex:i];
			for (j=0; j<=[interfaceIDs count]; j++) {
				if (j == 0) interfaceID = deviceName;
				else interfaceID = [NSString stringWithFormat:@"%@:%d",deviceName,j];
				// test if en0:i is in dictionary using allKeysForObject	
				list = [interfaceIDs allKeysForObject:interfaceID];
				if ([list count] == 0) {
					[interfaceIDs setObject:interfaceID forKey:serviceID];
					break;
				}
			}
		}
		userName = [userNames objectAtIndex:i];
		[interfaceTitles addObject:titleForNameAndID(userName,interfaceID)];
	}

	// pass back results
    if ([interfaceTitles count]) {
		returnValue = (NSArray *)interfaceTitles;
		if (outServiceIDs) *outServiceIDs = (NSArray *)serviceIDs;
	}
    [interfaceTitles autorelease];
	[serviceIDs autorelease];
	[deviceNames autorelease];
	[userNames autorelease];

	if (dynamicStoreRef) CFRelease(dynamicStoreRef);
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ bsdTitlesAndServiceIDs
// ---------------------------------------------------------------------------------
- (NSArray *)bsdTitlesAndServiceIDs:(NSArray **)outServiceIDs
{
    NSArray* returnValue = nil;
    SCDynamicStoreRef dynamicStoreRef = nil;
    NSMutableArray* interfaceTitles;
	NSMutableArray* serviceIDs;
	NSMutableArray* deviceNames;
	NSMutableArray* userNames;
    NSString* key;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    NSDictionary* interfaceDictionary;
    NSArray* serviceOrder;
    NSEnumerator* en;
    NSString* serviceID;
    NSString* deviceName;
	NSString* userName;
	NSString* type;
	int pppIndex = 0;
	int i, count;
    
    interfaceTitles = [[NSMutableArray alloc] init];
	serviceIDs = [[NSMutableArray alloc] init];
    deviceNames= [[NSMutableArray alloc] init];
	userNames = [[NSMutableArray alloc] init];
    do {
        // open a session to default system configuration dynamic store
        dynamicStoreRef = SCDynamicStoreCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil,	// callout
            nil);	// *context
        if (dynamicStoreRef == nil) break;
        // get current set of serviceIDs
        key = @"Setup:/Network/Global/IPv4";
        propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
        if (propertyListRef == nil) break;
        propertyList = (NSDictionary *)propertyListRef;
        [propertyList autorelease];
        serviceOrder = [propertyList objectForKey:@"ServiceOrder"];
        // for each serviceID
        en = [serviceOrder objectEnumerator];
        while ((serviceID = [en nextObject])) {
            // get interface dictionary
            key = [NSString
                stringWithFormat:@"Setup:/Network/Service/%@/Interface",serviceID];
            propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
            if (propertyListRef == nil) continue;
            interfaceDictionary = (NSDictionary *)propertyListRef;
            [interfaceDictionary autorelease];
			type = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceType];
			if ([type isEqualTo:(NSString *)kSCValNetInterfaceTypePPP]) {
				#if 1
					//NSString* subType;
					//subType = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceSubType];
					// "PPPSerial"
					// create a valid BSD name using our best guess!
					deviceName = [NSString stringWithFormat:@"%@%d",kPPPBSDName,pppIndex];
					userName = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceDeviceName];
					if (!userName) userName = kSCNotAvailable;
					// "modem"
					[serviceIDs addObject:serviceID];
					[deviceNames addObject:deviceName];
					[userNames addObject:userName];
					pppIndex += 1;
				#else
					// add ppp as a special case
					if (!pppIndex) {
						[serviceIDs addObject:serviceID];
						[deviceNames addObject:[NSString stringWithFormat:@"%@%d",kPPPBSDName,pppIndex]];
						[userNames addObject:kPPPUserName];
					}
					pppIndex += 1;				
				#endif
				continue;
			}
            deviceName = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceDeviceName];
			userName = [interfaceDictionary objectForKey:(NSString *)kSCPropUserDefinedName];
            // add corresponding title to list
			if (deviceName == nil) deviceName = kSCNotAvailable;
			if (userName == nil) userName = kSCNotAvailable;
			[serviceIDs addObject:serviceID];
			[deviceNames addObject:deviceName];
			[userNames addObject:userName];
        }
    } while (false);

	// check for BSD devices not registered with SCF
	{
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
			
			// loop to extract RTM-INFO and RTM_NEWADDR messages
			while (offset < [data length]) {
				// access message header and address structures
				struct if_msghdr *ifm;
				struct sockaddr_dl *sdl;
				ifm = (struct if_msghdr *)&dp[offset];
				// ap points to first socket address structure
				sdl = (struct sockaddr_dl *) (ifm + 1);
				// advance for next
				offset += ifm->ifm_msglen;
				// confirm message type
				if (ifm->ifm_type != RTM_IFINFO) continue;
				// confirm sdl type
				if (sdl->sdl_family != AF_LINK) continue;
				// confirm interface is up
				if ((ifm->ifm_flags & IFF_UP) == 0) continue;
				// get ifname
				if (sdl->sdl_nlen > 0) {
					deviceName = [[[NSString alloc] initWithBytes:&sdl->sdl_data[0] length:sdl->sdl_nlen encoding:NSUTF8StringEncoding] autorelease];
					// check if we already have it
					if ([deviceNames indexOfObject:deviceName] == NSNotFound) {
						serviceID = [NSString stringWithFormat:@"=%@",deviceName];
						if ([deviceName isEqualTo:kLoopbackBSDName]) userName = kLoopbackUserName;
						else if ([deviceName hasPrefix:kTunnelBSDName]) userName = kTunnelUserName;
						else userName = @"BSD Interface";
						// add to list
						[serviceIDs addObject:serviceID];
						[deviceNames addObject:deviceName];
						[userNames addObject:userName];
					}
				}
			}
		} while (false);
		[data release];
	}

	// - Create new entries as needed
	//   For each serviceID in list, lookup corresponding interfaceID
	count = [serviceIDs count];
	for (i=0; i<count; i++) {
		[interfaceTitles addObject:titleForNameAndID(
			[userNames objectAtIndex:i],[deviceNames objectAtIndex:i])];
	}

	// pass back results
    if ([interfaceTitles count]) {
		returnValue = (NSArray *)interfaceTitles;
		if (outServiceIDs) *outServiceIDs = (NSArray *)serviceIDs;
	}
    [interfaceTitles autorelease];
	[serviceIDs autorelease];
	[deviceNames autorelease];
	[userNames autorelease];

	if (dynamicStoreRef) CFRelease(dynamicStoreRef);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ serviceIDForInterface:
// ---------------------------------------------------------------------------------
- (NSString *)serviceIDForInterface:(NSString *)bsdName
    // return serviceID for accessing DHCP lease information
{
    SCPreferencesRef prefs = nil;
    NSString* path;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    NSArray* serviceOrder;
    NSEnumerator* en;
    NSString* serviceID;
    NSString* deviceName = nil;
    NSString* returnValue = nil;
    
    do {
		if ([bsdName isEqualTo:kLoopbackBSDName]) {
			returnValue = kLoopbackServiceID;
			break;
		}
        prefs = SCPreferencesCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil);	// prefsID (nil = default system preferences)
                    // Use Real Preference file: /var/db/SystemConfiguration/preferences.xml
        if (prefs == nil) {
            NSLog(@"serviceIDForInterface: open session for System Configuration failed");
            break;
        }
        // get service order for current set
        propertyListRef = SCPreferencesGetValue(prefs, (CFStringRef)@"CurrentSet");
        path = (NSString *)propertyListRef;
        path = [NSString stringWithFormat:@"%@/Network/Global/IPv4", path];
        propertyListRef = SCPreferencesPathGetValue(prefs, (CFStringRef)path);
        if (propertyListRef == nil) break;
        propertyList = (NSDictionary *)propertyListRef;
        serviceOrder = [propertyList objectForKey:@"ServiceOrder"];
        // for each serviceID
        en = [serviceOrder objectEnumerator];
        while ((serviceID = [en nextObject])) {
            // get interface dictionary
            path = [NSString
                stringWithFormat:@"/NetworkServices/%@/Interface",serviceID];
            propertyListRef = SCPreferencesPathGetValue(prefs, (CFStringRef)path);
            if (propertyListRef == nil) continue;
            propertyList = (NSDictionary *)propertyListRef;
            // look for matching device name
            deviceName = [propertyList objectForKey:(NSString *)kSCPropNetInterfaceDeviceName];
            if ([deviceName isEqualTo:bsdName]) {
                // get corresponding serviceID
                returnValue = serviceID;
                break;
            }
        }
    } while (false);
    // close session
    if (prefs) CFRelease(prefs);
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ bsdNameForServiceID:
// ---------------------------------------------------------------------------------
- (NSString *)bsdNameForServiceID:(NSString *)serviceID
{
    NSString* returnValue = nil;
	SCDynamicStoreRef dynamicStoreRef = nil;
    NSString* key;
    CFPropertyListRef propertyListRef;
    NSDictionary* interfaceDictionary;
	NSString* type;
    
    do {
		if ([serviceID hasPrefix:kServiceIDPrefixBSD]) {
			returnValue = [serviceID substringFromIndex:1];
			break;
		}
        // open a session to default system configuration dynamic store
        dynamicStoreRef = SCDynamicStoreCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil,	// callout
            nil);	// *context
        if (dynamicStoreRef == nil) break;
		// get interface dictionary
		key = [NSString stringWithFormat:@"Setup:/Network/Service/%@/Interface",serviceID];
		propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
		if (propertyListRef == nil) break;
		interfaceDictionary = (NSDictionary *)propertyListRef;
		[interfaceDictionary autorelease];
		type = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceType];
		if ([type isEqualTo:(NSString *)kSCValNetInterfaceTypePPP])
			returnValue = @"ppp0";
		else
			returnValue = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceDeviceName];
	} while (false);
	if (dynamicStoreRef) CFRelease(dynamicStoreRef);
    return returnValue;
}

#pragma mark -- sysctl support --

// ---------------------------------------------------------------------------------
//	¥ getParameter:
// ---------------------------------------------------------------------------------
- (NSData *)getParameter:(NSArray *)mibName
// return sysctl data for corresponding mibName
// mibName is an array of NSNumber
// return nil on error
{
    NSData* returnValue = nil;
	NSMutableData* data;
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
		// get size required
		returnLen = 0;
		sysctl(mib, [mibName count], nil, &returnLen, nil, 0);
		returnLen += 512;	// add some cushion
		// try to get a new buffer that size
		data = [NSMutableData dataWithCapacity:returnLen];
		if (data) {
			[data setLength:returnLen];
		}
		else break;
		// try our request again
		if (sysctl(mib, [mibName count],
			[data mutableBytes], &returnLen, nil, 0) < 0) break;
        // set size for the amount of data we got
        [data setLength:returnLen];
        // pass back resulting data
        returnValue = data;
    } while (false);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ bsdName:interfaceDataForKey:
// ---------------------------------------------------------------------------------
// Return composite information for key from BSD layer using sysctl when interface is not in SCF
- (NSString *)bsdName:(NSString *)bsdName interfaceDataForKey:(NSString *)infoKey
    // obtain interface information for requested key
    // grantAddress
	// subnetMask
	// netNumber
	// linkStatus
	// hardwareAddress
{
    NSString* returnValue = kSCNotAvailable;
    NSArray* mibName;
    NSData* data = nil;
	u_int8_t* dp;
    int offset;
	// RTM messages
	struct if_msghdr *ifm;
	struct ifa_msghdr *ifam;
	struct sockaddr *sa, *rti_info[RTAX_MAX];
	struct sockaddr_dl *sdl;
	struct sockaddr_in *sin;
	BOOL nameDidMatch = NO;
    
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
	
	// loop to extract RTM-INFO and RTM_NEWADDR messages
	while (offset < [data length]) {
		// access message header and address structures
		ifm = (struct if_msghdr *)&dp[offset];
		// advance for next RTM_GET
		offset += ifm->ifm_msglen;
		
		// handle message type RTM_IFINFO
		if (ifm->ifm_type == RTM_IFINFO) {
			// sdl points to first socket address structure
			sdl = (struct sockaddr_dl *) (ifm + 1);
			// confirm sdl type
			if (sdl->sdl_family != AF_LINK) continue;
			// get ifname
			if (sdl->sdl_nlen > 0) {
				NSString* name;
				name = [[[NSString alloc] initWithBytes:&sdl->sdl_data[0] length:sdl->sdl_nlen encoding:NSUTF8StringEncoding] autorelease];
				// check if names match
				if ([name isEqualTo:bsdName]) {
					nameDidMatch = YES;
					if ([infoKey isEqualTo:@"hardwareAddress"]) {
						if (sdl->sdl_alen == 6) {
							HardwareAddress* ha = [[[HardwareAddress alloc] init] autorelease];
							[ha setHardwareAddress:(EthernetAddress_t *)&sdl->sdl_data[sdl->sdl_nlen]];
							returnValue = [ha stringValue];
							break;
						}
					}
					if ([infoKey isEqualTo:@"linkStatus"]) {
						if ((ifm->ifm_flags & IFF_UP) == 0) returnValue = @"Inactive";
						else returnValue = @"Active";
						break;
					}
				}	// if ([name isEqualTo:bsdName]) {
				else nameDidMatch = NO;
			}
		}	// if (ifm->ifm_type == RTM_IFINFO) {
		
		// handle message type RTM_NEWADDR
		else if (ifm->ifm_type == RTM_NEWADDR) {			
			// confirm interfce name
			if (!nameDidMatch) continue;
			ifam = (struct ifa_msghdr *) ifm;
			// sa points to first socket address structure
			sa = (struct sockaddr *) (ifam + 1);
			get_rtaddrs(ifm->ifm_addrs, sa, rti_info);
			u_int32_t addr = 0;
			u_int32_t mask = 0;
			// ip addr
			if ( (sa = rti_info[RTAX_IFA]) != NULL) {
				if (sa->sa_family != AF_INET) continue;
				sin = (struct sockaddr_in *)sa;
				addr = ntohl(sin->sin_addr.s_addr);
			}
			// mask
			if ( (sa = rti_info[RTAX_NETMASK]) != NULL) {
				//if (sa->sa_family != AF_INET) continue;	// tap0 mask does not set this
				sin = (struct sockaddr_in *)sa;
				mask = ntohl(sin->sin_addr.s_addr);
			}				
			// return requested info
			if ([infoKey isEqualTo:@"grantAddress"]) {
				returnValue = stringForIP(addr);
				break;
			}
			if ([infoKey isEqualTo:@"subnetMask"]) {
				returnValue = stringForIP(mask);
				break;
			}
			if ([infoKey isEqualTo:@"netNumber"]) {
				returnValue = stringForNetNumber(addr, mask);
				break;
			}
		}	// if (ifm->ifm_type == RTM_NEWADDR) {
	}	// while (offset < [data length]) {
	[data release];
	return returnValue;
}

#pragma mark -- interface attributes --
// ---------------------------------------------------------------------------------
//	¥ service:interfaceDataForKey:
// ---------------------------------------------------------------------------------
// composite SCF information for key
- (NSString *)service:(NSString *)serviceID interfaceDataForKey:(NSString *)infoKey
    // obtain interface information for requested key
    // grantAddress
	// grantAddress6
	// subnetMask
	// grantAddress6
	// subnetMask
	// netNumber
	// linkStatus
	// hardwareAddress
{
    NSString* bsdName;
    NSString* returnValue = kSCNotAvailable;
	int count, i;
    
    do {
        // check for BSD layer interface not in SCF
		if ([serviceID hasPrefix:kServiceIDPrefixBSD]) {
			bsdName = [serviceID substringFromIndex:1];
			return [self bsdName:bsdName interfaceDataForKey:infoKey];
		}
		bsdName = [self bsdNameForServiceID:serviceID];

        if ([infoKey isEqualTo:@"grantAddress"]) {
            // get interface addresses
            NSArray* addresses;
			addresses = [self service:serviceID dataForDictionaryName:@"IPv4" key:@"Addresses"];
			if (![addresses count]) {
				// no addresses found under serviceID, try corresponding bsdName
				addresses = [self interface:bsdName dataForDictionaryName:@"IPv4" key:@"Addresses"];
			}
            if ([addresses count]) returnValue = [addresses componentsJoinedByString:@","];
        }
        else if ([infoKey isEqualTo:@"grantAddress6"]) {
            // get interface addresses
            NSArray* addresses;
			NSArray* prefixLengths;
			addresses = [self interface:bsdName dataForDictionaryName:@"IPv6" key:@"Addresses"];
			prefixLengths = [self interface:bsdName dataForDictionaryName:@"IPv6" key:@"PrefixLength"];
            if ((count = [addresses count])) {
				NSMutableString *result = [NSMutableString string];
				for (i=0; i<count; i++) {
					if (i) [result appendString:@","];
					[result appendFormat:@"%@/%@",[addresses objectAtIndex:i],[prefixLengths objectAtIndex:i]];
				}
				returnValue = result;
			}
        }
        else if ([infoKey isEqualTo:@"subnetMask"]) {
            // get interface subnet masks
            NSArray* netMasks;
			netMasks = [self service:serviceID dataForDictionaryName:@"IPv4" key:@"SubnetMasks"];
			if (![netMasks count]) {
				// no addresses found under serviceID, try corresponding bsdName
				netMasks = [self interface:bsdName dataForDictionaryName:@"IPv4" key:@"SubnetMasks"];		
			}
			if ([netMasks count]) returnValue = [netMasks componentsJoinedByString:@","];
        }		
        else if ([infoKey isEqualTo:@"netNumber"]) {
            // get interface addresses and masks
            NSArray* addresses;
            NSArray* netMasks;
			int i, count;
			NSString* addressStr;
			NSString* maskStr;
			NSString* prefixLenStr;
			NSString* netNumberStr;
			NSMutableArray* netNumbers = [[[NSMutableArray alloc] init] autorelease];
			
			addresses = [self service:serviceID dataForDictionaryName:@"IPv4" key:@"Addresses"];
			netMasks = [self service:serviceID dataForDictionaryName:@"IPv4" key:@"SubnetMasks"];			
			if (![addresses count]) {
				// no addresses found under serviceID, try corresponding bsdName
				addresses = [self interface:bsdName dataForDictionaryName:@"IPv4" key:@"Addresses"];
				netMasks = [self interface:bsdName dataForDictionaryName:@"IPv4" key:@"SubnetMasks"];		
			}
						
			count = [addresses count];
			for (i=0; i<count; i++) {
				addressStr = [addresses objectAtIndex:i];
				if (!addressStr) continue;
				maskStr = [netMasks objectAtIndex:i];
				if (!maskStr) prefixLenStr = @"32";
				else {
					prefixLenStr = prefixForMaskStr(maskStr);
					if ([prefixLenStr intValue] == 0) prefixLenStr = @"32";
				}
				netNumberStr = [NSString stringWithFormat:@"%@/%@",addressStr,prefixLenStr];
				[netNumbers addObject:netNumberStr];
			}
            if ([netNumbers count]) returnValue = [netNumbers componentsJoinedByString:@","];
        }		
        else if ([infoKey isEqualTo:@"linkStatus"]) {
            // get interface state
            NSString* state;
			state = [self interface:bsdName dataForDictionaryName:@"Link" key:@"Active"];
			if (!state) returnValue = @"Not reported";
			else if ([state intValue] == 1) returnValue = @"Active";
			else returnValue = @"Inactive";
        }
        else if ([infoKey isEqualTo:@"hardwareAddress"]) {
			// use sysctl to read hardware address info since Leopard no longer keeps it in same place in SCF
			returnValue = [self bsdName:bsdName interfaceDataForKey:infoKey];
#if 0
			NSString* key;
			CFPropertyListRef propertyListRef;
			NSDictionary* propertyList;
			SCDynamicStoreRef dynamicStoreRef = nil;
			do {
				// open a session to default system configuration dynamic store
				dynamicStoreRef = SCDynamicStoreCreate(
					nil,	// allocator
					(CFStringRef)PS_BUNDLE_ID,	// caller name
					nil,	// callout
					nil);	// *context
				if (dynamicStoreRef == nil) break;

				// get hardware address
				NSString* hardware;
				NSString* hardwareAddress;

				// get hardware type
				key = [NSString stringWithFormat:@"Setup:/Network/Service/%@/Interface", serviceID];
//				key = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv6", bsdName];
				propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
				if (propertyListRef == nil) break;
				propertyList = (NSDictionary *)propertyListRef;
				[propertyList autorelease];
//NSLog(@"%@",[propertyList description]);
				hardware = [propertyList objectForKey:@"Hardware"];

				// get MAC Address for hardware
				key = [NSString stringWithFormat:@"Setup:/Network/Service/%@/%@", serviceID, hardware];
				propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
				if (propertyListRef == nil) break;
				propertyList = (NSDictionary *)propertyListRef;
				[propertyList autorelease];
				hardwareAddress = [propertyList objectForKey:@"MACAddress"];
				if (hardwareAddress) returnValue = hardwareAddress;
			} while (false);
			if (dynamicStoreRef) CFRelease(dynamicStoreRef);
#endif
		}
		else {
			NSLog(@"interfaceDataForKey unknown request");
		}
    } while (false);

    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ service:dataForDictionaryName:key:
// ---------------------------------------------------------------------------------
// raw SCF information for key
- (id)service:(NSString *)serviceID dataForDictionaryName:(NSString *)dictionaryKey key:(NSString *)infoKey
    // obtain service information for requested dictionary and key
    // IPv4/Addresses
    // IPv4/SubnetMasks
	// IPv4/Router
    // DNS/ServerAddresses
	// IPv6/Addresses
	// IPv6/PrefixLength
    //
    // Using the flattenned dictionaries of the SystemConfiguration Framework,
    // we build a key for the desired dictionary, and then request the corresponding object.
    // The object will generally be an NSArray or NSString based on the requested infoKey.
{
	SCDynamicStoreRef dynamicStoreRef = nil;
    NSString* key;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    id returnValue = nil;
    
    do {
        if ([serviceID hasPrefix:kServiceIDPrefixBSD]) break;
        // open a session to default system configuration dynamic store
        dynamicStoreRef = SCDynamicStoreCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil,	// callout
            nil);	// *context
		if (dynamicStoreRef == nil) break;
		// get requested dictionary in State domain
        key = [NSString stringWithFormat:@"State:/Network/Service/%@/%@", serviceID, dictionaryKey];
        propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
        if (propertyListRef) {
			propertyList = (NSDictionary *)propertyListRef;
			[propertyList autorelease];
//			NSLog(@"%@",[propertyList description]);
			returnValue = [propertyList objectForKey:infoKey];
			if (returnValue) break;
		}
		// if no match found, look for setting in static store
		returnValue = [self staticService:serviceID dataForDictionaryName:dictionaryKey key:infoKey];
    } while (false);
	if (dynamicStoreRef) CFRelease(dynamicStoreRef);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ staticService:dataForDictionaryName:key:
// ---------------------------------------------------------------------------------
// look for matching information from static versus dynamic store
- (id)staticService:(NSString *)serviceID dataForDictionaryName:(NSString *)dictionaryKey key:(NSString *)key
{
    SCPreferencesRef prefs = nil;
    NSString* path;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    NSString* returnValue = nil;
    
    do {
        if ([serviceID hasPrefix:kServiceIDPrefixBSD]) break;
        prefs = SCPreferencesCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil);	// prefsID (nil = default system preferences)
                    // Use Real Preference file: /var/db/SystemConfiguration/preferences.xml
        if (prefs == nil) {
            NSLog(@"serviceIDForInterface: open session for System Configuration failed");
            break;
        }
		// get service dictionary
		path = [NSString stringWithFormat:@"/NetworkServices/%@/%@", serviceID, dictionaryKey];
		propertyListRef = SCPreferencesPathGetValue(prefs, (CFStringRef)path);
		if (propertyListRef == nil) break;
		propertyList = (NSDictionary *)propertyListRef;
		// make a copy that will outlive CFRelease(prefs)
		returnValue = [[propertyList objectForKey:key] copy]; 
		[returnValue autorelease];
     } while (false);
    // close session
    if (prefs) CFRelease(prefs);
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ interface:dataForDictionaryName:key:
// ---------------------------------------------------------------------------------
- (id)interface:(NSString *)bsdName dataForDictionaryName:(NSString *)dictionaryKey key:(NSString *)infoKey
    // obtain interface information for requested dictionary and key
    // obtain service information for requested dictionary and key
    // IPv4/Addresses
    // IPv4/SubnetMasks
	// IPv4/Router
    // DNS/ServerAddresses
	// IPv6/Addresses
	// IPv6/PrefixLength
    //
    // Using the flattenned dictionaries of the SystemConfiguration Framework,
    // we build a key for the desired dictionary, and then request the corresponding object.
    // The object will generally be an NSArray or NSString based on the requested infoKey.
    // Using the flattenned dictionaries of the SystemConfiguration Framework,
    // we build a key for the desired dictionary, and then request the corresponding object.
    // The object will generally be an NSArray or NSString based on the requested infoKey.
{
	SCDynamicStoreRef dynamicStoreRef = nil;
    NSString* key;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    id returnValue = nil;
    
    do {
        // open a session to default system configuration dynamic store
        dynamicStoreRef = SCDynamicStoreCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil,	// callout
            nil);	// *context
		if (dynamicStoreRef == nil) break;
		// get requested dictionary in State domain
        key = [NSString stringWithFormat:@"State:/Network/Interface/%@/%@", bsdName, dictionaryKey];
        propertyListRef = SCDynamicStoreCopyValue(dynamicStoreRef, (CFStringRef)key);
        if (propertyListRef) {
			propertyList = (NSDictionary *)propertyListRef;
			[propertyList autorelease];
//			NSLog(@"%@",[propertyList description]);
			returnValue = [propertyList objectForKey:infoKey];
		}
    } while (false);
	if (dynamicStoreRef) CFRelease(dynamicStoreRef);
    return returnValue;
}

#if !BUILD_AS_HELPER_TOOL
#pragma mark -- DHCP Interfaces --
// ---------------------------------------------------------------------------------
//	¥ dhcpInterfaceTitles
// ---------------------------------------------------------------------------------
- (NSArray *)dhcpTitlesAndServiceIDs:(NSArray **)outServiceIDs
    // return bsd names of DHCP configured interfaces
    // use SCPreferences versus SCDynamicStore to access interfaces that are currently inactive
    // Notice when accessing the persistant store, these are not "Copy" functions,
    // so there is nothing to CFRelease except our session handle.
{
    NSArray* returnValue = nil;
    NSMutableArray* interfaceTitles;
	NSMutableArray* serviceIDs;
    SCPreferencesRef prefs = nil;
    NSString* path;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    NSDictionary* interfaceDictionary;
    NSArray* serviceOrder;
    NSEnumerator* en;
    NSString* serviceID;
    NSString* configMethod;
    NSString* deviceName;
	NSString* interfaceID;
	NSString* userName;
    
    interfaceTitles = [[NSMutableArray alloc] init];
	serviceIDs = [[NSMutableArray alloc] init];
    do {
        prefs = SCPreferencesCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil);	// prefsID (nil = default system preferences)
                    // Use Real Preference file: /var/db/SystemConfiguration/preferences.xml
        if (prefs == nil) {
            NSLog(@"dhcpInterfaces: open session for System Configuration failed");
            break;
        }
        // get service order for current set
        propertyListRef = SCPreferencesGetValue(prefs, (CFStringRef)@"CurrentSet");
        path = (NSString *)propertyListRef;
        path = [NSString stringWithFormat:@"%@/Network/Global/IPv4", path];
        propertyListRef = SCPreferencesPathGetValue(prefs, (CFStringRef)path);
        if (propertyListRef == nil) break;
        propertyList = (NSDictionary *)propertyListRef;
        serviceOrder = [propertyList objectForKey:@"ServiceOrder"];
        // for each serviceID
        en = [serviceOrder objectEnumerator];
        while ((serviceID = [en nextObject])) {
            // get interface dictionary
            path = [NSString
                stringWithFormat:@"/NetworkServices/%@/Interface",serviceID];
            propertyListRef = SCPreferencesPathGetValue(prefs, (CFStringRef)path);
            if (propertyListRef == nil) continue;
            interfaceDictionary = (NSDictionary *)propertyListRef;
            // get IPv4 dictionary
            path = [NSString
                stringWithFormat:@"/NetworkServices/%@/IPv4",serviceID];
            propertyListRef = SCPreferencesPathGetValue(prefs, (CFStringRef)path);
            if (propertyListRef == nil) continue;
            propertyList = (NSDictionary *)propertyListRef;
            // look for matching config method and device name
            configMethod = [propertyList objectForKey:@"ConfigMethod"];
            deviceName = [interfaceDictionary objectForKey:(NSString *)kSCPropNetInterfaceDeviceName];
			userName = [interfaceDictionary objectForKey:(NSString *)kSCPropUserDefinedName];
            // add corresponding title to interfaceTitles
			//if (deviceName == nil) deviceName = kSCNotAvailable;
			if (userName == nil) userName = kSCNotAvailable;
            if ([configMethod isEqualTo:@"DHCP"]) {
                // add corresponding title to interfaceTitles
				NS_DURING
				if (deviceName) {
					[serviceIDs addObject:serviceID];
					interfaceID = [interfaceIDs objectForKey:serviceID];
					if (!interfaceID) interfaceID = deviceName;
					[interfaceTitles addObject:titleForNameAndID(userName,interfaceID)];
				}
				NS_HANDLER
					NSLog(@"Exception during SystemConfiguration.m dhcpTitlesAndInterfaces");
				NS_ENDHANDLER
            }
        }
    } while (false);
    // close session
    if (prefs) CFRelease(prefs);
    if ([interfaceTitles count]) {
		returnValue = (NSArray *)interfaceTitles;
		if (outServiceIDs) *outServiceIDs = serviceIDs;
	}
    [interfaceTitles autorelease];
	[serviceIDs autorelease];
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ service:dhcpLeaseDataForKey:
// ---------------------------------------------------------------------------------
// from dhcp.h
//#define kOptionAddressTime	51
//#define kOptionDHCPServerID		54
//#define kOptionDomainServer	6
//#define kOptionRouters 3
- (NSString *)service:(NSString *)serviceID dhcpLeaseDataForKey:(NSString *)infoKey
    // obtain DHCP lease information for requested key
    // serverAddress
    // grantTime
    // expireTime
	// domainNameServers
{
	SCDynamicStoreRef dynamicStoreRef = nil;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    NSString* returnValue = kSCNotAvailable;
    
    do {
        if ([serviceID hasPrefix:kServiceIDPrefixBSD]) break;
        // open a session to default system configuration dynamic store
        dynamicStoreRef = SCDynamicStoreCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil,	// callout
            nil);	// *context
        if (dynamicStoreRef == nil) break;

		if ([infoKey isEqualTo:@"serverAddress"]) {
            CFDataRef dataRef;
            NSData* data;
            UInt32	address;
            // get DHCP info
            propertyListRef = SCDynamicStoreCopyDHCPInfo(dynamicStoreRef, (CFStringRef)serviceID);
            if (propertyListRef == nil) break;
            propertyList = (NSDictionary *)propertyListRef;
            [propertyList autorelease];
            // get corresponding option data
			// Notice Option data is in Network Byte Order!
            dataRef = DHCPInfoGetOptionData(propertyListRef, kOptionDHCPServerID);	// !copy, do not release
            if (dataRef == nil) break;
            data = (NSData *)dataRef;
            // convert option data to NSString result
            memcpy(&address, [data bytes], 4);
			if (((NTOHL(address))));
			returnValue = stringForIP(address);
        }
        else if ([infoKey isEqualTo:@"grantTime"]) {
            CFDateRef dateRef;
            NSDate* date;
            // get DHCP info
            propertyListRef = SCDynamicStoreCopyDHCPInfo(dynamicStoreRef, (CFStringRef)serviceID);
            if (propertyListRef == nil) break;
            propertyList = (NSDictionary *)propertyListRef;
            [propertyList autorelease];
            // get lease grant time
            dateRef = DHCPInfoGetLeaseStartTime(propertyListRef);   // !copy, do not release         
            if (dateRef == nil) break;
            date = (NSDate *)dateRef;
            returnValue = [date description];
        }
        else if ([infoKey isEqualTo:@"expireTime"]) {
            CFDateRef dateRef;
            NSDate* date;
            CFDataRef dataRef;
            NSData* data;
            SInt32	addressTime;
            NSTimeInterval seconds;
            // get DHCP info
            propertyListRef = SCDynamicStoreCopyDHCPInfo(dynamicStoreRef, (CFStringRef)serviceID);
            if (propertyListRef == nil) break;
            propertyList = (NSDictionary *)propertyListRef;
            [propertyList autorelease];
            // get lease grant time
            dateRef = DHCPInfoGetLeaseStartTime(propertyListRef);   // !copy, do not release
            if (dateRef == nil) break;
            date = (NSDate *)dateRef;
            // get option data
            dataRef = DHCPInfoGetOptionData(propertyListRef, kOptionAddressTime);	// !copy, do not release
            if (dataRef == nil) break;
            data = (NSData *)dataRef;
            // convert option data to NSString result
            memcpy(&addressTime, [data bytes], 4);
            seconds = ntohl(addressTime);
            date = [date dateByAddingTimeInterval:seconds];
            returnValue = [date description];
        }
        else if ([infoKey isEqualTo:@"domainNameServers"]) {
            CFDataRef dataRef;
            NSData* data;
            UInt32	address;
            UInt8*	dp;
            // get DHCP info
            propertyListRef = SCDynamicStoreCopyDHCPInfo(dynamicStoreRef, (CFStringRef)serviceID);
            if (propertyListRef == nil) break;
            propertyList = (NSDictionary *)propertyListRef;
            [propertyList autorelease];
            // get corresponding option data
            dataRef = DHCPInfoGetOptionData(propertyListRef, kOptionDomainServer);	// !copy, do not release
            if (dataRef == nil) break;
            data = (NSData *)dataRef;
            dp = (UInt8*)[data bytes];
            // convert option data to NSString result
            if ([data length] >= 4) {
                memcpy(&address, &dp[0], 4);
				if ((NTOHL(address)));
				returnValue = stringForIP(address);
            }
            if ([data length] >= 8) {
                memcpy(&address, &dp[4], 4);
				if ((NTOHL(address)));
                returnValue = [NSString stringWithFormat:@"%@, %@",returnValue, stringForIP(address)];
            }
            if ([data length] >= 12) {
                memcpy(&address, &dp[8], 4);
				if ((NTOHL(address)));
                returnValue = [NSString stringWithFormat:@"%@, %@",returnValue, stringForIP(address)];
            }
        }
        else if ([infoKey isEqualTo:@"routers"]) {
            CFDataRef dataRef;
            NSData* data;
            UInt32	address;
            UInt8*	dp;
            // get DHCP info
            propertyListRef = SCDynamicStoreCopyDHCPInfo(dynamicStoreRef, (CFStringRef)serviceID);
            if (propertyListRef == nil) break;
            propertyList = (NSDictionary *)propertyListRef;
            [propertyList autorelease];
            // get corresponding option data
            dataRef = DHCPInfoGetOptionData(propertyListRef, kOptionRouters);	// !copy, do not release
            if (dataRef == nil) break;
            data = (NSData *)dataRef;
            dp = (UInt8*)[data bytes];
            // convert option data to NSString result
            if ([data length] >= 4) {
                memcpy(&address, &dp[0], 4);
				if ((NTOHL(address)));
                returnValue = stringForIP(address);
            }
            if ([data length] >= 8) {
                memcpy(&address, &dp[4], 4);
				if ((NTOHL(address)));
                returnValue = [NSString stringWithFormat:@"%@, %@",returnValue, stringForIP(address)];
            }
            if ([data length] >= 12) {
                memcpy(&address, &dp[8], 4);
				if ((NTOHL(address)));
                returnValue = [NSString stringWithFormat:@"%@, %@",returnValue, stringForIP(address)];
            }
        }
		else {
			NSLog(@"dhcpLeaseDataForKey unknown request");
		}
    } while (false);

	if (dynamicStoreRef) CFRelease(dynamicStoreRef);
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ setInactiveInterface:
// ---------------------------------------------------------------------------------
- (NSString *)setInactiveInterface:(NSString *)bsdName
    // Set corresponding interface to be inactive so client releases the active lease.
    // Return error string or nil for success.
    // Notice we need root privileges to make changes to the System Configuration
    // so we invoke our suid root ConfigDHCP tool to do this.
{
    NSString* returnValue = nil;
    NSString* path;
	BOOL fileExists;
    NSString* serviceID;
    int result;

    path = [AppSupport toolPathForName:@"ConfigDHCP" fileExists:&fileExists];
	if (!fileExists) {
		returnValue = [NSString stringWithFormat:@"Helper tool ConfigDHCP was not found at path: %@", path];
		return returnValue;
	}
    serviceID = [self serviceIDForInterface:bsdName];
    result = [AppSupport doTask:path
            arguments:[NSArray arrayWithObjects:@"-setInactive", serviceID, nil]
            output:nil];    

    switch (result) {
        case 0:
			// normal successful completion
			returnValue = nil;
			break;
		case 1:
            returnValue = @"setInactiveInterface: open session for System Configuration failed";
            break;
        case 2:
            returnValue = @"setInactiveInterface: service entry dictionary not found";
            break;
        case 3:
            returnValue = @"setInactiveInterface: SCPreferencesPathSetValue failed";
            break;
        case 4:
            returnValue = [NSString stringWithFormat:@"SCPreferencesCommitChanges failed: Permission denied\n"];
            break;
        case 5:
            returnValue = [NSString stringWithFormat:@"SCPreferencesApplyChanges failed: Permission denied\n"];
            break;
        default:	// defensive
            returnValue = [NSString stringWithFormat:@"SCPreferencesApplyChanges failed: Unknown\n"];
            break;
    }
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ setActiveInterface:
// ---------------------------------------------------------------------------------
- (NSString *)setActiveInterface:(NSString *)bsdName
    // set corresponding interface to be inactive then active
    // so client releases the active lease and tries to rebind
    // return error string or nil for success
{
    NSString* returnValue = nil;
    NSString* path;
	BOOL fileExists;
    NSString* serviceID;
    int result;

    path = [AppSupport toolPathForName:@"ConfigDHCP" fileExists:&fileExists];
	if (!fileExists) {
		returnValue = [NSString stringWithFormat:@"Helper tool ConfigDHCP was not found at path: %@", path];
		return returnValue;
	}

    serviceID = [self serviceIDForInterface:bsdName];
    result = [AppSupport doTask:path
            arguments:[NSArray arrayWithObjects:@"-setActive", serviceID, nil]
            output:nil];    

    switch (result) {
        case 0:
			// normal successful completion
			returnValue = nil;
			break;
        case 1:
            returnValue = @"setActiveInterface: open session for System Configuration failed";
            break;
        case 2:
            returnValue = @"setActiveInterface: service entry dictionary not found";
            break;
        case 3:
            returnValue = @"setActiveInterface: SCPreferencesPathSetValue failed";
            break;
        case 4:
            returnValue = [NSString stringWithFormat:@"SCPreferencesCommitChanges failed: Permission denied\n"];
            break;
        case 5:
            returnValue = [NSString stringWithFormat:@"SCPreferencesApplyChanges failed: Permission denied\n"];
            break;
        default:
            returnValue = [NSString stringWithFormat:@"SCPreferencesApplyChanges failed: Unknown\n"];
            break;
    }
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ isActiveInterface:
// ---------------------------------------------------------------------------------
- (BOOL)isActiveInterface:(NSString *)bsdName
{
    BOOL returnValue = NO;
    SCPreferencesRef prefs = nil;
    CFPropertyListRef propertyListRef;
    NSDictionary* propertyList;
    NSString* path;
    NSNumber* value;
    
    do {
        prefs = SCPreferencesCreate(
            nil,	// allocator
            (CFStringRef)PS_BUNDLE_ID,	// caller name
            nil);	// prefsID (nil = default system preferences)
        if (prefs == nil) break;
        // get service entry dictionary
        path = [NSString stringWithFormat:@"/NetworkServices/%@",
            [self serviceIDForInterface:bsdName]];
        propertyListRef = SCPreferencesPathGetValue(prefs,
            (CFStringRef)path);
        if (propertyListRef == nil) {
            NSLog(@"isActiveInterface: service entry dictionary not found");
            break;
        }
        propertyList = (NSDictionary *)propertyListRef;
        returnValue = YES;
        // check for active service entry
        value = [propertyList objectForKey:@"__INACTIVE__"];
        if ([value intValue] == 1) returnValue = NO;
    } while (false);
    // close session
    if (prefs) CFRelease(prefs);
    return returnValue;
}
#endif

#pragma mark -- Callback Notification --
// ---------------------------------------------------------------------------------
//	¥ dynamicStoreCallback
// ---------------------------------------------------------------------------------
- (void)dynamicStoreCallback:(NSArray *)changedKeys {
	NSEnumerator* en;
	NSString* key;
	CFPropertyListRef propertyListRef;
	NSDictionary* propertyList;
	NSMutableDictionary* list;
	NSString* str;
	NSString* serviceID;
	NSRange range;

//	NSLog(@"IPv4 configuration changed");
//	NSLog(@"%@", [changedKeys description]);	//"State:/Network/Service/3/IPv4"
	en = [changedKeys objectEnumerator];
	while (key = [en nextObject]) {
		// get serviceID
		serviceID = nil;
		str = key;
		range = [str rangeOfString:@"/IPv4"];
		if (range.length) {
			str = [str substringToIndex:range.location];
			range = [str rangeOfString:@"State:/Network/Service/"];
			if (range.length) serviceID = [str substringFromIndex:range.location+range.length];
		}
		// get dictionary for key
		propertyListRef = SCDynamicStoreCopyValue(storeRef, (CFStringRef)key);
		if (propertyListRef) {
			propertyList = (NSDictionary *)propertyListRef;
			[propertyList autorelease];
//			NSLog(@"%@", [propertyList description]);
//			{ Addresses = ("192.168.0.23"); 
//			  InterfaceName = en2; 
//			  Router = "192.168.0.1"; 
//			  SubnetMasks = ("255.255.255.0"); }
			list = [NSMutableDictionary dictionary];
			[list addEntriesFromDictionary:propertyList];
			if (serviceID) [list setObject:serviceID forKey:@"ServiceID"];
			[[NSNotificationCenter defaultCenter]
				postNotificationName:SystemConfigurationNotification
				object:self
				userInfo:list];
		}
		else if (serviceID) {
			// interface became unavailable
			propertyList = [NSDictionary dictionaryWithObject:serviceID forKey:@"ServiceID"];
			[[NSNotificationCenter defaultCenter]
				postNotificationName:SystemConfigurationNotification
				object:self
				userInfo:propertyList];
		}
	}
}

// ---------------------------------------------------------------------------------
//	¥ addObserver:
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:SystemConfigurationNotification 
    object:self];
}

// ---------------------------------------------------------------------------------
//	¥ removeObserver:
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:SystemConfigurationNotification
        object:self];
}
@end

#pragma mark -- Callback Support --

static OSStatus CreateIPAddressListChangeCallbackSCF(
                        SCDynamicStoreCallBack callback,
                        void *contextPtr,
                        SCDynamicStoreRef *storeRef,
                        CFRunLoopSourceRef *sourceRef)
    // Create a SCF dynamic store reference and a
    // corresponding CFRunLoop source.  If you add the
    // run loop source to your run loop then the supplied
    // callback function will be called when local IP
    // address list changes.
{
    OSStatus                err;
    SCDynamicStoreContext   context = {0, NULL, NULL, NULL, NULL};
    SCDynamicStoreRef       ref;
    CFStringRef             pattern;
    CFArrayRef              patternList;
    CFRunLoopSourceRef      rls;

    assert(callback   != NULL);
    assert( storeRef  != NULL);
    assert(*storeRef  == NULL);
    assert( sourceRef != NULL);
    assert(*sourceRef == NULL);

    ref = NULL;
    pattern = NULL;
    patternList = NULL;
    rls = NULL;

    // Create a connection to the dynamic store, then create
    // a search pattern that finds all IPv4 entities.
    // The pattern is "State:/Network/Service/[^/]+/IPv4".

    context.info = contextPtr;
    ref = SCDynamicStoreCreate( NULL,
                                CFSTR("AddIPAddressListChangeCallbackSCF"),
                                callback,
                                &context);
    err = MySCError(ref);
    if (err == noErr) {
        pattern = SCDynamicStoreKeyCreateNetworkServiceEntity(
                                NULL,
                                kSCDynamicStoreDomainState,
                                kSCCompAnyRegex,
                                kSCEntNetIPv4);
        err = MySCError(pattern);
    }

    // Create a pattern list containing just one pattern,
    // then tell SCF that we want to watch changes in keys
    // that match that pattern list, then create our run loop
    // source.

    if (err == noErr) {
        patternList = CFArrayCreate(NULL,
                                    (const void **) &pattern, 1,
                                    &kCFTypeArrayCallBacks);
        if (!patternList) err = coreFoundationUnknownErr;
    }
    if (err == noErr) {
        BOOL result = SCDynamicStoreSetNotificationKeys(
                    ref,
                    NULL,
                    patternList);
		if (!result) {
			err = SCError();
			if (err == kSCStatusOK) err = kSCStatusFailed;
		}
    }
    if (err == noErr) {
        rls = SCDynamicStoreCreateRunLoopSource(NULL, ref, 0);
        err = MySCError(rls);
    }

    // Clean up.

    //CFQRelease(pattern);
	if (pattern) CFRelease(pattern);
    //CFQRelease(patternList);
	if (patternList) CFRelease(patternList);
    if (err != noErr) {
        //CFQRelease(ref);
		if (ref) CFRelease(ref);
        ref = NULL;
    }
    *storeRef = ref;
    *sourceRef = rls;

    assert( (err == noErr) == (*storeRef  != NULL) );
    assert( (err == noErr) == (*sourceRef != NULL) );

    return err;
}


void myDynamicStoreCallback (
					SCDynamicStoreRef	store,
					CFArrayRef		changedKeys,
					void			*info
					)
{
	[[SystemConfiguration sharedInstance] dynamicStoreCallback:(NSArray *)changedKeys];
}
					

#pragma mark -- Interface Name Utilities --
// ---------------------------------------------------------------------------------
//	¥ titleForNameAndID
// ---------------------------------------------------------------------------------
// Create interface title of the form: <userName> (<interfaceID>)
NSString* titleForNameAndID(NSString* userName, NSString* interfaceID)
{
    NSString* returnValue;
	NSString* suffix = [NSString stringWithFormat:@" (%@)",interfaceID];
	
	if ([userName hasSuffix:suffix]) returnValue = userName;
	else returnValue = [userName stringByAppendingString:suffix];
	
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ userNameForTitle
// ---------------------------------------------------------------------------------
// extract bsd name from menu title of the form: <userName>(<bsdName>)
NSString* userNameForTitle(NSString* title)
{
    NSString* returnValue = title;
    NSRange range;
    range = [title rangeOfString:@" (" options:NSBackwardsSearch];
    if (range.length) {
        returnValue = [title substringToIndex:range.location];
    }
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ interfaceIDForTitle
// ---------------------------------------------------------------------------------
// extract bsd name from menu title of the form: <userName>(<bsdName>)
NSString* interfaceIDForTitle(NSString* title)
{
    NSString* returnValue = title;
    NSRange range;
    range = [title rangeOfString:@"(" options:NSBackwardsSearch];
    if (range.length) {
        range.location += 1;
        range.length = ([title length] - range.location) - 1;
        returnValue = [title substringWithRange:range];
    }
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ bsdNameForTitle
// ---------------------------------------------------------------------------------
// extract bsd name from menu title of the form: <userName>(<bsdName>)
NSString* bsdNameForTitle(NSString* title)
{
    NSString* returnValue = title;
    NSRange range;
    range = [title rangeOfString:@"(" options:NSBackwardsSearch];
    if (range.length) {
        range.location += 1;
        range.length = ([title length] - range.location) - 1;
        returnValue = [title substringWithRange:range];
    }
	returnValue = bsdNameForInterfaceID(returnValue);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ bsdNameForInterfaceID
// ---------------------------------------------------------------------------------
// extract bsd name from interfaceID of the form: en0:1
NSString* bsdNameForInterfaceID(NSString* interfaceID)
{
    NSString* returnValue = interfaceID;
    NSRange range;
    range = [interfaceID rangeOfString:@":" options:NSBackwardsSearch];
    if (range.length) {
        returnValue = [interfaceID substringToIndex:range.location];
    }
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ mySCError
// ---------------------------------------------------------------------------------
OSStatus MySCError(const void* value)
{
	OSStatus returnValue = noErr;
	int scErr;
	if (value == nil) {
		scErr = SCError();
        if (scErr == kSCStatusOK) scErr = kSCStatusFailed;
		returnValue = scErr;
	}
	return returnValue;
}
