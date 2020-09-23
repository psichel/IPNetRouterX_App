//
// IPKSupport.h
// IPNetSentryX
//
// Created by Peter Sichel on Mon Nov 25 2002.
// Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
// Base on IPNetRouter code from NatProcess.cp ©1997 Sustainable Softworks
//
// Kernel IP filter support functions
//
#include <sys/types.h>
#include "IPTypes.h"
#include "myTypes.h"

u_int16_t	hAdjustIpSum( u_int16_t oldSum, u_int16_t oldData, u_int16_t newData);
u_int16_t	hAdjustIpSum32( u_int16_t oldSum, u_int32_t oldData, u_int32_t newData);
u_int16_t	nAdjustIpSum( u_int16_t oldSum, u_int16_t oldData, u_int16_t newData);
u_int16_t	nAdjustIpSum32( u_int16_t oldSum, u_int32_t oldData, u_int32_t newData);

u_int16_t	IpSum( u_int16_t* dataPtr, u_int16_t* endPtr);
u_int16_t	RemoveFromSum( u_int16_t oldSum, u_int16_t* dataPtr, u_int16_t* endPtr);
u_int16_t	AddToSum( u_int16_t oldSum, u_int16_t* dataPtr, u_int16_t* endPtr);
bool ipCheck(u_int8_t* datagram);
bool tcpCheck(u_int8_t* datagram);
// internal representations
u_int32_t hashForName(const char* inName);
u_int32_t secondsForDuration(u_int8_t value);