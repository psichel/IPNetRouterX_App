//
//  IPNetMessage.m
//  IPNetMonitorX
//
//  Created by psichel on Wed Jul 11 2001.
//  Copyright (c) 2001 Sustainble Softworks, Inc. All rights reserved.
//

#import "IPNetMessage.h"

@implementation IPNetMessage
- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
    	data = nil;			// network data
		control = nil;		// ancilliary data
    	fromHost = nil;		// source for receiveFrom
    	toHost = nil;		// destination for sendTo
    	timeStamp = nil;	// when data was received        
    	socket = 0;			// BSD network socket
    }
    return self;
}

- (void)dealloc {
    if (data) [data release];
	if (control) [control release];
    if (fromHost) [fromHost release];
    if (toHost) [toHost release];
    if (timeStamp) [timeStamp release];
    [super dealloc];
}

- (NSMutableData *)data {
    return data;
}

- (NSMutableData *)control {
    return control;
}

- (IPHost *)fromHost {
    return fromHost;
}

- (IPHost *)toHost {
    return toHost;
}

- (int)socket {
    return socket;
}

- (NSDate *)timeStamp {
    return timeStamp;
}

- (void)setData:(NSMutableData *)inData {
    [inData retain];
    [data release];
    data = inData;
}

- (void)setControl:(NSMutableData *)inControl {
    [inControl retain];
    [control release];
    control = inControl;
}

- (void)setFromHost:(IPHost *)inFromHost {
    [inFromHost retain];
    [fromHost release];
    fromHost = inFromHost;
}

- (void)setToHost:(IPHost *)inToHost {
    [inToHost retain];
    [toHost release];
    toHost = inToHost;
}

- (void)setTimeStamp:(NSDate *)inTimeStamp {
    [inTimeStamp retain];
    [timeStamp release];
    timeStamp = inTimeStamp;
}

- (void)setSocket:(int)inSocket {
    socket = inSocket;
}

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];
    [coder encodeObject:data];
	[coder encodeObject:control];
    [coder encodeObject:fromHost];
    [coder encodeObject:toHost];
    [coder encodeObject:timeStamp];
    [coder encodeValueOfObjCType:@encode(int) at:&socket];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    data = 		[[coder decodeObject] retain];
	control =   [[coder decodeObject] retain];
    fromHost =	[[coder decodeObject] retain];
    toHost =	[[coder decodeObject] retain];
    timeStamp =	[[coder decodeObject] retain];
    [coder decodeValueOfObjCType:@encode(int) at:&socket];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}

// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    IPNetMessage *copy;
    copy = [[IPNetMessage allocWithZone:zone] init];
    [copy setData:data];
	[copy setControl:control];
    [copy setFromHost:fromHost];
    [copy setToHost:toHost];
    [copy setTimeStamp:timeStamp];
    [copy setSocket:socket];
    return copy;
}
@end
