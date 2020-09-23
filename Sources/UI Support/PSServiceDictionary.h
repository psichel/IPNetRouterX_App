//
//  PSServiceDictionary.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on Fri Feb 22 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates looking up network services by port number

#import <Foundation/Foundation.h>


@interface PSServiceDictionary : NSObject {
    NSDictionary* udpServiceNames;
    NSDictionary* tcpServiceNames;
	NSDictionary* icmpTypes;
	NSDictionary* icmpCodes;
}
+ (PSServiceDictionary *)sharedInstance; // returns a shared instance of the class
- (NSString *)serviceNameForPort:(int)port protocol:(int)protocol;
- (NSString *)servicePortForName:(NSString *)name protocol:(int)protocol;
- (NSString *)nameForICMPType:(int)type;
- (NSString *)nameForICMPCode:(int)code;
- (NSDictionary *)tcpServiceNames;
- (NSDictionary *)udpServiceNames;
@end

#define kProtocolTCP	6
#define kProtocolUDP	17

NSInteger intSort(id num1, id num2, void *context);
