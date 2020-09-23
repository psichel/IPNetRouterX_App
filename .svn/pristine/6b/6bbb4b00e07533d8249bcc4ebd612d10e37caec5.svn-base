//
//  PSSharedDictionary.h
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

#import <Foundation/Foundation.h>


@interface PSSharedDictionary : NSMutableDictionary
+ (PSSharedDictionary *)sharedInstance; // returns a shared instance of the class
@end

void saveAddressOrName(NSString* inString);
void saveAddressAndName(NSString* inAddress, NSString* inName);
// cache DNS results
void cacheSetObjectForKey(NSString* object, NSString* key);
NSString* cacheObjectForKey(NSString* key);
void cacheRemoveAllObjects();

// keys for checking whether product has been registered
#define kCheck1 @"checkRegistration"
#define kCheck2 @"helloHackers"
#define kCheck3 @"youFoundMe"
