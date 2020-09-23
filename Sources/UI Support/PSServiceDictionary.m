//
//  PSServiceDictionary.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on Fri Feb 22 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//

#import "PSServiceDictionary.h"
#import <netinet/in.h>

@implementation PSServiceDictionary
+ (PSServiceDictionary *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[PSServiceDictionary alloc] init];
	}
	return sharedTask;
}

- (id)init
{
    NSString *path;
    if (self = [super init]) {
        path=[[NSBundle mainBundle] pathForResource:@"tcpServiceNames" ofType:@"plist"];
        tcpServiceNames = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
        if (!tcpServiceNames) {
			NSLog(@"PSServiceDictionary could not find path for resource tcpServiceNames %@", path);
			NSLog(@"Bundle path %@", [[NSBundle mainBundle] bundlePath]);
		}
        path=[[NSBundle mainBundle] pathForResource:@"udpServiceNames" ofType:@"plist"];
        udpServiceNames = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
        if (!udpServiceNames)  {
			NSLog(@"PSServiceDictionary could not find path for resource udpServerNames %@", path);
		}
		// ICMP type and code
        path=[[NSBundle mainBundle] pathForResource:@"icmpTypes" ofType:@"plist"];
        icmpTypes = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
        if (!icmpTypes)  {
			NSLog(@"PSServiceDictionary could not find path for resource icmpTypes %@", path);
		}
        path=[[NSBundle mainBundle] pathForResource:@"icmpCodes" ofType:@"plist"];
        icmpCodes = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
        if (!icmpCodes)  {
			NSLog(@"PSServiceDictionary could not find path for resource icmpCodes %@", path);
		}
    }
    return self;
}
- (void)dealloc
{
    [tcpServiceNames release];
    [udpServiceNames release];   
    [icmpTypes release];
    [icmpCodes release];   
    [super dealloc];
}

- (NSString *)serviceNameForPort:(int)port protocol:(int)protocol
{
    NSString* returnValue = nil;
    if (protocol == IPPROTO_TCP)
        returnValue = [tcpServiceNames objectForKey:[NSString stringWithFormat:@"%d",port]];
    else if ((protocol == IPPROTO_UDP) || (protocol == 0))
        returnValue = [udpServiceNames objectForKey:[NSString stringWithFormat:@"%d",port]];
    return returnValue;
}

- (NSString *)servicePortForName:(NSString *)name protocol:(int)protocol
{
    NSString* returnValue = nil;
    NSArray* keyArray = nil;
    if (name) {
        if (protocol == kProtocolTCP)
            keyArray = [tcpServiceNames allKeysForObject:name];
        else if (protocol == kProtocolUDP)
            keyArray = [udpServiceNames allKeysForObject:name];
        if ([keyArray count]) returnValue = [keyArray objectAtIndex:0];
    }
    return returnValue;
}

- (NSDictionary *)tcpServiceNames { return tcpServiceNames; }

- (NSDictionary *)udpServiceNames { return udpServiceNames; }


// ICMP type and code
- (NSString *)nameForICMPType:(int)type
{
	return [icmpTypes objectForKey:[NSString stringWithFormat:@"%d",type]];
}

- (NSString *)nameForICMPCode:(int)code
{
	return [icmpCodes objectForKey:[NSString stringWithFormat:@"%d",code]];
}
@end


NSInteger intSort(id num1, id num2, void *context)
{
    int v1 = [num1 intValue];
    int v2 = [num2 intValue];
    if (v1 < v2)
        return NSOrderedAscending;
    else if (v1 > v2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}
