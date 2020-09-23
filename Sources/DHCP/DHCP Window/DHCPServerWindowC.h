//
//  DHCPServerWindowC.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Tue Nov 18 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DHCPTable.h"
@class DHCPState;
@class DHCPLogger;
@class DHCPController;

@interface DHCPServerWindowC : NSWindowController
{
    IBOutlet NSButton *applyButton;
	IBOutlet NSButton *dhcpRevert;
    IBOutlet NSButton *dhcpSave;
    IBOutlet NSButton *dhcpServerOn;
    IBOutlet NSTabView *tabView;
	IBOutlet NSButton *logDrawerButton;
    IBOutlet NSTextField *statusInfo;
	IBOutlet NSComboBox *networkInterfaceCombo;
	IBOutlet NSButton *dhcpOnCheckBox;
	// status table
    IBOutlet NSTableView *statusTableView;
    IBOutlet NSButton *statusTableDelete;
	IBOutlet NSPopUpButton *leaseStatePopUp;
	// static config table
    IBOutlet NSTableView *staticConfigTableView;
    IBOutlet NSButton *staticConfigTableDelete;
    IBOutlet NSButton *staticConfigTableNew;
	// dynamic config table
    IBOutlet NSTableView *dynamicConfigTableView;
    IBOutlet NSButton *dynamicConfigTableDelete;
    IBOutlet NSButton *dynamicConfigTableNew;
	// lease options table
    IBOutlet NSTableView *leaseOptionsTableView;
    IBOutlet NSButton *leaseOptionsTableDelete;
    IBOutlet NSButton *leaseOptionsTableNew;
	IBOutlet NSTextField *defaultLeaseTimeField;
	IBOutlet NSTextField *maxLeaseTimeField;
	IBOutlet NSTextField *searchDomainsField;
	IBOutlet NSPopUpButton *defaultLeaseTimeUnitPopUp;
	IBOutlet NSPopUpButton *maxLeaseTimeUnitPopUp;
	IBOutlet NSTextField *hostNameServerInfo;
	// server options table
    IBOutlet NSTableView *serverOptionsTableView;
    IBOutlet NSButton *serverOptionsTableDelete;
    IBOutlet NSButton *serverOptionsTableNew;
	IBOutlet NSPopUpButton *serverOptionsOptionTypePopUp;
	IBOutlet NSTextField *leaseGrantedField;
	IBOutlet NSTextField *leaseNotGrantedField;
	IBOutlet NSPopUpButton *verboseLoggingPopUp;
	IBOutlet NSButton *ignoreBootpCheckBox;
	IBOutlet NSButton *dynamicBootpCheckBox;
	IBOutlet NSButton *pingCheckCheckBox;
	
	IBOutlet NSDrawer   *logDrawer;
    IBOutlet NSTextView *logTextView;
	IBOutlet NSScrollView *logScrollView;
	DHCPController* controller;
	DHCPLogger* dhcpLogger;
}
- (void)awakeFromNib;
- (void)reloadStatusTable;
- (void)statusScrollRowToVisible:(int)index;
- (void)reloadStaticConfigTable;
- (void)reloadDynamicConfigTable;
- (void)reloadLeaseOptionsTable;
- (void)reloadServerOptionsTable;
- (void)reloadControllerState;
- (void)windowWillClose:(NSNotification *)aNotification;

// Logistics
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;
- (void)receiveDictionary:(NSDictionary *)dictionary;
- (void)copy:(id)sender;
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
// log drawer and help
- (void)loggerNotification:(NSNotification *)aNotification;
- (IBAction)logDrawer:(id)sender;
- (IBAction)myHelp:(id)sender;

// DHCP controls
- (IBAction)dhcpServerOn:(id)sender;
- (IBAction)dhcpShowActive:(id)sender;
- (IBAction)dhcpApply:(id)sender;
- (IBAction)dhcpUseDefaults:(id)sender;
- (IBAction)dhcpSave:(id)sender;
// status
- (IBAction)statusTableDelete:(id)sender;
- (IBAction)statusTableNew:(id)sender;
// static config
- (IBAction)staticConfigTableNew:(id)sender;
- (IBAction)staticConfigTableDelete:(id)sender;
- (IBAction)staticConfigImport:(id)sender;
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
- (IBAction)staticConfigExport:(id)sender;
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
// dynamic config
- (IBAction)dynamicConfigTableNew:(id)sender;
- (IBAction)dynamicConfigTableDelete:(id)sender;
// lease options
- (IBAction)leaseOptionsTableNew:(id)sender;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (void)displayDefaultLeaseTime:(int)leaseTime;
- (void)displayMaxLeaseTime:(int)leaseTime;
- (IBAction)leaseOptionsTableDelete:(id)sender;
- (IBAction)leaseTimeUnit:(id)sender;
- (IBAction)editLeaseOptions:(id)sender;
	// edit fields
- (IBAction)defaultLeaseTimeField:(id)sender;
- (IBAction)maxLeaseTimeField:(id)sender;
- (IBAction)searchDomainsField:(id)sender;
- (IBAction)leaseGrantedField:(id)sender;
- (IBAction)leaseNotGrantedField:(id)sender;
// server options
- (IBAction)serverOptionsTableNew:(id)sender;
- (IBAction)serverOptionsTableDelete:(id)sender;
- (IBAction)verboseLogging:(id)sender;
- (IBAction)ignoreBootp:(id)sender;
- (IBAction)dynamicBootp:(id)sender;
- (IBAction)pingCheck:(id)sender;
@end

#define kDHCPServerName			@"DHCPServer"
#define kDHCPServer_open		@"DHCPServer_open"
#define kDHCPServer_logDrawerOpen   @"DHCPServer_logDrawerOpen"
#define kDHCPServer_logDrawerSize   @"DHCPServer_logDrawerSize"

#define kDHCPServer_importFilePath @"DHCPServer_importFilePath"
