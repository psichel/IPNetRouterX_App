//
//  NameEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Jun 3 2004.
//  Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//

#import "NameEntry.h"
#import "IPSupport.h"
//#import "PSSharedDictionary.h"
//#import "IPValue.h"
//#import <netinet/tcp_fsm.h>

@implementation NameEntry
// ---------------------------------------------------------------------------------
//	¥ entryFromDictionary
// ---------------------------------------------------------------------------------
+ (NameEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	NameEntry* entry;
	entry = [[[NameEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

// accessors
- (NSString *)title { return [nodeDictionary objectForKey:NE_title]; }
- (void)setTitle:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:NE_title];
    else [nodeDictionary removeObjectForKey:NE_title];
}

- (NSString *)identifier { return [nodeDictionary objectForKey:NE_identifier]; }
- (void)setIdentifier:(NSString *)value
{
    if (value) [nodeDictionary setObject:value forKey:NE_identifier];
    else [nodeDictionary removeObjectForKey:NE_identifier];
}

@end
