//
//  PSSharedDictionary.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Nov 01 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Shared dictionary used to pass targets and results between
//  IPNetMonitor tools.  This allows each tool to access previously
//  entered targets and results from other tools without having to
//  invoke them explicitly or share the same history.
//
//  Dictionary objects and keys are NSStrings with the following
//  keys commonly used:
//	  name - target name
//    address - target address
//    url - a complete URL for a tool to be invoked

#import "PSSharedDictionary.h"
#import "IPSupport.h"

@implementation PSSharedDictionary
+ (PSSharedDictionary *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[NSMutableDictionary allocWithZone:[self zone]] init];
	}
	return sharedTask;
}
@end


// save address or name in dictionary
void
saveAddressOrName(NSString* inString)
{
    if ([inString length]) {
        if (isIPAddress(inString, nil, nil)) {
            [[PSSharedDictionary sharedInstance] setObject:inString forKey:@"address"];
            [[PSSharedDictionary sharedInstance] removeObjectForKey:@"name"];
        }
        else {
            [[PSSharedDictionary sharedInstance] setObject:inString forKey:@"name"];
            [[PSSharedDictionary sharedInstance] removeObjectForKey:@"address"];
        }
    }
    else {
        [[PSSharedDictionary sharedInstance] removeObjectForKey:@"name"];
        [[PSSharedDictionary sharedInstance] removeObjectForKey:@"address"];
    }
}

void saveAddressAndName(NSString* inAddress, NSString* inName)
{
    // address
    if ([inAddress length])
        [[PSSharedDictionary sharedInstance] setObject:inAddress forKey:@"address"];
    else
        [[PSSharedDictionary sharedInstance] removeObjectForKey:@"address"];

    // name
    if ([inName length])
        [[PSSharedDictionary sharedInstance] setObject:inName forKey:@"name"];
    else
        [[PSSharedDictionary sharedInstance] removeObjectForKey:@"name"];
}


// Cache DNS results
#define kNameCache @"NameCache"
void cacheSetObjectForKey(NSString* object, NSString* key)
{
	if (!key) {	// defensive
		PSSharedDictionary* sd;
		NSMutableDictionary* cache;
		sd = [PSSharedDictionary sharedInstance];
		cache = [sd objectForKey:kNameCache];
		if (!cache) {
			cache = [NSMutableDictionary dictionary];
			[sd setObject:cache forKey:kNameCache];
			cacheRemoveAllObjects();
		}
		if (object) [cache setObject:object forKey:key];
		else [cache removeObjectForKey:key];
	}
}

NSString* cacheObjectForKey(NSString* key)
{
	NSString* returnValue = nil;
	PSSharedDictionary* sd;
	NSMutableDictionary* cache;
	do {
		if (!key) break;
		sd = [PSSharedDictionary sharedInstance];
		cache = [sd objectForKey:kNameCache];
		if (!cache) {
			cache = [NSMutableDictionary dictionary];
			[sd setObject:cache forKey:kNameCache];
			cacheRemoveAllObjects();
		}
		returnValue = [cache objectForKey:key];
	} while (false);
	return returnValue;
}

void cacheRemoveAllObjects()
{
	NSMutableDictionary* cache;
	cache = [[PSSharedDictionary sharedInstance] objectForKey:kNameCache];
	if (cache) {
		[cache removeAllObjects];
		// load default entries
		[cache setObject:@"Broadcast" forKey:@"255.255.255.255"];
		[cache setObject:@"mDNS" forKey:@"224.0.0.251"];
		[cache setObject:@"Multicast Link-local" forKey:@"224.0.0.252"];
		[cache setObject:@"Multicast SLP v2" forKey:@"239.255.255.253"];
	}
}
