//
//  AddressScanEntry.h
//  IPNetMonitorX
//
//  Created by psichel on Fri Feb 1 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "unp.h"

typedef enum {
    kPingNone,
    kPingSent,
    kPingReturned,
    kPingTimedOut,
    kPingTargetDidNotMatch,
    kPingDestinationUnreachable,
	kPingDestinationNotUnreachable
} addressScanEntryStatus;


@interface AddressScanEntry : NSObject <NSCopying, NSCoding> {
    NSDate* startDate;
    NSTimeInterval elapsedInterval;
    int		status;
	int		pStatus;	// remember previous status (received or timed out to note changes)
    int		number;		// probe identifier
    int		type;		// probe type
    int		retry;
	// display stats
	int		sent;
	int		received;
	int		lost;
    NSString* address;
	NSString* name;
	NSString* macAddress;
    NSString* comment;
}
- (id)init;
- (void)dealloc;
- (NSDate *)startDate;
- (void)setStartDate:(NSDate *)value;
- (NSTimeInterval)elapsedInterval;
- (void)setElapsedInterval:(NSTimeInterval)value;
- (int)status;
- (void)setStatus:(int)value;
- (int)pStatus;
- (void)setPStatus:(int)value;
- (int)number;
- (void)setNumber:(int)value;
- (int)type;
- (void)setType:(int)value;
- (int)retry;
- (void)setRetry:(int)value;
// display stats
- (int)sent;
- (void)setSent:(int)value;
- (int)received;
- (void)setReceived:(int)value;
- (int)lost;
- (void)setLost:(int)value;
- (NSString *)address;
- (void)setAddress:(NSString *)value;
- (NSString *)name;
- (void)setName:(NSString *)value;
- (NSString *)macAddress;
- (void)setMacAddress:(NSString *)value;
- (NSString *)comment;
- (void)setComment:(NSString *)value;
- (id)valueForKey:(NSString *)key;
- (NSString *)description;
- (NSString *)portScanDescription;
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end

#define kProtocolTCP	6
#define kProtocolUDP	17
#define kProtocolAny	0
