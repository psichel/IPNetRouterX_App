//
//  DHCPLeaseState.m
//  IPNetRouterX
//
//  Created by psichel on Thu Nov 6 2003.
//  Copyright (c) 2003 Sustainable Softworks Inc. All rights reserved.
//

#import "DHCPLeaseState.h"
#import <string.h>

@implementation DHCPLeaseState
// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (DHCPLeaseState *)init {
    if (self = [super init]) {
        dhcpLeaseState = 0;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dhcpLeaseState
// ---------------------------------------------------------------------------------
- (int)dhcpLeaseState
{
	return dhcpLeaseState;
}

// ---------------------------------------------------------------------------------
//	¥ setDHCPLeaseState
// ---------------------------------------------------------------------------------
- (void)setDHCPLeaseState:(int)inValue
{
	dhcpLeaseState = inValue;
}

// ---------------------------------------------------------------------------------
//	¥ stringValue
// ---------------------------------------------------------------------------------
- (NSString *)stringValue
{
    NSString* returnValue = nil;
	switch (dhcpLeaseState) {
		case kLeaseNone:
			returnValue = @"";
			break;
		case kLeaseOffered:
			returnValue = kLeaseOfferedStr;
			break;
		case kLeaseBound:
			returnValue = kLeaseBoundStr;
			break;
		case kLeaseReleased:
			returnValue = kLeaseReleasedStr;
			break;
		case kLeaseExpired:
			returnValue = kLeaseExpiredStr;
			break;
		case kLeaseDeclined:
			returnValue = kLeaseDeclinedStr;
			break;
		case kLeaseInUse:
			returnValue = kLeaseInUseStr;
			break;
		case kLeaseBootp:
			returnValue = kLeaseBootpStr;
			break;
	}
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ setStringValue
// ---------------------------------------------------------------------------------
- (BOOL)setStringValue:(NSString *)inValue
{
    BOOL returnValue = NO;
	
	if ([inValue isEqualToString:kLeaseOfferedStr]) {
		dhcpLeaseState = kLeaseOffered;
		returnValue = YES;
	}
	else if ([inValue isEqualToString:kLeaseBoundStr]) {
		dhcpLeaseState = kLeaseBound;
		returnValue = YES;
	}
	else if ([inValue isEqualToString:kLeaseReleasedStr]) {
		dhcpLeaseState = kLeaseReleased;
		returnValue = YES;
	}
	else if ([inValue isEqualToString:kLeaseExpiredStr]) {
		dhcpLeaseState = kLeaseExpired;
		returnValue = YES;
	}
	else if ([inValue isEqualToString:kLeaseDeclinedStr]) {
		dhcpLeaseState = kLeaseDeclined;
		returnValue = YES;
	}
	else if ([inValue isEqualToString:kLeaseInUseStr]) {
		dhcpLeaseState = kLeaseInUse;
		returnValue = YES;
	}
	else if ([inValue isEqualToString:kLeaseBootpStr]) {
		dhcpLeaseState = kLeaseBootp;
		returnValue = YES;
	}
	return returnValue;
}

- (NSString *)description {
    return [self stringValue];
}

@end
