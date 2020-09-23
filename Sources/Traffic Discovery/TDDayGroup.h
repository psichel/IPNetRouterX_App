//
//  TDDayGroup.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 3/1/06.
//  Copyright 2006 Sustainable Softworks Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TDHourGroup.h"

typedef struct daySample {
	int32_t length;
	int16_t type;
	int8_t version;
	int8_t flags;
	int64_t totalIn;
	int64_t totalOut;
	int64_t maxIn;
	int64_t maxOut;
} daySample_t;

@interface TDDayGroup : NSObject {
	daySample_t sampleData;
	NSMutableDictionary* tdHours;
	NSString* identifier;	// service or device identifier for these samples
	NSString* name;
	NSString* bsdName;
	NSString* info;
	NSCalendarDate* lastTime;	// remember last time this entry updated
	int localEP;
	int protocol;
	int viewBy;					// remember what this sample is for
	// not saved
	NSMutableDictionary* tdCache;
	BOOL needsUpdate;
	int localPort;
	int remotePort;
	u_int8_t icmpType;
	u_int8_t icmpCode;
}
// save and restore
- (NSDictionary*)dictionary;
+ (TDDayGroup*)objectFromDictionary:(NSDictionary*)inDictionary;
- (void)setSampleData:(NSData*)inData;

// accessors
- (NSString*)identifier;
- (void)setIdentifier:(NSString*)value;
- (NSString*)name;
- (void)setName:(NSString*)value;
- (NSString*)bsdName;
- (void)setBsdName:(NSString*)value;
- (NSString*)info;
- (void)setInfo:(NSString*)value;
- (NSCalendarDate*)lastTime;
- (void)setLastTime:(NSCalendarDate*)value;

- (int)localEP;
- (void)setLocalEP:(int)value;
- (int)protocol;
- (void)setProtocol:(int)value;
- (int)viewBy;
- (void)setViewBy:(int)value;

// data access
- (TDEntry *)tdEntryForDate:(NSCalendarDate*)trafficDiscoveryTime interval:(int)interval;
- (TDEntry*)tdEntryForIndex:(unsigned)index;
- (TDHourGroup*)hourGroupForIndex:(int)hourOfDay allocate:(BOOL)allocate;
- (void)setHourGroupForIndex:(int)index withObject:anObject;

// action
- (void)setNeedsUpdate:(BOOL)value;
- (void)doUpdate;

// sorting
- (NSComparisonResult)compareTableViewRow:(TDDayGroup *)inDayGroup;

@end

#define kTDHoursOfDay 24