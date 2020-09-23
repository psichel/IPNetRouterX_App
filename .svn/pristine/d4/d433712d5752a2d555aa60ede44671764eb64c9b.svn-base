//
//  RouteServer.m
//  IPNetRouterX
//
//  Created by psichel on Wed Mar 05 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates reading the routes/arp list in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
#import "RouteServer.h"
//#import <Foundation/Foundation.h>
#import "IPValue.h"
#import "RouteEntry.h"
#import "ArpEntry.h"
#import "AppDelegate.h"
#import "PSURL.h"
#import "IPSupport.h"
#import "HardwareAddress.h"
#import "unp.h"
#import <sys/param.h>
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <net/route.h>
#import <net/if_arp.h>
#import <net/if_dl.h>
#import <net/if.h>
#import <netinet/if_ether.h>

#define socklen_t size_t

@implementation RouteServer

#pragma mark -- Thread Server Interface --
// ---------------------------------------------------------------------------------
//	¥ synchStartService:
// ---------------------------------------------------------------------------------
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSString* serverRequest;
	int result = 0;
NS_DURING    
    // The following line is an interesting optimisation.  We tell our proxy
    // to the controller object about the methods that we're going to
    // send to the proxy.    
    [controller setProtocolForProxy:@protocol(ControllerFromThread)];
    // init method vars
	[self setController:controller];
	// setup route action
	routeAction = [RouteAction sharedInstance];
	[routeAction setDelegate:self];

	// dispatch based on request
	// routeList
	// routeAdd
	// routeDelete
	// routeChange
	// terminate
	serverRequest = [(NSDictionary *)anObject objectForKey:kServerRequest];
	// dispatch commands
	if (mFinishFlag) {
		[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
	}
	else if ([serverRequest isEqualTo:kRouteList])
		result = [[routeAction routeList:anObject] count];
	else if ([serverRequest isEqualTo:kRouteAdd])
		result = [routeAction routeAdd:anObject];
	else if ([serverRequest isEqualTo:kRouteDelete])
		result = [routeAction routeDelete:anObject];
	else if ([serverRequest isEqualTo:kRouteChange])
		result = [routeAction routeChange:anObject];
	else if ([serverRequest isEqualTo:kArpList]) 
		result = [[routeAction arpList:anObject] count];
	else if ([serverRequest isEqualTo:kArpAdd])
		result = [routeAction arpAdd:anObject];
	else if ([serverRequest isEqualTo:kArpDelete])
		result = [routeAction arpDelete:anObject];
	else if ([serverRequest isEqualTo:kTerminate]) {
		[self finish];
		[routeAction setDelegate:nil];
	}
	else {
		[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
	}
NS_HANDLER
	NSLog(@"Exception during RouteServer.m synchStartService");
NS_ENDHANDLER
    [pool release]; pool = nil;
	return result;
}

@end
