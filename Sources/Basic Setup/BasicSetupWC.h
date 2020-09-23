//
// BasicSetup.h
// IPNetSentryX
//
// Created by Peter Sichel on 9/20/05.
// Copyright (c) 2005 Sustainable Softworks. All rights reserved.
//
// Drive basic setup view of firewall configuration

#import <Cocoa/Cocoa.h>
#import "SentryWC.h"
@class NSDatePicker;

@interface BasicSetupWC : SentryWC
{
	// Window controls
    IBOutlet NSButton *firewallStart;
    IBOutlet NSTextField *firewallStatus;
    IBOutlet NSButton *firewallShowActive;
    IBOutlet NSButton *firewallApply;
    IBOutlet NSTextField *statusInfo;
	// Firewall Setting
    IBOutlet NSTableView *firewallSettingTableView;
	IBOutlet NSTabView *firewallSettingTabView;
	
	// Interfaces
    IBOutlet NSPopUpButton *interfaceSelect;	
    IBOutlet NSTextField *interfaceUsing;	// with automatic
	
	// Filter Styles
    IBOutlet NSTableView *filterStyleTableView;
    IBOutlet NSTableView *filterTypeTableView;
	IBOutlet NSTabView *filterStyleTabView;
    IBOutlet NSPopUpButton *filterStyleContinueWith;
	// Style Blacklist
    IBOutlet NSPopUpButton *blacklistDuration;
	// Style Deny
	// Style Deny by address
    IBOutlet NSTableView *denyByAddressTable;
	// Style Deny by content
    IBOutlet NSTextField *denyByContentLookField;
    IBOutlet NSButton *denyByContentLookFor;
    IBOutlet NSButton *denyByContentSearchRelative;
    IBOutlet NSTextField *denyByContentStartOffset;
    IBOutlet NSTextField *denyByContentStopOffset;
    IBOutlet NSTextField *denyByContentURLField;
    IBOutlet NSButton *denyByContentURLKeyword;	
	// Style Allow by address
    IBOutlet NSTableView *allowByAddressTable;
	// Style Allow by time
    IBOutlet NSDatePicker *allowByTimeAfterDate;
    IBOutlet NSDatePicker *allowByTimeUntilDate;
    IBOutlet NSButton *allowByTimeAfter;
    IBOutlet NSButton *allowByTimeDayF;
    IBOutlet NSButton *allowByTimeDayM;
    IBOutlet NSButton *allowByTimeDayS;
    IBOutlet NSButton *allowByTimeDaySa;
    IBOutlet NSButton *allowByTimeDayT;
    IBOutlet NSButton *allowByTimeDayTh;
    IBOutlet NSButton *allowByTimeDayW;
    IBOutlet NSButton *allowByTimeOfDay;
    IBOutlet NSButton *allowByTimeOfWeek;
    IBOutlet NSButton *allowByTimeUntil;	
	// Style Reserve bandwidth
    IBOutlet NSButton *reserveBandwidthIn;
    IBOutlet NSTextField *reserveBandwidthInAmount;
    IBOutlet NSTextField *reserveBandwidthInTotal;
    IBOutlet NSButton *reserveBandwidthOut;
    IBOutlet NSTextField *reserveBandwidthOutAmount;
    IBOutlet NSTextField *reserveBandwidthOutTotal;
	// Style Limit bandwidth
    IBOutlet NSButton *limitBandwidthIn;
    IBOutlet NSTextField *limitBandwidthInAmount;
    IBOutlet NSButton *limitBandwidthOut;
    IBOutlet NSTextField *limitBandwidthOutAmount;
	// Style Notification
    IBOutlet NSButton *notificationAlert;
    IBOutlet NSButton *notificationAppleScript;
    IBOutlet NSTextField *notificationAppleScriptField;
    IBOutlet NSButton *notificationEmail;
    IBOutlet NSTextField *notificationEmailField;
    IBOutlet NSButton *notificationLog;
	// Style Allow
    IBOutlet NSButton *allowAccessDenyOthers;

	// Services
    IBOutlet NSTableView *serviceTableView;
	IBOutlet NSTableView *serviceEditTableView;
	IBOutlet NSButton* servicesDenyAllOthers;
	
	// Devices
	IBOutlet NSTextField *deviceDirectionPort;
	IBOutlet NSTextField *deviceDirectionAttached;
    IBOutlet NSTextField *deviceHardwareAddress;
    IBOutlet NSTextField *deviceIPAddress;
	IBOutlet NSTextField *deviceName;
    IBOutlet NSPopUpButton *devicePort;
	IBOutlet NSTableView *deviceTableView;
	IBOutlet NSTableView *deviceEditTableView;
    IBOutlet NSTabView *deviceTabView;
	IBOutlet NSTextField *deviceVendor;
	IBOutlet NSButton* devicesDenyAllOthers;
	
	// Options
    IBOutlet NSPopUpButton *optionSelect;
    IBOutlet NSButton *optionOn;
    IBOutlet NSTextView *optionDescription;
    IBOutlet NSTextField *optionValue;

	NSString* myStatus;
}
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

- (void)windowWillClose:(NSNotification *)aNotification;
- (void)saveState;
- (void)showDocument;

- (IBAction)allowByAddressDelete:(id)sender;
- (IBAction)allowByAddressEdit:(id)sender;
- (IBAction)allowByAddressNew:(id)sender;
- (IBAction)denyByAddressDelete:(id)sender;
- (IBAction)denyByAddressEdit:(id)sender;
- (IBAction)denyByAddressNew:(id)sender;

- (IBAction)deviceAdd:(id)sender;
- (IBAction)deviceRemove:(id)sender;
- (IBAction)deviceEdit:(id)sender;

- (IBAction)deviceEditAdd:(id)sender;
- (IBAction)deviceEditRemove:(id)sender;
- (IBAction)deviceEditDone:(id)sender;
- (IBAction)deviceDirection:(id)sender;
- (IBAction)deviceLookup:(id)sender;
- (IBAction)devicePort:(id)sender;
- (IBAction)deviceHardwareAddress:(id)sender;
- (IBAction)deviceConfigure:(id)sender;

- (IBAction)filterStyleConfigure:(id)sender;
- (IBAction)filterStyleEdit:(id)sender;

- (IBAction)firewallApply:(id)sender;
- (IBAction)firewallShowActive:(id)sender;
- (IBAction)firewallStart:(id)sender;

- (IBAction)interfaceSelect:(id)sender;

- (IBAction)limitBandwidthInStep:(id)sender;
- (IBAction)limitBandwidthOutStep:(id)sender;

- (IBAction)myHelp:(id)sender;
- (IBAction)notificationBrowse:(id)sender;

- (IBAction)optionOn:(id)sender;
- (IBAction)optionOpenPreferences:(id)sender;
- (IBAction)optionSelect:(id)sender;
- (IBAction)optionValue:(id)sender;

- (IBAction)reserveBandwidthInStep:(id)sender;
- (IBAction)reserveBandwidthOutStep:(id)sender;

- (IBAction)serviceAdd:(id)sender;
- (IBAction)serviceRemove:(id)sender;
- (IBAction)serviceEdit:(id)sender;
- (IBAction)serviceSortBy:(id)sender;

- (IBAction)serviceEditAdd:(id)sender;
- (IBAction)serviceEditRemove:(id)sender;
- (IBAction)serviceEditDone:(id)sender;

@end

#define kBasicSetupName	@"BasicSetup"
#define kBasicSetup_open @"BasicSetup_open"

#define kFirewallTab_devices @"devices"
#define kFirewallTab_devicesEdit @"devicesEdit"
#define kFirewallTab_services @"services"
#define kFirewallTab_servicesEdit @"servicesEdit"
