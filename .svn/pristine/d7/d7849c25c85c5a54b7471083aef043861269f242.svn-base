//
//  RoutingSocket.m
//  IPNetRouterX
//
//  Created by psichel on Mon Dec 15 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Get a privileged routing socket

#import <Foundation/Foundation.h>
#import "IPICMPSocket.h"
#import <sys/uio.h>		// iovec

int psGetRoutingSocket()
{
    int socket;
    //socket = Socket(PF_ROUTE, SOCK_RAW, 0);
	socket = OpenRawSocket([NSArray arrayWithObject:@"-routing"]);
    return socket;    
}
