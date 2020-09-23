//
//  RouteWindowC.h
//  IPNetRouterX
//
//  Created by psichel on Wed Jun 8 2004.
//  Copyright (c) 2004 Sustainable Softworks. All rights reserved.

#import <Cocoa/Cocoa.h>
#import "PSServerInterface.h"
@class RouteServer;

#import <Cocoa/Cocoa.h>
@class RouteServer;
@class RouteTable;
@class ArpTable;

@interface RouteWindowC : NSWindowController
{
    IBOutlet NSTabView *tabView;
	IBOutlet NSButton *restoreCB;
	// routes
    IBOutlet NSButton    *routeListButton;
    IBOutlet NSPopUpButton *routeTypePopUp;
	IBOutlet NSTextField *routeDestinationField;
    IBOutlet NSTextField *routeGatewayField;
	IBOutlet NSPopUpButton *routeNetworkPortPopUp;
	IBOutlet NSButton    *routeStaticButton;
    IBOutlet NSTableView *routeTableView;
	// arp
    IBOutlet NSButton    *arpListButton;
	IBOutlet NSTextField *arpIPAddressField;
    IBOutlet NSTextField *arpHWAddressField;
	IBOutlet NSPopUpButton *arpNetworkPortPopUp;
	IBOutlet NSButton    *arpPermanentButton;
	IBOutlet NSButton    *arpPublishButton;
	IBOutlet NSButton    *arpProxyButton;
    IBOutlet NSTableView *arpTableView;
	
    IBOutlet NSTextField *statusInfo;
}
- (void)setRouteDataSource:(RouteTable *)value;
- (void)setArpDataSource:(ArpTable *)value;
// actions
- (IBAction)routeListButton:(id)sender;
- (IBAction)routeAddButton:(id)sender;
- (IBAction)routeChangeButton:(id)sender;
- (IBAction)routeDeleteButton:(id)sender;

- (IBAction)arpListButton:(id)sender;
- (IBAction)arpAddButton:(id)sender;
- (IBAction)arpDeleteButton:(id)sender;
// help
- (IBAction)myHelp:(id)sender;
// events
- (BOOL)updateParameter:(NSString *)name withObject:(id)object;
- (oneway void)receiveDictionary:(NSDictionary *)dictionary;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
@end

#define kRouteName	@"Route"
#define kRoute_open @"Route_open"
