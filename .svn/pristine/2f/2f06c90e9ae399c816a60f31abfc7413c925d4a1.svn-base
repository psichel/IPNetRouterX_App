//
//  TCPFlowHistory.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Sep 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import "TCPFlowHistory.h"

@implementation TCPFlowHistory
+ sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[TCPFlowHistory allocWithZone:[self zone]] init];
	}
	return sharedTask;
}
- (id) init {
    NSArray* theArray = [NSArray arrayWithObjects:
		@"-p // my tcp data",
        @"-p port 80 // my web data",
        @"port 80  // all web data",
        nil];
    self = [super init];
    [self addTempArray:theArray];
    return self;
}
@end
