//
//  TCPDumpHistory.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Sep 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import "TCPDumpHistory.h"

@implementation TCPDumpHistory
+ sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[TCPDumpHistory allocWithZone:[self zone]] init];
	}
	return sharedTask;
}
- (id) init {
    NSArray* theArray = [NSArray arrayWithObjects:
        @"-n -p -t  // my packet headers",
        @"-n -t  // all packet headers",
        @"-n -p -t -q -X -s 1500 tcp port 80 // my web data",
        nil];
    self = [super init];
    [self addTempArray:theArray];
    return self;
}
@end
