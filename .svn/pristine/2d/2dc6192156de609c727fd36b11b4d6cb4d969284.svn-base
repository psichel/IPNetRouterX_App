//
//  LookupServer.m
//  IPNetMonitorX
//
//  Created by psichel on Wed Oct 17 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing a DNS Lookup in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
#import "LookupServer.h"
#import "PSURL.h"
#import "IPSupport.h"
#import "NSDate_Extensions.h"
#import "unp.h"
#import "netdb.h"	// gethostbyaddress
#import <CoreFoundation/CoreFoundation.h>

@implementation LookupServer
- (void)dealloc {
    [super dealloc];
}

// -- Thread Server Interface --
- (oneway void)startService:(NSString *)inURL fromController:(id)controller withObject:(id)object
// see comments in PSServerInterface.h
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // The following line is an interesting optimisation.  We tell our proxy
    // to the controller object about the methods that we're going to
    // send to the proxy.    
    [controller setProtocolForProxy:@protocol(ControllerFromThread)];
    // init method vars
	[self setController:controller];
	mURL = nil;
	NS_DURING
        // extract lookup parameters
        // <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
        mURL = [[PSURL alloc] init];
		[mURL setStringValue:inURL];
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}
        else if (![[mURL scheme] isEqualTo:kURL_lookup]) {
            [self finish];
        }
		else {
			// start lookup
			[self lookup];
		}
        // notice we keep the server thread around to handle further requests
	NS_HANDLER
		NSLog(@"Exception during LookupServer.m -startService");
		[self finish];
	NS_ENDHANDLER
    [mURL release]; mURL = nil;
    [pool release];
}

// attempt requested lookup
- (void)lookup
{
    NSString* lookupTarget;
    NSMutableString* resultString = [NSMutableString string];
	NSDate* startTime = nil;
    NSArray* resultArray;
	u_int32_t address;
	in6_addr_t address6;
	int addressFamily;
    do {
        // extract lookup parameters
        // <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
        lookupTarget = [mURL host];
        if ([lookupTarget length] == 0) {
            [self updateParameter:kStatusInfo withObject:NSLocalizedString(@"Please specify a target",@"specify target")];
            break;
        }
		// have lookup string, check for dotted quad
		addressFamily = isIPAddress(lookupTarget, &address, &address6);
		if (addressFamily) {
            // dotted quad address lookup using local resolver
            [self updateParameter:kStatusInfo withObject:NSLocalizedString(@"looking...",@"looking...")];
			startTime = [NSDate psDate];
			CFHostRef dnrCFHost;
			CFStreamError error;
			BOOL result;

			if (addressFamily == AF_INET6) dnrCFHost = CFHostCreateWithAddress(NULL, (CFDataRef)dataForAddress6(&address6, 0));
			else dnrCFHost = CFHostCreateWithAddress(NULL, (CFDataRef)dataForAddress(address, 0));
			result = CFHostStartInfoResolution(dnrCFHost, kCFHostNames, &error);
			resultArray = (NSArray *)CFHostGetNames(dnrCFHost, NULL);
			if (result) {
				[self updateParameter:@"elapsedInfo" withObject:[NSString stringWithFormat:@"%1.3f",-[startTime timeIntervalSinceNow]]];
                [self updateParameter:kStatusInfo withObject:@""];
				if ([[mURL paramValueForKey:@"listAll"] intValue]) {
					[self updateParameter:kResultField
						withObject:[resultArray componentsJoinedByString:@"\r"]];
				}
				else {
					// show only first name found
					[self updateParameter:kResultField withObject:[resultArray objectAtIndex:0]];
				}
			}
			else {
				[self updateParameter:kStatusInfo withObject:NSLocalizedString(@"No name found",@"No name found")];
				[self updateParameter:kNoAddressFound withObject:NSLocalizedString(@"No name found",@"No name found")];
			}
			CFRelease(dnrCFHost);
        }
        else {
            // domain name lookup using local resolver
            [self updateParameter:kStatusInfo withObject:NSLocalizedString(@"looking...",@"looking...")];
            startTime = [NSDate psDate];
			CFHostRef dnrCFHost;
			CFStreamError error;
			BOOL result;

			dnrCFHost = CFHostCreateWithName(NULL, (CFStringRef)lookupTarget);
			result = CFHostStartInfoResolution(dnrCFHost, kCFHostAddresses, &error);
			resultArray = (NSArray *)CFHostGetAddressing(dnrCFHost, NULL);
			if ([resultArray count]) {
				u_int32_t tAddress;
				in6_addr_t tAddress6;
				u_int16_t tPort;
				int i, type;
				NSString* str;
				NSRange range;
				// look for IP addresses
				for (i=0;i<[resultArray count];i++) {
					type = addressForData([resultArray objectAtIndex:i], &tAddress, &tAddress6, &tPort);
					if (type == AF_INET) {
						str = stringForIP(tAddress);
						range = [resultString rangeOfString:str];
						if (range.length == 0) [resultString appendFormat:@"%@\r",str];
					}
					else if (type == AF_INET6) {
						str = stringForIP6(&tAddress6, kOptionDefault);
						range = [resultString rangeOfString:str];
						if (range.length == 0) [resultString appendFormat:@"%@\r",str];
					}
				}
				//if (![resultString length]) [resultString appendString:[resultArray componentsJoinedByString:@" "]];
			}
			CFRelease(dnrCFHost);
            if ([resultString length]) {
				[self updateParameter:@"elapsedInfo" withObject:[NSString stringWithFormat:@"%1.3f",-[startTime timeIntervalSinceNow]]];
                [self updateParameter:kStatusInfo withObject:@""];
                if (resultString) [self updateParameter:kResultField withObject:resultString];
            }
			else {
				[self updateParameter:kStatusInfo withObject:NSLocalizedString(@"No address found",@"No address found")];
				[self updateParameter:kNoAddressFound withObject:NSLocalizedString(@"No address found",@"No address found")];
			}
        }
    } while (false);
    [self updateParameter:kLookupComplete withObject:@""];
}

@end

