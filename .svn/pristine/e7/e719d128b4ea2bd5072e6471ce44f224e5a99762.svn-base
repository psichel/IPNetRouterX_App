//
//  RouteEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Jun 3 2004.
//  Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//
// represent a Network Routing entry
// type
// destination
// gateway
// interfaces
// attributes [Up Static]
// comment

#import <Foundation/Foundation.h>
#import "PSStateEntry.h"

@interface RouteEntry : PSStateEntry {
}

// accessors
// could use key value coding, but this is convenient and allows us to intervene
- (NSNumber *)restore;
- (void)setRestore:(NSNumber *)value;

- (NSString *)type;
- (void)setType:(NSString *)value;

- (NSString *)destination;
- (void)setDestination:(NSString *)value;

- (NSString *)gateway;
- (void)setGateway:(NSString *)value;

- (NSString *)interface;
- (void)setInterface:(NSString *)value;

- (NSString *)attributes;
- (void)setAttributes:(NSString *)value;

- (NSString *)comment;
- (void)setComment:(NSString *)value;

- (NSDate *)lastTime;
- (void)setLastTime:(NSDate *)value;
// suppport
- (NSString *)description;
@end

#define RE_restore		@"restore"
#define RE_type			@"type"
#define RE_destination  @"destination"
#define RE_gateway		@"gateway"
#define RE_interface	@"interface"
#define RE_attributes   @"attributes"
#define RE_comment		@"comment"
#define RE_lastTime		@"lastTime"

// route types are:
#define RE_typeHost		@"Host"
#define RE_typeDirect   @"Direct"
#define RE_typeIndirect @"Indirect"
#define RE_typeDefault  @"Default"

// route attributes not included in type are:
#define RE_attributeUp  @"Up"
#define RE_attributeStatic  @"Static"

