//
//  PortMapEntry.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import PS_TNKE_INCLUDE

@interface PortMapEntry : NSObject <NSCopying, NSCoding> {
    // Store our instance variables in a mutable dictionary to simplify
    // coding and decoding interface entries.
    NSMutableDictionary* nodeDictionary;
    // The variables to be represented are:
	//
	// NSNumber*	on
	// NSString*	dynamic
	// NSString*	apparentAddress
	// NSString*	apparentPort
	// NSString*	actualAddress
	// NSString*	actualPort
	// NSString*	protocol <number>(name)
	// NSNumber*	localProxy
	// NSString*	comment
	//
    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding
}
// dictionary
- (NSMutableDictionary *)nodeDictionary;
- (void)setNodeDictionary:(NSMutableDictionary *)value;
+ (PortMapEntry *)entryFromDictionary:(NSDictionary *)entryDictionary;

- (NSComparisonResult)compareActual:(PortMapEntry *)value;
- (NSComparisonResult)compareApparent:(PortMapEntry *)value;
- (NSString *)description;
- (NSScriptObjectSpecifier *)objectSpecifier;

// accessors
- (NSNumber *)enabled;
- (void)setEnabled:(NSNumber *)value;

- (NSString *)dynamic;	// corresponds to bsdName in KFT_natEntry_t
- (void)setDynamic:(NSString *)value;

- (NSString *)apparentAddress;
- (void)setApparentAddress:(NSString *)value;

- (NSString *)apparentPort;
- (void)setApparentPort:(NSString *)value;

- (NSString *)actualAddress;
- (void)setActualAddress:(NSString *)value;

- (NSString *)actualPort;
- (void)setActualPort:(NSString *)value;

- (NSString *)protocol;
- (void)setProtocol:(NSString *)value;

- (NSNumber *)localProxy;
- (void)setLocalProxy:(NSNumber *)value;

- (NSString *)comment;
- (void)setComment:(NSString *)value;

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

int portMapObjectToData(PortMapEntry* inObject, KFT_natEntry_t* data);
PortMapEntry* portMapObjectFromData(KFT_natEntry_t* inData);

#define PM_enabled				@"enabled"
#define PM_dynamic				@"dynamic"
#define PM_apparentAddress		@"apparentAddress"
#define PM_apparentPort			@"apparentPort"
#define PM_actualAddress		@"actualAddress"
#define PM_actualPort			@"actualPort"
#define PM_protocol				@"protocol"
#define PM_localProxy			@"localProxy"
#define PM_comment				@"comment"

