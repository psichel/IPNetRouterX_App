//
//  IPUDPSocket.h
//  IPNetMonitorX
//
//  Created by psichel on Mon Nov 12 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate a BSD UDP Socket
//  receiveFrom can block so we add a timeOut parameter that uses select
//  does not encapsulate threading

#import <Foundation/Foundation.h>
#import "IPSocket.h"
#import "IPHost.h"

@interface IPUDPSocket : IPSocket {
}
- (id)init;
- (ssize_t) receiveFrom:(IPHost *)host data:(NSMutableData *)inBuffer
    control:(NSMutableData *)controlBuffer withTimeOut:(NSTimeInterval)seconds;
    //  receiveFrom can block so we add a timeOut parameter that uses select
    //  does not encapsulate threading
- (ssize_t) sendTo:(IPHost *)host data:(NSData *)data;
    // returns the number of bytes sent
    // for UDP, there is no socket buffer, so this should never block
@end
