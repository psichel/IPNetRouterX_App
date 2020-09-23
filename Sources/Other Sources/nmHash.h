// =================================================================================
//	nmHash.c					©2001 Sustainable Softworks All rights reserved.
// =================================================================================
//	Calculate 160-bit message digest per FIPS PUB 180-1
//  Secure Hash Standard (sha1)
//
int
nmHash(char* inBuf, int len, int maxLen, unsigned long hash[5]);
// Input: buffer containing message text
//   lenght of message text in bytes
//   max length of buffer in bytes, must be large enough to pad
//     message to an even multiple of 512 bits
// Output:
//   hash resulting 160-bit SHA1 hash
// Return:	0=success
//			-1=buffer to small
//			-2=internal error
