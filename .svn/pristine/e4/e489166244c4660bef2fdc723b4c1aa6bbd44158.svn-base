//
//  DHCPLeaseState.h
//  IPNetRouterX
//
//  Created by psichel on Thu Nov 6 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
// Object used to represent DHCP Lease State as both an integer and string value

#import <Foundation/Foundation.h>

// lease state in DHCP Status element
#define kLeaseNone			0
#define kLeaseOffered		1
#define kLeaseBound			2
#define kLeaseReleased		3
#define kLeaseExpired		4
#define kLeaseDeclined		5
#define kLeaseInUse			6
#define kLeaseBootp			7

#define kLeaseOfferedStr	    @"offered"
#define kLeaseBoundStr		    @"bound"
#define kLeaseReleasedStr	    @"released"
#define kLeaseExpiredStr	    @"expired"
#define kLeaseDeclinedStr	    @"declined"
#define kLeaseInUseStr		    @"in use"
#define kLeaseBootpStr			@"BOOTP"

@interface DHCPLeaseState : NSObject {
    int16_t dhcpLeaseState;
}
- (DHCPLeaseState *)init;
- (int)dhcpLeaseState;
- (void)setDHCPLeaseState:(int)inValue;

- (NSString *)stringValue;
- (BOOL)setStringValue:(NSString *)inValue;
// <NSCopying>
- (NSString *)description;
@end
