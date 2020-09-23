//
//  Quad.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on 5/14/08.
//  Copyright 2008 Sustainable Softworks, inc. All rights reserved.
//
//	Simple 128-bit arithmetic for manipulating IPv6 addresses
//	Treat Quad objects as immutable, all operations return a new instance
//	get/set in network byte order

#import <Cocoa/Cocoa.h>
#import "unp.h"


@interface Quad : NSObject {
	u_int32_t mQuad[4];
}
+ (Quad *)quadWithInt:(int)inValue;
+ (Quad *)quadWithMaskL:(int)count;
+ (Quad *)quadWithMaskR:(int)count;
+ (Quad *)quadWithIPv6:(in6_addr_t *)address6;
// get/set
- (u_int32_t *)value;
- (in6_addr_t *)value6;
- (void)setValue:(u_int32_t *)dp;
- (void)getValue:(u_int32_t *)dp;
// byte order neutral arithmetic
- (Quad *)andQuad:(Quad *)inQuad;
- (Quad *)andBitNotQuad:(Quad *)inQuad;
- (Quad *)orQuad:(Quad *)inQuad;
- (Quad *)xorQuad:(Quad *)inQuad;
- (BOOL)isZero;
// address arithmetic
- (Quad *)shiftL:(int)count;
- (Quad *)shiftR:(int)count;
- (Quad *)increment;
- (Quad *)decrement;
- (int)compareQuad:(Quad *)inQuad;
- (int)findRightBitStartingFrom:(int)inStart;
- (int)findLeftBitStartingFrom:(int)inStart;
@end
