//
//  TDEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 3/21/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TDEntry : NSObject <NSCopying, NSCoding> {
	NSString* identifier;
	NSNumber* attachBytesIn;
	NSNumber* attachBytesOut;
	NSNumber* percentIn;
	NSNumber* percentOut;
	NSNumber* bytesIn;
	NSNumber* bytesOut;
	NSNumber* totalIn;
	NSNumber* totalOut;
	NSNumber* maxIn;
	NSNumber* maxOut;
	// display strings
	NSString* service;
	NSString* name;
	NSString* bsdName;
	NSString* info;
	NSCalendarDate* lastTime;
	
	int viewBy;		// display type of this entry (device, service, netflow)
	int dataIndex;	// data index of this entry used to find next/previous
	int plotIndex;	// plot index of this entry used to update plotView
}

#if 0
// key vaklue coding
- (id)valueForKey:(NSString *)key;
- (void)setValue:(id)value forKey:(NSString *)key;
#endif
- (NSString *)identifier;
- (void)setIdentifier:(NSString *)value;

- (NSNumber *)attachBytesIn;
- (void)setAttachBytesIn:(NSNumber *)value;

- (NSNumber *)attachBytesOut;
- (void)setAttachBytesOut:(NSNumber *)value;

- (NSNumber *)percentIn;
- (void)setPercentIn:(NSNumber *)value;

- (NSNumber *)percentOut;
- (void)setPercentOut:(NSNumber *)value;

- (NSNumber *)bytesIn;
- (void)setBytesIn:(NSNumber *)value;

- (NSNumber *)bytesOut;
- (void)setBytesOut:(NSNumber *)value;

- (NSNumber *)totalIn;
- (void)setTotalIn:(NSNumber *)value;

- (NSNumber *)totalOut;
- (void)setTotalOut:(NSNumber *)value;

- (NSNumber *)maxIn;
- (void)setMaxIn:(NSNumber *)value;

- (NSNumber *)maxOut;
- (void)setMaxOut:(NSNumber *)value;

- (NSString *)service;
- (void)setService:(NSString *)value;

- (NSString *)name;
- (void)setName:(NSString *)value;

- (NSString *)bsdName;
- (void)setBsdName:(NSString *)value;

- (NSString*)info;
- (void)setInfo:(NSString*)value;

- (NSCalendarDate*)lastTime;
- (void)setLastTime:(NSCalendarDate*)value;
- (NSString*)lastTimeStr;

- (int)viewBy;
- (void)setViewBy:(int)value;

- (int)dataIndex;
- (void)setDataIndex:(int)value;

- (int)plotIndex;
- (void)setPlotIndex:(int)value;

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

// key value coding
#define TDE_identifier	@"identifier"
#define TDE_attachBytesIn	@"attachBytesIn"
#define TDE_attachBytesOut	@"attachBytesOut"
#define TDE_percentIn	@"percentIn"
#define TDE_percentOut	@"percentOut"
#define TDE_bytesIn		@"bytesIn"
#define TDE_bytesOut	@"bytesOut"
#define TDE_totalIn		@"totalIn"
#define TDE_totalOut	@"totalOut"
#define TDE_maxIn		@"maxIn"
#define TDE_maxOut		@"maxOut"
#define TDE_service		@"service"
#define TDE_name		@"name"
#define TDE_bsdName		@"bsdName"
// display column identifiers
#define TDE_info		@"info"
#define TDE_lastTime	@"lastTime"

#define kTrafficDiscovery_sortBy	@"TrafficDiscovery_sortBy"