//
//  IPNetMessage.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Jul 11 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate message data to or from the network
#import <Foundation/Foundation.h>
#import "IPHost.h"
@class IPHost;
@class IPNetMessage;


@interface IPNetMessage : NSObject {
    NSMutableData*	data;			// network data
    NSMutableData*	control;		// recvmsg ancilliary data
    IPHost*			fromHost;		// source for receiveFrom
    IPHost*			toHost;			// destination for sendTo
    NSDate*			timeStamp;		// when data was received
    int				socket;			// BSD network socket
 }
- (id)init;
- (void)dealloc;
- (NSMutableData *)data;
- (NSMutableData *)control;
- (IPHost *)fromHost;
- (IPHost *)toHost;
- (NSDate *)timeStamp;
- (int)socket;
- (void)setData:(NSMutableData *)inData;
- (void)setControl:(NSMutableData *)inControl;
- (void)setFromHost:(IPHost *)inFromHost;
- (void)setToHost:(IPHost *)inToHost;
- (void)setTimeStamp:(NSDate *)inTimeStamp;
- (void)setSocket:(int)inSocket;
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end
