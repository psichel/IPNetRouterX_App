//
//  LookupHistory.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Sep 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import "LookupHistory.h"

@implementation LookupHistory
+ sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[LookupHistory allocWithZone:[self zone]] init];
	}
	return sharedTask;
}
@end
