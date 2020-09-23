//
//  FilterStyleEntry.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 10/14/05.
//  Copyright 2005 Sustainable Softworks. All rights reserved.
//

#import "FilterStyleEntry.h"
#import "IPSupport.h"
//#import "PSSharedDictionary.h"
//#import "IPValue.h"
//#import <netinet/tcp_fsm.h>

@implementation FilterStyleEntry
// ---------------------------------------------------------------------------------
//	¥ entryFromDictionary
// ---------------------------------------------------------------------------------
+ (FilterStyleEntry *)entryFromDictionary:(NSDictionary *)entryDictionary {
	FilterStyleEntry* entry;
	entry = [[[FilterStyleEntry alloc] init] autorelease];
	[entry setNodeDictionary:[NSMutableDictionary dictionaryWithDictionary:entryDictionary]];
	return entry;
}

// accessors
- (NSString *)title { return [nodeDictionary objectForKey:SE_title]; }
- (void)setTitle:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:SE_title];
    else [nodeDictionary removeObjectForKey:SE_title];
}

- (NSString *)type { return [nodeDictionary objectForKey:SE_type]; }
- (void)setType:(NSString *)value {
    if (value) [nodeDictionary setObject:value forKey:SE_type];
    else [nodeDictionary removeObjectForKey:SE_type];
}

#pragma mark -- support --

// ---------------------------------------------------------------------------------
//	¥ description
// ---------------------------------------------------------------------------------
- (NSString *)description
{
	return [nodeDictionary description];
}

@end
