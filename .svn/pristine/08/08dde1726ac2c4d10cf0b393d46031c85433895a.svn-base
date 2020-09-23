//
//  Quad.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on 5/14/08.
//  Copyright 2008 Sustainable Softworks, inc.  All rights reserved.
//
//	Simple 128-bit arithmetic for manipulating IPv6 addresses
//	Treat Quad objects as immutable, all operations return a new instance
//	get/set in network byte order

#import "Quad.h"

@implementation Quad
// ---------------------------------------------------------------------------
//  • init
// ---------------------------------------------------------------------------
- (Quad *)init {
    if (self = [super init]) {
	}
    return self;
}
//- (void)dealloc {
//    [super dealloc];
//}

// ---------------------------------------------------------------------------
//  • quadWithInt:(int)inValue
// ---------------------------------------------------------------------------
+ (Quad *)quadWithInt:(int)inValue {
	Quad *object = [[Quad alloc] init];
	u_int32_t *tempQ = [object value];
	bzero(tempQ, 16);
	tempQ[3] = htonl(inValue);
	return [object autorelease];
}

// ---------------------------------------------------------------------------
//  • quadWithMaskL
// ---------------------------------------------------------------------------
// initialize with Left (MSB) mask of count "1" bits
+ (Quad *)quadWithMaskL:(int)count {
	Quad *object = [[Quad alloc] init];
	u_int32_t *tempQ = [object value];
	bzero(tempQ, 16);
	if (count > 128) count = 128;
	int wMask = count / 32;
	int bMask = count % 32;
	int i;
	// word mask
	if (wMask) {
		for (i=0; i<wMask; i++) {
			tempQ[i] = 0xFFFFFFFF;
		}
	}
	// bit mask
	if (bMask) {
		tempQ[wMask] = htonl( 0xFFFFFFFF << (32 - bMask) );
	}
	return [object autorelease];
}

// ---------------------------------------------------------------------------
//  • quadWithMaskR
// ---------------------------------------------------------------------------
// initialize with Right (LSB) mask of count "1" bits
+ (Quad *)quadWithMaskR:(int)count {
	Quad *object = [[Quad alloc] init];
	u_int32_t *tempQ = [object value];
	bzero(tempQ, 16);
	if (count > 128) count = 128;
	int wMask = count / 32;
	int bMask = count % 32;
	int i;
	// word mask
	if (wMask) {
		for (i=0; i<wMask; i++) {
			tempQ[3-i] = 0xFFFFFFFF;
		}
	}
	// bit mask
	if (bMask) {
		tempQ[3-wMask] = htonl( 0xFFFFFFFF >> (32 - bMask) );
	}
	return [object autorelease];
}

// ---------------------------------------------------------------------------
//  • quadWithIPv6
// ---------------------------------------------------------------------------
+ (Quad *)quadWithIPv6:(in6_addr_t *)address6 {
	Quad *object = [[Quad alloc] init];
	[object setValue:(u_int32_t*)address6];
	return [object autorelease];
}

#pragma mark - get/set -
// ---------------------------------------------------------------------------
//  • value
// ---------------------------------------------------------------------------
// returns pointer to 4x32-bit value
- (u_int32_t *)value {
	return mQuad;
}

// ---------------------------------------------------------------------------
//  • value6
// ---------------------------------------------------------------------------
// returns pointer to in6_addr_t value
- (in6_addr_t *)value6 {
	return (in6_addr_t *)mQuad;
}

// ---------------------------------------------------------------------------
//  • setValue
// ---------------------------------------------------------------------------
// copy in from buffer
- (void)setValue:(u_int32_t *)dp {
	memcpy(mQuad, dp, 16);
}

// ---------------------------------------------------------------------------
//  • getValue
// ---------------------------------------------------------------------------
// copy out to buffer
- (void)getValue:(u_int32_t *)dp {
	memcpy(dp, mQuad, 16);
}

#pragma mark - byte order neutral arithmetic -
// ---------------------------------------------------------------------------
//  • andQuad
// ---------------------------------------------------------------------------
- (Quad *)andQuad:(Quad *)inQuad {
	Quad *outQuad = [[Quad alloc] init];
	u_int32_t tempQ[4];
	[inQuad getValue:tempQ];

	tempQ[0] = mQuad[0] & tempQ[0];
	tempQ[1] = mQuad[1] & tempQ[1];
	tempQ[2] = mQuad[2] & tempQ[2];
	tempQ[3] = mQuad[3] & tempQ[3];
	
	[outQuad setValue:tempQ]; 
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • andBitNotQuad
// ---------------------------------------------------------------------------
- (Quad *)andBitNotQuad:(Quad *)inQuad {
	Quad *outQuad = [[Quad alloc] init];
	u_int32_t tempQ[4];
	[inQuad getValue:tempQ];

	tempQ[0] = mQuad[0] & ~tempQ[0];
	tempQ[1] = mQuad[1] & ~tempQ[1];
	tempQ[2] = mQuad[2] & ~tempQ[2];
	tempQ[3] = mQuad[3] & ~tempQ[3];
	
	[outQuad setValue:tempQ]; 
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • orQuad
// ---------------------------------------------------------------------------
- (Quad *)orQuad:(Quad *)inQuad {
	Quad *outQuad = [[Quad alloc] init];
	u_int32_t tempQ[4];
	[inQuad getValue:tempQ];

	tempQ[0] |= mQuad[0];
	tempQ[1] |= mQuad[1];
	tempQ[2] |= mQuad[2];
	tempQ[3] |= mQuad[3];
	
	[outQuad setValue:tempQ]; 
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • xorQuad
// ---------------------------------------------------------------------------
- (Quad *)xorQuad:(Quad *)inQuad {
	Quad *outQuad = [[Quad alloc] init];
	u_int32_t tempQ[4];
	[inQuad getValue:tempQ];

	tempQ[0] ^= mQuad[0];
	tempQ[1] ^= mQuad[1];
	tempQ[2] ^= mQuad[2];
	tempQ[3] ^= mQuad[3];
	
	[outQuad setValue:tempQ]; 
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • isZero
// ---------------------------------------------------------------------------
- (BOOL)isZero {
	if (mQuad[0]) return NO;
	if (mQuad[1]) return NO;
	if (mQuad[2]) return NO;
	if (mQuad[3]) return NO;
	return YES;
}

#pragma mark - network byte order arithmetic -
// ---------------------------------------------------------------------------
//  • quadShiftL
// ---------------------------------------------------------------------------
// return a quad shifted left count bits
- (Quad *)shiftL:(int)count {
	Quad *outQuad = [[Quad alloc] init];
	if (count < 128) {
		u_int32_t tempQ[4];
		[self getValue:tempQ];
		tempQ[0] = ntohl(tempQ[0]);
		tempQ[1] = ntohl(tempQ[1]);
		tempQ[2] = ntohl(tempQ[2]);
		tempQ[3] = ntohl(tempQ[3]);
		
		int wShift = count / 32;
		int bShift = count % 32;
		int i;
		// word shift
		if (wShift) {
			for (i=0; i<4; i++) {
				if ((i+wShift) < 4) tempQ[i] = tempQ[i+wShift];
				else tempQ[i] = 0;
			}
		}
		// bit shift
		if (bShift) {
			u_int32_t mask = 0xFFFFFFFF << (32 - bShift);
			u_int32_t temp;
			for (i=0; i<4; i++) {
				// get bits we're about to shift out
				temp = (tempQ[i] & mask) >> (32 - bShift);
				// or back to previous word (if any)
				if (i > 0) tempQ[i-1] |= temp;
				// shift this word
				tempQ[i] <<= bShift;
			}
		}
		
		tempQ[0] = htonl(tempQ[0]);
		tempQ[1] = htonl(tempQ[1]);
		tempQ[2] = htonl(tempQ[2]);
		tempQ[3] = htonl(tempQ[3]);
		[outQuad setValue:tempQ];
	}
	else bzero([outQuad value], 16);
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • quadShiftR
// ---------------------------------------------------------------------------
- (Quad *)shiftR:(int)count {
	Quad *outQuad = [[Quad alloc] init];
	if (count < 128) {
		u_int32_t tempQ[4];
		[self getValue:tempQ];
		tempQ[0] = ntohl(tempQ[0]);
		tempQ[1] = ntohl(tempQ[1]);
		tempQ[2] = ntohl(tempQ[2]);
		tempQ[3] = ntohl(tempQ[3]);
		
		int wShift = count / 32;
		int bShift = count % 32;
		int i;
		// word shift
		if (wShift) {
			for (i=3; i>=0; i--) {
				if ((i-wShift) >= 0) tempQ[i] = tempQ[i-wShift];
				else tempQ[i] = 0;
			}
		}
		// bit shift
		if (bShift) {
			u_int32_t mask = 0xFFFFFFFF >> (32 - bShift);
			u_int32_t temp;
			for (i=3; i>=0; i--) {
				// get bits we're about to shift out
				temp = (tempQ[i] & mask) << (32 - bShift);
				// or back to previous word (if any)
				if (i < 3) tempQ[i+1] |= temp;
				// shift this word
				tempQ[i] >>= bShift;
			}
		}
		
		tempQ[0] = htonl(tempQ[0]);
		tempQ[1] = htonl(tempQ[1]);
		tempQ[2] = htonl(tempQ[2]);
		tempQ[3] = htonl(tempQ[3]);
		[outQuad setValue:tempQ];
	}
	else bzero([outQuad value], 16);
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • quadIncrement
// ---------------------------------------------------------------------------
- (Quad *)increment {
	Quad *outQuad = [[Quad alloc] init];
	u_int32_t tempQ[4];
	u_int32_t value;
	[self getValue:tempQ];

	value = ntohl(tempQ[3]);
	value += 1;
	tempQ[3] = htonl(value);
	if (value == 0) {
		value = ntohl(tempQ[2]);
		value += 1;
		tempQ[2] = htonl(value);
	}
	if (value == 0) {
		value = ntohl(tempQ[1]);
		value += 1;
		tempQ[1] = htonl(value);
	}
	if (value == 0) {
		value = ntohl(tempQ[0]);
		value += 1;
		tempQ[0] = htonl(value);
	}
	
	[outQuad setValue:tempQ]; 
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • quadDecrement
// ---------------------------------------------------------------------------
- (Quad *)decrement {
	Quad *outQuad = [[Quad alloc] init];
	u_int32_t value;
	u_int32_t tempQ[4];
	[self getValue:tempQ];

	value = ntohl(tempQ[3]);
	value -= 1;
	tempQ[3] = htonl(value);
	if (value == 0xFFFFFFFF) {
		value = ntohl(tempQ[2]);
		value -= 1;
		tempQ[2] = htonl(value);
	}
	if (value == 0xFFFFFFFF) {
		value = ntohl(tempQ[1]);
		value -= 1;
		tempQ[1] = htonl(value);
	}
	if (value == 0xFFFFFFFF) {
		value = ntohl(tempQ[0]);
		value -= 1;
		tempQ[0] = htonl(value);
	}
	
	[outQuad setValue:tempQ]; 
	return [outQuad autorelease];
}

// ---------------------------------------------------------------------------
//  • compareQuad
// ---------------------------------------------------------------------------
// -1 for receiver < inQuad; 0 for receiver = inQuad; +1 for receiver > inQuad
- (int)compareQuad:(Quad *)inQuad {
	u_int32_t tempQ[4];
	[inQuad getValue:tempQ];
	int i;
	for (i=0; i<4; i++) {
		if ( ntohl(mQuad[i]) < ntohl(tempQ[i]) ) return -1;
		if ( ntohl(mQuad[i]) > ntohl(tempQ[i]) ) return +1;
	}
	return 0;
}

// ---------------------------------------------------------------------------
//  • findRightBitStartingFrom
// ---------------------------------------------------------------------------
//	Find right most one bit in 128 bit data.
//	If found, return bit position from MSB (1) to LSB (128)
//	Returns zero if not found
- (int)findRightBitStartingFrom:(int)inStart {
	u_int32_t mask, index;
	int i;

	if (inStart < 1) return 0;
	if (inStart > 128) inStart = 128;
	int startW = (inStart-1) / 32;
	int startB = (inStart-1) % 32;
	
	for (i=startW; i>=0; i--) {
		if (mQuad[i]) {
			for (index=startB+1; index>=1; index--) {
				mask = (u_int32_t)0x01 << (32-index);
				if ( (mask & ntohl(mQuad[i])) != 0 ) return ((i * 32) + index);
			}
		}
	}
	return 0;
}

// ---------------------------------------------------------------------------
//  • findLeftBitStartingFrom
// ---------------------------------------------------------------------------
//	Find left most one bit in 128 bit data.
//	If found, return bit position from MSB (1) to LSB (128)
//	Returns zero if not found
- (int)findLeftBitStartingFrom:(int)inStart {
	u_int32_t mask, index;
	int i;

	if (inStart > 128) return 0;
	if (inStart < 1) inStart = 1;
	int startW = (inStart-1) / 32;
	int startB = (inStart-1) % 32;
	
	for (i=0; i<=startW; i++) {
		if (mQuad[i]) {
			for (index=1; index<=startB+1; index++) {
				mask = (u_int32_t)0x01 << (32-index);
				if ( (mask & ntohl(mQuad[i])) != 0 ) return ((i * 32) + index);
			}
		}
	}
	return 0;
}

@end

// ---------------------------------------------------------------------------
//  • 
// ---------------------------------------------------------------------------
