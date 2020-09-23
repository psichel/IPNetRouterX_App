/*
 *  unp.h
 *  IPNetMonitorX
 *
 *  Created by psichel on Fri Jun 15 2001.
 *  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
 *
 *  Our own generic Unix Network Programming (unp) headers
 */
#ifndef __unp_h
#define __unp_h

// block Mach kernel definition
//#define	TIME_VALUE_H_

#import <sys/types.h>		// basic system data types
#import <sys/socket.h>		// basic socket definitions
#import <sys/time.h>		// timeval{} for select
#import <netinet/in.h>		// sockaddr_in{} and other Internet defs
#include <signal.h>
#include <unistd.h>			// select
#import <arpa/inet.h>		// inet_pton, inet_ntop...
#import <netinet/in.h>		// INET_ADDRSTRLEN, INET6_ADDRSTRLEN
#import <net/if_arp.h>		// SIOCGARP...
//#import <strings.h>		// bzero, bcopy, bcmp

#import <errno.h>

typedef struct sockaddr sockaddr_t;
typedef struct sockaddr_in sockaddr_in_t;
typedef struct sockaddr_in6 sockaddr_in6_t;
//typedef struct in_addr in_addr_t;
typedef struct in_addr in_addr_tt;
typedef struct hostent hostent_t;
typedef struct icmp icmp_t; 
typedef struct timeval timeval_t;
typedef struct msghdr msghdr_t;
typedef struct cmsghdr cmsghdr_t;
typedef struct iovec iovec_t;
typedef struct so_nke so_nke_t;
typedef struct arpreq arpreq_t;
typedef struct in6_addr in6_addr_t;
// reference as name.s6_addr[0..15]

typedef void Sigfunc(int);
Sigfunc *Signal(int signo, Sigfunc *func);
// error checking wrappers
int Close(int fd);
ssize_t	 Read(int fd, void *buf, size_t size);
ssize_t	 Write(int fd, const void *buf , size_t size);
int	Select(int maxfd, fd_set *rset, fd_set *wset, fd_set *except, struct timeval *tvp);
#endif
