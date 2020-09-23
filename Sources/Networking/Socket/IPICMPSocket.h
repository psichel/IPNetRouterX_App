//
//  IPICMPSocket.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Jun 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate a BSD Raw ICMP Socket

#import <Foundation/Foundation.h>
#import "IPUDPSocket.h"
#import "IPHost.h"

@interface IPICMPSocket : IPUDPSocket {
}
- (id)init;
@end


// Forward Function Declarations
int OpenRawSocket(NSArray* arguments);
