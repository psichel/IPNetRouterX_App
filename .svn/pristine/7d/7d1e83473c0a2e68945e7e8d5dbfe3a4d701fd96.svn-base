//
//  IPTCPSocket.h
//  IPNetMonitorX
//
//  Created by psichel on Mon Nov 12 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate a BSD TCP Socket
//  Connect can block so we add a timeOut parameter that uses select
//  does not encapsulate threading

#import "IPSocket.h"
#import "IPHost.h"

@interface IPTCPSocket : IPSocket {
}
- (id)init;
// active connect (client)
- (int)connectTo:(IPHost *)host;
- (int)connectTo:(IPHost *)host withTimeOut:(NSTimeInterval)seconds;
- (NSArray *)connectToList:(NSArray *)hosts withTimeOut:(NSTimeInterval)seconds;
// passive connect (server)
- (int)bind:(IPHost *)host;
- (int)listen:(int)backlog;
- (int)accept:(IPHost **)outHost withTimeOut:(NSTimeInterval)seconds;
// data transfer
- (int)readn:(NSMutableData *)data;
- (int)writen:(NSData *)data;
- (int)readline:(NSMutableData *)data;
@end
