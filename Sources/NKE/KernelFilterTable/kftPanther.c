//
//  kftPanther.c
//  IPNetRouterX
//
//  Created by Peter Sichel on Wed Apr 13 2005.
//  Copyright (c) 2005 Sustainable Softworks. All rights reserved.
//
//  Shim to simplify coding to Tiger's stable KPI functions
//
#if !TIGER
#include "kftPanther.h"
#include <sys/param.h>

#pragma mark -- kpi_interface.h --
// ---------------------------------------------------------------------------------
//	¥ ifnet_mtu
// ---------------------------------------------------------------------------------
u_int32_t ifnet_mtu(ifnet_t interface)
{
	return interface->if_mtu;
}
errno_t ifnet_set_mtu(ifnet_t interface, u_int32_t mtu)
{
	interface->if_mtu = mtu;
	return 0;
}
	
// ---------------------------------------------------------------------------------
//	¥ ifnet_hdrlen
// ---------------------------------------------------------------------------------
u_int8_t ifnet_hdrlen(ifnet_t interface)
{
	return interface->if_hdrlen;
}

// ---------------------------------------------------------------------------------
//	¥ ifnet_type
// ---------------------------------------------------------------------------------
u_int8_t ifnet_type(ifnet_t interface)
{
	return interface->if_type;
}
	
#pragma mark -- kpi_mbuf.h --
// ---------------------------------------------------------------------------------
//	¥ mbuf_data
// ---------------------------------------------------------------------------------
void* mbuf_data(mbuf_t mbuf)
{
	return mbuf->m_data;
}
errno_t mbuf_setdata(mbuf_t mbuf, void *data, size_t len)
{
	mbuf->m_data = data;
	mbuf->m_len = len;
	return 0;
}
	
// ---------------------------------------------------------------------------------
//	¥ mbuf_pkthdr_len
// ---------------------------------------------------------------------------------
size_t mbuf_pkthdr_len(mbuf_t mbuf)
{
	return mbuf->m_pkthdr.len;
}
void mbuf_pkthdr_setlen(mbuf_t mbuf, size_t len)
{
	mbuf->m_pkthdr.len = len;
}

// ---------------------------------------------------------------------------------
//	¥ mbuf_pkthdr_setrcvif
// ---------------------------------------------------------------------------------
errno_t mbuf_pkthdr_setrcvif(mbuf_t mbuf, ifnet_t ifnet)
{
	mbuf->m_pkthdr.rcvif = ifnet;
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ mbuf_len
// ---------------------------------------------------------------------------------
size_t mbuf_len(mbuf_t mbuf)
{
	return mbuf->m_len;
}
void mbuf_setlen(mbuf_t mbuf, size_t len)
{
	mbuf->m_len = len;
}

// ---------------------------------------------------------------------------------
//	¥ mbuf_next
// ---------------------------------------------------------------------------------
mbuf_t mbuf_next(mbuf_t mbuf)
{
	return mbuf->m_next;
}

errno_t mbuf_setnext(mbuf_t mbuf, mbuf_t next)
{
	mbuf->m_next = next;
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ mbuf_nextpkt
// ---------------------------------------------------------------------------------
mbuf_t mbuf_nextpkt(mbuf_t mbuf)
{
	return mbuf->m_nextpkt;
}
void mbuf_setnextpkt(mbuf_t mbuf, mbuf_t nextpkt)
{
	mbuf->m_nextpkt = nextpkt;
}

// ---------------------------------------------------------------------------------
//	¥ mbuf_setflags
// ---------------------------------------------------------------------------------
errno_t mbuf_setflags( mbuf_t mbuf,mbuf_flags_t flags)
{
	mbuf->m_flags = flags;
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ mbuf_settype
// ---------------------------------------------------------------------------------
errno_t mbuf_settype(mbuf_t mbuf, mbuf_type_t new_type)
{
	mbuf->m_type = new_type;
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ mbuf_freem
// ---------------------------------------------------------------------------------
void mbuf_freem(mbuf_t mbuf)
{
#if IPK_NKE
	m_freem(mbuf);
#endif
}

#pragma mark -- mtag --
errno_t PROJECT_mtag(mbuf_t mbuf_ref, int tag_value)	{ return 0; }
int PROJECT_is_mtag(mbuf_t mbuf_ref, int tag_value)		{ return 0; }

#endif

