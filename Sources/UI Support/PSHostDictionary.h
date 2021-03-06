//
//  PSHostDictionary.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on Sun Jan 4 2004.
//  Copyright (c) 2004 Sustainable Softworks. All rights reserved.
//
//  Encapsulates browsing for a host name for an IP address

#import <Foundation/Foundation.h>


@interface PSHostDictionary : NSObject <NSNetServiceBrowserDelegate> {
    NSNetServiceBrowser* afpServiceBrowser;
	NSNetServiceBrowser* httpServiceBrowser;
	NSMutableArray* discoveredServices;
	NSMutableDictionary* hostNames;
	NSDate* lastUpdate;
	BOOL inProgress;
}
+ (PSHostDictionary *)sharedInstance; // returns a shared instance of the class
- (NSString *)hostNameForAddress:(NSString *)address;
- (NSDictionary *)hostNames;
- (void)startUpdate;
- (void)stopUpdate;

#pragma mark --- NSNetServieceBrowser delegate methods ---
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict;
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser;
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser;
// NSNetService delegate methods
- (void)netServiceDidResolveAddress:(NSNetService *)sender;
@end
