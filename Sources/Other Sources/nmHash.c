// =================================================================================
//	nmHash.c					©2001 Sustainable Softworks All rights reserved.
// =================================================================================
//	Calculate 160-bit message digest per FIPS PUB 180-1
//  Secure Hash Standard
//
//  We use this as a first step toward impelementing FIPS PUB 180-2
//  Digital Signature Standard or other secure registration code
//
//  Updated 3/14/2006 to work with Big or Little Endian byte order
//
// Test Vectors
// "abc"
//   A9993E36 4706816A BA3E2571 7850C26C 9CD0D89D
// "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
//   84983E44 1C3BD26E BAAE4AA1 F95129E5 E54670F1
// A million repetitions of "a"
//   34AA973C D4C4DAA4 F61EEB2B DBAD2731 6534016F
//

#include "nmHash.h"
#include <string.h>
//#include <netinet/in.h>
//#include <stdio.h>
#include <sys/types.h>

// Basic SHA1 functions.
#define f0(B, C, D) (((B) & (C)) | ((~B) & (D)))
#define f1(B, C, D) ((B) ^ (C) ^ (D))
#define f2(B, C, D) (((B) & (C)) | ((B) & (D)) | ((C) & (D)))
#define f3(B, C, D) ((B) ^ (C) ^ (D))

// ROTATE_LEFT rotates x left n bits.
#define ROTATE_LEFT(x, n) (((x) << (n)) | ((x) >> (32-(n))))

static const unsigned long
 K0 = 0x5a827999, K1 = 0x6ed9eba1,  K2 = 0x8f1bbcdc, K3 = 0xca62c1d6 ;

static unsigned char PADDING[64] = {
  0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

// forward function declaration
void hashBlock(char *inBuf, unsigned long  hash[5]);

int
nmHash(char *inBuf, int len, int maxLen, unsigned long hash[5])
// Input: buffer containing message text
//   lenght of message text in bytes
//   max length of buffer in bytes, must be large enough to pad
//     message to an even multiple of 512 bits (64 bytes)
// Output:
//   hash resulting 160-bit SHA1 hash
// Return: 0=success -1=buffer to small -2=internal error
{
    unsigned long bitLength;
    unsigned long x;
    unsigned long padBits;
    unsigned long padBytes;
    unsigned long totalBytes;
    int i;
    
    // calculate how many bits we need to pad to mod 512 before appending a 64-bit length
    bitLength = len * 8;
    x = bitLength % 512;	// mod 512 
    if (x < 448) padBits = 448 - x;
    else padBits = (448+512) - x;
    padBytes = padBits/8;
    // check whether buffer is large enough
    if ((len + padBytes + 8) > maxLen) return -1;
    
    // pad message as needed
    memcpy(&inBuf[len], PADDING, padBytes);
    // append 64 bit length (assume less than 2^32 for this implementation)
    x = 0;
    memcpy(&inBuf[len+padBytes], &x, 4);
	if ((HTONL(bitLength)));	// treat inbBuf as Network Byte order
    memcpy(&inBuf[len+padBytes+4], &bitLength, 4);
    totalBytes = len + padBytes + 8;
    // check message was padded to a valid length mod 512 bits
    if ((totalBytes % 64) != 0) return -2;
    
    // initialize hash value and process each message block in sequence
    hash[0] = 0x67452301;
    hash[1] = 0xefcdab89;
    hash[2] = 0x98badcfe;
    hash[3] = 0x10325476;
    hash[4] = 0xc3d2e1f0;
    
    for (i=0; i<totalBytes; i+=64) {
        hashBlock(&inBuf[i], hash);
    }

	// convert result to network byte order
	if ((HTONL(hash[0])));	// OK
	if ((HTONL(hash[1])));
	if ((HTONL(hash[2])));
	if ((HTONL(hash[3])));
	if ((HTONL(hash[4])));
	if ((HTONL(hash[5])));
    
    return 0;
}

void
hashBlock(char* inBuf, unsigned long hash[5])
// hash next block of message
{
    unsigned long w[80];
    unsigned long a, b, c, d, e, temp;
    int t;
    unsigned long *m;
    
    // break message into 16 32-bit words and load into w
	m = (unsigned long *)inBuf;    
    for (t=0; t<=15; t++) {
        w[t] = ntohl(m[t]);		// convert to host byte order for processing
    }
    // initialize rest of w
    for (t=16; t<=79; t++) {
        w[t] = ROTATE_LEFT( (w[t-3] ^ w[t-8] ^ w[t-14] ^ w[t-16]) ,1);
    }
    // setup temps
    a = hash[0];
    b = hash[1];
    c = hash[2];
    d = hash[3];
    e = hash[4];
    // compute this block
    for (t=0; t<=19; t++) {
        temp = ROTATE_LEFT(a, 5) + f0(b,c,d) + e + w[t] + K0;
        e = d;
        d = c;
        c = ROTATE_LEFT(b, 30);
        b = a;
        a = temp;
        //printf("\nt=%d %0x %0x %0x %0x %0x",t,a,b,c,d,e);
    }
    for (t=20; t<=39; t++) {
        temp = ROTATE_LEFT(a, 5) + f1(b,c,d) + e + w[t] + K1;
        e = d;
        d = c;
        c = ROTATE_LEFT(b, 30);
        b = a;
        a = temp;    
    }
    for (t=40; t<=59; t++) {
        temp = ROTATE_LEFT(a, 5) + f2(b,c,d) + e + w[t] + K2;
        e = d;
        d = c;
        c = ROTATE_LEFT(b, 30);
        b = a;
        a = temp;
    }
    for (t=60; t<=79; t++) {
        temp = ROTATE_LEFT(a, 5) + f3(b,c,d) + e + w[t] + K3;
        e = d;
        d = c;
        c = ROTATE_LEFT(b, 30);
        b = a;
        a = temp;
    }
    // set result
    hash[0] += a;
    hash[1] += b;
    hash[2] += c;
    hash[3] += d;
    hash[4] += e;
}
