//
//  DHCPServerWindowC.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Tue Nov 18 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
#import "DHCPServerWindowC.h"
#import "DocumentSupport.h"
#import "DHCPState.h"
//#import "DHCPTable.h"
//#import "DHCPAction.h"
#import "DHCPController.h"
//#import "DHCPServer.h"
#import "DHCPLogger.h"
#import "DHCPSupport.h"

#import "AppDelegate.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "InterfaceEntry.h"
#import "InterfaceTable.h"
#import "kftSupport.h"
#import "IPValue.h"
#import "IPSupport.h"
#import "SystemConfiguration.h"
#import "PSSharedDictionary.h"
#import "SentryDocument.h"

#define preferences [NSUserDefaults standardUserDefaults]

@interface DHCPServerWindowC (PrivateMethods)
- (void)appendString:(NSString *)string;
- (int)logDrawerState;
- (void)setLogDrawerState:(int)inState;
@end

@implementation DHCPServerWindowC
- init
{
    if (self = [super init]) {
        // initialize instance vars
		// use awakeFromNib
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	// use windowWillClose
    [super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ awakeFromNib
// ---------------------------------------------------------------------------------
- (void)awakeFromNib
{
	NSTableColumn *tableColumn;
	controller = [DHCPController sharedInstance];
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
    // initialize controls in the window
	// dhcpLogger
	dhcpLogger = [DHCPLogger sharedInstance];
    [logTextView setRichText:NO];
	// setup to receive Event Log messages
	[dhcpLogger addObserver:self withSelector:@selector(loggerNotification:)];
	// get network Interface list
	{
		NSArray* interfaceArray;
		InterfaceEntry* interfaceE;
		NSEnumerator* en;
		NSString* title;
		
		[networkInterfaceCombo removeAllItems];
		[networkInterfaceCombo setBordered:NO];
		interfaceArray = [[InterfaceTable sharedInstance] interfaceArray];
		en = [interfaceArray objectEnumerator];
		while (interfaceE = [en nextObject]) {
			if ([[interfaceE bsdName] isEqualTo:@"lo0"]) continue;
			title = [interfaceE ifNet];
			if ( !isDigit([title UTF8String][0]) ) continue;
			[networkInterfaceCombo addItemWithObjectValue:title];
		}
	}
	// status table
	tableColumn = [statusTableView tableColumnWithIdentifier:DS_leaseState];
    [tableColumn setDataCell:[leaseStatePopUp cell]];
	// static config table
	tableColumn = [staticConfigTableView tableColumnWithIdentifier:DS_networkInterface];
    [tableColumn setDataCell:[networkInterfaceCombo cell]];
	// dynamic config table
	tableColumn = [dynamicConfigTableView tableColumnWithIdentifier:DS_networkInterface];
    [tableColumn setDataCell:[networkInterfaceCombo cell]];
	// lease options table
	tableColumn = [leaseOptionsTableView tableColumnWithIdentifier:DS_networkInterface];
    [tableColumn setDataCell:[networkInterfaceCombo cell]];
	tableColumn = [leaseOptionsTableView tableColumnWithIdentifier:DS_dhcpOn];
	[tableColumn setDataCell:[dhcpOnCheckBox cell]];
	// server options
	tableColumn = [serverOptionsTableView tableColumnWithIdentifier:DS_dhcpOptionType];
	[tableColumn setDataCell:[serverOptionsOptionTypePopUp cell]];

	// tell DHCPController to talk to us
	[controller setCallbackTarget:self];
	// check if DHCP Server is already running
	// if yes, show that state and refresh
	[controller connectToExistingServer:2 showActive:YES];

	// display current state
	// notice any state we read in should already have been applied to the DHCPController
	// and server if enabled when IPNRx or document was opened
	[self reloadControllerState];

	// preferences
	NSNumber* num = [preferences objectForKey:kDHCPServer_logDrawerOpen];
	if (num) [self setLogDrawerState:[num intValue]];
	num = [preferences objectForKey:kDHCPServer_logDrawerSize];
	if (num) {
		NSSize size;
		size.height = [num intValue];
		size.width = 0;
		[logDrawer setContentSize:size];
	}
}

// ---------------------------------------------------------------------------------
//	¥ reloadStatusTable
// ---------------------------------------------------------------------------------
- (void)reloadStatusTable
{
	[statusTableView reloadData];
}
- (void)statusScrollRowToVisible:(int)index
{
	if (index >= 0) [statusTableView scrollRowToVisible:index];
}
- (void)reloadStaticConfigTable
{
	[staticConfigTableView reloadData];
}
- (void)reloadDynamicConfigTable
{
	[dynamicConfigTableView reloadData];
}
- (void)reloadLeaseOptionsTable
{
	[leaseOptionsTableView reloadData];
}
- (void)reloadServerOptionsTable
{
	[serverOptionsTableView reloadData];
}

// ---------------------------------------------------------------------------------
//	¥ reloadControllerState
// ---------------------------------------------------------------------------------
- (void)reloadControllerState {
	DHCPState *dhcpState = [controller dhcpState];
	// Update controls in window to reflect new state
	NSString* str;
	NSNumber* num;
	DHCPLeaseOptionsEntry* leaseOptionsE;
	// set delegate for DHCP state (so window can be notified when data changes)
	[dhcpState setDelegate:self];
    
    // set data source for tableviews
	[statusTableView		setDataSource:[dhcpState statusTable]];
	[staticConfigTableView  setDataSource:[dhcpState staticConfigTable]];
	[dynamicConfigTableView setDataSource:[dhcpState dynamicConfigTable]];
	[leaseOptionsTableView  setDataSource:[dhcpState leaseOptionsTable]];
	[serverOptionsTableView setDataSource:[dhcpState serverOptionsTable]];
	
	// other dhcp controls
	if ((str = [dhcpState grantedMessage])) [leaseGrantedField setStringValue:str];
	if ((str = [dhcpState notGrantedMessage])) [leaseNotGrantedField setStringValue:str];
	[verboseLoggingPopUp setObjectValue:[dhcpState verboseLogging]];
	[ignoreBootpCheckBox setIntValue:[[dhcpState ignoreBootp] intValue]];
	[dynamicBootpCheckBox setIntValue:[[dhcpState dynamicBootp] intValue]];
	[pingCheckCheckBox setIntValue:[[dhcpState pingCheck] intValue]];
	[leaseOptionsTableView selectRow:0 byExtendingSelection:NO];
	
	if ([[dhcpState leaseOptionsTable] count]) {
		leaseOptionsE = [[dhcpState leaseOptionsTable] objectAtIndex:0];
		if ((num = [leaseOptionsE defaultLeaseTime])) {
			[defaultLeaseTimeField setIntValue:[num intValue]];
			[self displayDefaultLeaseTime:[num intValue]];
		}
		if ((num = [leaseOptionsE maxLeaseTime])) {
			[maxLeaseTimeField setIntValue:[num intValue]];
			[self displayMaxLeaseTime:[num intValue]];
		}
		if ((str = [leaseOptionsE searchDomains]))
			[searchDomainsField setStringValue:str];
		[self leaseTimeUnit:nil];
	}
}

// ---------------------------------------------------------------------------------
//	¥ windowWillClose
// ---------------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification;
{    
    NSWindow* theWindow;

	// No longer want to receive DHCP Log messages
	[dhcpLogger removeObserver:self];

	// remove ourself as delegate for DHCP Controller
	[controller setCallbackTarget:nil];
	// remove ourself as delegate for status table
	[[[controller dhcpState] statusTable] setDelegate:nil];

	// remove data sources from table views
	[statusTableView		setDataSource:nil];
	[staticConfigTableView  setDataSource:nil];
	[dynamicConfigTableView setDataSource:nil];
	[leaseOptionsTableView  setDataSource:nil];
	[serverOptionsTableView setDataSource:nil];
		
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kDHCPServerName];
    // remember preferences
	[preferences setObject:[NSNumber numberWithInt:[self logDrawerState]] forKey:kDHCPServer_logDrawerOpen];
	NSSize size = [logDrawer contentSize];
	[preferences setObject:[NSNumber numberWithInt:size.height] forKey:kDHCPServer_logDrawerSize];
    // release ourself
    [self autorelease];
}

#pragma mark -- logistics --
// delegate method for when table entries are updated via local UI
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
	if ([name isEqualTo:DS_statusEntry]) {
		DHCPStatusEntry* statusE = anObject;
		// update DHCP Server status
		[statusE setAction:[NSNumber numberWithInt:kActionUpdate]];		
		[controller dhcpApply:[NSDictionary dictionaryWithObjectsAndKeys:
				statusE, DS_statusEntry,
				nil]];
		[statusTableView reloadData];
	}
	else if ([name isEqualTo:DS_staticConfigEntry]) {
		[staticConfigTableView reloadData];
	}
	else if ([name isEqualTo:DS_dynamicConfigEntry]) {
		[dynamicConfigTableView reloadData];
	}
	else if ([name isEqualTo:DS_leaseOptionsEntry]) {
		[leaseOptionsTableView reloadData];
	}
	else if ([name isEqualTo:DS_serverOptionsEntry]) {
		[serverOptionsTableView reloadData];
	}
	else if ([name isEqualTo:DS_applyPending]) {
		if ([anObject intValue]) [applyButton setEnabled:YES];
		else [applyButton setEnabled:NO];
	}
	return YES;
}

// ---------------------------------------------------------------------------
//	¥ receiveDictionary
// ---------------------------------------------------------------------------
// Receive DHCPServer status updates
// Update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
{
	NSEnumerator *en = [dictionary keyEnumerator];
	id key;
	id object;

	while ((key = [en nextObject])) { 
		// code that uses the returned key
		if (![key isKindOfClass:[NSString class]]) continue; 
		object = [dictionary objectForKey:key];
		if (([object isKindOfClass:[NSString class]]) &&
			([@"nil" isEqualTo:object])) object = nil;
		// status
		if ([key isEqualTo:@"statusInfo"])	{
			[statusInfo setStringValue:object];
		}
		else if ([key isEqualTo:@"statusInfoAppend"]) {
			NSString* str;
			str = [[statusInfo stringValue] stringByAppendingString:object];
			[statusInfo setStringValue:str];
		}
		
		// individual states
		else if ([key isEqualTo:DS_dhcpServerOn]) {
			// record actual state from server
			[dhcpServerOn setIntValue:[object intValue]];
		}
		else if ([key isEqualTo:DS_verboseLogging]) {
			[verboseLoggingPopUp setObjectValue:object];
		}
		else if ([key isEqualTo:DS_ignoreBootp]) {
			[ignoreBootpCheckBox setIntValue:[object intValue]];
		}
		else if ([key isEqualTo:DS_dynamicBootp]) {
			[dynamicBootpCheckBox setIntValue:[object intValue]];
		}
		else if ([key isEqualTo:DS_pingCheck]) {
			[pingCheckCheckBox setIntValue:[object intValue]];
		}
		else if ([key isEqualTo:DS_grantedMessage]) {
			if (!object) object = @"";
			[leaseGrantedField setStringValue:object];
		}
		else if ([key isEqualTo:DS_notGrantedMessage]) {
			if (!object) object = @"";
			[leaseNotGrantedField setStringValue:object];
		}
		else if ([key isEqualTo:DS_hostDNS]) {
			if ([object isKindOfClass:[NSString class]]) [hostNameServerInfo setStringValue:object];
		}
		else if ([key isEqualTo:DS_changeDone]) {
			// DHCP state has been edited, note document has changed accordingly
			[[self document] updateChangeCount:NSChangeDone];
		}		
		//[[SentryModel sharedInstance] updateChangeCount:NSChangeDone];		
	}	// while ((key = [enumerator nextObject]))
}

// ---------------------------------------------------------------------------
//	¥ copy
// ---------------------------------------------------------------------------
// Edit->Copy selection to clipboard
- (void)copy:(id)sender {
    NSEnumerator* en;
    NSNumber* rowNumber;
    DHCPStatusTable* data;
    DHCPStatusEntry* entry;
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	NSMutableString * tString;

	[pboard declareTypes:[NSArray arrayWithObjects:NSTabularTextPboardType,NSStringPboardType,nil] owner:nil];
    tString = [[NSMutableString alloc] initWithCapacity:1024];
    // setup access to each selected row
    data = [statusTableView dataSource];
    en = [statusTableView selectedRowEnumerator];
    while ((rowNumber = [en nextObject])) {
        if ([rowNumber intValue] == 0) {
            // include headings with first row
            [tString appendString:[NSString stringWithFormat:@"\nIP Address \t State \t Last Update \t Expire Time \t Hardware Address \t Client ID"]];        
        }
        entry = [data objectAtIndex:[rowNumber intValue]];
        [tString appendString:@"\n"];
        [tString appendString:[entry description]];
    }
    [pboard setString:tString forType: NSTabularTextPboardType];
    [pboard setString:tString forType: NSStringPboardType];
    [tString release];
}

// ---------------------------------------------------------------------------
//	¥ selectionShouldChangeInTableView
// ---------------------------------------------------------------------------
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView
{
	BOOL returnValue = YES;
	NSEventType type = [[NSApp currentEvent] type];
	// don't jump to top of table for Enter or Return
	if (type == NSKeyDown) {
		u_int16_t keyCode = [[NSApp currentEvent] keyCode];
		if (keyCode == 76) returnValue = NO;	// Enter
		else if (keyCode == 36) {   // Return
			int selected = [aTableView selectedRow];
			int lastRow = [(PSArrayTable *)[aTableView dataSource] count] - 1;
			if (selected == lastRow) returnValue = NO;
			//NSLog(@"selectionShouldChangeInTableView selected = %d lastRow = %d", selected, lastRow);
		}
	}
	//NSLog(@"selectionShouldChangeInTableView type = %d code = %d", type, keyCode);
	return returnValue;
}

#pragma mark -- log drawer and help --

// ---------------------------------------------------------------------------
//	¥ loggerNotification
// ---------------------------------------------------------------------------
- (void)loggerNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;

	if ([logDrawer state] != NSDrawerClosedState) {
		dictionary = [aNotification userInfo];
		[self appendString:[dictionary objectForKey:DHCPLoggerNotification]];
	}
}

#define END_RANGE NSMakeRange([[logTextView string] length], 0)
- (void)appendString:(NSString *)inString
{
    [logTextView replaceCharactersInRange:END_RANGE withString:inString];
	// scroll for update
	if ([logDrawer state] == NSDrawerOpenState) {
		NSRect bounds;
		NSRect visible;
		bounds = [[logScrollView documentView] bounds];
		visible = [logScrollView documentVisibleRect];
		if (visible.origin.y+visible.size.height+20 >= bounds.size.height) {
			[logTextView scrollRangeToVisible:END_RANGE];
		}
	}
}

// ---------------------------------------------------------------------------
// ¥ logDrawer
// ---------------------------------------------------------------------------
- (IBAction)logDrawer:(id)sender
{
	int state = [logDrawer state];
	
	if (state == NSDrawerClosedState) {
		[logDrawer open];
		// display existing text if any
		[logTextView setString:[dhcpLogger string]];
	}
	else if (state == NSDrawerOpenState) {
		[logDrawer close];
		// release existing text if any
		[logTextView setString:@""];
	}
}
- (int)logDrawerState { return [logDrawer state]; }
- (void)setLogDrawerState:(int)inState
{
	int state = [logDrawer state];
	
	if ((state == NSDrawerClosedState) && (inState == NSDrawerOpenState)) {
		[logDrawer open];
		[logDrawerButton setIntValue:1];
		// display existing text if any
		[logTextView setString:[dhcpLogger string]];
	}
	else if ((state == NSDrawerOpenState) && (inState == NSDrawerClosedState)) {
		[logDrawer close];
		[logDrawerButton setIntValue:0];
		// release existing text if any
		[logTextView setString:@""];
	}
	else {
		if (inState == NSDrawerOpenState) [logDrawerButton setIntValue:1];
	}
}

// ---------------------------------------------------------------------------------
//	¥ myHelp
// ---------------------------------------------------------------------------------
- (IBAction)myHelp:(id)sender
{
    NSString *filePath;
	NSURL *fileURL;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    
    if ((filePath = [thisBundle pathForResource:@"DHCPServerHelp" ofType:@"html" inDirectory:@"IPNetRouterX Help/html"]))
		if ((fileURL = [NSURL fileURLWithPath:filePath]))
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
}


#pragma mark -- DHCP controls --
// ---------------------------------------------------------------------------
//	¥ dhcpServerOn
// ---------------------------------------------------------------------------
- (IBAction)dhcpServerOn:(id)sender
{
	if (![controller dhcpServerOn:[sender intValue]]) {
		// could not connect server, toggle button to off
		[dhcpServerOn setIntValue:0];
	}
}

// ---------------------------------------------------------------------------
//	¥ dhcpApply
// ---------------------------------------------------------------------------
- (IBAction)dhcpApply:(id)sender
{
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// apply our state
	[controller dhcpApply:nil];
	// clear applyPending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:0]];
}

// ---------------------------------------------------------------------------
//	¥ dhcpShowActive
// ---------------------------------------------------------------------------
- (IBAction)dhcpShowActive:(id)sender
{
	[controller dhcpShowActive];
}

// ---------------------------------------------------------------------------
//	¥ dhcpUseDefaults
// ---------------------------------------------------------------------------
// initialize tables with defaults by removing any previous entries and
// adding a new default entry.
- (IBAction)dhcpUseDefaults:(id)sender
{	
	// DHCP tables
	DHCPState *dhcpState = [controller dhcpState];
	[[dhcpState staticConfigTable] removeAllObjects];
	[staticConfigTableView deselectAll:sender];
	[staticConfigTableView reloadData];
	//[self staticConfigTableNew:self];
	
	[[dhcpState dynamicConfigTable] removeAllObjects];
	[dynamicConfigTableView deselectAll:sender];
	[dynamicConfigTableView reloadData];
	[self dynamicConfigTableNew:self];
	
	[[dhcpState leaseOptionsTable] removeAllObjects];
	[leaseOptionsTableView deselectAll:sender];
	[leaseOptionsTableView reloadData];
	[self leaseOptionsTableNew:self];
	
	[[dhcpState serverOptionsTable] removeAllObjects];
	[serverOptionsTableView deselectAll:sender];
	[serverOptionsTableView reloadData];
	//[self serverOptionsTableNew:self];
	
	// DHCP state
	[dhcpState setIgnoreBootp:[NSNumber numberWithInt:0]];
	[dhcpState setDynamicBootp:[NSNumber numberWithInt:1]];
	[dhcpState setPingCheck:[NSNumber numberWithInt:1]];
	[dhcpState setVerboseLogging:[NSNumber numberWithInt:0]];
}

// ---------------------------------------------------------------------------
//	¥ saveButton
// ---------------------------------------------------------------------------
// save active settings
- (IBAction)dhcpSave:(id)sender
{
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// save entire document
	[[AppDelegate sharedInstance] saveDocument:self];
		// calls [DocumentSupport saveState] which does [DocumentSupport dhcpSaveState]
	[statusInfo setStringValue:@"DHCP settings saved"];
}

#pragma mark - statusTable -
// ---------------------------------------------------------------------------
//	¥ statusTableNew
// ---------------------------------------------------------------------------
- (IBAction)statusTableNew:(id)sender
{
}

// ---------------------------------------------------------------------------
//	¥ statusTableDelete
// ---------------------------------------------------------------------------
- (IBAction)statusTableDelete:(id)sender
{	
	DHCPStatusTable* statusT;
	DHCPStatusEntry* statusE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	
	statusT = [statusTableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[statusT count]];
	// gather entries to be deleted before altering indexes
	en = [statusTableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[statusT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (statusE = [en nextObject]) {
		[statusE setAction:[NSNumber numberWithInt:kActionDelete]];		
		//[controller synchStartService:kServerApply
		[controller dhcpApply:[NSDictionary dictionaryWithObjectsAndKeys:
				statusE, DS_statusEntry,
				nil]];
		// remove from local copy
		[statusT removeObject:statusE];
	}
	// refresh tableView
	[statusTableView deselectAll:self];
	[statusTableView reloadData];
	// make sure status table gets saved
	//[controller synchStartService:kServerWriteStatus withObject:nil];
	[controller writeStatus];
}

#pragma mark - staticConfigTable -
// ---------------------------------------------------------------------------
//	¥ staticConfigTableNew
// ---------------------------------------------------------------------------
- (IBAction)staticConfigTableNew:(id)sender
{
	DHCPStaticConfigTable* staticConfigT;
	int selectedRow;

	staticConfigT = [staticConfigTableView dataSource];
	selectedRow = [staticConfigTableView selectedRow];
	selectedRow = [staticConfigT newDefaultEntry:selectedRow];
	// refresh display
	[staticConfigTableView reloadData];
	// sellect new row
	[staticConfigTableView selectRow:selectedRow byExtendingSelection:NO];
	// make sure new row is visible
	[staticConfigTableView scrollRowToVisible:selectedRow];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ staticConfigTableDelete
// ---------------------------------------------------------------------------
- (IBAction)staticConfigTableDelete:(id)sender
{
	DHCPStaticConfigTable* staticConfigT;
	DHCPStaticConfigEntry* staticConfigE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	
	staticConfigT = [staticConfigTableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[staticConfigT count]];
	// gather entries to be deleted before altering indexes
	en = [staticConfigTableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[staticConfigT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (staticConfigE = [en nextObject]) [staticConfigT removeObject:staticConfigE];
	// refresh tableView
	[staticConfigTableView deselectAll:self];
	[staticConfigTableView reloadData];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ staticConfigImport
// ---------------------------------------------------------------------------
- (IBAction)staticConfigImport:(id)sender
{
	NSOpenPanel* panel;
	NSString* directory;
	NSString* filename;

	panel = [NSOpenPanel openPanel];
	if ((directory = [preferences objectForKey:kDHCPServer_importFilePath])) {
		filename = [directory lastPathComponent];
		directory = [directory stringByDeletingLastPathComponent];
	}
	else {
		directory = @"";
		filename = @"";
	}
	// display OpenPanel as window sheet
	[panel beginSheetForDirectory:directory
		file:filename types:nil modalForWindow:[self window]
		modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSFileHandlingPanelOKButton) {
		NSString* str = [panel filename];
		[preferences setObject:str forKey:kDHCPServer_importFilePath];
		if ([str length]) {
			BOOL result = [[DocumentSupport sharedInstance] staticConfigImportFromFile:str];
			if (!result) [statusInfo setStringValue:@"Read from file failed"];
		}
	}
}

// ---------------------------------------------------------------------------
//	¥ staticConfigExport
// ---------------------------------------------------------------------------
- (IBAction)staticConfigExport:(id)sender
{
	NSSavePanel* panel;
	NSString* directory;
	NSString* filename;

	panel = [NSSavePanel savePanel];
	if ((directory = [preferences objectForKey:kDHCPServer_importFilePath])) {
		filename = [directory lastPathComponent];
		directory = [directory stringByDeletingLastPathComponent];
	}
	else {
		directory = @"";
		filename = @"";
	}
	// display SavePanel as window sheet
	[panel beginSheetForDirectory:directory
		file:filename modalForWindow:[self window]
		modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSFileHandlingPanelOKButton) {
		[preferences setObject:[panel filename] forKey:kDHCPServer_importFilePath];
		// perform export if filename given
		NSString* str = [panel filename];
		if ([str length]) {
			BOOL result = [[DocumentSupport sharedInstance] staticConfigExportToFile:str];
			if (!result) {
				[statusInfo setStringValue:@"Write to file failed"];
				NSBeep();
			}
		}
	}
}

#pragma mark - dynamicConfigTable -
// ---------------------------------------------------------------------------
//	¥ dynamicConfigTableNew
// ---------------------------------------------------------------------------
- (IBAction)dynamicConfigTableNew:(id)sender
{
	DHCPDynamicConfigTable* dynamicConfigT;
	int selectedRow;
		
	dynamicConfigT = [dynamicConfigTableView dataSource];
	selectedRow = [dynamicConfigTableView selectedRow];
	selectedRow = [dynamicConfigT newDefaultEntry:selectedRow];
	// refresh display
	[dynamicConfigTableView reloadData];
	// sellect new row
	[dynamicConfigTableView selectRow:selectedRow byExtendingSelection:NO];
	// make sure new row is visible
	[dynamicConfigTableView scrollRowToVisible:selectedRow];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ dynamicConfigTableDelete
// ---------------------------------------------------------------------------
- (IBAction)dynamicConfigTableDelete:(id)sender
{
	DHCPDynamicConfigTable* dynamicConfigT;
	DHCPDynamicConfigEntry* dynamicConfigE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	
	dynamicConfigT = [dynamicConfigTableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[dynamicConfigT count]];
	// gather entries to be deleted before altering indexes
	en = [dynamicConfigTableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[dynamicConfigT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (dynamicConfigE = [en nextObject]) [dynamicConfigT removeObject:dynamicConfigE];
	// refresh tableView
	[dynamicConfigTableView deselectAll:self];
	[dynamicConfigTableView reloadData];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}


#pragma mark - leaseOptionsTable -
// ---------------------------------------------------------------------------
//	¥ leaseOptionsTableNew
// ---------------------------------------------------------------------------
- (IBAction)leaseOptionsTableNew:(id)sender
{
	DHCPLeaseOptionsTable* leaseOptionsT;
	int selectedRow;
	
	leaseOptionsT = [leaseOptionsTableView dataSource];
	selectedRow = [leaseOptionsTableView selectedRow];
	selectedRow = [leaseOptionsT newDefaultEntry:selectedRow];
	// refresh display
	[leaseOptionsTableView reloadData];
	// sellect new row
	[leaseOptionsTableView selectRow:selectedRow byExtendingSelection:NO];
	// make sure new row is visible
	[leaseOptionsTableView scrollRowToVisible:selectedRow];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ tableViewSelectionDidChange
// ---------------------------------------------------------------------------
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	DHCPLeaseOptionsEntry* leaseOptionsE;
	NSString* str;
	int selectedRow;
	int leaseTime;
	if ([aNotification object] == leaseOptionsTableView) {
		// display data from selected entry
		selectedRow = [leaseOptionsTableView selectedRow];
		if (selectedRow >= 0) {
			leaseOptionsE = [[leaseOptionsTableView dataSource] objectAtIndex:selectedRow];
			leaseTime = [[leaseOptionsE defaultLeaseTime] intValue];
			[self displayDefaultLeaseTime:leaseTime];
			leaseTime = [[leaseOptionsE maxLeaseTime] intValue];
			[self displayMaxLeaseTime:leaseTime];
			str = [leaseOptionsE searchDomains];
			if (str) [searchDomainsField setStringValue:str];
			else [searchDomainsField setStringValue:@""];
		}
	}
}

// ---------------------------------------------------------------------------
//	¥ displayDefaultLeaseTime
// ---------------------------------------------------------------------------
- (void)displayDefaultLeaseTime:(int)leaseTime
{
	// > 36 hours, use days
	// > 90 minutes, use hours
	// else use seconds
	if (leaseTime > 129600) {   // 36 hours
		leaseTime = leaseTime/86400;
		[defaultLeaseTimeUnitPopUp selectItemAtIndex:2];
	}
	else if (leaseTime > 5400) {	// 90 minutes
		leaseTime = leaseTime/3600;
		[defaultLeaseTimeUnitPopUp selectItemAtIndex:1];
	}
	else {
		leaseTime = leaseTime/60;
		[defaultLeaseTimeUnitPopUp selectItemAtIndex:0];
	}
	[defaultLeaseTimeField setStringValue:[NSString stringWithFormat:@"%d",leaseTime]];
}

// ---------------------------------------------------------------------------
//	¥ displayMaxLeaseTime
// ---------------------------------------------------------------------------
- (void)displayMaxLeaseTime:(int)leaseTime
{
	// > 36 hours, use days
	// > 90 minutes, use hours
	// else use seconds
	if (leaseTime > 129600) {   // 36 hours
		leaseTime = leaseTime/86400;
		[maxLeaseTimeUnitPopUp selectItemAtIndex:2];
	}
	else if (leaseTime > 5400) {	// 90 minutes
		leaseTime = leaseTime/3600;
		[maxLeaseTimeUnitPopUp selectItemAtIndex:1];
	}
	else {
		leaseTime = leaseTime/60;
		[maxLeaseTimeUnitPopUp selectItemAtIndex:0];
	}
	[maxLeaseTimeField setStringValue:[NSString stringWithFormat:@"%d",leaseTime]];
}
// ---------------------------------------------------------------------------
//	¥ editLeaseOptions
// ---------------------------------------------------------------------------
- (IBAction)editLeaseOptions:(id)sender
{
	DHCPLeaseOptionsEntry* leaseOptionsE;
	int selectedRow;
	int units;
	int value;
	
	selectedRow = [leaseOptionsTableView selectedRow];
	if (selectedRow >= 0) {	
		leaseOptionsE = [[leaseOptionsTableView dataSource] objectAtIndex:selectedRow];
		if (sender == defaultLeaseTimeField) {
			units = [defaultLeaseTimeUnitPopUp indexOfSelectedItem];
			value = [defaultLeaseTimeField intValue];
			if (units == 0) value *= 60;
			else if (units == 1) value *= 3600;
			else if (units == 2) value *= 86400;
			[leaseOptionsE setDefaultLeaseTime:[NSNumber numberWithInt:value]];
			[self displayDefaultLeaseTime:value];
		}
		else if (sender == maxLeaseTimeField) {
			units = [maxLeaseTimeUnitPopUp indexOfSelectedItem];
			value = [maxLeaseTimeField intValue];
			if (units == 0) value *= 60;
			else if (units == 1) value *= 3600;
			else if (units == 2) value *= 86400;
			[leaseOptionsE setMaxLeaseTime:[NSNumber numberWithInt:value]];
			[self displayMaxLeaseTime:value];
		}
		else if (sender == searchDomainsField) {
			[leaseOptionsE setSearchDomains:[searchDomainsField stringValue]];
		}
	}
}
// ---------------------------------------------------------------------------
//	¥ leaseTimeUnit
// ---------------------------------------------------------------------------
- (IBAction)leaseTimeUnit:(id)sender
{
	DHCPLeaseOptionsEntry* leaseOptionsE;
	int selectedRow;
	int value;
	int units;
	selectedRow = [leaseOptionsTableView selectedRow];
	if (selectedRow >= 0) {	
		leaseOptionsE = [[leaseOptionsTableView dataSource] objectAtIndex:selectedRow];
		value = [[leaseOptionsE defaultLeaseTime] intValue];
		units = [defaultLeaseTimeUnitPopUp indexOfSelectedItem];
		if (units == 0) value /= 60;
		else if (units == 1) value /= 3600;
		else if (units == 2) value /= 86400;
		[defaultLeaseTimeField setIntValue:value];
		
		value = [[leaseOptionsE maxLeaseTime] intValue];
		units = [maxLeaseTimeUnitPopUp indexOfSelectedItem];
		if (units == 0) value /= 60;
		else if (units == 1) value /= 3600;
		else if (units == 2) value /= 86400;
		[maxLeaseTimeField setIntValue:value];
	}
}

// ---------------------------------------------------------------------------
//	¥ leaseOptionsTableDelete
// ---------------------------------------------------------------------------
- (IBAction)leaseOptionsTableDelete:(id)sender
{
	DHCPLeaseOptionsTable* leaseOptionsT;
	DHCPLeaseOptionsEntry* leaseOptionsE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	
	leaseOptionsT = [leaseOptionsTableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[leaseOptionsT count]];
	// gather entries to be deleted before altering indexes
	en = [leaseOptionsTableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[leaseOptionsT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (leaseOptionsE = [en nextObject]) [leaseOptionsT removeObject:leaseOptionsE];
	// refresh tableView
	[leaseOptionsTableView deselectAll:self];
	[leaseOptionsTableView reloadData];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}
- (IBAction)defaultLeaseTimeField:(id)sender
{
	[self editLeaseOptions:sender];
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];	// apply pending
}
- (IBAction)maxLeaseTimeField:(id)sender
{
	[self editLeaseOptions:sender];
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];	// apply pending
}
- (IBAction)searchDomainsField:(id)sender
{
	[self editLeaseOptions:sender];
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];	// apply pending
}

#pragma mark - serverOptionsTable -
- (IBAction)leaseGrantedField:(id)sender
{
	DHCPState *dhcpState = [controller dhcpState];
	[dhcpState setGrantedMessage:[leaseGrantedField stringValue]];
	[dhcpState setApplyPending:[NSNumber numberWithInt:1]];	// apply pending
}
- (IBAction)leaseNotGrantedField:(id)sender
{
	DHCPState *dhcpState = [controller dhcpState];
	[dhcpState setNotGrantedMessage:[leaseNotGrantedField stringValue]];
	[dhcpState setApplyPending:[NSNumber numberWithInt:1]];	// apply pending
}
// ---------------------------------------------------------------------------
//	¥ serverOptionsTableNew
// ---------------------------------------------------------------------------
- (IBAction)serverOptionsTableNew:(id)sender
{
	DHCPServerOptionsTable* serverOptionsT;
	int selectedRow;
	
	serverOptionsT = [serverOptionsTableView dataSource];
	selectedRow = [serverOptionsTableView selectedRow];
	selectedRow = [serverOptionsT newDefaultEntry:selectedRow];
	// refresh display
	[serverOptionsTableView reloadData];
	// sellect new row
	[serverOptionsTableView selectRow:selectedRow byExtendingSelection:NO];
	// make sure new row is visible
	[serverOptionsTableView scrollRowToVisible:selectedRow];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ serverOptionsTableDelete
// ---------------------------------------------------------------------------
- (IBAction)serverOptionsTableDelete:(id)sender
{
	DHCPServerOptionsTable* serverOptionsT;
	DHCPServerOptionsEntry* serverOptionsE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	
	serverOptionsT = [serverOptionsTableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[serverOptionsT count]];
	// gather entries to be deleted before altering indexes
	en = [serverOptionsTableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[serverOptionsT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (serverOptionsE = [en nextObject]) [serverOptionsT removeObject:serverOptionsE];
	// refresh tableView
	[serverOptionsTableView deselectAll:self];
	[serverOptionsTableView reloadData];
	// apply pending
	[[controller dhcpState] setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ verboseLogging
// ---------------------------------------------------------------------------
- (IBAction)verboseLogging:(id)sender
{
	NSNumber* num;
	int level;
	// set editable copy
	level = [verboseLoggingPopUp indexOfSelectedItem];
	num = [NSNumber numberWithInt:level];
	[[controller dhcpState] setVerboseLogging:num];
	// set DO server state
	[controller dhcpApply:
		[NSDictionary dictionaryWithObject:num forKey:DS_verboseLogging]];
	// tell user what we did
	switch (level) {
		case kDHCP_exceptionLogging:
			[dhcpLogger appendMessage:@"\nBegin DHCP exception logging"];
			break;
		case kDHCP_summaryLogging:
			[dhcpLogger appendMessage:@"\nBegin DHCP summary logging"];
			break;
		case kDHCP_verboseLogging:
			[dhcpLogger appendMessage:@"\nBegin DHCP verbose logging"];
			break;
		default:
			[dhcpLogger appendMessage:@"\nDHCP unknown logging level"];
	}
}
// ---------------------------------------------------------------------------
//	¥ ignoreBootp
// ---------------------------------------------------------------------------
- (IBAction)ignoreBootp:(id)sender
{
	[[controller dhcpState] setIgnoreBootp:[NSNumber numberWithInt:[sender intValue]]];
}
- (IBAction)dynamicBootp:(id)sender
{
	[[controller dhcpState] setDynamicBootp:[NSNumber numberWithInt:[sender intValue]]];
}
- (IBAction)pingCheck:(id)sender
{
	[[controller dhcpState] setPingCheck:[NSNumber numberWithInt:[sender intValue]]];
}

@end
