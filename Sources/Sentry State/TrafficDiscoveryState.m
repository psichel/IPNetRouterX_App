//
//  TrafficDiscoveryState.m
//  IPNetSentryX
//
//  Created by Peter Sichel on 2007-10-18
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.

#import "TrafficDiscoveryState.h"

@implementation TrafficDiscoveryState
// ---------------------------------------------------------------------------------
//	¥ sharedInstance
// ---------------------------------------------------------------------------------
+ (TrafficDiscoveryState *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[TrafficDiscoveryState alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	¥ setTrafficDiscovery:
// ---------------------------------------------------------------------------------
- (NSNumber *)trafficDiscovery { return [nodeDictionary objectForKey:SS_trafficDiscovery]; }
- (void)setTrafficDiscovery:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_trafficDiscovery];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_trafficDiscovery];
		else [nodeDictionary removeObjectForKey:SS_trafficDiscovery];
		// notify listeners
		[self updateParameterCD:SS_trafficDiscovery withObject:value];
	}
}

- (NSNumber *)tdDevice { return [nodeDictionary objectForKey:SS_tdDevice]; }
- (void)setTdDevice:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_tdDevice];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_tdDevice];
		else [nodeDictionary removeObjectForKey:SS_tdDevice];
		// notify listeners
		[self updateParameterCD:SS_tdDevice withObject:value];
	}
}

- (NSNumber *)tdService { return [nodeDictionary objectForKey:SS_tdService]; }
- (void)setTdService:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_tdService];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_tdService];
		else [nodeDictionary removeObjectForKey:SS_tdService];
		// notify listeners
		[self updateParameterCD:SS_tdService withObject:value];
	}
}

- (NSNumber *)tdNetflow { return [nodeDictionary objectForKey:SS_tdNetflow]; }
- (void)setTdNetflow:(NSNumber *)value {
	// if setting has changed
	NSNumber* previous = [nodeDictionary objectForKey:SS_tdNetflow];
	if ( (!previous && value) || ([value intValue] != [previous intValue]) ) {
		// update model
		if (value) [nodeDictionary setObject:value forKey:SS_tdNetflow];
		else [nodeDictionary removeObjectForKey:SS_tdNetflow];
		// notify listeners
		[self updateParameterCD:SS_tdNetflow withObject:value];
	}
}

@end
