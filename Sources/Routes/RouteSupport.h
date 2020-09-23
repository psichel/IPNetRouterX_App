//
//  RouteSupport.h
//  IPNetRouterX
//
//  Created by psichel on Wed Mar 05 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Support routines for dealing with Routing Sockets

#import "unp.h"
#import <sys/param.h>
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <net/route.h>
#import <net/if_arp.h>
#import <net/if_dl.h>
#import <net/if.h>
#import <netinet/in.h>
#import <netinet/if_ether.h>
#include <net/if_types.h>

#define socklen_t size_t

// forward function declarations
void get_rtaddrs(int addrs, struct sockaddr *sa, struct sockaddr **rti_info);
char *sock_masktop(struct sockaddr *sa, socklen_t salen);
u_int32_t sock_mask(struct sockaddr *sa, socklen_t salen);
char *sock_ntop_host(const struct sockaddr *sa, socklen_t salen);
u_int32_t sock_host(const struct sockaddr *sa, socklen_t salen);

