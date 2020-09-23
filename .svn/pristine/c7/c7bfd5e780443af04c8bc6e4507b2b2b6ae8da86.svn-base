//
// kftNatProcess.c
// IPNetRouterX
//
// Created by Peter Sichel on Thu Jul 24 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
#if IPK_NKE
#define DEBUG_IPK 0
#else
#define DEBUG_IPK 0
#endif

#if DEBUG_IPK
#include <sys/syslog.h>
#endif

#include "IPTypes.h"
#include PS_TNKE_INCLUDE
#include "kftNatProcess.h"
#include "kftNatTable.h"
#include "kftPortMapTable.h"
#include "kftFragmentTable.h"
#include "kft.h"
#include "FilterTypes.h"
#include "IPKSupport.h"
//#include "kftSupport.h"
//#include "FilterTypes.h"
//#include "avl.h"

#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netinet/tcp_seq.h>	// sequence number compare macros SEQ_LT, SEQ_LEQ, SEQ_GT, SEQ_GEQ(a,b)
#include <sys/socket.h>
#include <sys/mbuf.h>

#if IPK_NKE
#include <sys/systm.h>
#include <machine/spl.h>
#include <sys/param.h>
#include <libkern/OSAtomic.h>
#endif

// Global storage
#include "kftGlobal.h"

// internal function declarations
int KFT_natTranslateDst(KFT_packetData_t* packet, KFT_connectionEndpoint_t* target);
int KFT_natTranslateSrc(KFT_packetData_t* packet, KFT_connectionEndpoint_t* target);

// ---------------------------------------------------------------------------------
//	¥ KFT_natIn()
// ---------------------------------------------------------------------------------
//	Convert destination from apparent to actual endpoint
//  Output: 0 = success, or other NKE result
//
// Two transparent proxy cases:
// (1) Matched wild card port map entry, packet to be proxied.
// (2) NAT entry has proxy flag set, response from proxy server addressed to apparent endpoint
int KFT_natIn(KFT_packetData_t* packet)
{
	int returnValue = 0;
	int result = 0;
	do {
		u_int32_t	netData;
		u_int32_t	netToMatch;
		KFT_interfaceEntry_t* params;
		KFT_connectionEndpoint_t target;
		KFT_connectionEndpoint_t proxy;
		ip_header_t* ipHeader;
		tcp_header_t* tcpHeader;
		u_int16_t fragmentOffset;
		u_int8_t transparentProxy = 0;

		ipHeader = (ip_header_t*)packet->datagram;
		tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
		fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;
		target.address = 0;
		target.port = 0;
		proxy.address = 0;
		proxy.port = 0;
		// get interface params
		params = &packet->myAttach->kftInterfaceEntry;
		// to or from exclude network?
		if (params->excludeNet.mask != 0) {
			netToMatch = params->excludeNet.address & params->excludeNet.mask;
			// from exclude network
			netData = ipHeader->srcAddress & params->excludeNet.mask;
			if (netData == netToMatch) break;
			// to exclude network?
			netData = ipHeader->dstAddress & params->excludeNet.mask;
			if (netData == netToMatch) break;
		}
		// to or from single network? (used for single Ethernet)
		if (params->singleNet.mask != 0) {
			netToMatch = params->singleNet.address & params->singleNet.mask;
				// KFT_natIn() from single network (do not masquerade unless local NAT)
			netData = ipHeader->srcAddress & params->singleNet.mask;
			if ((netData == netToMatch) && (ipHeader->dstAddress != params->natNet.address)) break;
				// KFT_natIn() to single network (do not masquerade, to LAN interface of gateway)
			netData = ipHeader->dstAddress & params->singleNet.mask;
			if (netData == netToMatch) break;
		}
		{
			KFT_natEntry_t compareEntry;
			bzero(&compareEntry, sizeof(KFT_natEntry_t));
			compareEntry.apparent.protocol 	= ipHeader->protocol;
			compareEntry.apparent.address	= ipHeader->dstAddress;
			if ((ipHeader->protocol == IPPROTO_TCP) || (ipHeader->protocol == IPPROTO_UDP)) {
				if (fragmentOffset == 0) {
					compareEntry.apparent.port	= tcpHeader->dstPort;
				}
				else {
					// try to get port information from ip fragment table
					KFT_fragmentEntry_t *foundFEntry = NULL;
					KFT_fragmentEntry_t cEntry;
					cEntry.fragment.srcAddress = ipHeader->srcAddress;
					cEntry.fragment.identification = ipHeader->identification;			
					result = KFT_fragmentFindEntry(&cEntry, &foundFEntry);
					if (result == 0) {
						compareEntry.apparent.port	= foundFEntry->dstPort;
					}
				}
			}
			// lookup actual endpoint
			packet->natEntry = NULL;	// defensive
			// internal interface?
			if (!packet->myAttach->kftInterfaceEntry.externalOn) {
				// skip broadcast & multicast
				// in case Local NAT and Exposed Host is none
				if (ipHeader->dstAddress == INADDR_BROADCAST) break;
				if (IN_MULTICAST(ipHeader->dstAddress)) break;					
			}
			result = KFT_natFindActualForApparent(packet, &compareEntry, &packet->natEntry);
			if (result == 0) {
				target.address = packet->natEntry->actual.address;
				target.port = packet->natEntry->actual.port;
				// replace wildcard
				if (target.port == 0) target.port = compareEntry.apparent.port;
				// transparent proxy (case 1)?
				if (packet->natEntry->apparent.address == 0) {
					// avoid redirecting proxy server back to itself
					if (target.address == ipHeader->srcAddress) break;
					// remember to process this packet as a transparentProxy
					transparentProxy = 1;
					// remember original destination
					proxy.address = compareEntry.apparent.address;
					proxy.port = compareEntry.apparent.port;
					proxy.protocol = compareEntry.apparent.protocol;
					// if local proxy, flag to replace the local from address with reflector address "1"
					packet->localProxy = packet->natEntry->localProxy;
				}
			}
			else {
				// No match found.  Use the exposed host selection
				// for packets on external interface
				// 0 = gateway, 1 = exposedHost, 2 = stealth
				if (!packet->myAttach->kftInterfaceEntry.externalOn) break;
				if (params->exposedHostSelection == 0) break;
				if (params->exposedHostSelection == 2) {
					KFT_logEvent(packet, -kReasonNATActionReject, kActionDelete);
					returnValue = KFT_deletePacket(packet);
					break;
				}
				target.address = params->exposedHost;
				target.port = tcpHeader->dstPort;
			}
		}
		// update NAT entry flags
		if (packet->natEntry && (ipHeader->protocol == IPPROTO_TCP)) {
			// SYN
			if (!(tcpHeader->code & kCodeSYN)) packet->natEntry->flags |= kNatFlagNonSyn;
			// FIN
			if (tcpHeader->code & kCodeFIN) {
				packet->natEntry->flags |= kNatFlagFINPeer;
				packet->natEntry->seqFINPeer = tcpHeader->seqNumber;
			}
			// FIN ACK (local has sent FIN and peer is acking it)
			if (packet->natEntry->flags & kNatFlagFINLocal) {
				if (tcpHeader->code & kCodeACK) {
					if ( SEQ_GT(tcpHeader->ackNumber,packet->natEntry->seqFINLocal) )
						packet->natEntry->flags |= kNatFlagFINAckPeer;
				}
			}
		}
		// skip if nothing to translate
		if ((target.address == ipHeader->dstAddress) &&
			(target.port == tcpHeader->dstPort)) break;

		// do address translation in packet
		KFT_natTranslateDst(packet, &target);
		// if proxy (case 2), translate source
		// response from remote proxy server addressed to apparent endpoint
		if (packet->natEntry && (packet->natEntry->flags & kNatFlagProxy)) {
			if (PROJECT_flags & kFlag_portMapLogging) KFT_portMapLog(packet, packet->natEntry, kMapLookup_proxy);
			KFT_natTranslateSrc(packet, &packet->natEntry->proxy);
			break;
		}
		
		// transparent proxy (case 1)?
		if (transparentProxy) {
			// temporarily forget NAT entry found during inbound dstAddress translation
			KFT_natEntry_t *holdEntry = packet->natEntry;
			packet->natEntry = NULL;
			KFT_natOut(packet);	// if local proxy, we replace the local from address with reflector address "1"
			if (packet->natEntry) {
				// remember redirected endpoint in nat entry
				memcpy(&packet->natEntry->proxy, &proxy, sizeof(KFT_connectionEndpoint_t));
				packet->natEntry->flags |= kNatFlagProxy;
			}
			// put back dstAddress NAT entry
			packet->natEntry = holdEntry;
			break;
		}
		// if internal interface and source IP is from our LAN,
		// translate source for Local NAT so response is directed back to gateway.
		// Notice packet direction is still inbound.
		if (!packet->myAttach->kftInterfaceEntry.externalOn || (params->singleNet.mask != 0)) {
			if (params->singleNet.mask != 0) {
				// from single network? (used for single Ethernet)
				netToMatch = params->singleNet.address & params->singleNet.mask;
				netData = ipHeader->srcAddress & params->singleNet.mask;
				if (netData != netToMatch) break;   // no skip local NAT
			}
#if 0	// allow Local NAT to other IP subnets
			else {
				// from directly attached net?
				netToMatch = params->ifNet.address & params->ifNet.mask;
				netData = ipHeader->srcAddress & params->ifNet.mask;
				if (netData != netToMatch) break;   // no skip local NAT
			}
#endif
			// forget NAT entry found during inbound dstAddress translation
			packet->natEntry = NULL;
			KFT_natOut(packet);
			break;
		}

	} while (0);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natTranslateDst()
// ---------------------------------------------------------------------------------
int KFT_natTranslateDst(KFT_packetData_t* packet, KFT_connectionEndpoint_t* target)
{
	int returnValue = 0;
	int result = 0;
	
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	u_int16_t fragmentOffset;

	// prepare to modify packet
	int status;
	status = PROJECT_modifyReadyPacket(packet);

	ipHeader = (ip_header_t*)packet->datagram;
	tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
	fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;

	udp_header_t* udpHeader;
	u_int32_t oldAddress;
	u_int16_t oldPort;

	// translate destination using entry we found
	// handle each protocol as a separate case
	switch (ipHeader->protocol) {
		case IPPROTO_UDP: {
			oldAddress = ipHeader->dstAddress;
			ipHeader->dstAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
				// UDP checksums are optional
				// If checksum was not computed (0), don't update it.
				// do UDP header in first fragment only
			udpHeader = (udp_header_t*)&packet->datagram[packet->ipHeaderLen];
			if ((fragmentOffset == 0) && (udpHeader->checksum != 0)) {
				udpHeader->checksum = hAdjustIpSum32(udpHeader->checksum, oldAddress, target->address);
			}
			// repeat for port if necessary
			if (fragmentOffset == 0) {
				oldPort = udpHeader->dstPort;
				udpHeader->dstPort = target->port;
				if (udpHeader->checksum != 0)
					udpHeader->checksum = hAdjustIpSum(udpHeader->checksum,
						oldPort, target->port);
			}
			break;
		}
		case IPPROTO_TCP: {
			oldAddress = ipHeader->dstAddress;
			ipHeader->dstAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
				// do TCP header in first fragment only
			if (fragmentOffset == 0) {
				// update tcp checksum for IP address in pseudo header
				#if TIGER
					tcpHeader->checksum = hAdjustIpSum32(tcpHeader->checksum, oldAddress, target->address);
				#else
					if ((status & CSUM_PSEUDO_HDR) == 0)
						tcpHeader->checksum = hAdjustIpSum32(tcpHeader->checksum, oldAddress, target->address);
				#endif
				// update tcp checksum for port if necessary
				oldPort = tcpHeader->dstPort;
				tcpHeader->dstPort = target->port;
				if (status == 0) tcpHeader->checksum = hAdjustIpSum(tcpHeader->checksum, oldPort, target->port);
			}
			// handle embedded ports as a special case
			/*
				// if FTP control connection...
				if (tcpHeader->srcPort == kFtpControlPort) {
					Convert2ActualFtp(table, datagram, mp,
										&lookupEntry, ipHeader, tcpHeader);
				}
				// if RTSP connection
				if (tcpHeader->srcPort == kRTSPControlPort) {
					Convert2ActualRTSP(table, datagram, mp,
										&lookupEntry, ipHeader, tcpHeader);
				}
			*/
			break;
		}
		case IPPROTO_ICMP: {
			u_int8_t* dp;
			icmp_header_t* icmpHeader;
			ip_header_t* ipHeader2 = NULL;
			udp_header_t* udpHeader2 = NULL;
			u_int8_t ipHeaderLen2;
			KFT_natEntry_t compareEntry;
			KFT_natEntry_t *foundEntry = NULL;
			u_int8_t foundTrigger = 0;
			icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
			// if the ICMP message contains a triggering datagram (we sent),
			// use its protocol and apparent source to find the actual destination
			if (fragmentOffset == 0) {  // first fragment
				switch (icmpHeader->type) {
					case kIcmpTypeDestUnreachable:
					case kIcmpTypeSourceQuench:
					case kIcmpTypeRedirect:
					case kIcmpTypeTimeExceeded:
					case kIcmpTypeParameterProblem:
						foundTrigger = 1;
						ipHeader2 = (ip_header_t*)&icmpHeader->data[0];
						ipHeaderLen2 = (ipHeader2->hlen & 0x0F) << 2;	// in bytes
						dp = (UInt8*)ipHeader2;
						udpHeader2 = (udp_header_t*)&dp[ipHeaderLen2];
						compareEntry.apparent.pad = 0;
						compareEntry.apparent.protocol = ipHeader2->protocol;
						compareEntry.apparent.port	= udpHeader2->srcPort;
						compareEntry.apparent.address = ipHeader->dstAddress;
						// lookup actual endpoint
						result = KFT_natFindActualForApparent(packet, &compareEntry, &foundEntry);
						if (!result) {
							target->address = foundEntry->actual.address;
							target->port = foundEntry->actual.port;
							// replace wildcard
							if (target->port == 0) target->port = compareEntry.apparent.port;
						}
					default:
						// No action required
						break;
				}				
			}				
			oldAddress = ipHeader->dstAddress;
			ipHeader->dstAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
			// if the ICMP message contains a triggering datagram, convert it
			if (foundTrigger) {
				// Convert ICMP triggering datagram to appear as if its source was
				// the actual endpoint.
				// Triggering datagram was originally sent through NAT Gateway and converted
				// to an apparent endpoint, need to reverse this translation.
				
				// Get apparent address, protocol from datagram.		
				compareEntry.apparent.address 	= ipHeader2->srcAddress;
				compareEntry.apparent.protocol	= ipHeader2->protocol;
				if ((ipHeader2->protocol == IPPROTO_TCP) ||
					(ipHeader2->protocol == IPPROTO_UDP)) compareEntry.apparent.port = udpHeader2->srcPort;
				else compareEntry.apparent.port = 0;
				// lookup actual endpoint
				result = KFT_natFindActualForApparent(packet, &compareEntry, &foundEntry);
				if (!result) {
					target->address = foundEntry->actual.address;
					target->port = foundEntry->actual.port;
					// replace wildcard
					if (target->port == 0) target->port = compareEntry.apparent.port;
					// replace apparent address with actual address and update checksums
					u_int16_t ipChecksum = ipHeader2->checksum;
					u_int16_t udpChecksum = udpHeader2->checksum;
					u_int16_t oldChecksum;
					oldAddress = ipHeader2->srcAddress;	// srcAddress of triggering dg
					ipHeader2->srcAddress = target->address;
					ipChecksum  = hAdjustIpSum32(ipChecksum,
						oldAddress, ipHeader2->srcAddress);	  // ip sum of trigger dg
					if (ipHeader2->protocol == IPPROTO_UDP) {
						// UDP checksums are optional
						// If checksum was not computed (0), don't update it.
						if (udpChecksum != 0)
							udpChecksum = hAdjustIpSum32(udpChecksum,
								oldAddress, ipHeader2->srcAddress);  // udp sum of trigger dg
					}
						// notice TCP checksum is not contained in reported trigger
						// (IP header + first 64-bits of datagram)
					icmpHeader->checksum = hAdjustIpSum32(icmpHeader->checksum,
						oldAddress, ipHeader2->srcAddress);	// icmp sum which includes trigger dg
					// repeat for port if necessary
					if (compareEntry.apparent.port != target->port) {
						oldPort = udpHeader2->srcPort;
						udpHeader2->srcPort = target->port;
						if ((ipHeader2->protocol == IPPROTO_UDP) && (udpChecksum != 0)) {
							udpChecksum = hAdjustIpSum(udpChecksum, oldPort, udpHeader2->srcPort);
						}
							// TCP checksum is not contained in reported trigger
							// IP checksum does not cover transport header
						icmpHeader->checksum = hAdjustIpSum(icmpHeader->checksum,
							oldPort, udpHeader2->srcPort);	// icmp sum which includes trigger dg
					}
					// replace trigger ipChecksum and update ICMP checksum
					oldChecksum = ipHeader2->checksum;
					ipHeader2->checksum = ipChecksum;
					icmpHeader->checksum = hAdjustIpSum(icmpHeader->checksum,
							oldChecksum, ipChecksum);
					// replace trigger udp checksum and update ICMP checksum
					if ((ipHeader2->protocol == IPPROTO_UDP) && (udpChecksum != 0)) {
						oldChecksum = udpHeader2->checksum;
						udpHeader2->checksum = udpChecksum;
						icmpHeader->checksum = hAdjustIpSum(icmpHeader->checksum,
							oldChecksum, udpChecksum);
					}						
				}
			}
			break;
		}
		//case IPPROTO_GRE:
		default:
			// translate address only (port if any is unknown)
			oldAddress = ipHeader->dstAddress;
			ipHeader->dstAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
			break;
	}  // switch (ipHeader->protocol)
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ KFT_natOut()
// ---------------------------------------------------------------------------------
//	Convert source from actual to apparent endpoint for corresponding interface
//  so datagram appears to originate from the NAT gateway.
//
// Do not translate datagram if the destination IP address is that
// of our private LAN (actual network).  This allows a 2nd IP interface
// on the same Ethernet port to bypass masquerading.
//
//  Output: 0 = success, or other NKE result
//    including EJUSTRETURN, *packet->mbuf_ptr = NULL; packet was consumed.
//
// Two transparent proxy cases:
// (1) Packet to be proxied and local proxy flag is set, use address "1" as source.
// (2) Response from local proxy server, destination address is "1".
int KFT_natOut(KFT_packetData_t* packet)
{
	int returnValue = 0;
	int result = 0;
	do {
		u_int32_t	netData;
		u_int32_t	netToMatch;
		KFT_interfaceEntry_t* params;
		KFT_connectionEndpoint_t target;
		ip_header_t* ipHeader;
		tcp_header_t* tcpHeader;
		u_int16_t fragmentOffset;

		ipHeader = (ip_header_t*)packet->datagram;
		// reflector for local transparent proxy (case 2)
		if (ipHeader->dstAddress == 1) {
			KFT_natIn(packet);
			returnValue = KFT_reflectPacket(packet);
			break;
		}
		tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
		fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;
		target.address = 0;
		target.port = 0;
		// get interface params
		params = &packet->myAttach->kftInterfaceEntry;
		// do not masquerade outbound via internal interface
		if (!params->externalOn && (packet->direction == kDirectionOutbound)) break;
		// to or from exclude network?
		if (params->excludeNet.mask != 0) {
			netToMatch = params->excludeNet.address & params->excludeNet.mask;
			// from exclude network
			netData = ipHeader->srcAddress & params->excludeNet.mask;
			if (netData == netToMatch) break;
			// to exclude network?
			netData = ipHeader->dstAddress & params->excludeNet.mask;
			if (netData == netToMatch) break;
		}
		// unregistered only
		if (PROJECT_flags & kFlag_unregisteredOnly) {
			// -unregistered_only | -u
			//	Only alter outgoing packets with an unregistered source
			//	address.  According to RFC 1918, unregistered source
            //	addresses are 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16.			
			if (((ipHeader->srcAddress & 0xFFFF0000) != 0xC0A80000) &&		// 192.168.0.0
				((ipHeader->srcAddress & 0xFFF00000) != 0xAC100000) &&		// 172.16.0.0
				((ipHeader->srcAddress & 0xFF000000) != 0x0A000000) ) break;	// 10.0.0.0
			// don't translate if dst is directly attached on external subnet
			netToMatch = params->natNet.address & params->natNet.mask;
			// to nat network?
			netData = ipHeader->dstAddress & params->natNet.mask;
			if (netData == netToMatch) break;			
		}
		// to single network? (used for single Ethernet)
		if (params->singleNet.mask != 0) {
			netToMatch = params->singleNet.address & params->singleNet.mask;
			netData = ipHeader->dstAddress & params->singleNet.mask;
			if ((netData == netToMatch) && (packet->direction == kDirectionOutbound)) break;
		}
		// Do not masquerade datagrams from our NAT network that are not from the NAT address
		// unless local NAT (This is to support multiple public IP addresses)
		if ((params->natNet.mask != 0) &&
			(ipHeader->srcAddress != params->natNet.address) &&
			(packet->direction == kDirectionOutbound)) {
			netToMatch = params->natNet.address & params->natNet.mask;
			netData = ipHeader->srcAddress & params->natNet.mask;
			if (netData == netToMatch) break;
		}
		// look for NAT entry
		// Get actual address and protocol from datagram.
		if (packet->natEntry) {
			target.address = packet->natEntry->apparent.address;
			target.port = packet->natEntry->apparent.port;		
		}
		else {
			KFT_natEntry_t compareEntry;
			bzero(&compareEntry, sizeof(KFT_natEntry_t));			
			compareEntry.actual.protocol = ipHeader->protocol;
			compareEntry.actual.address	= ipHeader->srcAddress;
			if ((ipHeader->protocol == IPPROTO_TCP) || (ipHeader->protocol == IPPROTO_UDP)) {
				if (fragmentOffset == 0) {
					compareEntry.actual.port = tcpHeader->srcPort;
				}
				else {
					// try to get port information from ip fragment table
					KFT_fragmentEntry_t *foundFEntry = NULL;
					KFT_fragmentEntry_t cEntry;
					cEntry.fragment.srcAddress = ipHeader->srcAddress;
					cEntry.fragment.identification = ipHeader->identification;			
					result = KFT_fragmentFindEntry(&cEntry, &foundFEntry);
					if (result == 0) {
						compareEntry.actual.port	= foundFEntry->srcPort;
					}
				}
			}
			// lookup apparent endpoint
			result = KFT_natFindApparentForActual(packet, &compareEntry, &packet->natEntry);
			if (result == 0) {
				target.address = packet->natEntry->apparent.address;
				target.port = packet->natEntry->apparent.port;
				// replace wildcard
				if (target.port == 0) target.port = compareEntry.actual.port;
			}
			else {
				// No match found.  Create a new NAT table entry
				result = KFT_natPacket(packet);
				if (result == 0) {  // entry was created
					target.address = packet->natEntry->apparent.address;
					target.port = packet->natEntry->apparent.port;
				}
			}
		}
		// update NAT entry flags
		if (packet->natEntry && (ipHeader->protocol == IPPROTO_TCP)) {
			// SYN
			if (!(tcpHeader->code & kCodeSYN)) packet->natEntry->flags |= kNatFlagNonSyn;
			// FIN
			if (tcpHeader->code & kCodeFIN) {
				packet->natEntry->flags |= kNatFlagFINLocal;
				packet->natEntry->seqFINLocal = tcpHeader->seqNumber;
			}
			// FIN ACK (peer has sent FIN and local is acking it
			if (packet->natEntry->flags & kNatFlagFINPeer) {
				if (tcpHeader->code & kCodeACK) {
					if ( SEQ_GT(tcpHeader->ackNumber,packet->natEntry->seqFINPeer) )
						packet->natEntry->flags |= kNatFlagFINAckLocal;
				}
			}
		}
		// translate if needed
		if ((target.address != ipHeader->srcAddress) || (target.port != tcpHeader->srcPort)) {
			KFT_natTranslateSrc(packet, &target);
		}

#if 0
		// hair pin if destination is our NAT address
		if ((params->natNet.mask != 0) &&
			(ipHeader->dstAddress == params->natNet.address) &&
			(packet->direction == kDirectionOutbound)) {
			KFT_natIn(packet);
			returnValue = KFT_reflectPacket(packet);
			break;
		}
#endif
	} while (0);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ KFT_natTranslateSrc()
// ---------------------------------------------------------------------------------
int KFT_natTranslateSrc(KFT_packetData_t* packet, KFT_connectionEndpoint_t* target)
{
	int returnValue = 0;
	int result = 0;
	
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	u_int16_t fragmentOffset;
	
	// prepare to modify packet
	int status;
	status = PROJECT_modifyReadyPacket(packet);

	ipHeader = (ip_header_t*)packet->datagram;
	tcpHeader = (tcp_header_t*)&packet->datagram[packet->ipHeaderLen];
	fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;

	udp_header_t* udpHeader;
	u_int32_t oldAddress;
	u_int16_t oldPort;

	// translate source using entry we found
	// handle each protocol as a separate case
	switch (ipHeader->protocol) {
		case IPPROTO_UDP: {
			oldAddress = ipHeader->srcAddress;
			ipHeader->srcAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
				// UDP checksums are optional
				// If checksum was not computed (0), don't update it.
				// do UDP header in first fragment only
			udpHeader = (udp_header_t*)&packet->datagram[packet->ipHeaderLen];
			if ((fragmentOffset == 0) && (udpHeader->checksum != 0)) {
				udpHeader->checksum = hAdjustIpSum32(udpHeader->checksum, oldAddress, target->address);
			}
			// repeat for port if necessary
			if (fragmentOffset == 0) {
				oldPort = udpHeader->srcPort;
				udpHeader->srcPort = target->port;
				if (udpHeader->checksum != 0)
					udpHeader->checksum = hAdjustIpSum(udpHeader->checksum,
						oldPort, target->port);
			}
			break;
		}
		case IPPROTO_TCP: {
			oldAddress = ipHeader->srcAddress;
			ipHeader->srcAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
				// do TCP header in first fragment only
			if (fragmentOffset == 0) {
				// update tcp checksum for IP address in pseudo-header
				#if TIGER
					tcpHeader->checksum = hAdjustIpSum32(tcpHeader->checksum, oldAddress, target->address);
				#else
					if ((status & CSUM_PSEUDO_HDR) == 0)
						tcpHeader->checksum = hAdjustIpSum32(tcpHeader->checksum, oldAddress, target->address);
				#endif
				// repeat for port if necessary
				oldPort = tcpHeader->srcPort;
				tcpHeader->srcPort = target->port;
				if (status == 0) tcpHeader->checksum = hAdjustIpSum(tcpHeader->checksum, oldPort, target->port);
			}
			// handle embedded ports as a special case
			/*
				// if FTP control connection...
				if (tcpHeader->srcPort == kFtpControlPort) {
					Convert2ActualFtp(table, datagram, mp,
										&lookupEntry, ipHeader, tcpHeader);
				}
				// if RTSP connection
				if (tcpHeader->srcPort == kRTSPControlPort) {
					Convert2ActualRTSP(table, datagram, mp,
										&lookupEntry, ipHeader, tcpHeader);
				}
			*/
			break;
		}
		case IPPROTO_ICMP: {
			u_int8_t* dp;
			icmp_header_t* icmpHeader;
			ip_header_t* ipHeader2 = NULL;
			udp_header_t* udpHeader2 = NULL;
			u_int8_t ipHeaderLen2;
			KFT_natEntry_t compareEntry;
			KFT_natEntry_t *foundEntry = NULL;
			u_int8_t foundTrigger = 0;
			icmpHeader = (icmp_header_t*)&packet->datagram[packet->ipHeaderLen];
			// if the ICMP message contains a triggering datagram (we are returning),
			// use its protocol and actual destination to lookup the apparent source
			if (fragmentOffset == 0) {  // first fragment
				switch (icmpHeader->type) {
					case kIcmpTypeDestUnreachable:
					case kIcmpTypeSourceQuench:
					case kIcmpTypeRedirect:
					case kIcmpTypeTimeExceeded:
					case kIcmpTypeParameterProblem:
						foundTrigger = 1;
						ipHeader2 = (ip_header_t*)&icmpHeader->data[0];
						ipHeaderLen2 = (ipHeader2->hlen & 0x0F) << 2;	// in bytes
						dp = (UInt8*)ipHeader2;
						udpHeader2 = (udp_header_t*)&dp[ipHeaderLen2];
						compareEntry.actual.pad = 0;
						compareEntry.actual.protocol = ipHeader2->protocol;
						compareEntry.actual.port	= udpHeader2->dstPort;
						compareEntry.actual.address = ipHeader->srcAddress;
						// lookup apparent endpoint
						result = KFT_natFindApparentForActual(packet, &compareEntry, &foundEntry);
						if (!result) {
							target->address = foundEntry->apparent.address;
							target->port = foundEntry->apparent.port;
							// replace wildcard
							if (target->port == 0) target->port = compareEntry.actual.port;
						}
					default:
						// No action required
						break;
				}				
			}				
			oldAddress = ipHeader->srcAddress;
			ipHeader->srcAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
			// if the ICMP message contains a triggering datagram, convert it
			if (foundTrigger) {
				// Convert ICMP triggering datagram to appear as if its destination was
				// the apparent endpoint.
				// The triggering datagram was originally sent through NAT Gateway and converted
				// to an actual endpoint, need to reverse this translation.
				
				// Get actual address, protocol from datagram.		
				compareEntry.actual.address 	= ipHeader2->dstAddress;
				compareEntry.actual.protocol	= ipHeader2->protocol;
				if ((ipHeader2->protocol == IPPROTO_TCP) ||
					(ipHeader2->protocol == IPPROTO_UDP)) compareEntry.actual.port = udpHeader2->dstPort;
				else compareEntry.actual.port = 0;
				// lookup apparent endpoint
				result = KFT_natFindApparentForActual(packet, &compareEntry, &foundEntry);
				if (!result) {
					target->address = foundEntry->apparent.address;
					target->port = foundEntry->apparent.port;
					// replace wildcard
					if (target->port == 0) target->port = compareEntry.actual.port;
					// replace actual address with apparent address and update checksums
					u_int16_t ipChecksum = ipHeader2->checksum;
					u_int16_t udpChecksum = udpHeader2->checksum;
					u_int16_t oldChecksum;
					oldAddress = ipHeader2->dstAddress;	// dstAddress of triggering dg
					ipHeader2->dstAddress = target->address;
					ipChecksum  = hAdjustIpSum32(ipChecksum,
						oldAddress, ipHeader2->dstAddress);	  // ip sum of trigger dg
					if (ipHeader2->protocol == IPPROTO_UDP) {
						// UDP checksums are optional
						// If checksum was not computed (0), don't update it.
						if (udpChecksum != 0)
							udpChecksum = hAdjustIpSum32(udpChecksum,
								oldAddress, ipHeader2->dstAddress);  // udp sum of trigger dg
					}
						// notice TCP checksum is not contained in reported trigger
						// (IP header + first 64-bits of datagram)
					icmpHeader->checksum = hAdjustIpSum32(icmpHeader->checksum,
						oldAddress, ipHeader2->dstAddress);	// icmp sum which includes trigger dg
					// repeat for port if necessary
					if (compareEntry.actual.port != target->port) {
						oldPort = udpHeader2->dstPort;
						udpHeader2->dstPort = target->port;
						if ((ipHeader2->protocol == IPPROTO_UDP) && (udpChecksum != 0)) {
							udpChecksum = hAdjustIpSum(udpChecksum, oldPort, udpHeader2->dstPort);
						}
							// TCP checksum is not contained in reported trigger
							// IP checksum does not cover transport header
						icmpHeader->checksum = hAdjustIpSum(icmpHeader->checksum,
							oldPort, udpHeader2->dstPort);	// icmp sum which includes trigger dg
					}
					// replace trigger ipChecksum and update ICMP checksum
					oldChecksum = ipHeader2->checksum;
					ipHeader2->checksum = ipChecksum;
					icmpHeader->checksum = hAdjustIpSum(icmpHeader->checksum,
							oldChecksum, ipChecksum);
					// replace trigger udp checksum and update ICMP checksum
					if ((ipHeader2->protocol == IPPROTO_UDP) && (udpChecksum != 0)) {
						oldChecksum = udpHeader2->checksum;
						udpHeader2->checksum = udpChecksum;
						icmpHeader->checksum = hAdjustIpSum(icmpHeader->checksum,
							oldChecksum, udpChecksum);
					}						
				}
			}
			break;
		}
		//case IPPROTO_GRE:
		default:
			// translate address only (port if any is unknown)
			oldAddress = ipHeader->srcAddress;
			ipHeader->srcAddress = target->address;
			ipHeader->checksum  = hAdjustIpSum32(ipHeader->checksum, oldAddress, target->address);
			break;
	}  // switch (ipHeader->protocol)

	return returnValue;
}
