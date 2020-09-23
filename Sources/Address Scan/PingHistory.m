//
//  PingHistory.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Sep 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import "PingHistory.h"

@implementation PingHistory
+ sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[PingHistory allocWithZone:[self zone]] init];
	}
	return sharedTask;
}
@end
