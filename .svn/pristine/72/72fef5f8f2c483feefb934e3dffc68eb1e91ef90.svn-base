//
//  IPTCPSocket.m
//  IPNetMonitorX
//
//  Created by psichel on Mon Nov 12 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate a BSD UDP Socket
//  receiveFrom can block so we add a timeOut parameter that uses select
//  does not encapsulate threading

#import "IPTCPSocket.h"
#import "IPConnectionEntry.h"
#import "fcntl.h"
#import <sys/uio.h>		// iovec

// Forward function declarations
int			Connect(int sockfd, const struct sockaddr *to, int addrlen);
ssize_t		readn(int fd, void *vptr, size_t n);
ssize_t		writen(int fd, const void *vptr, size_t n);
ssize_t		readline(int fd, void *vptr, size_t maxlen);

@implementation IPTCPSocket
//--Setup--
- (id)init {
    int socket;
    socket = Socket(AF_INET, SOCK_STREAM, 0);
    self = [super initWithSocket:socket];
	mCloseSocket = YES;
    return self;
}

#pragma mark -- active connect (client) --
- (int)connectTo:(IPHost *)host
{
	// use connectTO:withTimeout:0 so we can abort
	return [self connectTo:host withTimeOut:0];
}

- (int)connectTo:(IPHost *)host withTimeOut:(NSTimeInterval)seconds
    // connect with timeout
	// seconds=nil wait forever
    // 0 = success
    // -1 for socket errors, or result code ETIMEDOUT, ECONNREFUSED,...
{
    int returnValue;
    int flags;
    int len;
    fd_set rset, wset;
    timeval_t tval;
	timeval_t* tvp = nil;
    long part;
    int maxfd;
        
    if (mSocket > 0) {
        do {	// make sure we got a valid socket
            // set socket to nonblocking
            flags = fcntl(mSocket, F_GETFL, 0);
            fcntl(mSocket, F_SETFL, flags | O_NONBLOCK);
            // try to connect
            returnValue = connect(mSocket, [host socketAddress], [host socketAddressLen]);
            // connection failed?
            if (returnValue < 0) if (errno != EINPROGRESS) break;
            // connection succeeded already?
            if (returnValue == 0) break;
            // connection in progress, wait for it to finish
				// maxfd
			maxfd = mSocket;
            if (mAbortFD[0] > maxfd) maxfd = mAbortFD[0];
				// fd_sets
			FD_ZERO(&rset);
            FD_SET(mSocket, &rset);
            wset = rset;
            FD_SET(mAbortFD[0], &rset);
				// tval
			if (seconds) {
				part = (long)seconds;
				tval.tv_sec = part;
				tval.tv_usec = (seconds - part)*1000000;
				tvp = &tval;
			}
			// select
			returnValue = Select(maxfd+1, &rset, &wset, NULL, tvp);
               // <0 socket error, 0 time out, >0 if descriptor is readable
            if (returnValue < 0) break;
			if (FD_ISSET(mAbortFD[0], &rset)) {
				returnValue = ETIMEDOUT;	// just abort
				break;
			}
            if (returnValue == 0) {
                returnValue = ETIMEDOUT;
                break;
            }
            if (FD_ISSET(mSocket, &rset) || FD_ISSET(mSocket, &wset)) {
                len = sizeof(returnValue);
                if (getsockopt(mSocket, SOL_SOCKET, SO_ERROR, &returnValue, (socklen_t *)&len) < 0) {
                    returnValue = -2;	// Solaris pending error
                    break;
                }
            } else {	// select error
                returnValue = -1;
                break;
            }
            
        } while (false);
        // set socket back to default blocking mode
        fcntl(mSocket, F_SETFL, flags);
    }
    else returnValue = mSocket;	// return the socket error we got
    // For any connect error, the socket can no longer be used and must
    // be closed.  Our socket is closed upon dealloc (class release).
    return returnValue;
}


- (NSArray *)connectToList:(NSArray *)hosts withTimeOut:(NSTimeInterval)seconds
    // connect to list of hosts with timeout, returns an NSArray of connection entries
    // 0 = success
    // -1 for socket errors, or result code ETIMEDOUT, ECONNREFUSED,...
    // This method is intended for parallel port scanning.
    // connectionEntry { host, socket, status }
{
    NSDate* doneTime;
    NSMutableArray* connectionList = nil;
    NSEnumerator* en;
    IPHost* host;
    int tSocket;
    IPConnectionEntry* entry;
    BOOL pending = NO;
    int result;
    int flags;
    fd_set mset, rset, wset;
    NSTimeInterval remaining;
    timeval_t tval;
    long part;
    int maxfd;
    
    do {
        if (!hosts) break;				// no hosts specified
        if ([hosts count] > 20) break;	// allow 20 hosts max
        connectionList = [[NSMutableArray alloc] initWithCapacity:20];
        maxfd = mAbortFD[0];			// initialize select params
        FD_ZERO(&mset);
        // for each host
        en = [hosts objectEnumerator];
        while (host = [en nextObject]) {
            // create a connection entry
            entry = [[[IPConnectionEntry alloc] init] autorelease];
            [entry setHost:host];
            [entry setStatus:-1];
            [connectionList addObject:entry];
            // get a socket
            tSocket = Socket(AF_INET, SOCK_STREAM, 0);
            [entry setSocket:tSocket];
            if (tSocket < 0) {
                [entry setStatus:tSocket];	// return the socket error we got
                continue;
            }
            // set socket to nonblocking
            flags = fcntl(tSocket, F_GETFL, 0);
            fcntl(tSocket, F_SETFL, flags | O_NONBLOCK);
            // try to connect
            result = connect(tSocket, [host socketAddress], [host socketAddressLen]);
            // connection failed?
            if (result < 0) if (errno != EINPROGRESS) {
                [entry setStatus:errno];
                continue;
            }
            // connection succeeded already?
            if (result == 0) {
            	[entry setStatus:result];
                continue;
            }
            // connection in progress, setup select params to wait for it
            FD_SET(tSocket, &mset);
            pending = YES;
            if (tSocket > maxfd) maxfd = tSocket;
        }
        // wait for connections to finish or time out
        doneTime = [NSDate dateWithTimeIntervalSinceNow:seconds];
        // while not timed out
        while ( ((remaining=[doneTime timeIntervalSinceNow]) > 0) && pending ) {
            pending = NO;
            wset = mset;	// finish select params
            rset = mset;
            FD_SET(mAbortFD[0], &rset);
            part = (long)remaining;
            tval.tv_sec = part;
            tval.tv_usec = (remaining - part)*1000000;            
            // wait for next socket or time out
			result = Select(maxfd+1, &rset, &wset, NULL, &tval);
				// <0 socket error, 0 time out, >0 number of descriptors ready
            // update results for each pending connection (socket)
            // connection status defaults to socket error (-1)
            if (result < 0) {
                NSLog(@"connectToList:withTimeOut socket error");
                break;
            }
            en = [connectionList objectEnumerator];
            while (entry = [en nextObject]) {
                tSocket = [entry socket];
                // if connection on socket was pending
                if (FD_ISSET(tSocket, &mset)) {
                    // timed out?
                    if (result == 0) {
                        [entry setStatus:ETIMEDOUT];
                        FD_CLR(tSocket, &mset);	// remove socket from fd_set
                    }
                    // ready?
                    else if (FD_ISSET(tSocket, &rset) || FD_ISSET(tSocket, &wset)) {
                        int returnValue, len;
                        len = sizeof(returnValue);
                        if (getsockopt(tSocket, SOL_SOCKET, SO_ERROR, &returnValue, (socklen_t *)&len) < 0) {
                            returnValue = -2;	// Solaris pending error
                        }
                        [entry setStatus:returnValue];
                        FD_CLR(tSocket, &mset);	// remove socket from fd_set
                    }
                    // connection on socket still pending (not ready or timed out)?
                    else pending = YES;
                }
            }
            // check if any still pending
            if (!pending) break;
        }	// while time remaining
    } while (false);
    return [connectionList autorelease];
}

#pragma mark -- passive connect (server) --
// ---------------------------------------------------------------------------
//		¥ bind
// ---------------------------------------------------------------------------
- (int)bind:(IPHost *)host
{
	int returnValue;
	if (mSocket > 0) {  // make sure we got a valid socket
		returnValue = bind(mSocket, [host socketAddress], [host socketAddressLen]);
		if (returnValue < 0) returnValue = errno;
	}
	else returnValue = mSocket;		// return the socket error we got
	return returnValue;
}

// ---------------------------------------------------------------------------
//		¥ listen
// ---------------------------------------------------------------------------
- (int)listen:(int)backlog
{
	int returnValue;
	if (mSocket > 0) {  // make sure we got a valid socket
		returnValue = listen(mSocket, backlog);
		if (returnValue < 0) returnValue = errno;
	}
	else returnValue = mSocket;		// return the socket error we got
	return returnValue;
}

// ---------------------------------------------------------------------------
//		¥ accept
// ---------------------------------------------------------------------------
// input: *host = nil
// output: connection fd or error, *host = peer endpoint
// This may block waiting for a connection so we include a timeOut interval.
// Use zero to wait indefinitely or until aborted.
- (int)accept:(IPHost **)outHost withTimeOut:(NSTimeInterval)seconds
{
	int returnValue;
	IPHost* host;
	socklen_t addrlen;
	
	if (mSocket > 0) {  // make sure we got a valid socket
		// wait for connection
		returnValue = [self waitUntilReadableTimeOut:seconds];
		// handle select event (<0=socket error, 0=timeout, >0=readable
		if (returnValue > 0) {
			host = [[IPHost alloc] init];
			addrlen = [host socketAddressLen];
			returnValue = accept(mSocket, [host socketAddress], &addrlen);
			if (returnValue < 0) returnValue = errno;
			else {
				*outHost = host;
			}
			[host autorelease];
		}
	}
	else returnValue = mSocket;		// return the socket error we got
	return returnValue;
}

#pragma mark -- data transfer --
// ---------------------------------------------------------------------------
//		¥ readn
// ---------------------------------------------------------------------------
// read n bytes from connected socket fd, return how many we got or -1 on error
- (int)readn:(NSMutableData *)data
{
	int returnValue;
	
	if (mSocket > 0) {  // make sure we got a valid socket
		returnValue = readn(mSocket, [data mutableBytes], [data length]);
	}
	else returnValue = mSocket;		// return the socket error we got
	return returnValue;
}

// ---------------------------------------------------------------------------
//		¥ writen
// ---------------------------------------------------------------------------
// write n bytes to connected socket fd, return how many were written -1 on error
- (int)writen:(NSData *)data
{
	int returnValue;
	
	if (mSocket > 0) {  // make sure we got a valid socket
		returnValue = writen(mSocket, [data bytes], [data length]);
	}
	else returnValue = mSocket;		// return the socket error we got
	return returnValue;
}

// ---------------------------------------------------------------------------
//		¥ readline
// ---------------------------------------------------------------------------
// read line from connected socket fd, return how many we got or -1 on error
- (int)readline:(NSMutableData *)data
{
	int returnValue;
	
	if (mSocket > 0) {  // make sure we got a valid socket
		returnValue = readline(mSocket, [data mutableBytes], [data length]);
	}
	else returnValue = mSocket;		// return the socket error we got
	return returnValue;
}

@end

#pragma mark -- UNIX wrappers --
int
Connect(int sockfd, const struct sockaddr *to, int addrlen)
{
	int n;
	int errno_save;
	
	if ( (n = connect(sockfd, to, addrlen)) < 0) {
		errno_save = errno;
		NSLog(@"sendto error");
		NSLog(@"%s", strerror(errno_save));					
	}
	return (n);
}

// ---------------------------------------------------------------------------
//		¥ readn, writen, readline
// ---------------------------------------------------------------------------
ssize_t						/* Read "n" bytes from a descriptor. */
readn(int fd, void *vptr, size_t n)
{
	size_t	nleft;
	ssize_t nread;
	char	*ptr;

	ptr = vptr;
	nleft = n;
	while (nleft > 0) {
		if ( (nread = Read(fd, ptr, nleft)) < 0) {
			return (-1);		// error
		} else if (nread == 0)
			break;				/* EOF */

		nleft -= nread;
		ptr   += nread;
	}
	return(n - nleft);		/* return >= 0 */
}

ssize_t
writen(int fd, const void *vptr, size_t n)
{
	size_t  nleft;
	ssize_t nwritten;
	const char *ptr;
	
	ptr = vptr;
	nleft = n;
	while (nleft > 0) {
		if ( (nwritten = Write(fd, ptr, nleft)) <= 0) {
			return (-1);		// error
		}
		nleft -= nwritten;
		ptr += nwritten;
	}
	return (n);
}

ssize_t
readline(int fd, void *vptr, size_t maxlen)
{
	ssize_t	n, rc;
	char	c, *ptr;

	ptr = vptr;
	for (n = 1; n < maxlen; n++) {
		if ( (rc = Read(fd, &c, 1)) == 1) {
			*ptr++ = c;
			if (c == '\n')
				break;	/* newline is stored, like fgets() */
		} else if (rc == 0) {
			if (n == 1)
				return(0);	/* EOF, no data read */
			else
				break;		/* EOF, some data was read */
		} else {
			return(-1);		/* error, errno set by read() */
		}
	}

	*ptr = 0;	/* null terminate like fgets() */
	return(n);
}

