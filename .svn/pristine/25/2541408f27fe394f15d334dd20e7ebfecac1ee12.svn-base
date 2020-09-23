//
//  ExpertViewWC.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Wed Jul 24 2002.
//  Copyright (c) 2001 Sustainable Softworks, Inc. All rights reserved.
//
//  Encapsulate IPNetSentryX/IPNetRouterX document as part of MVC design.
//
//  ExpertViewWC displays the current model and interprets user input to change model state.
//  SentryState maintains the model state and notifies observers when it changes.
//  SentryModel observes state changes and performs the corresponding model action.
//
//  ExpertViewWC plays two basic roles:
//  (1) receive state change notifications from SentryState and update
//  	the displayed state accordingly;
//  (2) interpret user input and call SentryState to modify the
//		model state accordingly.

#import <Cocoa/Cocoa.h>
#import "SentryWC.h"
@class FilterTable;
@class FilterEntry;
@class PSPropertyValue;
@class IPNetMessage;
@class SentryState;
@class SentryLogger;

@interface ExpertViewWC : SentryWC
{
	IBOutlet	NSButton*	applyButton;
    IBOutlet	NSButton*	firewallOnCheckBox;
	IBOutlet	NSTabView*	tabView;
	IBOutlet	NSButton*		logDrawerButton;
	IBOutlet	NSTextField*	statusInfo;
	IBOutlet	NSDrawer*		logDrawer;
    IBOutlet	NSTextView*		logTextView;
	IBOutlet	NSScrollView*   logScrollView;
	// table cells
	IBOutlet	NSButton*	ruleEnabledCheckBox;
    IBOutlet	NSPopUpButton* propertyPopUp;
    IBOutlet	NSPopUpButton* relationPopUp;
    IBOutlet	NSPopUpButton* actionPopUp;
//    IBOutlet	NSComboBox* valueComboBox;
	// interface table
	IBOutlet	NSTableView*	interfaceTableView;
	IBOutlet	NSButton*		firewallCheckBox;
	IBOutlet	NSButton*		externalCheckBox;
	IBOutlet	NSButton*		bridgeCheckBox;
#ifdef IPNetRouter
	IBOutlet	NSButton*		natCheckBox;
	IBOutlet	NSTextField*	excludeNetField;
	IBOutlet	NSButton*		ipForwarding;
	// portMap table
	IBOutlet	NSTableView*	portMapTableView;
	IBOutlet	NSButton*		portMapOnButton;
//		IBOutlet	NSComboBox*		portMapDynamicCombo;
//		IBOutlet	NSComboBox*		portMapApparentAddressCombo;
//		IBOutlet	NSComboBox*		portMapApparentPortCombo;
//		IBOutlet	NSComboBox*		portMapActualPortCombo;
//		IBOutlet	NSComboBox*		portMapProtocolCombo;
	IBOutlet	NSButton*		portMapLocalProxyButton;	
	IBOutlet	NSPopUpButton*	exposedHostPopUp;
	IBOutlet	NSTextField*	exposedHostField;
	IBOutlet	NSButton*		portMapLogging;
	IBOutlet	NSButton*		unregisteredOnly;
#endif	
	// filter table
    IBOutlet	NSOutlineView*	outlineViewOutlet;
	IBOutlet	NSPopUpButton*	parameterPopUp;
	IBOutlet	NSButton*		newButton;
    IBOutlet	NSButton*		deleteButton;
	IBOutlet	NSButton*		toggleSiblingChildButton;
	IBOutlet	NSButton*		blockIPv6CheckBox;
	IBOutlet	NSTextField*	ruleCount;
    // trigger table
	IBOutlet	NSTableView*	triggerTableView;
	IBOutlet	NSButton*		triggerDeleteButton;
	IBOutlet	NSPopUpButton*  triggerDefaultDuration;
	IBOutlet	NSPopUpButton*  triggerDuration;
	IBOutlet	NSPopUpButton*  triggerType;

	SentryLogger*   sentryLogger;
    BOOL			createChild;
    PSPropertyValue* valueData;	// data source for value ComboBox
	SentryState*	sentryState;
}

- (ExpertViewWC *)init;

- (id)outlineViewOutlet;	// return outlineView for access from dataSource
- (id)valueData;			// return valueData for access from dataSource
- (id)selectProperty:(int)propertyID;	// call through for data source
- (int)indexOfSelectedParameter;

- (void)saveState;
- (void)showDocument;
#if 0
- (BOOL)readFromFile:(NSString *)filePath;
#endif

// log drawer and help
- (void)appendString:(NSString *)string;
- (void)historyClear:(id)sender;
- (IBAction)logDrawer:(id)sender;
- (int)logDrawerState;
- (void)setLogDrawerState:(int)inState;
- (IBAction)myHelp:(id)sender;
// copy and paste
- (void)copy:(id)sender;
- (void)cut:(id)sender;
- (void)paste:(id)sender;
- (void)paste:(NSString *)string toTarget:(FilterEntry *)targetItem childIndex:(int)childIndex;
// NSDocument
- (void)windowDidResignKey:(NSNotification *)aNotification;
- (void)windowWillClose:(NSNotification *)aNotification;
// actions
- (IBAction)firewallOn:(id)sender;
- (IBAction)apply:(id)sender;
- (IBAction)showActive:(id)sender;
- (IBAction)testButton:(id)sender;
- (IBAction)defaultsButton:(id)sender;
- (IBAction)selectParameter:(id)sender;
- (void)receiveNotification:(NSNotification *)aNotification;
// tab view
- (IBAction)tabView:(NSTabView*)view didSelectTabViewItem:(NSTabViewItem*)item;
// interfaces
#ifdef IPNetRouter
- (IBAction)ipForwarding:(id)sender;
- (IBAction)exposedHostPopUp:(id)sender;
- (IBAction)exposedHostField:(id)sender;
- (IBAction)excludeNetField:(id)sender;
- (IBAction)alternateGateways:(id)sender;
#endif
- (IBAction)interfaceList:(id)sender;
// port map
#ifdef IPNetRouter
- (IBAction)portMapNew:(id)sender;
- (IBAction)portMapDelete:(id)sender;
- (IBAction)portMapLogging:(id)sender;
- (IBAction)unregisteredOnly:(id)sender;
#endif
// filters
- (IBAction)new:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)toggleSiblingChild:(id)sender;
- (IBAction)blockIPv6CheckBox:(id)sender;
// trigger
- (IBAction)triggerNew:(id)sender;
- (IBAction)triggerDelete:(id)sender;
- (IBAction)triggerImport:(id)sender;
- (IBAction)triggerDefaultDuration:(id)sender;
- (IBAction)whoisButton:(id)sender;
- (IBAction)traceButton:(id)sender;
- (IBAction)lookupButton:(id)sender;
// outlineView delegate methods
- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification;
- (void)outlineViewItemDidExpand:(NSNotification *)notification;
- (void)outlineViewItemDidCollapse:(NSNotification *)notification;

@end

#define kExpertViewName	@"ExpertView"
#define kExpertView_open	@"ExpertView_open"
