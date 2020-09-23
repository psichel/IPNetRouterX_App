//
//  SystemConfiguration.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on Tue Jan 15 2002.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//	Access system configuration APIs

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
// Globals
extern NSString* SystemConfigurationNotification;


@interface SystemConfiguration : NSObject {
	// interface address list changed
	SCDynamicStoreRef storeRef;
	CFRunLoopSourceRef sourceRef;
	// keep a dictionary of unique interfaceIDs (en0:x)
	NSMutableDictionary* interfaceIDs;
	BOOL purgeInterfaceIDs;
}
+ (SystemConfiguration *)sharedInstance; // returns a shared instance of the class
- (id)init;
- (void)dealloc;
// sets
- (NSDictionary *)setsDictionary;
- (NSString *)currentSet;
// enumerate interfaces
- (NSMutableDictionary *)interfaceIDs;
- (void)purgeInterfaceIDs;
- (NSArray *)currentInterfaceTitles;
- (NSArray *)interfaceTitlesAndServiceIDs:(NSArray **)outServiceIDs;
- (NSArray *)bsdTitlesAndServiceIDs:(NSArray **)outServiceIDs;
- (NSString *)serviceIDForInterface:(NSString *)bsdName;
// sysctl support
- (NSData *)getParameter:(NSArray *)mibName;
- (NSString *)bsdName:(NSString *)bsdName interfaceDataForKey:(NSString *)key;
// interface attributes
- (NSString *)service:(NSString *)serviceID interfaceDataForKey:(NSString *)key;
- (id)service:(NSString *)serviceID dataForDictionaryName:(NSString *)dictionaryKey key:(NSString *)infoKey;
    // obtain service information for requested dictionary and key
- (id)staticService:(NSString *)serviceID dataForDictionaryName:(NSString *)dictionary key:(NSString *)key;
    // obtain interface information for requested dictionary and key
- (id)interface:(NSString *)bsdName dataForDictionaryName:(NSString *)dictionaryKey key:(NSString *)infoKey;

#if !BUILD_AS_HELPER_TOOL
// DHCP interfaces
- (NSArray *)dhcpTitlesAndServiceIDs:(NSArray **)outServiceIDs;
- (NSString *)service:(NSString *)serviceID dhcpLeaseDataForKey:(NSString *)key;
- (NSString *)setInactiveInterface:(NSString *)bsdName;
    // set corresponding interface to be inactive so client releases the active lease
    // return error string or nil for success
- (NSString *)setActiveInterface:(NSString *)bsdName;
    // set corresponding interface to be inactive then active
    // so client releases the active lease and tries to rebind
    // return error string or for success
- (BOOL) isActiveInterface:(NSString *)bsdName;
#endif

// callback notification
- (void)dynamicStoreCallback:(NSArray *)changedKeys;
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
@end

// Interface name utilities
NSString* titleForNameAndID(NSString* userName, NSString* interfaceID);
NSString* userNameForTitle(NSString* title);
NSString* interfaceIDForTitle(NSString* title);
NSString* bsdNameForTitle(NSString* title);
    // extract bsd name from menu title of the form: <userName>(<bsdName>)
NSString* bsdNameForInterfaceID(NSString* interfaceID);
	// check for SC errors
OSStatus MySCError(const void* value);

#define kSCNotAvailable	NSLocalizedString(@"not available",@"not available")

#define kPPPUserName @"Modem or PPPoE"
#define kPPPBSDName	@"ppp"

#define kLoopbackServiceID @"=lo0"
#define kLoopbackUserName @"Loopback"
#define kLoopbackBSDName @"lo0"
#define kServiceIDPrefixBSD @"="

#define kTunnelUserName @"VPN Tunnel"
#define kTunnelBSDName @"tun"
#define kTapServiceID @"=tap"
