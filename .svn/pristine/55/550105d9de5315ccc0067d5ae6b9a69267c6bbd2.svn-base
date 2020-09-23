//
//  TDMinuteGroup.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 3/1/06.
//  Copyright 2006 Sustainable Softworks Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ipkTypes.h"
typedef struct minuteSample {
	int32_t length;
	int16_t type;
	int8_t version;
	int8_t flags;
	int bytesIn[60];
	int bytesOut[60];
	int32_t totalIn;
	int32_t totalOut;
	int32_t maxIn;
	int32_t maxOut;
	int minuteOfHour;
} minuteSample_t;

@class TDHourGroup;
@class TDEntry;

@interface TDMinuteGroup : NSObject {
	minuteSample_t sampleData;
	NSString* identifier;	// service or device identifier for these samples
	NSString* bsdName;
	TDHourGroup* hourGroup;	// pointer to containing hour group
}
// save and restore
- (NSDictionary*)dictionary;
+ (TDMinuteGroup*)objectFromDictionary:(NSDictionary*)inDictionary;
- (void)setSampleData:(NSData*)inData;
// accessors
- (NSString*)identifier;
- (void)setIdentifier:(NSString*)value;
- (NSString*)bsdName;
- (void)setBsdName:(NSString*)value;
- (TDHourGroup*)hourGroup;
- (void)setHourGroup:(TDHourGroup *)value;
- (int)minuteOfHour;
- (void)setMinuteOfHour:(int)value;
// data access
- (TDEntry*)tdEntryForIndex:(unsigned)index;
- (int)bytesInForIndex:(unsigned)index;
- (int)bytesOutForIndex:(unsigned)index;
- (int32_t)totalIn;
- (int32_t)totalOut;
- (int32_t)maxIn;
- (int32_t)maxOut;
- (TDEntry*)tdEntryRecentForIndex:(unsigned)index;
- (int)bytesInForIndexRange:(NSRange)range;
- (int)bytesOutForIndexRange:(NSRange)range;
// action
- (BOOL)addSample:(KFT_trafficEntry_t*)tEntry forDate:(NSCalendarDate*)trafficDiscoveryTime;
- (TDMinuteGroup*)previousGroup;
@end

#define kTDSecondsOfMinute 60
