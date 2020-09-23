//
//  TDHourGroup.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 3/1/06.
//  Copyright 2006 Sustainable Softworks Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TDMinuteGroup.h"
@class TDDayGroup;

typedef struct hourSample {
	int32_t length;
	int16_t type;
	int8_t version;
	int8_t flags;
	int64_t totalIn;
	int64_t totalOut;
	int64_t maxIn;
	int64_t maxOut;
	int hourOfDay;
} hourSample_t;


@interface TDHourGroup : NSObject {
	hourSample_t sampleData;
	NSMutableDictionary* tdMinutes;
	NSString* identifier;	// service or device identifier for these samples
	NSString* bsdName;
	TDDayGroup* dayGroup;
	BOOL needsUpdate;
}
// save and restore
- (NSDictionary*)dictionary;
+ (TDHourGroup*)objectFromDictionary:(NSDictionary*)inDictionary;
- (void)setSampleData:(NSData*)inData;

// accessors
- (NSString*)identifier;
- (void)setIdentifier:(NSString*)value;
- (NSString*)bsdName;
- (void)setBsdName:(NSString*)value;
- (TDDayGroup*)dayGroup;
- (void)setDayGroup:(TDDayGroup*)value;
- (int)hourOfDay;
- (void)setHourOfDay:(int)value;

// data access
- (TDMinuteGroup*)minuteGroupForIndex:(int)minuteOfHour allocate:(BOOL)allocate;
- (void)setMinuteGroupForIndex:(int)index withObject:anObject;
- (TDEntry*)tdEntryForIndex:(unsigned)index;

- (int64_t)totalIn;
- (int64_t)totalOut;

// action
- (void)setNeedsUpdate:(BOOL)value;
- (void)doUpdate;
@end

#define kTDMinutesOfHour 60