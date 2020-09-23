//
//  AlternateRouteWC.h
//  IPNetRouterX
//
//  Created by psichel on Wed Jan 3 2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Window controller for Alternate Route table and settings

#import <Cocoa/Cocoa.h>
@class AlternateRouteModel;
@class SentryState;

@interface AlternateRouteWC : NSWindowController
{
    IBOutlet NSButton *applyButton;
    IBOutlet NSButton *automaticFailover;
    IBOutlet NSButton *loadBalance;
    IBOutlet NSButton *sourceAwareRouting;
    IBOutlet NSTextField *statusInfo;
    IBOutlet NSTableView *tableView;
	
	AlternateRouteModel *model;
	SentryState *sentryState;
}
- (IBAction)addGateway:(id)sender;
- (IBAction)removeGateway:(id)sender;

- (IBAction)automaticFailover:(id)sender;
- (IBAction)loadBalance:(id)sender;
- (IBAction)sourceAwareRouting:(id)sender;

- (IBAction)saveButton:(id)sender;
- (IBAction)revertButton:(id)sender;
- (IBAction)applyButton:(id)sender;

- (IBAction)myHelp:(id)sender;
@end

#define kAlternateRouteName		@"AlternateRoute"
#define kAlternateRoute_open	@"AlternateRoute_open"
