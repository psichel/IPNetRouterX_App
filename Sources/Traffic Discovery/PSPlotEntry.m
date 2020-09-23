//
//  PSPlotEntry.m
//  IPNetMonitorX
//
//  Created by psichel on Tue Mar 19 2002.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import "PSPlotEntry.h"
#import "PSSharedDictionary.h"

@implementation PSPlotEntry

- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
        sent = 0;
        received = 0;
        retransmit = 0;
        duplicate = 0;
        sentControl = 0;
        receivedControl = 0;
        sentAverage = 0;
        receivedAverage = 0;
    }
    return self;
}
- (void)dealloc {
    [super dealloc];
}

- (u_long)sent { return sent; }
- (void)setSent:(u_long)value { sent = value; }
- (u_long)received { return received; }
- (void)setReceived:(u_long)value { received = value; }

- (u_long)retransmit { return retransmit; }
- (void)setRetransmit:(u_long)value { retransmit = value; }
- (u_long)duplicate { return duplicate; }
- (void)setDuplicate:(u_long)value { duplicate = value; }

- (u_long)sentControl { return sentControl; }
- (void)setSentControl:(u_long)value { sentControl = value; }
- (u_long)receivedControl { return receivedControl; }
- (void)setReceivedControl:(u_long)value { receivedControl = value; }

- (u_long)sentAverage { return sentAverage; }
- (void)setSentAverage:(u_long)value { sentAverage = value; }
- (u_long)receivedAverage { return receivedAverage; }
- (void)setReceivedAverage:(u_long)value { receivedAverage = value; }

- (u_long)maxR
{
    u_long max;
    max = (received > duplicate)? received : duplicate;
    max = (receivedControl > max)? receivedControl : max;
    return max;
}

- (u_long)maxT
{
    u_long max;
    max = (sent > retransmit)? sent : retransmit;
    max = (sentControl > max)? sentControl : max;
    return max;
}

- (NSString *)description {
    NSString* str;
    str = [NSString stringWithFormat:@"sent=%lu received=%lu retransmit=%lu duplicate=%lu",
        sent, received, retransmit, duplicate];
    return str;
}

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeValueOfObjCType:@encode(u_long) at:&sent];
    [coder encodeValueOfObjCType:@encode(u_long) at:&received];
    [coder encodeValueOfObjCType:@encode(u_long) at:&retransmit];
    [coder encodeValueOfObjCType:@encode(u_long) at:&duplicate];
    [coder encodeValueOfObjCType:@encode(u_long) at:&sentControl];
    [coder encodeValueOfObjCType:@encode(u_long) at:&receivedControl];
    [coder encodeValueOfObjCType:@encode(u_long) at:&sentAverage];
    [coder encodeValueOfObjCType:@encode(u_long) at:&receivedAverage];
}

- (id)initWithCoder:(NSCoder *)coder
{
    //if (self = [super initWithCoder:coder]) {
    if (self = [super init]) {
        [coder decodeValueOfObjCType:@encode(u_long) at:&sent];
        [coder decodeValueOfObjCType:@encode(u_long) at:&received];
        [coder decodeValueOfObjCType:@encode(u_long) at:&retransmit];
        [coder decodeValueOfObjCType:@encode(u_long) at:&duplicate];
        [coder decodeValueOfObjCType:@encode(u_long) at:&sentControl];
        [coder decodeValueOfObjCType:@encode(u_long) at:&receivedControl];
        [coder decodeValueOfObjCType:@encode(u_long) at:&sentAverage];
        [coder decodeValueOfObjCType:@encode(u_long) at:&receivedAverage];
    }
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    PSPlotEntry *copy;
    copy = [[PSPlotEntry allocWithZone:zone] init];
    [copy setSent:sent];
    [copy setReceived:received];
    [copy setRetransmit:retransmit];
    [copy setDuplicate:duplicate];
    [copy setSent:sentControl];
    [copy setReceived:receivedControl];
    [copy setSentAverage:sentAverage];
    [copy setReceivedAverage:receivedAverage];
    return copy;
}
@end
