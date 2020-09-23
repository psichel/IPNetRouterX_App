//
//  IPSocket.m
//  IPNetMonitorX
//
//  Created by psichel on Wed Jun 27 2001.
//  Copyright (c) 2001-02 Sustainable Softworks. All rights reserved.
//
//  Base class for encapsulating a BSD Socket

#import "IPSocket.h"
#import <sys/uio.h>		// iovec

// Global
NSString *PSAbortFD = @"PSAbortFD";


@implementation IPSocket
//--Setup--
- (id)initWithSocket:(int)socket {
    if (self = [super init]) {
        mSocket = socket;
        mAbortFD[0] = -1;
        mAbortFD[1] = -1;
        pipe(mAbortFD);	// create a pipe for aborting select
		mCloseSocket = NO;
    }
    return self;
}

- (void)dealloc {
    
	if (mAbortFD[1] >= 0) {
		Write(mAbortFD[1], "wakeup", 6);	// wakeup any select
		Close(mAbortFD[1]);
        mAbortFD[1] = -1;
        [NSThread  sleepUntilDate:[NSDate
            dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
    }
    if (mAbortFD[0] >= 0) {
		Close(mAbortFD[0]);
		mAbortFD[0] = -1;
	}
    if ((mSocket > 0) && mCloseSocket) {
		Close(mSocket);
	}
    [super dealloc];
}

- (int)socket {
    return mSocket;
}

- (int)abortFD {
	return mAbortFD[1];
}

- (BOOL)setIP_TTL:(int)value {
    BOOL returnValue = YES;
    int result;
    do {
        if (mSocket <= 0) {
            returnValue = NO;
            break;
        }
        if ((value < 1) || (value > 255)) {
            returnValue = NO;
            break;        
        }
        result = setsockopt(mSocket, IPPROTO_IP, IP_TTL, &value, sizeof(int));
        if (result != 0) returnValue = NO;   
    } while (false);
    return returnValue;
}

- (BOOL)setIP_HDRINCL:(int)value {
    BOOL returnValue = YES;
    int result;
    do {
        if (mSocket <= 0) {
            returnValue = NO;
            break;
        }
        if ((value < 1) || (value > 255)) {
            returnValue = NO;
            break;        
        }
        result = setsockopt(mSocket, IPPROTO_IP, IP_HDRINCL, &value, sizeof(int));
        if (result != 0) returnValue = NO;   
    } while (false);
    return returnValue;
}

- (BOOL)setSO_RCVTIMEO:(time_value_t*)timeValue {
    BOOL returnValue = YES;
    int result;
    do {
        if (mSocket <= 0) {
            returnValue = NO;
            break;
        }
        result = setsockopt(mSocket, SOL_SOCKET, SO_RCVTIMEO, timeValue, sizeof(time_value_t));
        if (result != 0) returnValue = NO;   
    } while (false);
    return returnValue;
}

- (BOOL)setSO_TIMESTAMP:(int)value
{
    BOOL returnValue = YES;
    int result;
    do {
        if (mSocket <= 0) {
            returnValue = NO;
            break;
        }
        result = setsockopt(mSocket, SOL_SOCKET, SO_TIMESTAMP, &value, sizeof(int));
        if (result != 0) returnValue = NO;   
    } while (false);
    return returnValue;
}

- (int)setSO:(int)option param:(void *)param size:(unsigned)size
{
    int returnValue = 0;
    do {
        if (mSocket <= 0) {
            returnValue = mSocket;	// return the socket error we got
            break;
        }
        returnValue = setsockopt(mSocket, SOL_SOCKET, option, param, size);
		if (returnValue < 0) {
			returnValue = errno;
		}
    } while (false);
    return returnValue;
}

- (int)getSO:(int)option param:(void *)param size:(socklen_t *)size
{
    int returnValue = 0;
    do {
        if (mSocket <= 0) {
            returnValue = mSocket;	// return the socket error we got
            break;
        }
        returnValue = getsockopt(mSocket, SOL_SOCKET, option, param, size);
    } while (false);
    return returnValue;
}

- (BOOL)setRST {
    return [self setRST:mSocket];
}

- (BOOL)setRST:(int) socket {
    BOOL returnValue = YES;
    int result;
    struct linger ling;
    ling.l_onoff = 1;
    ling.l_linger = 0;
    do {
        if (socket <= 0) {
            returnValue = NO;
            break;
        }
        result = setsockopt(socket, SOL_SOCKET, SO_LINGER, &ling, sizeof(ling));
        if (result != 0) returnValue = NO;   
    } while (false);
    return returnValue;
}

- (int)waitUntilReadableTimeOut:(NSTimeInterval)seconds
{
	int result;
    timeval_t tval;
	timeval_t* tvp = nil;
    long part;
    fd_set rset;
    int maxfd;

	do {
		if (mSocket < 0) {		// make sure we got a valid socket
			result = mSocket;	// return the socket error we got
			errno = EBADF;		// return as if socket was closed to tell client to abort
			break;
		}
		if (mAbortFD[0] < 0) {	// valid abortFD?
			result = -1;
			errno = EBADF;		// return as if socket was closed to tell client to abort
			break;
		}
		// setup for select
			// maxfd
		maxfd = mSocket;
		if (mAbortFD[0] > maxfd) maxfd = mAbortFD[0];
			// fd_sets
		FD_ZERO(&rset);
		FD_SET(mSocket, &rset);
		FD_SET(mAbortFD[0], &rset);
			// tval
		if (seconds) {
			part = (long)seconds;
			tval.tv_sec = part;
			tval.tv_usec = (seconds - part)*1000000;
			tvp = &tval;
		}
		// select()
		result = Select(maxfd+1, &rset, NULL, NULL, tvp);
		// <0 socket error
		// 0  time out
		// >0 if descriptor is readable
		if (result < 0) {
			if (errno != EBADF) {   // socket was closed to force quit
				int errno_save = errno;
				NSLog(@"select error: %s", strerror(errno_save));
			}
		}
		else if (result > 0) {
			if (FD_ISSET(mAbortFD[0], &rset)) {
				char recvline[16];
				Read(mAbortFD[0], recvline, 15);	// clear the condition
				//result = 0;	// return as if we timed out
				result = -1;
				errno = EBADF;	// return as if socket was closed to tell client to abort
			}
		}
    } while (false);
    return result;
}


// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];
    [coder encodeValueOfObjCType:@encode(int) at:&mSocket];
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    //self = [super initWithCoder:coder];
    self = [super init];
    [coder decodeValueOfObjCType:@encode(int) at:&mSocket];
    return self;
}

// tell the PortCoder not to use a proxy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
    return self;
}


// <NSCopying>
- (id)copyWithZone:(NSZone *)zone {
    IPSocket *copy;
    copy = [[IPSocket allocWithZone:zone] initWithSocket:mSocket];
    return copy;
}
@end


// ---------------------------------------------------------------------------
//		¥ Error checking wrappers
// ---------------------------------------------------------------------------
int
Socket(int family, int type, int protocol)
{
	int n;
	int errno_save;
	
	if ( (n = socket(family, type, protocol)) < 0) {
		errno_save = errno;
		NSLog(@"socket error: %s", strerror(errno_save));
	}
	return (n);
}

