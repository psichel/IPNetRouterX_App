//
//  TrafficDiscoveryState.h
//  IPNetSentryX
//
//  Created by Peter Sichel on 2007-10-18
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSToolState.h"
#import "SentryDefs.h"

@interface TrafficDiscoveryState : PSToolState {		
    // Store firewall state variables (model) in a mutable dictionary to simplify
    // coding and decoding interface entries.
}
+ (TrafficDiscoveryState *)sharedInstance;
- (NSNumber *)trafficDiscovery;
- (void)setTrafficDiscovery:(NSNumber *)value;
- (NSNumber *)tdDevice;
- (void)setTdDevice:(NSNumber *)value;
- (NSNumber *)tdService;
- (void)setTdService:(NSNumber *)value;
- (NSNumber *)tdNetflow;
- (void)setTdNetflow:(NSNumber *)value;

@end
