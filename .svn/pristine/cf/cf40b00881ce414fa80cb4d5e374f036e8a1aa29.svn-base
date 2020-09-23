//
//  TriggerEntry.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 16 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import PS_TNKE_INCLUDE

@interface TriggerEntry : NSObject <NSCopying, NSCoding> {
    // Store our instance variables in a mutable dictionary to simplify
    // coding and decoding interface entries.
    NSMutableDictionary* nodeDictionary;
    // The variables to be represented are:
	//
	// NSString*	ipAddress
	// NSString*	type
	// NSNumber*	endOffset	- offset to last IP address in ragne
    // NSString* 	triggeredBy		- x.x.x rule number
	// NSNumber* 	matchCount		- kernel matchCount of this entry
	// NSDate*		lastTime
	// NSNumber*	duration
	//
    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding
	id delegate;
}

- (NSMutableDictionary *)nodeDictionary;
- (void)setNodeDictionary:(NSMutableDictionary *)value;

+ (TriggerEntry *)entryFromDictionary:(NSDictionary *)entryDictionary;

- (NSComparisonResult)compare:(TriggerEntry *)value;
- (NSString *)description;
- (NSScriptObjectSpecifier *)objectSpecifier;

- (NSString *)ipAddress;
- (void)setIpAddress:(NSString *)value;

- (NSNumber *)type;
- (void)setType:(NSNumber *)value;
- (NSString *)typeString;

	// support address ranges
- (NSNumber *)endOffset;
- (void)setEndOffset:(NSNumber *)value;
- (NSString *)addressString;
- (void)setAddressString:(NSString *)value;

- (NSString *)triggeredBy;
- (void)setTriggeredBy:(NSString *)value;

- (NSNumber *)matchCount;
- (void)setMatchCount:(NSNumber *)value;

- (NSDate *)lastTime;
- (void)setLastTime:(NSDate *)value;

- (NSNumber *)duration;
- (void)setDuration:(NSNumber *)value;
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

int triggerObjectToData(TriggerEntry* inObject, KFT_triggerEntry_t* data);
TriggerEntry* triggerObjectFromData(KFT_triggerEntry_t* inData);

#define TT_addressString	@"addressString"
#define TT_ipAddress		@"ipAddress"
#define TT_type				@"type"
#define TT_endOffset		@"endOffset"
#define TT_triggeredBy		@"triggeredBy"
#define TT_matchCount		@"matchCount"
#define TT_duration			@"duration"
#define TT_lastTime			@"lastTime"

#define kTriggerTypeTrigger	0
#define kTriggerTypeAddress	1
#define kTriggerTypeAuthorize 2
#define kTriggerTypeInvalid 3
#define kTriggerTypeTriggerStr	@"trigger"
#define kTriggerTypeAddressStr	@"address"
#define kTriggerTypeAuthorizeStr @"authorize"
#define kTriggerTypeInvalidStr @"invalid"

