//
//  TDServer.m
//  IPNetRouterX
//
//  Created by psichel on Wed Jan 24 2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing Traffic Discovery I/O in a separate thread
//  so we don't block while using NSPropertyListSerialization classes

#import "TDServer.h"
#import "TrafficDiscoveryModel.h"
#import "PSURL.h"

@interface TDServer (PrivateMethods)
- (int)serverTerminate:(PSURL *)url withObject:(id)anObject;
@end

@implementation TDServer
- init {
    if (self = [super init]) {
		// initialize our instance variables
		tdm = [TrafficDiscoveryModel sharedInstance];
		[tdm setCallbackTarget:self];
		[tdm enableTD:YES];
    }
    return self;
}

#pragma mark -- Thread Server Interface --
// ---------------------------------------------------------------------------------
//	¥ synchStartService:
// ---------------------------------------------------------------------------------
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	int result = 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    PSURL* url=nil;

	NS_DURING    
		// The following line is an interesting optimisation.  We tell our proxy
		// to the controller object about the methods that we're going to
		// send to the proxy.    
		[controller setProtocolForProxy:@protocol(ControllerFromThread)];
		// init method vars
		[self setController:controller];

		// extract TD parameters
		// sendEmailstart://localhost/filepath
		// terminate:
		url = [PSURL urlWithString:inURL];
		// dispatch commands
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}
		else if ([[url scheme] isEqualTo:kTDTrafficUpdate]) {
			[tdm receiveTrafficUpdate:anObject];
		}
		else if ([[url scheme] isEqualTo:kTDTableUpdate]) {
			result = [tdm tableUpdateWithObject:anObject];
		}
		else if ([[url scheme] isEqualTo:kTDPlotUpdate]) {
			result = [tdm plotUpdateWithObject:anObject];
		}
		else if ([[url scheme] isEqualTo:kTDShowNow]) {
			result = [tdm showNowWithObject:anObject];
		}
		else if ([[url scheme] isEqualTo:kTDSave]) {
			[tdm trafficDiscoverySaveForDate:nil];
		}
		else if ([[url scheme] isEqualTo:kServerTerminate]) {
			result = [self serverTerminate:url withObject:anObject];
		}
		else {
			[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
		}
	NS_HANDLER
		NSLog(@"Exception during TDServer.m synchStartService");
	NS_ENDHANDLER
    [pool release]; pool = nil;
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ serverTerminate:withObject:
// ---------------------------------------------------------------------------------
- (int)serverTerminate:(PSURL *)url withObject:(id)anObject
{
	[self finish];
	return 0;
}

@end
