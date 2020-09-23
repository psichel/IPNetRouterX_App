//
//  AddressScanHistory.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Sep 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import "AddressScanHistory.h"

@implementation AddressScanHistory
+ sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[AddressScanHistory allocWithZone:[self zone]] init];
	}
	return sharedTask;
}
@end
