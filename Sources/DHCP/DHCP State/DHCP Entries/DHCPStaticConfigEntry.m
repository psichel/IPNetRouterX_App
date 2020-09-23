////  DHCPStaticConfigEntry.m//  IPNetRouterX////  Created by Peter Sichel on Thu May 01 2003.//  Copyright (c) 2003-04 Sustainable Softworks, Inc. All rights reserved.//#import "DHCPStaticConfigEntry.h"#import "IPSupport.h"// =================================================================================//	� DHCPStaticConfigEntry// =================================================================================@implementation DHCPStaticConfigEntry- init {    if (self = [super init]) {		// initialize our instance variables		bzero(&ha16.octet[0], 16);		ipAddressInt = 0;    }    return self;}#if 0- (void) dealloc {    [super dealloc];}#endif- (void)setNodeDictionary:(NSMutableDictionary *)value {    [value retain];    [nodeDictionary release];    nodeDictionary = value;	ipAddressInt = ipForString([nodeDictionary objectForKey:DS_ipAddress]);}- (id)initWithCoder:(NSCoder *)coder{    self = [super init];	nodeDictionary = [[coder decodeObject] retain];	ipAddressInt = ipForString([nodeDictionary objectForKey:DS_ipAddress]);    return self;}+ (DHCPStaticConfigEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {	DHCPStaticConfigEntry* entry;	entry = [[[DHCPStaticConfigEntry alloc] init] autorelease];	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];	return entry;}#pragma mark -- sort by key --// ---------------------------------------------------------------------------------//	� key// ---------------------------------------------------------------------------------- (id)key { return [nodeDictionary objectForKey:DS_ipAddress]; }// ---------------------------------------------------------------------------------//	� keyInt// ---------------------------------------------------------------------------------- (u_int32_t)keyInt { return ipAddressInt; }// ---------------------------------------------------------------------------------//	� compareKey// ---------------------------------------------------------------------------------- (NSComparisonResult)compareKey:(id)key{	u_int32_t ta = ipForString([self key]);	u_int32_t tb = ipForString(key);		if (ta > tb) return NSOrderedDescending;	else if (ta < tb) return NSOrderedAscending;	return NSOrderedSame;}// ---------------------------------------------------------------------------------//	� compareKeyInt// ---------------------------------------------------------------------------------- (NSComparisonResult)compareKeyInt:(u_int32_t)key{	//u_int32_t ta = ipAddressInt	//u_int32_t tb = key;		if (ipAddressInt > key) return NSOrderedDescending;	else if (ipAddressInt < key) return NSOrderedAscending;	return NSOrderedSame;}#pragma mark --- Accessors ---- (NSString *)networkInterface { return [nodeDictionary objectForKey:DS_networkInterface]; }- (void)setNetworkInterface:(NSString *)value {    if (value) [nodeDictionary setObject:value forKey:DS_networkInterface];    else [nodeDictionary removeObjectForKey:DS_networkInterface];}- (u_int32_t)ipAddressInt { return ipAddressInt; }- (void)setIpAddressInt:(u_int32_t)value{	ipAddressInt = value;	if (value) [nodeDictionary setObject:stringForIP(value) forKey:DS_ipAddress];	else [nodeDictionary removeObjectForKey:DS_ipAddress];}- (NSString *)ipAddress { return [nodeDictionary objectForKey:DS_ipAddress]; }- (void)setIpAddress:(NSString *)value {    if (value) [nodeDictionary setObject:value forKey:DS_ipAddress];    else [nodeDictionary removeObjectForKey:DS_ipAddress];	ipAddressInt = ipForString(value);}- (NSString *)hardwareAddress { return [nodeDictionary objectForKey:DS_hardwareAddress]; }- (void)setHardwareAddress:(NSString *)value {    if (value) [nodeDictionary setObject:value forKey:DS_hardwareAddress];    else [nodeDictionary removeObjectForKey:DS_hardwareAddress];	// clear cached value	bzero(&ha16.octet[0], 16);	hlen = 0;}- (HardwareAddress16_t *)ha16 {	if (hlen == 0) {		NSString* str = [nodeDictionary objectForKey:DS_hardwareAddress];		if (str) ha16ForString(str, &ha16, &hlen);	}	return &ha16;}- (int)hlen { return hlen; }- (NSString *)clientID { return [nodeDictionary objectForKey:DS_clientID]; }- (void)setClientID:(NSString *)value {    if (value) [nodeDictionary setObject:value forKey:DS_clientID];    else [nodeDictionary removeObjectForKey:DS_clientID];}- (NSString *)comment { return [nodeDictionary objectForKey:DS_comment]; }- (void)setComment:(NSString *)value {    if (value) [nodeDictionary setObject:value forKey:DS_comment];    else [nodeDictionary removeObjectForKey:DS_comment];}@end