#import "IPValueFormatter.h"
#import "IPValue.h"
#import "IPSupport.h"
#import "Quad.h"

@implementation IPValueFormatter
+ (IPValueFormatter *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[IPValueFormatter alloc] init];
	}
	return sharedTask;
}
// ---------------------------------------------------------------------------------
//	¥ stringForObjectValue:
// ---------------------------------------------------------------------------------
// Return the dotted quad string representing an IP network range
- (NSString *)stringForObjectValue:(id)inIPValue {
    NSMutableString *str = [[NSMutableString alloc] initWithCapacity:128];
    UInt8  prefixLen;
	UInt8 options;

    do {
        // test passed in object for correct class
        if (![inIPValue isKindOfClass:[IPValue class]]) break;
		IPValue* inValue = inIPValue;		
		prefixLen = [inValue prefixLen];
		options = [inValue options];
		if ([inValue type] == AF_INET) {		
			// get IP address or start of range and convert to dotted quad
			[str appendString:stringForIP([inValue ipAddress])];
			// append prefixLen (CIDR notation) if any
			if (prefixLen && !(options & kOptionHidePrefixLen)) {
				if (prefixLen > 32) prefixLen = 32;
				[str appendFormat:@"/%d", prefixLen];
				// append port range if present
				if ([inValue startPort]) {
					[str appendFormat:@":%d", (SInt32)[inValue startPort]];
					if ([inValue endPort]) {
						[str appendFormat:@"-%d", (SInt32)[inValue endPort]];
					}
				}
			}
			// else append end of address range if present
			else {
				int32_t value = [inValue endAddress];
				if (value) {
					[str appendFormat:@"-%@",stringForIP(value)];
				}
				// append port range if present
				if ([inValue startPort]) {
					[str appendFormat:@":%d", (SInt32)[inValue startPort]];
					if ([inValue endPort]) {
						[str appendFormat:@"-%d", (SInt32)[inValue endPort]];
					}
				}
			}
		}
		else if ([inValue type] == AF_INET6) {
			// get IP address or start of range and convert address string
			[str appendString:stringForIP6([inValue ipAddress6], options)];
			// append prefixLen (CIDR notation) if any
			if (prefixLen && !(options & kOptionHidePrefixLen)) {
				if (prefixLen > 128) prefixLen = 128;
				[str appendFormat:@"/%d", prefixLen];
				// append port range if present
				if ([inValue startPort]) {
					[str appendFormat:@".%d", (SInt32)[inValue startPort]];
					if ([inValue endPort]) {
						[str appendFormat:@"-%d", (SInt32)[inValue endPort]];
					}
				}
			}
			// else append end of address range if present
			else {
				if ([inValue hasEndAddress]) {
					[str appendFormat:@"-%@",stringForIP6([inValue endAddress6], options)];
				}
				// append port range if present
				if ([inValue startPort]) {
					[str appendFormat:@":%d", (SInt32)[inValue startPort]];
					if ([inValue endPort]) {
						[str appendFormat:@"-%d", (SInt32)[inValue endPort]];
					}
				}
			}
		}
    } while (false);
    [str autorelease];
    return str;
}

// override isDigit() with macro definition
// macro is not compatible with auto-increment
//#define isDigit(a) ((a >= '0') && (a <= '9'))
// ---------------------------------------------------------------------------------
//	¥ getObjectValue:forString:errorDescription:
// ---------------------------------------------------------------------------------
// load network range from a dotted quad string
- (BOOL)getObjectValue:(id *)outIPValue forString:(NSString *)inString errorDescription:(NSString **)error {
	BOOL returnValue = NO;
	u_int32_t   address;
    u_int32_t   part;
	char		cbuf[255];
	int			len;
	int			type;
	int			start, i, j, k, outLen;
	int			digit;
	BOOL		foundDigit;

    IPValue* ipValue;
	BOOL	anotherSegment;
    
    // initialize result to be empty
	if (error) *error = nil;
	ipValue = [[[IPValue alloc] init] autorelease];
    do {
		len = [inString length];
		if ((len == 0) || (len >= 255)) break;
		// look for first "." or ":" to distinguish IPv4 or IPv6
		type = AF_INET;
		NSRange range1 = [inString rangeOfString:@"."];
		NSRange range2 = [inString rangeOfString:@":"];
		if ( range2.length &&
			((range1.length == 0) || (range2.location < range1.location)) ) type = AF_INET6;
		[ipValue setType:type];
		// convert to C string for quick character access
		[inString getCString:&cbuf[0] maxLength:255 encoding:NSUTF8StringEncoding];

		// skip leading whitespace
		for (start = 0; start < len; start++) {
			if (cbuf[start] == ' ') continue;
			if (cbuf[start] == ',') continue;
			if (cbuf[start] == '-') continue;
			if (cbuf[start] == '\t') continue;
			if (cbuf[start] == '\r') continue;
			break;
		}
		
		// must have a valid first segment
		if (type == AF_INET) {
			if ( !isDigit(cbuf[start]) ) break;
			// look for IP address as dotted quad x.x.x.x
			anotherSegment = YES;
			address = 0;
			// convert address segments, use 0 if missing        
			for (i=1; i<=4; i++) {
				part = 0;
				if (anotherSegment) {
					if (i==1) {
						part = ipSegment1FromBuf(cbuf, &start, &outLen);
						[ipValue setSegments:i];
						// allow address in decimal format
						if (part > 255) {
							address = part;
							if (start == len) returnValue = YES;
							else if (cbuf[start] == ' ') returnValue = YES;
							break;
						}
					}
					else {
						part = ipSegmentFromBuf(cbuf, &start, &outLen);
						[ipValue setSegments:i];
					}
				}
				address <<= 8;
				address |= part & 0xFF;
				// more segments?
				if (cbuf[start] != '.') anotherSegment = NO;
				else start++;	// dotted quad
			}
			[ipValue setIpAddress:address];
		}
 		else if (type == AF_INET6) {
			// an IPv6 address may be enclosed in []
			if (cbuf[start] == '[') start++;
			// confirm valid first digit or ::
			if ( !isHexDigit(cbuf[start]) &&
				((cbuf[start] != ':') || (cbuf[start+1] != ':'))
				) break;
			int count = 0;
			in6_addr_t address6;
			bzero(&address6, sizeof(address6));
			for (i=0; i<=7; i++) {
				part = ipSegment6FromBuf(cbuf, &start, &outLen);
				address6.s6_addr[2*i] = (part >> 8) & 0xFF;
				address6.s6_addr[2*i+1] = part & 0xFF;
				[ipValue setSegments:i+1];
				// more segments?
				if (i == 7) break;
				if (cbuf[start] != ':') break;
				start++;	// skip :
				if ((outLen == 0) && (count == 0)) {
					// determine length of run
						// count number of ":" remaining
					j = start;
					while (j<len) {
						if (cbuf[j] == ':') {
							count++;
							j++;
							continue;
						}
						if (!isHexDigit(cbuf[j++])) break;					
					}
					// should be count+1 segments left
					int index = 6 - count;
					if (index > i) i = index;
				}
			}
			[ipValue setIpAddress6:&address6];
			// extract interface name if present
			if (cbuf[start] == '%') {
				start++;	// skip %
				for (j=0; j<kBSDNameLength; j++) {
					k = start+j;
					if (k == len) break;
					if ( !isDigit(cbuf[k]) && !isAlpha(cbuf[k]) ) break;
				}
				[ipValue setBsdName:[[[NSString alloc] initWithBytes:&cbuf[start] length:j encoding:NSUTF8StringEncoding] autorelease] ];
				start += j;
			}
			// skip ending [] if present
			if (cbuf[start] == ']') start++;
		}
        
		// look for port range x.x.x.x:y-y
		if (cbuf[start] == ':') {
            start++;	// skip ":"
            // convert starting port
            part = 0;
			for (j=0; j<5; j++) {
				if ( isDigit(cbuf[start]) ) {
					digit = cbuf[start++] - '0';
					part = part * 10 + digit;
				}
				else break;
			}
			[ipValue setStartPort:part];

			if (cbuf[start] == '-') {
				start++;	// skip "-"
				// convert ending port
				part = 0;
				for (j=0; j<5; j++) {
					if ( isDigit(cbuf[start]) ) {
						digit = cbuf[start++] - '0';
						part = part * 10 + digit;
					}
					else break;
				}
				[ipValue setEndPort:part];
            }
        }
        // look for prefix length (CIDR notation /xx)
		if (cbuf[start] == '/') {
            start++;	// skip "/"
			{
				NSString* possibleMask;
				u_int32_t mask;
				in6_addr_t mask6;
				int status;
				possibleMask = [inString substringFromIndex:start];
				status = isIPAddress(possibleMask, &mask, &mask6);
				if (status == AF_INET6) {
					[ipValue setMask6:&mask6];
					break;
				}
				if (status == AF_INET) {
					[ipValue setMask:mask];
					break;
				}
				// convert prefix length
				part = 0;
				foundDigit = NO;
				for (j=0; j<3; j++) {
					if ( isDigit(cbuf[start]) ) {
						digit = cbuf[start++] - '0';
						part = part * 10 + digit;
						foundDigit = YES;
					}
					else break;
				}
				if (type == AF_INET) {
					if (foundDigit && (part <= 32)) [ipValue setPrefixLen:part];
					else {
						if (foundDigit) [ipValue setPrefixLen:32];	// default to prefix length 32
						else {
							// notice we already matched a "/" but there were no digits, use CIDR alignment
							part = FindRightBit([ipValue ipAddress], 32);
							[ipValue setPrefixLen:part];
						}
					}
				}
				else if (type == AF_INET6) {
					if (foundDigit && (part <= 128)) [ipValue setPrefixLen:part];
					else {
						if (foundDigit) [ipValue setPrefixLen:128];	// default to prefix length 128
						else {
							// notice we already matched a "/" but there were no digits, use CIDR alignment
							Quad* address6Q = [Quad quadWithIPv6:[ipValue ipAddress6]];
							part = [address6Q findRightBitStartingFrom:128];
							[ipValue setPrefixLen:part];
						}
					}
				}
			} while (false);
		}
        // else look for address range x.x.x.x-y.y.y.y
		// allow x.x.x.x - y.y.y.y in address range
		else {
			// skip spaces
			j = start;
			while (cbuf[j] == ' ') j += 1;
			if (cbuf[j] == '-') {
				start = j + 1;	// skip "-"
				while (cbuf[start] == ' ') start += 1;
				if (type == AF_INET) {
					address = 0;
					// convert address segments        
					for (i=1; i<=4; i++) {
						part = ipSegmentFromBuf(cbuf, &start, &outLen);
						address <<= 8;
						address |= part & 0xFF;
						// more segments?
						if (cbuf[start] != '.') break;
						else start++;	// dotted quad
					}
					if (i==1) [ipValue setEndAddress:([ipValue ipAddress] & 0xFFFFFF00) + address];
					else if (i==2) [ipValue setEndAddress:([ipValue ipAddress] & 0xFFFF0000) + address];
					else if (i==3) [ipValue setEndAddress:([ipValue ipAddress] & 0xFF000000) + address];
					else [ipValue setEndAddress:address];
				}
				else if (type == AF_INET6) {
					// an IPv6 address may be enclosed in []
					if (cbuf[start] == '[') start++;
					// confirm valid first digit or ::
					if ( !isHexDigit(cbuf[start]) &&
						((cbuf[start] != ':') || (cbuf[start+1] != ':'))
						) break;
					int count = 0;
					in6_addr_t address6;
					bzero(&address6, sizeof(address6));
					for (i=0; i<=7; i++) {
						part = ipSegment6FromBuf(cbuf, &start, &outLen);
						address6.s6_addr[2*i] = (part >> 8) & 0xFF;
						address6.s6_addr[2*i+1] = part & 0xFF;
						// more segments?
						if (i == 7) break;
						if (cbuf[start] != ':') break;
						start++;	// skip :
						if ((outLen == 0) && (count == 0)) {
							// determine length of run
								// count number of ":" remaining
							j = start;
							while (j<len) {
								if (cbuf[j] == ':') {
									count++;
									j++;
									continue;
								}
								if (!isHexDigit(cbuf[j++])) break;					
							}
							// should be count+1 segments left
							int index = 6 - count;
							if (index > i) i = index;
						}
					}
					[ipValue setEndAddress6:&address6];
					// skip ending [] if present
					if (cbuf[start] == ']') start++;
				}	// if (type == AF_INET6)
			}
		}

        // look for port range x.x.x.x:y-y
		if (cbuf[start] == ':') {
            start++;	// skip ":"
            // convert starting port
            part = 0;
			for (j=0; j<5; j++) {
				if ( isDigit(cbuf[start]) ) {
					digit = cbuf[start++] - '0';
					part = part * 10 + digit;
				}
				else break;
			}
			[ipValue setStartPort:part];

			if (cbuf[start] == '-') {
				start++;	// skip "-"
				// convert ending port
				part = 0;
				for (j=0; j<5; j++) {
					if ( isDigit(cbuf[start]) ) {
						digit = cbuf[start++] - '0';
						part = part * 10 + digit;
					}
					else break;
				}
				[ipValue setEndPort:part];
            }
        }

		// make sure address ends with final digit or whitespace, otherwise treat as domain name
		if (start == len) returnValue = YES;
		else if (cbuf[start] == ' ') returnValue = YES;
		//else if (cbuf[start] == ',') returnValue = YES;	// allow address list
    } while (false);
	 // set result
	if (outIPValue) *outIPValue = ipValue;
	else if (error) {
		*error = NSLocalizedString(@"IPValueFormatter: nil object pointer",@"IPValueFormatter: nil object pointer");
		returnValue = NO;
	}
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ attributedStringForObjectValue:withDefaultAttributes
// ---------------------------------------------------------------------------------
- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes {
    NSAttributedString *theString;
    // create attributed string for object
    theString = [[NSAttributedString alloc] initWithString:[self stringForObjectValue:anObject] attributes:attributes];
    [theString autorelease];
    return theString;
}

@end

