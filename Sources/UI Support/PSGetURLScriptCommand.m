//
//  PSGetURLScriptCommand.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on Tue Sep 17 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//

#import "PSGetURLScriptCommand.h"
#import "PSURL.h"
#import "PingDelegate.h"
#import "PingController.h"
#import "TraceRouteDelegate.h"
#import "TraceRouteController.h"
#import "PortScanDelegate.h"
#import "PortScanController.h"
#import "AddressScanDelegate.h"
#import "AddressScanController.h"
#import "MonitorDelegate.h"
#import "MonitorController.h"
#import "WhoIsDelegate.h"
#import "WhoIsController.h"
#import "FingerDelegate.h"
#import "FingerController.h"
#import "NameQueryDelegate.h"
#import "NameQueryController.h"
#import "PSSharedDictionary.h"
#import "AppDelegate.h"


@implementation PSGetURLScriptCommand

+ sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[PSGetURLScriptCommand allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	¥ performDefaultImplementation
// ---------------------------------------------------------------------------------
- (id)performDefaultImplementation
{
    PSURL* url;
    NSString* returnValue = nil;
	
    // initialize url object to examine components
    url = [[PSURL alloc] init];
    [url setStringValue:[self directParameter]];
	
	// perform GetURL
	returnValue = [self performURL:url windowController:nil];
	
    // remember our GetURL
    [[PSSharedDictionary sharedInstance] setObject:url forKey:@"GetURL"];
    //NSLog([url stringValue]);
	return returnValue;
}	

// ---------------------------------------------------------------------------------
//	¥ performURL
// ---------------------------------------------------------------------------------
- (NSString *)performURL:(PSURL *)url windowController:(NSWindowController **)controller
{
    NSString* returnValue = nil;
	
    PingWindowM* pingWindowM;
    PingWindowC* pingController;
    TraceRouteWindowM* traceDelegate;
    TraceRouteWindowC* traceController;
    WhoIsWindowM* whoIsWindowM;
    WhoIsWindowC* whoIsController;
    FingerWindowM* fingerWindowM;
    FingerWindowC* fingerController;

    PortScanWindowM* portScanWindowM;
    PortScanWindowC* portScanController;
    AddressScanWindowM* addressScanWindowM;
    AddressScanWindowC* addressScanController;

    NameQueryDelegate* nameQueryDelegate;
    NameQueryController* nameQueryController;

    MonitorDelegate* monitorDelegate;
    MonitorController* monitorController;

	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
	// if registration not yet confirmed, check it
    if (![[sd objectForKey:kCheck1] intValue]) [[NSApp delegate] isRegistered];
    
    // dispatch based on url scheme
    if ([[[url scheme] lowercaseString] isEqualTo:@"ping"]) {
        // create a Ping Window
        pingWindowM = [[PingWindowM alloc] init];
        [pingWindowM showWindow:self];
        pingController = [pingWindowM controller];
        [pingWindowM release];
		if (controller) *controller = pingController;
        // ping corresponding target
        returnValue = [pingController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [pingController ping:self];
    }
    else if ([[[url scheme] lowercaseString] isEqualTo:@"traceroute"]) {
        // create a TraceRoute Window
        traceDelegate = [[TraceRouteWindowM alloc] init];
        [traceDelegate showWindow:self];
        traceController = [traceDelegate controller];
        [traceDelegate release];
		if (controller) *controller = traceController;
        // trace corresponding target
        returnValue = [traceController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [traceController trace:self];
    }
    else if ([[[url scheme] lowercaseString] isEqualTo:@"whois"]) {
        // create a WhoIs Window
        whoIsWindowM = [[WhoIsWindowM alloc] init];
        [whoIsWindowM showWindow:self];
        whoIsController = [whoIsWindowM controller];
        [whoIsWindowM release];
		if (controller) *controller = whoIsController;
        // whoIs corresponding target
        returnValue = [whoIsController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [whoIsController query:self];
    }
    else if ([[[url scheme] lowercaseString] isEqualTo:@"finger"]) {
        // create a Finger Window
        fingerWindowM = [[FingerWindowM alloc] init];
        [fingerWindowM showWindow:self];
        fingerController = [fingerWindowM controller];
        [fingerWindowM release];
		if (controller) *controller = fingerController;
        // finger corresponding target
        returnValue = [fingerController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [fingerController query:self];
    }
    else if ([[[url scheme] lowercaseString] isEqualTo:@"portscan"]) {
        // create a port scan Window
        portScanWindowM = [[PortScanWindowM alloc] init];
        [portScanWindowM showWindow:self];
        portScanController = [portScanWindowM controller];
        [portScanWindowM release];
		if (controller) *controller = portScanController;
        // portScan corresponding target
        returnValue = [portScanController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [portScanController scan:self];
    }
    else if ([[[url scheme] lowercaseString] isEqualTo:@"scan"]) {
        // create a address scan Window
        addressScanWindowM = [[AddressScanWindowM alloc] init];
        [addressScanWindowM showWindow:self];
        addressScanController = [addressScanWindowM controller];
        [addressScanWindowM release];
		if (controller) *controller = addressScanController;
        // addressScan corresponding target
        returnValue = [addressScanController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [addressScanController scan:self];
    }
    else if ([[[url scheme] lowercaseString] isEqualTo:@"monitor"]) {
        // create a Monitor Window
        monitorDelegate = [[MonitorDelegate alloc] init];
        [monitorDelegate showWindow:self];
        monitorController = [monitorDelegate controller];
        [monitorDelegate release];
        // monitor corresponding target
        returnValue = [monitorController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [monitorController monitor:self];
    }
    else if (
        ([[[url scheme] lowercaseString] isEqualTo:@"nslookup"]) ||
        ([[[url scheme] lowercaseString] isEqualTo:@"dig"])
        ) {
        // create a Name Query Window
        nameQueryDelegate = [[NameQueryDelegate alloc] init];
        [nameQueryDelegate showWindow:self];
        nameQueryController = [nameQueryDelegate controller];
        [nameQueryDelegate release];
        // nameQuery corresponding target
        returnValue = [nameQueryController setURL:[url stringValue]];
        if (returnValue) NSLog(returnValue);
        else [nameQueryController query:self];
    }
    return returnValue;
}
@end
