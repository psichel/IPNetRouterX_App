//
//  IPConnectionEntry.m
//  IPNetMonitorX
//
//  Created by psichel on Fri Sep 6 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//	Encapsulate connection attempt status for doing parallel connections
//	connectionEntry { host, socket, status }

#import "IPConnectionEntry.h"

@implementation IPConnectionEntry

- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
        host = nil;
        socket = 0;
        status = 0;
    }
    return self;
}
- (void)dealloc {
    [host release];
    [super dealloc];
}

- (IPHost *)host { return host; }
- (void)setHost:(IPHost *)value {
    [value retain];
    [host release];
    host = value;
}

- (int)socket { return socket; }
- (void)setSocket:(int)value {
    socket = value;
}

- (int)status { return status; }
- (void)setStatus:(int)value {
    status = value;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ socket:%d status:%d",[host description],socket,status];
}

// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];
    [coder encodeObject:host];
    [coder encodeValueOfObjCType:@encode(int) at:&socket];
    [coder encodeValueOfObjCType:@encode(int) at:&status];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    //self = [super initWithCoder:coder];
    self = [super init];
    host = 	[[coder decodeObject] retain];
    [coder decodeValueOfObjCType:@encode(int) at:&socket];
    [coder decodeValueOfObjCType:@encode(int) at:&status];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    IPConnectionEntry *copy;
    copy = [[IPConnectionEntry allocWithZone:zone] init];
    [copy setHost:host];
    [copy setSocket:socket];
    [copy setStatus:status];
    return copy;
}
@end
