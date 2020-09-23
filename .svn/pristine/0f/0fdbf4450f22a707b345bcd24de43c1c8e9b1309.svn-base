//
// kftSupport.c
// IPNetSentryX
//
// Created by Peter Sichel on Mon Nov 25 2002.
// Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Filter Table support functions
//

#include "kftSupport.h"
#include "IPTypes.h"
#include "myTypes.h"
#include <netinet/in.h>
#include <sys/time.h>

#pragma mark -- text support --
int isDigit(char c)
{
	if (('0' <= c) && (c <= '9')) return 1;
	else return 0;
}

int isHexDigit(char c)
{
	int returnValue = 0;
	if (('0' <= c) && (c <= '9')) returnValue = 1;
	else if (('A' <= c) && (c <= 'F')) returnValue = 1;
	else if (('a' <= c) && (c <= 'f')) returnValue = 1;
	return returnValue;
}

int isAlpha(char c)
{
	if (('a' <= c) && (c <= 'z')) return 1;
	if (('A' <= c) && (c <= 'Z')) return 1;
	else return 0;
}

// ---------------------------------------------------------------------------
//	¥ findByte
// ---------------------------------------------------------------------------
//	Find Byte in data buffer starting from inBuf->offset
//	Output: offset of byte or -1 if not found (offset not updated)
int findByte(PSData* inBuf, u_int8_t inByte)
{
	int			pos;		// position in data block
	int			inLast;
	u_int8_t	hold;		// hold last byte
	u_int8_t*	p1;
	
	inLast = inBuf->length-1;
	pos = -1;
	if (inBuf->offset <= inLast) {		
		// replace end of data with byte we're looking for
		// to insure we will find it.
		hold = inBuf->bytes[inLast];
		inBuf->bytes[inLast] = inByte;
		
		// scan for byte
		p1 = &inBuf->bytes[inBuf->offset];
		while (*p1++ != inByte);	// this is OK
		p1--;	// point to matching byte	
		
		// restore last byte
		inBuf->bytes[inLast] = hold;
		
		// recheck matching byte
		if (*p1 == inByte) pos = p1 - inBuf->bytes;
	}
	
	// return result
	if (pos >= 0) inBuf->offset = pos;
	return pos;
}

// ---------------------------------------------------------------------------
//	¥ findByteIgnoreCase
// ---------------------------------------------------------------------------
//	Find Byte in data buffer starting from inBuf->offset
//  Stop at delimiter if > 0
//	Output: offset of byte or -1 if not found (offset not updated)
int findByteIgnoreCase(PSData* inBuf, u_int8_t inByte, int16_t delimiter)
{
	int			pos;		// position in data block
	int			inLast;
	u_int8_t	hold;		// hold last byte
	u_int8_t	byte, c1;
	u_int8_t*	p1;
	
	inLast = inBuf->length-1;
	pos = -1;
	if (inBuf->offset <= inLast) {		
		// replace end of data with byte we're looking for
		// to insure we will find it.
		hold = inBuf->bytes[inLast];
		inBuf->bytes[inLast] = inByte;
		
		// scan for byte
		byte = (inByte|0x20);
		p1 = &inBuf->bytes[inBuf->offset];
		if (delimiter >= 0) {
			while ((c1 = (*p1++|0x20)) != byte) if (c1 == delimiter) break;
		}
		else while ((*p1++|0x20) != byte);	// this is OK
		p1--;	// point to matching byte	
		
		// restore last byte
		inBuf->bytes[inLast] = hold;
		
		// recheck matching byte
		if ((*p1|0x20) == byte) pos = p1 - inBuf->bytes;
	}
	
	// return result
	if (pos >= 0) inBuf->offset = pos;
	return pos;
}

// ---------------------------------------------------------------------------
//	¥ findByteInRange
// ---------------------------------------------------------------------------
// update range to start at desired byte if found, return offset or -1 if not found
int findByteInRange(PSData* inBuf, PSRange* range, u_int8_t inByte)
{
	int returnValue = -1;
	int holdOffset;
	int holdDataLength;
	// save offset and length
	holdOffset = inBuf->offset;
	holdDataLength = inBuf->length;
	// set from range
	inBuf->offset = range->location;
	inBuf->length = range->location + range->length;
	// look for byte
	if (returnValue = findByte(inBuf, inByte) > 0) {
		// update range
		range->length -= inBuf->offset - range->location;
		range->location = inBuf->offset;
	}
	// restore offset and length
	inBuf->offset = holdOffset;
	inBuf->length = holdDataLength;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ skipWhiteSpace()
// ---------------------------------------------------------------------------------
//	return offset of first non-white space character starting from offset
// -1 = end of buffer
int skipWhiteSpace(PSData* inBuf)
{
	int pos = inBuf->offset;
	do {
		if (inBuf->bytes[pos] == ' ') continue;
		if (inBuf->bytes[pos] == '\t') continue;
		if (inBuf->bytes[pos] == '\r') continue;
		if (inBuf->bytes[pos] == '\n') continue;
		break;
	} while (pos++ < inBuf->length);
	inBuf->offset = pos;
	if (pos == inBuf->length) pos = -1;
	return pos;
}

// ---------------------------------------------------------------------------------
//	¥ decodeContent()
// ---------------------------------------------------------------------------------
// recognize escaped characters in search content
void decodeContent(KFT_contentSpec_t* content)
{
	int i, j;
	u_int8_t c;
	j = 0;
	for (i=0; i<content->length; i++) {
		c = content->dataPtr[i];
		if (c == '\\') {
			i++;
			if (content->dataPtr[i] == '\\') i++;
			c = content->dataPtr[i];
			if (c == 'n') content->dataPtr[j++] = 0x0A;
			else if (c == 'r') content->dataPtr[j++] = 0x0D;
			else if (c == 't') content->dataPtr[j++] = 0x09;
			else if (c == '0') content->dataPtr[j++] = 0x00;
			else if (c == 'f') content->dataPtr[j++] = 0x0C;
			else if (c == 'b') content->dataPtr[j++] = 0x08;
			else content->dataPtr[j++] = c;			
		}
		else content->dataPtr[j++] = c;
	}
	content->length = j;
}

// ---------------------------------------------------------------------------------
//	¥ encodeContent()
// ---------------------------------------------------------------------------------
// escape special characters in search content
int encodeContent(PSData* inBuf, KFT_contentSpec_t* content)
{
	int returnValue = 0;
	int i;
	u_int8_t c;
	for (i=0; i<content->length; i++) {
		if (inBuf->offset+2 > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		c = content->dataPtr[i];
		if (c == 0x0A) {
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = 'n';
		}
		else if (c == 0x0D) {
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = 'r';
		}
		else if (c == 0x09) {
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = 't';
		}
		else if (c == 0x00) {
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = '0';
		}
		else if (c == 0x0C) {
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = 'f';
		}
		else if (c == 0x08) {
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = '\\';
			inBuf->bytes[inBuf->offset++] = 'b';
		}
		else inBuf->bytes[inBuf->offset++] = c;
	}
	if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ findEndOfToken()
// ---------------------------------------------------------------------------------
//	return offset of first white space character starting from offset
// -1 = end of buffer
int findEndOfToken(PSData* inBuf)
{
	int pos = inBuf->offset;
	while (pos < inBuf->length) {
		if (inBuf->bytes[pos] == ' ') break;
		if (inBuf->bytes[pos] == '\t') break;
		if (inBuf->bytes[pos] == '\r') break;
		if (inBuf->bytes[pos] == '\n') break;
		
		if (inBuf->bytes[pos] == ';') break;
		if (inBuf->bytes[pos] == ',') break;
		if (inBuf->bytes[pos] == '=') break;
		if (inBuf->bytes[pos] == ')') break;
		if (inBuf->bytes[pos] == '}') break;
		pos += 1;
	}
	inBuf->offset = pos;
	if (pos == inBuf->length) pos = -1;
	return pos;
}

// ---------------------------------------------------------------------------------
//	¥ nextToken()
// ---------------------------------------------------------------------------------
// Output: range.length = 0 indicates not found
// range points to token
// returns offset to one past token
int nextToken(PSData* inBuf, PSRange* range)
{
	int start, end;
	int returnValue = -1;
	range->length = 0;
	do {
		// find start
		start = skipWhiteSpace(inBuf);
		if (start < 0) break;
		// if " look for end of quoted value
		if (inBuf->bytes[start] == '"') {
			start += 1;
			inBuf->offset = start;
			end = findByte(inBuf, '"');
			if (end < 0) break;
			inBuf->offset = end + 1;	// skip terminating "
		}
		else {
			inBuf->offset = start + 1;
			end = findEndOfToken(inBuf);
			if (end < 0) break;
		}
		// set return value
		range->location = start;
		range->length = end - start;
		returnValue = inBuf->offset;
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ intParamValue()
// ---------------------------------------------------------------------------------
// extract int parameter value, offset points to one past keyword in "key = value"
// return int value and update offset to end of parameter
int intParamValue(PSData* inBuf)
{
	PSRange range;
	int returnValue = 0;
	
	do {
		// skip =
		nextToken(inBuf, &range);
		if (inBuf->bytes[range.location] != '=') break;
		// get integer value
		nextToken(inBuf, &range);
		returnValue = intValue(inBuf, &range);
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ int64ParamValue()
// ---------------------------------------------------------------------------------
// extract int parameter value, offset points to one past keyword in "key = value"
// return int value and update offset to end of parameter
int64_t int64ParamValue(PSData* inBuf)
{
	PSRange range;
	int64_t returnValue = 0;
	
	do {
		// skip =
		nextToken(inBuf, &range);
		if (inBuf->bytes[range.location] != '=') break;
		// get integer value
		nextToken(inBuf, &range);
		returnValue = int64Value(inBuf, &range);
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ intValue()
// ---------------------------------------------------------------------------------
int intValue(PSData* inBuf, PSRange* range)
// Convert token specified by range to an integer value
// Convert up to first non-digit character and update range accordingly
{
	int returnValue = 0;
	u_int8_t outLen;
	returnValue = string2Num(&inBuf->bytes[range->location], range->length, &outLen);
	range->location += outLen;
	range->length -= outLen;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ intValueWithFraction()
// ---------------------------------------------------------------------------------
int intValueWithFraction(PSData* inBuf, PSRange* range)
// Convert token specified by range to an integer value
// Convert up to first non-digit character and update range accordingly
{
	int returnValue = 0;
	int fraction = 0;
	u_int8_t outLen;
	returnValue = string2Num(&inBuf->bytes[range->location], range->length, &outLen);
	range->location += outLen;
	range->length -= outLen;
	// interpret decimal point
	if (inBuf->bytes[range->location] == '.') {
		range->location += 1;
		range->length -= 1;
		if ( isDigit(inBuf->bytes[range->location]) ) {
			fraction = inBuf->bytes[range->location] - '0';
			range->location += 1;
			range->length -= 1;
		}
		fraction = fraction * 100;
	}
	// interpret K or M
	if (inBuf->bytes[range->location] == 'K') {
		range->location += 1;
		range->length -= 1;
		returnValue *= 1000;
		returnValue += fraction;
	}
	else if (inBuf->bytes[range->location] == 'M') {
		range->location += 1;
		range->length -= 1;
		returnValue *= 1000000;
		returnValue += fraction * 1000;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ int64Value()
// ---------------------------------------------------------------------------------
int64_t int64Value(PSData* inBuf, PSRange* range)
// Convert token specified by range to a 64-bit (longlong) integer value
// Convert up to first non-digit character and update range accordingly
{
	int64_t returnValue = 0;
	u_int8_t outLen;
	returnValue = string2Num64(&inBuf->bytes[range->location], range->length, &outLen);
	range->location += outLen;
	range->length -= outLen;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ intHexValue()
// ---------------------------------------------------------------------------------
int intHexValue(PSData* inBuf, PSRange* range)
// Convert token specified by range to an integer value
// Convert up to first non-hexdigit character and update range accordingly
{
	int returnValue = 0;
	u_int8_t outLen;
	returnValue = string2HexNum(&inBuf->bytes[range->location], range->length, &outLen);
	range->location += outLen;
	range->length -= outLen;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ string2Num()
// ---------------------------------------------------------------------------------
// assumes str points to a series of 0 or more digits delimited by a non-digit character
// returns the decimal value and how many consequetive digits were found upto max.
int string2Num(u_int8_t* str, u_int8_t inMax, u_int8_t* outLen)
{
	int returnValue = 0;
	int i;
	char c;
	for (i=0; i<inMax; i++) {
		c = str[i];
		if ( !isDigit(c) ) break;
		returnValue *= 10;
		returnValue += c - '0';
	}
	if (outLen) *outLen = i;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ string2Num64()
// ---------------------------------------------------------------------------------
// assumes str points to a series of 0 or more digits delimited by a non-digit character
// returns the decimal value and how many consequetive digits were found upto max.
int64_t string2Num64(u_int8_t* str, u_int8_t inMax, u_int8_t* outLen)
{
	int64_t returnValue = 0;
	int i;
	char c;
	for (i=0; i<inMax; i++) {
		c = str[i];
		if ( !isDigit(c) ) break;
		returnValue *= 10;
		returnValue += c - '0';
	}
	if (outLen) *outLen = i;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ string2HexNum()
// ---------------------------------------------------------------------------------
// assumes str points to a series of 0 or more digits delimited by a non-digit character
// returns the decimal value and how many consequetive digits were found upto max.
int string2HexNum(u_int8_t* str, u_int8_t inMax, u_int8_t* outLen)
{
	int returnValue = 0;
	int i;
	char c;
	for (i=0; i<inMax; i++) {
		c = str[i];
		if ( !isHexDigit(c) ) break;
		returnValue *= 16;
		if (c <= '9') returnValue += c - '0';
		else if (c <= 'F') returnValue += c - 'A' + 10;
		else returnValue += c - 'a' + 10;
	}
	if (outLen) *outLen = i;
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ skipByte()
// ---------------------------------------------------------------------------------
int skipByte(PSData* inBuf, PSRange* range, u_int8_t inByte)
// if byte matches first character in range, advance range and return true
{
	int returnValue = 0;
	if (range->location < inBuf->length) {
		if (inBuf->bytes[range->location] == inByte) {
			range->location += 1;
			range->length -= 1;
			returnValue = 1;
		}
	}
	return returnValue;
} 

// ---------------------------------------------------------------------------------
//	¥ findInSegment()
// ---------------------------------------------------------------------------------
// look for string in data segment
// Output: 0=found, inBuf->offset points to start of match
//  -1 not found, inBuf->offset not updated
//   n partial match of n characters, inBuf->offset point to start of match
int findInSegment(PSData* inBuf, u_int8_t* string, int16_t length, int16_t delimiter, u_int8_t ignoreCase)
{
	int returnValue = -1;
	int pos;
	int hold;
	int compareL;
	u_int8_t byte;
	int result;
	
	do {
		// check for data
		if (inBuf->offset >= inBuf->length) break;
		if (!string) break;
		if (length == 0) break;
		// look for possible start of string
		hold = inBuf->offset;
		byte = string[0];
		compareL = length;
		if (ignoreCase) pos = findByteIgnoreCase(inBuf, byte, delimiter);
		else pos = findByte(inBuf, byte);
		while (pos >= 0) {
			if ((pos + length) > inBuf->length) compareL = inBuf->length - pos;
			// try to match the rest
			if (ignoreCase) result = compareIgnoreCase(&inBuf->bytes[pos], string, compareL);
			else result = memcmp(&inBuf->bytes[pos], string, compareL);
			if (result == 0) {
				inBuf->offset = pos;
				if (compareL != length) returnValue = compareL;
				else returnValue = 0;
				break;
			}
			inBuf->offset = pos + 1;
			if (ignoreCase) pos = findByteIgnoreCase(inBuf, byte, delimiter);
			else pos = findByte(inBuf, byte);
		}
		if (returnValue == -1) inBuf->offset = hold;
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ compareIgnoreCase()
// ---------------------------------------------------------------------------------
// Compare sequence of bytes ignoring case.
// Assumes US ASCII.
int compareIgnoreCase(u_int8_t* str1, u_int8_t* str2, int length)
{
	u_int8_t* p1 = str1;
	u_int8_t* p2 = str2;
	u_int8_t hold;
	int inLast;
	// remember last byte of str1 and set it to terminate loop
	inLast = length-1;
	hold = str1[inLast];
	str1[inLast] = str2[inLast] + 1;	
	// loop to compare
	while ((*p1++|0x20) == (*p2++|0x20)) ;	// this is OK
	// restore last byte
	str1[inLast] = hold;
	// check last byte or return value
	return ( (*--p1|0x20) - (*--p2|0x20) );
}

// ---------------------------------------------------------------------------------
//	¥ tcpHeaderFlagValue()
// ---------------------------------------------------------------------------------
// convert header flag (ack,fin,psh,rst,syn,urg) to corresponding mask bits (0 for none)
// update range accordingly
int tcpHeaderFlagValue(PSData* inBuf, PSRange* range)
{
	int returnValue = 0;
	if (range->length >= 3) {
		if (memcmp("fin", &inBuf->bytes[range->location], 3) == 0) returnValue = kCodeFIN;
		else if (memcmp("syn", &inBuf->bytes[range->location], 3) == 0) returnValue = kCodeSYN;
		else if (memcmp("rst", &inBuf->bytes[range->location], 3) == 0) returnValue = kCodeRST;
		else if (memcmp("psh", &inBuf->bytes[range->location], 3) == 0) returnValue = kCodePSH;
		else if (memcmp("ack", &inBuf->bytes[range->location], 3) == 0) returnValue = kCodeACK;
		else if (memcmp("urg", &inBuf->bytes[range->location], 3) == 0) returnValue = kCodeURG;
		if (returnValue != 0) {
			range->location += 3;
			range->length -= 3;
		}
	}
	return returnValue;
}

#pragma mark -- text output --
// ---------------------------------------------------------------------------------
//	¥ appendCString()
// ---------------------------------------------------------------------------------
// append C string at current position in buffer
// advance offset and dataLength if needed
// Output: -1 on error (end of buffer, string too long,...)
int appendCString(PSData* inBuf, char* string)
{
	int returnValue = 0;
	int len;
	do {
		// get length
		len = strlen(string);
		// check if there is enough room in buffer
		if ((inBuf->offset + len) > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		// move bytes
		memcpy(&inBuf->bytes[inBuf->offset], string, len);
		// update pointers
		inBuf->offset += len;
		if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	}
	while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ appendPString()
// ---------------------------------------------------------------------------------
// append P string at curent position in buffer and advance position
// Output: -1 on error
int appendPString(PSData* inBuf, unsigned char* string)
{
	int returnValue = 0;
	int len;
	do {
		// get length
		len = string[0];
		// check if there is enough room in buffer
		if ((inBuf->offset + len) > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		// move bytes
		memcpy(&inBuf->bytes[inBuf->offset], &string[1], len);
		// update pointers
		inBuf->offset += len;
		if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	}
	while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ appendBytes()
// ---------------------------------------------------------------------------------
// append bytes at curent position in buffer and advance position
// skip non-printing characters
// Output: -1 on error
int appendBytes(PSData* inBuf, unsigned char* string, int howMany)
{
	int returnValue = 0;
	int extra = 0;
	int i;
	int c;
	do {
		// check if there is enough room in buffer
		if ((inBuf->offset + howMany) > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		// move bytes		
		for (i=0; i<howMany; i++) {
			c = string[i];
			if (c == '"') {
				inBuf->bytes[inBuf->offset++] = 0x5C;	// "\"
				extra += 1;
				if ((inBuf->offset + howMany + extra) > inBuf->bufferLength) {
					returnValue = -1;
					break;
				}
			}
			// skip non-printing characters
			if ((c < 0x20) || (c >= 0x7F)) continue;
			inBuf->bytes[inBuf->offset++] = c;
		}
		
		if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	}
	while (false);
	return returnValue;
}


#define maxDigits 32
// ---------------------------------------------------------------------------------
//	¥ appendInt()
// ---------------------------------------------------------------------------------
// append integer value at curent position in buffer and advance position
// Output: -1 on error
int appendInt(PSData* inBuf, int32_t value)
{
	int returnValue = 0;
	char str[maxDigits];
	int digit;
	int len;
	int negative = 0;
	
	do {
		if (value < 0) {
			value = -value;
			negative = 1;
		}
		// convert digits from right to left
		for (len=1; len<=maxDigits; len++) {
			digit = value % 10;
			value = value / 10;
			str[maxDigits-len] = '0' + digit;
			if (value == 0) break;
		}
		if (negative) {
			len++;
			str[maxDigits-len] = '-';
		}
		// check if there is enough room in buffer
		if ((inBuf->offset + len) > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		// append to buffer
		memcpy(&inBuf->bytes[inBuf->offset], &str[maxDigits-len], len);
		// update pointers
		inBuf->offset += len;
		if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ appendInt64()
// ---------------------------------------------------------------------------------
// append integer value at curent position in buffer and advance position
// Output: -1 on error
int appendInt64(PSData* inBuf, int64_t value)
{
	int returnValue = 0;
	char str[maxDigits];
	int digit;
	int len;
	int negative = 0;
	
	do {
		if (value < 0) {
			value = -value;
			negative = 1;
		}
		// convert digits from right to left
		for (len=1; len<=maxDigits; len++) {
			digit = value % 10;
			value = value / 10;
			str[maxDigits-len] = '0' + digit;
			if (value == 0) break;
		}
		if (negative) {
			len++;
			str[maxDigits-len] = '-';
		}
		// check if there is enough room in buffer
		if ((inBuf->offset + len) > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		// append to buffer
		memcpy(&inBuf->bytes[inBuf->offset], &str[maxDigits-len], len);
		// update pointers
		inBuf->offset += len;
		if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	} while (false);
	return returnValue;
}
// ---------------------------------------------------------------------------------
//	¥ appendHexInt()
// ---------------------------------------------------------------------------------
// append integer value at curent position in buffer and advance position
// Output: -1 on error
int appendHexInt(PSData* inBuf, u_int32_t value, int howMany, int options)
{
	int returnValue = 0;
	char str[maxDigits];
	int digit;
	int i;
	int len = 0;
	
	do {
		// convert digits from right to left
		for (i=0; i<howMany; i++) {
			digit = value % 16;
			value = value / 16;
			// skip leading zeros if requested
			if (!(options & kOptionExpand) && (digit == 0) && (value == 0) && (len > 0)) continue;
			if (digit < 10) {
				len++;
				str[maxDigits-len] = '0' + digit;
			}
			else {
				len++;
				if (kOptionUpper & options) str[maxDigits-len] = 'A' + digit - 10;
				else str[maxDigits-len] = 'a' + digit - 10;
			}
		}
		// check if there is enough room in buffer
		if ((inBuf->offset + len) > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		// append to buffer
		memcpy(&inBuf->bytes[inBuf->offset], &str[maxDigits-len], len);
		// update pointers
		inBuf->offset += len;
		if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	} while (false);
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ appendIP()
// ---------------------------------------------------------------------------------
// append 32-bit value (host B.O.) as dotted quad IP address
// Output: -1 on error
int appendIP(PSData* inBuf, u_int32_t value)
{
	int returnValue = 0;
	int segment;
		// output dotted quad
	segment = (value >> 24) & 0xFF;
	appendInt(inBuf, segment);
	appendCString(inBuf, ".");
	
	segment = (value >> 16) & 0xFF;
	appendInt(inBuf, segment);
	appendCString(inBuf, ".");
	
	segment = (value >> 8) & 0xFF;
	appendInt(inBuf, segment);
	appendCString(inBuf, ".");
	
	segment = value & 0xFF;
	returnValue = appendInt(inBuf, segment);
		// return result of last append in case buffer was full
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ appendTabs()
// ---------------------------------------------------------------------------------
// append count tabs at curent position in buffer and advance position
// Output: -1 on error
int appendTabs(PSData* inBuf, int count)
{
	int returnValue = 0;
	int i;
	do {
		// check if there is enough room in buffer
		if ((inBuf->offset + count) > inBuf->bufferLength) {
			returnValue = -1;
			break;
		}
		// append tabs
		for (i=0; i<count; i++) inBuf->bytes[inBuf->offset++] = '\t';
		// adjust data length
		if (inBuf->length < inBuf->offset) inBuf->length = inBuf->offset;
	} while (false);
	return returnValue;
}


// ---------------------------------------------------------------------------
//		¥ findRightBit
// ---------------------------------------------------------------------------
//	Find right most one bit in 32 bit data.
//	If found, return bit position from MSB (1) to LSB (32)
//	Returns zero if not found
u_int8_t findRightBit(u_int32_t inData, u_int8_t inStart)
{
	u_int32_t	mask, index;

	for (index=inStart; index>=1; index--) {
		mask = (u_int32_t)0x01 << (32-index);
		if ( (mask&inData) != 0 ) {
			return index;
		}
	}
	return 0;
}


// ---------------------------------------------------------------------------------
//	¥ tcpHeaderFlagString()
// ---------------------------------------------------------------------------------
// convert mask  to correspondingheader flag (ack,fin,psh,rst,syn,urg)
int tcpHeaderFlagString(PSData* inBuf, int maskOn, int maskOff)
{
	int returnValue = 0;
	if ((inBuf->offset + 24) < inBuf->bufferLength) {
		if (maskOn & kCodeFIN)  appendCString(inBuf, "fin,");
		if (maskOn & kCodeSYN)  appendCString(inBuf, "syn,");
		if (maskOn & kCodeRST)  appendCString(inBuf, "rst,");
		if (maskOn & kCodePSH)  appendCString(inBuf, "psh,");
		if (maskOn & kCodeACK)  appendCString(inBuf, "ack,");
		if (maskOn & kCodeURG)  appendCString(inBuf, "urg,");
	}
	if ((inBuf->offset + 30) < inBuf->bufferLength) {
		if (maskOff & kCodeFIN)  appendCString(inBuf, "-fin,");
		if (maskOff & kCodeSYN)  appendCString(inBuf, "-syn,");
		if (maskOff & kCodeRST)  appendCString(inBuf, "-rst,");
		if (maskOff & kCodePSH)  appendCString(inBuf, "-psh,");
		if (maskOff & kCodeACK)  appendCString(inBuf, "-ack,");
		if (maskOff & kCodeURG)  appendCString(inBuf, "-urg,");
	}
	if (maskOn || maskOff) inBuf->offset -= 1;	// remove final comma
	else returnValue = -1;
	return returnValue;
}

#pragma mark -- byte swapping --

// ---------------------------------------------------------------------------
//	¥ KFT_ntohPacket
// ---------------------------------------------------------------------------
// Convert packet headers from network to host byte order
void KFT_ntohPacket(KFT_packetData_t* packet, u_int8_t option)
{
	if (packet->swap == kNetworkByteOrder) {
		mbuf_t mbuf_ref = *packet->mbuf_ptr;
		if (mbuf_ref) {
			u_int8_t* datagram = (u_int8_t*)mbuf_data(mbuf_ref);
			datagram = &datagram[packet->ipOffset];
			KFT_ntohDgram(datagram, option);
			packet->swap = kHostByteOrder;
		}
	}
}

void KFT_ntohDgram(u_int8_t* datagram, u_int8_t option)
{
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	udp_header_t* udpHeader;
	icmp_header_t* icmpHeader;
	u_int16_t fragmentOffset;
	u_int8_t ipHeaderLen;
	// setup header access
	ipHeader = (ip_header_t*)datagram;
	ipHeaderLen = (ipHeader->hlen & 0x0F) << 2;	// in bytes

	// ip
	if (!(option & kOptionFinalize)) ipHeader->totalLength = ntohs(ipHeader->totalLength);
	ipHeader->identification = ntohs(ipHeader->identification);
	ipHeader->fragmentOffset = ntohs(ipHeader->fragmentOffset);
	ipHeader->checksum = ntohs(ipHeader->checksum);
	ipHeader->srcAddress = ntohl(ipHeader->srcAddress);
	ipHeader->dstAddress = ntohl(ipHeader->dstAddress);
	fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;
	// ip options are not converted
	
	if (fragmentOffset == 0) switch(ipHeader->protocol) {
		case IPPROTO_TCP:
			tcpHeader = (tcp_header_t*)&datagram[ipHeaderLen];
			tcpHeader->srcPort = ntohs(tcpHeader->srcPort);
			tcpHeader->dstPort = ntohs(tcpHeader->dstPort);
			tcpHeader->seqNumber = ntohl(tcpHeader->seqNumber);
			tcpHeader->ackNumber = ntohl(tcpHeader->ackNumber);
			tcpHeader->windowSize = ntohs(tcpHeader->windowSize);
			tcpHeader->checksum = ntohs(tcpHeader->checksum);
			tcpHeader->urgentPointer = ntohs(tcpHeader->urgentPointer);
			// tcp options are not converted
			break;
		case IPPROTO_UDP:
			udpHeader = (udp_header_t*)&datagram[ipHeaderLen];
			udpHeader->srcPort = ntohs(udpHeader->srcPort);
			udpHeader->dstPort = ntohs(udpHeader->dstPort);
			udpHeader->messageLength = ntohs(udpHeader->messageLength);
			udpHeader->checksum = ntohs(udpHeader->checksum);
			break;
		case IPPROTO_ICMP:
			icmpHeader = (icmp_header_t*)&datagram[ipHeaderLen];
			icmpHeader->checksum = ntohs(icmpHeader->checksum);
			icmpHeader->identifier = ntohs(icmpHeader->identifier);
			icmpHeader->seqNumber = ntohs(icmpHeader->seqNumber);
			// look for triggering datagram
			switch (icmpHeader->type) {
				case kIcmpTypeDestUnreachable:
				case kIcmpTypeSourceQuench:
				case kIcmpTypeRedirect:
				case kIcmpTypeTimeExceeded:
				case kIcmpTypeParameterProblem:
				{
					ip_header_t* ipHeader2;
					udp_header_t* udpHeader2;
					u_int8_t ipHeaderLen2;
					u_int8_t* dp;
					ipHeader2 = (ip_header_t*)&icmpHeader->data[0];
					ipHeaderLen2 = (ipHeader2->hlen & 0x0F) << 2;	// in bytes
					dp = (UInt8*)ipHeader2;
					udpHeader2 = (udp_header_t*)&dp[ipHeaderLen2];
					// ip
					ipHeader2->totalLength = htons(ipHeader2->totalLength);
					ipHeader2->identification = htons(ipHeader2->identification);
					ipHeader2->fragmentOffset = htons(ipHeader2->fragmentOffset);
					ipHeader2->checksum = htons(ipHeader2->checksum);
					ipHeader2->srcAddress = htonl(ipHeader2->srcAddress);
					ipHeader2->dstAddress = htonl(ipHeader2->dstAddress);
					switch(ipHeader2->protocol) {
						case IPPROTO_TCP:
							udpHeader2->srcPort = htons(udpHeader2->srcPort);
							udpHeader2->dstPort = htons(udpHeader2->dstPort);
							// trigger contains IP header + 64-bits (8-bytes), so we stop here
							break;
						case IPPROTO_UDP:
							udpHeader2->srcPort = htons(udpHeader2->srcPort);
							udpHeader2->dstPort = htons(udpHeader2->dstPort);
							udpHeader2->messageLength = htons(udpHeader2->messageLength);
							udpHeader2->checksum =htons(udpHeader2->checksum);
							break;
					}
				}
			}
			break;
	}
}

// ---------------------------------------------------------------------------
//	¥ KFT_htonPacket
// ---------------------------------------------------------------------------
// Convert packet headers from host to network byte order
// Input: KFT_packetData_t* with mbuf_ptr and ipOffset
void KFT_htonPacket(KFT_packetData_t* packet, u_int8_t option)
{
	if (packet->swap == kHostByteOrder) {
		mbuf_t mbuf_ref = *packet->mbuf_ptr;
		if (mbuf_ref) {
			u_int8_t* datagram = (u_int8_t*)mbuf_data(mbuf_ref);
			datagram = &datagram[packet->ipOffset];
			KFT_htonDgram(datagram, option);
			packet->swap = kNetworkByteOrder;
		}
	}
}

void KFT_htonDgram(u_int8_t* datagram, u_int8_t option)
{
	ip_header_t* ipHeader;
	tcp_header_t* tcpHeader;
	udp_header_t* udpHeader;
	icmp_header_t* icmpHeader;
	u_int16_t fragmentOffset;
	u_int8_t ipHeaderLen;
	// setup header access
	ipHeader = (ip_header_t*)datagram;
	ipHeaderLen = (ipHeader->hlen & 0x0F) << 2;	// in bytes

	// ip
	fragmentOffset = ipHeader->fragmentOffset & 0x1FFF;
	if (!(option & kOptionFinalize)) ipHeader->totalLength = htons(ipHeader->totalLength);
	ipHeader->identification = htons(ipHeader->identification);
	ipHeader->fragmentOffset = htons(ipHeader->fragmentOffset);
	ipHeader->checksum = htons(ipHeader->checksum);
	ipHeader->srcAddress = htonl(ipHeader->srcAddress);
	ipHeader->dstAddress = htonl(ipHeader->dstAddress);
	// ip options are not converted
	
	if (fragmentOffset == 0) switch(ipHeader->protocol) {
		case IPPROTO_TCP:
			tcpHeader = (tcp_header_t*)&datagram[ipHeaderLen];
			tcpHeader->srcPort = htons(tcpHeader->srcPort);
			tcpHeader->dstPort = htons(tcpHeader->dstPort);
			tcpHeader->seqNumber = htonl(tcpHeader->seqNumber);
			tcpHeader->ackNumber = htonl(tcpHeader->ackNumber);
			tcpHeader->windowSize = htons(tcpHeader->windowSize);
			tcpHeader->checksum = htons(tcpHeader->checksum);
			tcpHeader->urgentPointer = htons(tcpHeader->urgentPointer);
			// tcp options are not converted
			break;
		case IPPROTO_UDP:
			udpHeader = (udp_header_t*)&datagram[ipHeaderLen];
			udpHeader->srcPort = htons(udpHeader->srcPort);
			udpHeader->dstPort = htons(udpHeader->dstPort);
			udpHeader->messageLength = htons(udpHeader->messageLength);
			udpHeader->checksum = htons(udpHeader->checksum);
			break;
		case IPPROTO_ICMP:
			icmpHeader = (icmp_header_t*)&datagram[ipHeaderLen];
			icmpHeader->checksum = htons(icmpHeader->checksum);
			icmpHeader->identifier = htons(icmpHeader->identifier);
			icmpHeader->seqNumber = htons(icmpHeader->seqNumber);
			// look for triggering datagram
			switch (icmpHeader->type) {
				case kIcmpTypeDestUnreachable:
				case kIcmpTypeSourceQuench:
				case kIcmpTypeRedirect:
				case kIcmpTypeTimeExceeded:
				case kIcmpTypeParameterProblem:
				{
					ip_header_t* ipHeader2;
					udp_header_t* udpHeader2;
					u_int8_t ipHeaderLen2;
					u_int8_t* dp;
					ipHeader2 = (ip_header_t*)&icmpHeader->data[0];
					ipHeaderLen2 = (ipHeader2->hlen & 0x0F) << 2;	// in bytes
					dp = (UInt8*)ipHeader2;
					udpHeader2 = (udp_header_t*)&dp[ipHeaderLen2];
					// ip
					ipHeader2->totalLength = htons(ipHeader2->totalLength);
					ipHeader2->identification = htons(ipHeader2->identification);
					ipHeader2->fragmentOffset = htons(ipHeader2->fragmentOffset);
					ipHeader2->checksum = htons(ipHeader2->checksum);
					ipHeader2->srcAddress = htonl(ipHeader2->srcAddress);
					ipHeader2->dstAddress = htonl(ipHeader2->dstAddress);
					switch(ipHeader2->protocol) {
						case IPPROTO_TCP:
							udpHeader2->srcPort = htons(udpHeader2->srcPort);
							udpHeader2->dstPort = htons(udpHeader2->dstPort);
							// trigger contains IP header + 64-bits (8-bytes), so we stop here
							break;
						case IPPROTO_UDP:
							udpHeader2->srcPort = htons(udpHeader2->srcPort);
							udpHeader2->dstPort = htons(udpHeader2->dstPort);
							udpHeader2->messageLength = htons(udpHeader2->messageLength);
							udpHeader2->checksum = htons(udpHeader2->checksum);
							break;
					}
				}
			}
			break;
	}
}
