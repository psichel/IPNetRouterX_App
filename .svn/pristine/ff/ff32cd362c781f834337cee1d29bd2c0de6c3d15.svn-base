//
//  HardwareAddressFormatter.h
//  IPNetRouterX
//
//  Created by psichel on Thu Nov 6 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//

#import "HardwareAddressFormatter.h"
#import "HardwareAddress.h"
#import "kftSupport.h"

@implementation HardwareAddressFormatter
+ (HardwareAddressFormatter *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[HardwareAddressFormatter alloc] init];
	}
	return sharedTask;
}
// ---------------------------------------------------------------------------------
//	¥ stringForObjectValue:
// ---------------------------------------------------------------------------------
// Return the colon separated hex string representing an Ethernet MAC address
- (NSString *)stringForObjectValue:(id)inHardwareAddress {
	NSString* returnValue = nil;
	EthernetAddress_t* macA;

	// test passed in object for correct class
	if ([inHardwareAddress isKindOfClass:[HardwareAddress class]]) {
		macA = [inHardwareAddress hardwareAddress];
		returnValue = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
		macA->octet[0],macA->octet[1],macA->octet[2],macA->octet[3],macA->octet[4],macA->octet[5]];
	}
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ getObjectValue:forString:errorDescription:
// ---------------------------------------------------------------------------------
// load MAC address for colon separated hex string
- (BOOL)getObjectValue:(id *)outHardwareAddress forString:(NSString *)inString errorDescription:(NSString **)error {
    BOOL returnValue = YES;
	HardwareAddress* macValue;
	EthernetAddress_t* macA;
	PSData inBuf;
	PSRange range;
	int i;

	if (error) *error = nil;
	do {
		// ignore empty string
		if (![inString length]) {
			if (error) *error = NSLocalizedString(@"HardwareAddressFormatter: inString is nil",@"HardwareAddressFormatter: inString is nil");
			returnValue = NO;
			break;
		}
		// initialize result to be empty
		macValue = [[[HardwareAddress alloc] init] autorelease];
		if (!macValue) {
			*error = NSLocalizedString(@"HardwareAddressFormatter: object could not be allocated",@"HardwareAddressFormatter: object could not be allocated");
			returnValue = NO;
			break;
		}
		inBuf.bytes = (u_int8_t*)[inString UTF8String];
		inBuf.length = [inString length];
		inBuf.bufferLength = inBuf.length;
		range.location = 0;
		range.length = inBuf.length;
		macA = [macValue hardwareAddress];
		
		macA->octet[0] = intHexValue(&inBuf, &range);
		for (i=1; i<6; i++) {
			if ( !skipByte(&inBuf, &range, ':') && !skipByte(&inBuf, &range, '-') ) {
				if (error) *error = NSLocalizedString(@"HardwareAddressFormatter: invalid Ethernet address",@"HardwareAddressFormatter: invalid Ethernet address");
				returnValue = NO;
				NSLog(@"Input: %@",inString);
				break;
			}
			macA->octet[i] = intHexValue(&inBuf, &range);
		}
		*outHardwareAddress = macValue;
	} while (false);
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
