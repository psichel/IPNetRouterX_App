//
//  AddressScanEntry.m
//  IPNetMonitorX
//
//  Created by psichel on Fri Feb 1 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//

#import "AddressScanEntry.h"
#import "PSSharedDictionary.h"

@implementation AddressScanEntry

- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
        startDate = nil;
        elapsedInterval = 0;
        number = 0;
        status = 0;
		pStatus = 0;
        type = 0;
        retry = 0;
        address = nil;
		name = nil;
		macAddress = nil;
        comment = nil;
    }
    return self;
}
- (void)dealloc {
    [startDate release];	startDate = nil;
    [address release];		address = nil;
	[name release];			name = nil;
	[macAddress release];	macAddress = nil;
    [comment release];		comment = nil;
    [super dealloc];
}

- (NSDate *)startDate { return startDate; }
- (void)setStartDate:(NSDate *)value {
    [value retain];
    [startDate release];
    startDate = value;
}
- (NSTimeInterval)elapsedInterval { return elapsedInterval; }
- (void)setElapsedInterval:(NSTimeInterval)value {
    elapsedInterval = value;
}

- (int)status { return status; }
- (void)setStatus:(int)value {
    // remember previous result to detect when status changes
	if (value == kPingSent) pStatus = status;
	status = value;
}

- (int)pStatus { return pStatus; }
- (void)setPStatus:(int)value {
    pStatus = value;
}

- (int)number { return number; }
- (void)setNumber:(int)value {
    number = value;
}

- (int)type { return type; }
- (void)setType:(int)value {
    type = value;
}

- (int)retry { return retry; }
- (void)setRetry:(int)value { retry = value; }
// display stats
- (int)sent { return sent; }
- (void)setSent:(int)value { sent = value; }

- (int)received { return received; }
- (void)setReceived:(int)value { received = value; }

- (int)lost { return lost; }
- (void)setLost:(int)value { lost = value; }

- (NSString *)address { return address; }
- (void)setAddress:(NSString *)value {
    [value retain];
    [address release];
    address = value;
}

- (NSString *)name { return name; }
- (void)setName:(NSString *)value {
    [value retain];
    [name release];
    name = value;
}

- (NSString *)macAddress { return macAddress; }
- (void)setMacAddress:(NSString *)value {
    [value retain];
    [macAddress release];
    macAddress = value;
}

- (NSString *)comment { return comment; }
- (void)setComment:(NSString *)value {
    [value retain];
    [comment release];
    comment = value;
}

- (id)valueForKey:(NSString *)key {
    NSMutableAttributedString* strA;
    NSAttributedString* greenCheck;
    NSAttributedString* redX;
	int value;
    id returnValue = @"";

    if ([key isEqualToString:@"Port"]) {
        returnValue = [NSString stringWithFormat:@"%d",[self number]];
    }
    else if ([key isEqualTo:@"Type"]) {
        if ([self type] == IPPROTO_TCP) returnValue = @"TCP";
        else if ([self type] == IPPROTO_UDP) returnValue = @"UDP";
        else if ([self type] == IPPROTO_ICMP) returnValue = @"ICMP";
    }
    else if ([key isEqualToString:@"Packet"]) {
        returnValue = [NSString stringWithFormat:@"%d",[self number]];
    }
    else if ([key isEqualToString:@"Sent"]) {
        if ([self status] >= kPingSent) {
            greenCheck = [[PSSharedDictionary sharedInstance] objectForKey:@"greenCheck"];
            strA = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
            [strA appendAttributedString:greenCheck];
            returnValue = strA;
        }
    }
    else if ([key isEqualToString:@"Received"]) {
        greenCheck = [[PSSharedDictionary sharedInstance] objectForKey:@"greenCheck"];
        redX = [[PSSharedDictionary sharedInstance] objectForKey:@"redX"];
        if ([self status] == kPingReturned) {
            strA = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
            [strA appendAttributedString:greenCheck];
            returnValue = strA;
        }
        else if ([self status] == kPingTimedOut) {
            strA = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
            [strA appendAttributedString:redX];
            returnValue = strA;
        }
        else if ([self status] == kPingTargetDidNotMatch) returnValue = @"!target";
        else if ([self status] == kPingDestinationUnreachable) returnValue = @"closed";
        else if ([self status] == kPingDestinationNotUnreachable) returnValue = @"open";
    }
    else if ([key isEqualToString:@"Lost"]) {
		value = [self lost];
		if (value >= 2) returnValue = [NSString stringWithFormat:@"%d",value];
	}
    else if ([key isEqualToString:@"Seconds"]) {
        NSTimeInterval time;
        time = [self elapsedInterval];
        // display non zero value as seconds
        if (time > 0) {
            returnValue = [NSString stringWithFormat:@"%1.3f", time];
        }
    }
    else if ([key isEqualToString:@"Address"]) {
        if ([self address]) returnValue = [self address];
    }
    else if ([key isEqualToString:@"Name"]) {
        if ([self name]) returnValue = [self name];
    }
    else if ([key isEqualToString:@"macAddress"]) {
        if ([self macAddress]) returnValue = [self macAddress];
    }
    else if ([key isEqualToString:@"Comment"]) {
        if ([self comment]) returnValue = [self comment];
    }
    return returnValue;
}

- (NSString *)description {
    NSMutableString* str;
    // address
    str = [NSMutableString stringWithFormat:@"%@\t",address];
    // sent
    if (status >= kPingSent) [str appendString:@"Sent"];
    [str appendString:@"\t"];
    // returned
    if (status == kPingTargetDidNotMatch) [str appendString:@"!target"];
    else if (status == kPingDestinationUnreachable) [str appendString:@"closed"];
    else if (status == kPingDestinationNotUnreachable) [str appendString:@"open"];
    else {
        if (status == kPingSent) [str appendString:@" "];
        else if (status == kPingReturned) [str appendString:@"Received"];
        else if (status == kPingTimedOut) [str appendString:@"X"];
    }
    [str appendString:@"\t"];
    // seconds
    if (elapsedInterval != 0) [str appendString:[NSString stringWithFormat:@"%1.3f\t", elapsedInterval]];
    // name
    if (name) {
		[str appendString:@"\t"];
        [str appendString:name];
    }
    // macAddress
    if (macAddress) {
		[str appendString:@"\t"];
        [str appendString:macAddress];
    }
    // comment
    if (comment) {
		[str appendString:@"\t"];
        [str appendString:comment];
    }
    return str;
}

- (NSString *)portScanDescription {
    NSMutableString* str;
    // number
    str = [NSMutableString stringWithFormat:@"%d\t",[self number]];
    // type
    if ([self type] == kProtocolTCP) {
        if ([self status] == kPingTimedOut) [str appendString:@"stealth"];
        else [str appendString:@"TCP"];
    }
    else if ([self type] == kProtocolUDP) [str appendString:@"UDP"];
    [str appendString:@"\t"];
    // comment
    if (comment) {
        [str appendString:comment];
    }
    return str;
}

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:startDate];
    [coder encodeValueOfObjCType:@encode(NSTimeInterval) at:&elapsedInterval];
    [coder encodeValueOfObjCType:@encode(int) at:&status];
    [coder encodeValueOfObjCType:@encode(int) at:&pStatus];
    [coder encodeValueOfObjCType:@encode(int) at:&number];
    [coder encodeValueOfObjCType:@encode(int) at:&type];
    [coder encodeValueOfObjCType:@encode(int) at:&retry];
    [coder encodeValueOfObjCType:@encode(int) at:&sent];
    [coder encodeValueOfObjCType:@encode(int) at:&received];
    [coder encodeValueOfObjCType:@encode(int) at:&lost];
    [coder encodeObject:address];
    [coder encodeObject:name];
    [coder encodeObject:macAddress];
    [coder encodeObject:comment];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    startDate = 	[[coder decodeObject] retain];
    [coder decodeValueOfObjCType:@encode(NSTimeInterval) at:&elapsedInterval];
    [coder decodeValueOfObjCType:@encode(int) at:&status];
    [coder decodeValueOfObjCType:@encode(int) at:&pStatus];
    [coder decodeValueOfObjCType:@encode(int) at:&number];
    [coder decodeValueOfObjCType:@encode(int) at:&type];
    [coder decodeValueOfObjCType:@encode(int) at:&retry];
    [coder decodeValueOfObjCType:@encode(int) at:&sent];
    [coder decodeValueOfObjCType:@encode(int) at:&received];
    [coder decodeValueOfObjCType:@encode(int) at:&lost];
    address = 		[[coder decodeObject] retain];
    name =			[[coder decodeObject] retain];
    macAddress =	[[coder decodeObject] retain];
    comment = 		[[coder decodeObject] retain];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}

// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    AddressScanEntry *copy;
    copy = [[AddressScanEntry allocWithZone:zone] init];
    [copy setStartDate:startDate];
    [copy setElapsedInterval:elapsedInterval];
    [copy setStatus:status];
    [copy setPStatus:pStatus];
    [copy setNumber:number];
    [copy setType:type];
    [copy setRetry:retry];
    [copy setRetry:sent];
    [copy setRetry:received];
    [copy setRetry:lost];
    [copy setAddress:address];
    [copy setName:name];
    [copy setMacAddress:macAddress];
    [copy setComment:comment];
    return copy;
}
@end
