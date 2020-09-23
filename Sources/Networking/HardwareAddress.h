//
//  HardwareAddress.h
//  IPNetRouterX
//
//  Created by psichel on Thu Nov 6 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "unp.h"
#import "ipkTypes.h"

// MAC Address value used for field input/output
// <empty>				; 0
// XX:XX:XX:XX:XX:XX
// XX-XX-XX-XX-XX-XX
// 
// Internally we store a MAC Address as an array of 6 octets
#if 0
typedef struct {
	u_int8_t octet[6];
} EthernetAddress_t;

typedef struct {
	u_int8_t octet[16];
} HardwareAddress16_t;
#endif

@interface HardwareAddress : NSObject <NSCopying> {
    EthernetAddress_t hardwareAddress;
}
- (id)init;
- (EthernetAddress_t *)hardwareAddress;
- (void)setHardwareAddress:(EthernetAddress_t *)inValue;
- (void)getHardwareAddress:(EthernetAddress_t *)outValue;

- (NSString *)stringValue;
- (BOOL)setStringValue:(NSString *)inValue;
// <NSCopying>
- (const void *)bytes;
- (unsigned)length;
- (NSString *)description;
- (id)copyWithZone:(NSZone *)zone;
@end

int hwAddressForIP(u_int32_t ipAddress, u_int8_t* hwAddress, u_int8_t* hwAddressLen);
NSString* hwAddressStringForIPString(NSString* ipAddress);
BOOL eaForString(NSString* inString, EthernetAddress_t* outBuf);
NSString* stringForEA(EthernetAddress_t* ea);
BOOL ha16ForString(NSString* inString, HardwareAddress16_t* outBuf, int* hlen);
NSString* stringForHA16(HardwareAddress16_t* ha, int hlen);
