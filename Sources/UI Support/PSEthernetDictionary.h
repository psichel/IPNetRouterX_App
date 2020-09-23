//
//  PSEthernetDictionary.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on Fri Jun 21 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates looking up network services by port number

#import <Foundation/Foundation.h>


@interface PSEthernetDictionary : NSObject {
    NSDictionary* ethernetNames;
    NSMutableDictionary* nameCache;
}
+ (PSEthernetDictionary *)sharedInstance; // returns a shared instance of the class
- (NSString *)orgForEthernetAddress:(NSString *)macAddress;
@end
