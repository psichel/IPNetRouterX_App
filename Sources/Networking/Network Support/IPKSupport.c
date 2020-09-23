//
// IPKSupport.c
// IPNetSentryX
//
// Created by Peter Sichel on Mon Nov 25 2002.
// Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
// Base on IPNetRouter code from NatProcess.cp ©1997 Sustainable Softworks
//
// Kernel IP filter support functions
//

#include "IPKSupport.h"
#include "IPTypes.h"

#pragma mark -- adjust checksums --
// ---------------------------------------------------------------------------
//		¥ hAdjustIpSum
// ---------------------------------------------------------------------------
// Adjust IP checksum for modified data
// Underlying data and checksums are passed in host byte order to be swapped later
//  4/13/96 Peter Sichel - Original version
u_int16_t hAdjustIpSum( u_int16_t oldSum, u_int16_t oldData, u_int16_t newData)
{
	// oldSum is the previous checksum value
	// oldData is prevous value of word to be modified
	// newData is word to replace oldata
	
	int32_t	sum;
	
	sum = ~oldSum & 0xFFFF;	// reverse one's complement to get previous sum
	sum -= oldData;	// subtract old data
	sum += newData;	// add new data
	
	// adjust to include carry for ones complement sum
	while (sum>>16)
		sum = (sum & 0xffff) + (sum >> 16);
	
	// return the one's complement of the one's complement sum
	return ((u_int16_t)~sum);
}


// ---------------------------------------------------------------------------
//		¥ hAdjustIpSum32
// ---------------------------------------------------------------------------
// Adjust IP checksum for modified data
// Underlying data and checksums are passed in host byte order to be swapped later
u_int16_t hAdjustIpSum32( u_int16_t oldSum, u_int32_t oldData, u_int32_t newData)
{
	int32_t	sum;
	
	sum = ~oldSum & 0xffff;	// reverse one's complement to get previous sum

	sum -= oldData>>16;			// subtract old data
	sum += newData>>16;			// add new data
	sum -= oldData & 0xffff;	// subtract old data
	sum += newData & 0xffff;	// add new data
	
	// adjust to include carry for ones complement sum
	while (sum>>16)
		sum = (sum & 0xffff) + (sum >> 16);
	
	// return the one's complement of the one's complement sum
	return ((u_int16_t)~sum);
}


// ---------------------------------------------------------------------------
//		¥ nAdjustIpSum
// ---------------------------------------------------------------------------
// Adjust IP checksum for modified data
// Underlying data and checksums are passed in network byte order
//  4/13/96 Peter Sichel - Original version
u_int16_t nAdjustIpSum( u_int16_t oldSum, u_int16_t oldData, u_int16_t newData)
{
	// oldSum is the previous checksum value
	// oldData is prevous value of word to be modified
	// newData is word to replace oldata
	
	int32_t	sum;
	
	sum = ~ntohs(oldSum) & 0xFFFF;	// reverse one's complement to get previous sum
	sum -= ntohs(oldData);	// subtract old data
	sum += ntohs(newData);	// add new data
	
	// adjust to include carry for ones complement sum
	while (sum>>16)
		sum = (sum & 0xffff) + (sum >> 16);
	
	// return the one's complement of the one's complement sum
	return ((u_int16_t)htonl(~sum));
}


// ---------------------------------------------------------------------------
//		¥ nAdjustIpSum32
// ---------------------------------------------------------------------------
// Adjust IP checksum for modified data
// Underlying data and checksums are passed in network byte order
u_int16_t nAdjustIpSum32( u_int16_t oldSum, u_int32_t oldData, u_int32_t newData)
{
	int32_t	sum;
	
	sum = ~ntohs(oldSum) & 0xffff;	// reverse one's complement to get previous sum

	sum -= ntohs(oldData>>16);			// subtract old data
	sum += ntohs(newData>>16);			// add new data
	sum -= ntohs(oldData & 0xffff);		// subtract old data
	sum += ntohs(newData & 0xffff);		// add new data
	
	// adjust to include carry for ones complement sum
	while (sum>>16)
		sum = (sum & 0xffff) + (sum >> 16);
	
	// return the one's complement of the one's complement sum
	return ((u_int16_t)htonl(~sum));
}

#pragma mark -- compute checksums --
// ---------------------------------------------------------------------------
//		¥ IpSum
// ---------------------------------------------------------------------------
// Compute IP checksums
// One's complement of 16 bit one's complement sum
//		dataPtr points to a sequence of 16 bit words to be checksummed
//		endPtr points to one past the last word to be included in checksum
// Underlying data is in network byte order, but csum passed in host order
// for further processing or conversion by kernel.
u_int16_t IpSum(u_int16_t* dataPtr, u_int16_t* endPtr)
{
	u_int16_t	value;
	int32_t		sum;
	u_int16_t	result;
	
	// initialize checksum to zero
	sum = 0;
	
	// add in each word, accumulating overflow in the upper word
	while (dataPtr < endPtr)
		{
		value = *dataPtr++;
		sum += ntohs(value);
		};
	
	// remove extra byte if not an even number
	if (dataPtr != endPtr) {
		sum -= *(u_int8_t*)endPtr;
	}
	
	// add in the overflow to form one's complement sum
	while (sum>>16)
		sum = (sum & 0xffff) + (sum >> 16);
	
	// return the one's complement of the one's complement sum
	result = (u_int16_t)~sum;
	if (result == 0) result = 0xFFFF;
	return result;
}

// ---------------------------------------------------------------------------
//		¥ RemoveFromSum
// ---------------------------------------------------------------------------
// Remove old data from IP checksum
// One's complement of 16 bit one's complement sum
//		dataPtr points to a sequence of 16 bit words to be checksummed
//		endPtr points to one past the last word to be included in checksum
// Underlying data is in network byte order, but csum passed in host order
// for further processing.
u_int16_t RemoveFromSum( u_int16_t oldSum, u_int16_t* dataPtr, u_int16_t* endPtr)
{
	int32_t	sum;
	u_int16_t value;
	
	sum = ~oldSum & 0xffff;	// reverse one's complement to get previous sum

	// remove each word, accumulating overflow in the upper word
	while (dataPtr < endPtr)
		{
		value = *dataPtr++;
		sum -= ntohs(value);
		};
	
	// add back extra byte if not an even number
	if (dataPtr != endPtr) {
		sum += *(u_int8_t*)endPtr;
	}
	
	// adjust to include carry for ones complement sum
	while (sum>>16)
		sum = (sum & 0xffff) + (sum >> 16);
	
	// return the one's complement of the one's complement sum
	return ((u_int16_t)~sum);
}


// ---------------------------------------------------------------------------
//		¥ AddToSum
// ---------------------------------------------------------------------------
// Add new data to IP checksum
// One's complement of 16 bit one's complement sum
//		dataPtr points to a sequence of 16 bit words to be checksummed
//		endPtr points to one past the last word to be included in checksum
// Underlying data is in network byte order, but csum passed in host order
// for further processing or conversion by kernel.
u_int16_t AddToSum( u_int16_t oldSum, u_int16_t* dataPtr, u_int16_t* endPtr)
{
	int32_t	sum;
	u_int16_t value;
	
	sum = ~oldSum & 0xffff;	// reverse one's complement to get previous sum

	// add in each word, accumulating overflow in the upper word
	while (dataPtr < endPtr)
		{
		value = *dataPtr++;
		sum += ntohs(value);
		};
	
	// remove extra byte if not an even number
	if (dataPtr != endPtr) {
		sum -= *(u_int8_t*)endPtr;
	}
	
	// adjust to include carry for ones complement sum
	while (sum>>16)
		sum = (sum & 0xffff) + (sum >> 16);
	
	// return the one's complement of the one's complement sum
	return ((u_int16_t)~sum);
}


// ---------------------------------------------------------------------------
//		¥ ipCheck
// ---------------------------------------------------------------------------
// Verify IP header checksum.  True if OK, otherwise false.
// Used primarily for debugging.
bool
ipCheck(u_int8_t* datagram)
{
	ip_header_t*	ipHeader;
	u_int8_t			ipHeaderLen;
	bool			result = true;

	// setup to access IP Header
	ipHeader = (ip_header_t*)datagram;

	ipHeaderLen = (ipHeader->hlen & 0x0F) << 2;	// in bytes
	// verify header checksum
	if (IpSum( (u_int16_t*)&datagram[0], (u_int16_t*)&datagram[ipHeaderLen] ) != 0xFFFF) {
		result = false;
	}

	return result;
}


// ---------------------------------------------------------------------------
//		¥ tcpCheck
// ---------------------------------------------------------------------------
// Verify tcp segment checksum.  True if OK, otherwise false.
// Used primarily for debugging.
bool
tcpCheck(u_int8_t* datagram)
{
	ip_header_t*	ipHeader;
	tcp_header_t*	tcpHeader;
	u_int8_t		ipHeaderLen;
	u_int8_t		tcpHeaderLen;
	u_int16_t		sum;
	tcp_pseudo_t	pseudoHeader;
	u_int8_t*		dp;
	int 			checksumLength;
	bool			result = true;

	// setup to access IP Header
	ipHeader = (ip_header_t*)datagram;
	ipHeaderLen = (ipHeader->hlen & 0x0F) << 2;	// in bytes

	// setup access to TCP header
	tcpHeader = (tcp_header_t*)&datagram[ipHeaderLen];	
	tcpHeaderLen = (tcpHeader->hlen & 0xF0) >> 2;	// in bytes

	// build TCP pseudo header
	pseudoHeader.srcAddress	= ipHeader->srcAddress;
	pseudoHeader.dstAddress	= ipHeader->dstAddress;
	pseudoHeader.zero		= 0;
	pseudoHeader.protocol	= 6;
	pseudoHeader.length		= ipHeader->totalLength - ipHeaderLen;

	// compute pseudo header sum
	dp = (u_int8_t*)&pseudoHeader;
	sum = IpSum((u_int16_t*)&dp[0], (u_int16_t*)&dp[sizeof(tcp_pseudo_t)] );

	// add tcp segment
	dp = (u_int8_t*)tcpHeader;
	checksumLength = ipHeader->totalLength - ipHeaderLen;
	if (checksumLength % 2) {
		dp[checksumLength] = 0;
		checksumLength += 1;
	}
	sum = AddToSum(sum, (u_int16_t*)&dp[0], (u_int16_t*)&dp[checksumLength]);
	if (sum == 0) sum = 0xffff;
	
	// verify checksum
	if (sum != 0xFFFF) {
		result = false;
	}

	return result;
}

#pragma mark -- internal representations --
// ---------------------------------------------------------------------------------
//	¥ hashForName
// ---------------------------------------------------------------------------------
//	Hash table name to a 32-bit value
//  Only the first 16 characters of inName will be hashed
u_int32_t hashForName(const char* inName)
{
	u_int32_t	result = 0;
	u_int32_t	part = 0;
	u_int32_t	index;
	u_int8_t	c;
	
	for (index=0; index<16; index++) {
		if ((c = inName[index])) {
			part = result >> 24;		// get left most byte
			result = result << 8;		// shift left 8-bits
			result += c;				// add next character in name
			result += part << 5;		// add back anything shifted out
			result += part << 19;
		}
	}
	
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ secondsForDuration
// ---------------------------------------------------------------------------------
// convert menu index to seconds
u_int32_t secondsForDuration(u_int8_t value)
{
	u_int32_t returnValue = 0;
	switch (value) {
		case 0:		// unlimited
			returnValue = 0;
			break;
		case 1:		// 1 minute
			returnValue = 60;
			break;
		case 2:		// 10 minutes
			returnValue = 600;
			break;
		case 3:		// 1 hour
			returnValue = 3600;
			break;
		case 4:		// 10 hours
			returnValue = 36000;
			break;
		case 5:		// 1 day
			returnValue = 86400;
			break;
		case 6:		// 10 days
			returnValue = 864000;
			break;
	}
	return returnValue;
}


