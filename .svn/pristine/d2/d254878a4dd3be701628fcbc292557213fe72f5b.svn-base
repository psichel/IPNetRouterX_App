//
//  kftPanther.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Wed Apr 13 2005.
//  Copyright (c) 2005 Sustainable Softworks. All rights reserved.
//
//  Shim to simplify coding to Tiger's stable KPI functions
//
#if !TIGER
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if_types.h>
#include <net/if.h>
#include <sys/mbuf.h>
#if !IPK_NKE
#include "mbuf.h"
#include "if_var.h"
#endif

//#include "ipkTypes.h"
typedef struct ifnet *ifnet_t;
typedef u_int32_t protocol_family_t;
typedef struct mbuf *mbuf_t;
typedef int errno_t;

#pragma mark -- kpi_interface.h --
u_int32_t ifnet_mtu(ifnet_t interface);
errno_t ifnet_set_mtu(ifnet_t interface, u_int32_t mtu);
u_int8_t ifnet_hdrlen(ifnet_t interface);	
u_int8_t ifnet_type(ifnet_t interface);
	
#pragma mark -- kpi_mbuf.h --
typedef enum { 
    MBUF_TYPE_FREE = 0, /* should be on free list */
    MBUF_TYPE_DATA = 1, /* dynamic (data) allocation */
    MBUF_TYPE_HEADER = 2, /* packet header */
    MBUF_TYPE_SOCKET = 3, /* socket structure */
    MBUF_TYPE_PCB = 4, /* protocol control block */
    MBUF_TYPE_RTABLE = 5, /* routing tables */
    MBUF_TYPE_HTABLE = 6, /* IMP host tables */
    MBUF_TYPE_ATABLE = 7, /* address resolution tables */
    MBUF_TYPE_SONAME = 8, /* socket name */
    MBUF_TYPE_SOOPTS = 10, /* socket options */
    MBUF_TYPE_FTABLE = 11, /* fragment reassembly header */
    MBUF_TYPE_RIGHTS = 12, /* access rights */
    MBUF_TYPE_IFADDR = 13, /* interface address */
    MBUF_TYPE_CONTROL = 14, /* extra-data protocol message */
    MBUF_TYPE_OOBDATA = 15 /* expedited data */
} mbuf_type_t;

typedef enum { 
    MBUF_EXT = 0x0001, /* has associated external storage */
    MBUF_PKTHDR = 0x0002, /* start of record */
    MBUF_EOR = 0x0004, /* end of record */
    MBUF_BCAST = 0x0100, /* send/received as link-level broadcast */
    MBUF_MCAST = 0x0200, /* send/received as link-level multicast */
    MBUF_FRAG = 0x0400, /* packet is a fragment of a larger packet */
    MBUF_FIRSTFRAG = 0x0800, /* packet is first fragment */
    MBUF_LASTFRAG = 0x1000, /* packet is last fragment */
    MBUF_PROMISC = 0x2000 /* packet is promiscuous */
} mbuf_flags_t;


void* mbuf_data(mbuf_t mbuf);
errno_t mbuf_setdata(mbuf_t mbuf, void *data, size_t len);
size_t mbuf_pkthdr_len(mbuf_t mbuf);
void mbuf_pkthdr_setlen(mbuf_t mbuf, size_t len);
errno_t mbuf_pkthdr_setrcvif(mbuf_t mbuf, ifnet_t ifnet);
size_t mbuf_len(mbuf_t mbuf);
void mbuf_setlen(mbuf_t mbuf, size_t len);
mbuf_t mbuf_next(mbuf_t mbuf);
errno_t mbuf_setnext(mbuf_t mbuf, mbuf_t next);
mbuf_t mbuf_nextpkt(mbuf_t mbuf);
void mbuf_setnextpkt(mbuf_t mbuf, mbuf_t nextpkt);
errno_t mbuf_setflags(mbuf_t mbuf, mbuf_flags_t flags);
errno_t mbuf_settype(mbuf_t mbuf, mbuf_type_t new_type);
void mbuf_freem(mbuf_t mbuf);

#pragma mark -- mtag --
errno_t PROJECT_mtag(mbuf_t mbuf_ref, int tag_value);
int PROJECT_is_mtag(mbuf_t mbuf_ref, int tag_value);
#define TAG_IN 1
#define TAG_OUT 2

#endif
