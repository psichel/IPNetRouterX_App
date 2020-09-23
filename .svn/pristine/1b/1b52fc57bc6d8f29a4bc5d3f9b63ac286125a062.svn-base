//
//  AlternateRouteEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Wed Jan 3 2007.
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import PS_TNKE_INCLUDE

@interface AlternateRouteEntry : NSObject <NSCopying, NSCoding> {
    // Store our instance variables in a mutable dictionary to simplify
    // coding and decoding interface entries.
    NSMutableDictionary* nodeDictionary;
    // The variables to be represented are:
	//
	// NSNumber*	enabled
	// NSString*	interface
	// NSString*	gatewayIP
	// NSString*	gatewayHA
	// NSNumber*	activeConnections
	// NSNumber*	failedConnections
	// NSString*	comment
	//
    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding
}
// dictionary
- (NSMutableDictionary *)nodeDictionary;
- (void)setNodeDictionary:(NSMutableDictionary *)value;
+ (AlternateRouteEntry *)entryFromDictionary:(NSDictionary *)entryDictionary;

- (NSString *)description;
//- (NSScriptObjectSpecifier *)objectSpecifier;

// accessors
- (NSNumber *)enabled;
- (void)setEnabled:(NSNumber *)value;

- (NSString *)interface;	// corresponds to bsdName in KFT_routeEntry_t
- (void)setInterface:(NSString *)value;

- (NSString *)gatewayIP;
- (void)setGatewayIP:(NSString *)value;

- (NSString *)gatewayHA;
- (void)setGatewayHA:(NSString *)value;

- (NSNumber *)activeConnections;
- (void)setActiveConnections:(NSNumber *)value;

- (NSNumber *)failedConnections;
- (void)setFailedConnections:(NSNumber *)value;

- (NSString *)comment;
- (void)setComment:(NSString *)value;

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

int alternateRouteObjectToData(AlternateRouteEntry* inObject, KFT_routeEntry_t* data);
AlternateRouteEntry* alternateRouteObjectFromData(KFT_routeEntry_t* inData);

#define AR_enabled				@"enabled"
#define AR_interface			@"interface"
#define AR_gatewayIP			@"gatewayIP"
#define AR_gatewayHA			@"gatewayHA"
#define AR_activeConnections	@"activeConnections"
#define AR_failedConnections	@"failedConnections"
#define AR_comment				@"comment"

#define AR_routeEntry			@"alternateRouteEntry"
