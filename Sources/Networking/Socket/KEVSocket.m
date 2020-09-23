//
//  KEVSocket.m
//  IPNetMonitorX
//
//  Created by psichel on Sat Apr 12 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulate a PF_SYSTEM socket for receiving SYSPROTO_EVENT messages

#import "KEVSocket.h"
#import <sys/uio.h>		// iovec

@implementation KEVSocket
//--Setup--
- (id)init {
    int socket;
    //socket = Socket(PF_SYSTEM, SOCK_RAW, SYSPROTO_EVENT);
	socket = OpenRawSocket([NSArray arrayWithObject:@"-kev"]);
    self = [super initWithSocket:socket];
	mCloseSocket = YES;
    return self;    
}
@end
