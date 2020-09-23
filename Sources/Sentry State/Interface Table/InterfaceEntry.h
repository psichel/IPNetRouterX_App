//
//  InterfaceEntry.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ipkTypes.h"


@interface InterfaceEntry : NSObject <NSCopying, NSCoding> {
    // Store our instance variables in a mutable dictionary to simplify
    // coding and decoding interface entries.
    NSMutableDictionary* nodeDictionary;
    // The variables to be represented are:
	//
	// NSNumber* filterOn
	// NSNumber* externalOn
	// NSNumber* natOn
	// NSNumber* bridgeOn
	// NSString* interfaceName
	// NSString* serviceID
	// NSString* interfaceID
	// NSString* ifNet
	// NSString* natNet
	// NSString* singleNet
	// NSString* excludeNet
	// NSNumber* exposedHostSelection
	// NSString* exposedHost
	// NSString* gateway1
	// NSString* gateway2
	//
    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding
}

- (NSMutableDictionary *)nodeDictionary;
- (void)setNodeDictionary:(NSMutableDictionary *)value;

+ (InterfaceEntry *)entryFromDictionary:(NSDictionary *)entryDictionary;
- (NSString *)description;
- (NSScriptObjectSpecifier *)objectSpecifier;

// Interface table visible
- (NSNumber *)filterOn;
- (void)setFilterOn:(NSNumber *)value;

- (NSNumber *)externalOn;
- (void)setExternalOn:(NSNumber *)value;

- (NSNumber *)natOn;
- (void)setNatOn:(NSNumber *)value;

- (NSNumber *)bridgeOn;
- (void)setBridgeOn:(NSNumber *)value;

- (NSString *)bsdName;
- (NSString *)interfaceName;
- (void)setInterfaceName:(NSString *)value;

- (NSString *)serviceID;
- (void)setServiceID:(NSString *)value;

- (NSString *)interfaceID;
- (void)setInterfaceID:(NSString *)value;

- (NSString *)ifNet;
- (void)setIfNet:(NSString *)value;

- (NSString *)natNet;
- (void)setNatNet:(NSString *)value;

- (NSString *)singleNet;
- (void)setSingleNet:(NSString *)value;

// Interface table implicit
- (NSString *)excludeNet;
- (void)setExcludeNet:(NSString *)value;

- (NSNumber *)exposedHostSelection;
- (void)setExposedHostSelection:(NSNumber *)value;

- (NSString *)exposedHost;
- (void)setExposedHost:(NSString *)value;

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

int interfaceObjectToData(InterfaceEntry* interfaceE, KFT_interfaceEntry_t* outData);
InterfaceEntry* interfaceObjectFromData(KFT_interfaceEntry_t* inData);

// Interface table visible
#define IT_filterOn				@"filterOn"
#define IT_externalOn			@"externalOn"
#define IT_natOn				@"natOn"
#define IT_bridgeOn				@"bridgeOn"
#define IT_interfaceName		@"interfaceName"
#define IT_serviceID			@"serviceID"
#define IT_interfaceID			@"interfaceID"
#define IT_ifNet				@"ifNet"
#define IT_natNet				@"natNet"
#define IT_singleNet			@"singleNet"
// Interface table implicit
#define IT_excludeNet			@"excludeNet"
#define IT_exposedHostSelection	@"exposedHostSelection"
#define IT_exposedHost			@"exposedHost"
