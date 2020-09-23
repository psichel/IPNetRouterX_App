//
//  IPConnectionEntry.h
//  IPNetMonitorX
//
//  Created by psichel on Fri Sep 6 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//	Encapsulate connection attempt status for doing parallel connections
//	connectionEntry { host, socket, status }

#import "unp.h"
#import <Foundation/Foundation.h>
#import "IPHost.h"


@interface IPConnectionEntry : NSObject <NSCopying, NSCoding> {
    IPHost* host;
    int		socket;
    int		status;
}
- (id)init;
- (void)dealloc;
- (IPHost *)host;
- (void)setHost:(IPHost *)value;
- (int)socket;
- (void)setSocket:(int)value;
- (int)status;
- (void)setStatus:(int)value;
- (NSString *)description;
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end
