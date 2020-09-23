//
//  ExpertViewWC.m
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
//  (2) interpret user input and call SentryState or SentryModel to modify the
//		model accordingly.
//
//	Serves as delegate for Filter window and outline view
#define preferences [NSUserDefaults standardUserDefaults]

#import "ExpertViewWC.h"
#import "DocumentSupport.h"
#import "SentryDocument.h"

#import "FilterTable.h"
#import "FilterEntry.h"
#import PS_TNKE_INCLUDE
#import "kft.h"
#import "NSOutlineView_Extensions.h"
#import "PSPropertyValue.h"
#import "InterfaceTable.h"
#import "SystemConfiguration.h"
#import "TriggerTable.h"
#import "TriggerEntry.h"
#ifdef IPNetRouter
	#import "PortMapTable.h"
	#import "PortMapEntry.h"
	#import "DHCPState.h"
#endif
#import "PSServiceDictionary.h"
//#import "IPValue.h"
#import "IPSupport.h"
#import "SentryState.h"
#import "SentryModel.h"
#import "SentryController.h"

#import "AppDelegate.h"
#import "LookupWindowC.h"
#import "SentryLogger.h"
#import "MenuDispatch.h"
#import <syslog.h>
#import <stdarg.h>


// Private Methods
@interface ExpertViewWC (PrivateMethods)
- (void)setSentryState:(SentryState *)value;
- (void)updateRuleCount;
- (void)restoreState;
- (void)setupOutlineView;
- (void)setupTriggerTable;
- (void)setupInterfaceTable;
- (void)setFilterDataSource:(FilterTable *)value;
- (void)setTriggerDataSource:(TriggerTable *)value;
- (void)setInterfaceDataSource:(InterfaceTable *)value;
#ifdef IPNetRouter
- (void)setPortMapDataSource:(PortMapTable *)value;
- (void)setupPortMapTable;
- (void)portMapLoadCombos;
#endif
- (void)deleteItems:(NSArray *)items;
@end


@implementation ExpertViewWC

// ---------------------------------------------------------------------------------
// ¥ init
// ---------------------------------------------------------------------------------
- (ExpertViewWC *)init {
    if (self = [super init]) {
        // initialize our instance variables
        valueData = nil;
		sentryState = nil;
    }
    return self;
}
// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	// release our ivars
	[valueData release]; valueData = nil;
	[sentryState release]; sentryState = nil;
	
    [super dealloc];
}

- (id)outlineViewOutlet { return outlineViewOutlet; }
- (id)valueData { return valueData; }
- (void)setSentryState:(SentryState *)value
{
//	[sentryState removeObserver:self];	// remove old observer if any
	[value retain];
	[sentryState release];
	sentryState = value;
	// connect sentryState to ExpertViewWC
	if (sentryState) {
		// set windowController in sentry state to track editing changes
		// and provide access to filter table for editing outlineView
		//[sentryState setWindowController:self];
		[[SentryModel sharedInstance] setWindowController:self];
		// set data source for filter table (outlineView)
		if (![sentryState filterTable])
			[sentryState setFilterTable:[[[FilterTable alloc] init] autorelease]];
		[self setFilterDataSource:[sentryState filterTable]];
		// restore which nodes were expanded
		[outlineViewOutlet reloadData];
		[[sentryState filterTable] restoreExpandedForOutlineView:outlineViewOutlet];
		// reset nodeCount cache
		[[sentryState filterTable] setNodeCount:0];
		// display filter data
		[outlineViewOutlet reloadData];
		
		// set data source for trigger table
		if (![sentryState triggerTable])
			[sentryState setTriggerTable:[[[TriggerTable alloc] init] autorelease]];
		[self setTriggerDataSource:[sentryState triggerTable]];

		// set data source for interface table (initialized during sentryState init)
		[self setInterfaceDataSource:[InterfaceTable sharedInstance]];

	#ifdef IPNetRouter
		// set data source for port map table
		if (![sentryState portMapTable])
			[sentryState setPortMapTable:[[[PortMapTable alloc] init] autorelease]];
		[self setPortMapDataSource:[sentryState portMapTable]];
	#endif
		// apply button
		if ([[sentryState applyPending] intValue]) [applyButton setEnabled:YES];
		else [applyButton setEnabled:NO];
		// restore window state
		[self restoreState];
		// setup to receive messages from SentryState
//		[sentryState addObserver:self withSelector:@selector(receiveNotification:)];
	}
}

- (int)indexOfSelectedParameter { return [parameterPopUp indexOfSelectedItem]; }

- (id)selectProperty:(int)propertyID
{
    id returnValue;
    returnValue = [valueData selectProperty:propertyID];
		// reload cell data
		NSTableColumn* tableColumn = [outlineViewOutlet tableColumnWithIdentifier:CID_VALUE];
		NSComboBoxCell* dataCell = [tableColumn dataCell];
		[dataCell reloadData];
    return returnValue;
}


#pragma mark -- log drawer and help --

// ---------------------------------------------------------------------------
// ¥ appendString
// ---------------------------------------------------------------------------
#define END_RANGE NSMakeRange([[logTextView string]length],0)
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
// ¥ historyClear
// ---------------------------------------------------------------------------
// clear previous log window contents, does not affect log file
- (void)historyClear:(id)sender
{
	// release existing text if any
	[logTextView setString:@""];
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
		[logTextView setString:[sentryLogger string]];
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
		[logTextView setString:[sentryLogger string]];
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
	NSString* tabID;
	NSString* document = nil;

	tabID = [[tabView selectedTabViewItem] identifier];
	if ([tabID isEqualTo:@"filters"])  document = @"FirewallDocument"; // Filters
	else if ([tabID isEqualTo:@"triggered"])  document = @"FirewallDocument";	// Triggers
#ifdef IPNetRouter
	else if ([tabID isEqualTo:@"interfaces"])  document = @"InternetSharingHelp";  // Interfaces
#else
	else if ([tabID isEqualTo:@"interfaces"])  document = @"FirewallDocument";  // Interfaces
#endif
	else if ([tabID isEqualTo:@"portMapping"])  document = @"InboundPortMappingHelp";  // Port Mapping
	filePath = [thisBundle pathForResource:document ofType:@"html" inDirectory:PS_HELP_DIRECTORY];
	if (filePath)
		if ((fileURL = [NSURL fileURLWithPath:filePath]))
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
}


#pragma mark --- NSWindowController ---
// ---------------------------------------------------------------------------------
//	¥ awakeFromNib
// ---------------------------------------------------------------------------------
- (void)awakeFromNib {
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	// sentryLogger
	sentryLogger = [SentryLogger sharedInstance];
    [logTextView setRichText:NO];
	// display existing text if any
	[logTextView setString:[sentryLogger string]];
	// setup to receive Event Log messages
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(receiveNotification:)
		name:SentryLoggerNotification
		object:sentryLogger
		];
		
	[outlineViewOutlet setDelegate:self];
    // initialize controls in the window
    createChild = NO;
    [newButton setEnabled:YES];
    //[newButton setTitle:NSLocalizedString(@"New Sibling",@"New Sibling")];
    [deleteButton setEnabled:NO];
	[toggleSiblingChildButton setImage:[NSImage imageNamed:@"collapsed.tiff"]];

	// setup table cells
	[self setupOutlineView];
	[self setupTriggerTable];
	[self setupInterfaceTable];
	#if IPNetRouter
	[self setupPortMapTable];
	#endif

    // Register to get our custom type, strings, and file names
#if DRAG_ENABLE
    [outlineViewOutlet registerForDraggedTypes:[NSArray arrayWithObjects:FilterEntryPboardType, NSStringPboardType, NSFilenamesPboardType, nil]];
#endif
	
	// preferences
	NSNumber* num = [preferences objectForKey:kSentryDocument_logDrawerOpen];
	if (num) [self setLogDrawerState:[num intValue]];
	// log drawer open?
	if ([logDrawer state] == NSDrawerOpenState) [logDrawerButton setIntValue:1];
	num = [preferences objectForKey:kSentryDocument_logDrawerSize];
	if (num) {
		NSSize size;
		size.height = [num intValue];
		size.width = 0;
		[logDrawer setContentSize:size];
	}
	// selected tabView
	NSString *str;
	if ((str = [preferences objectForKey:kSentryDocument_tabViewIdentifier])) {
		[tabView selectTabViewItemWithIdentifier:str];
	}

	// setup to receive messages from SentryController which includes SentryState messages
	[[NKEController sharedInstance] addObserver:self withSelector:@selector(receiveNotification:)];
}

// ---------------------------------------------------------------------------------
// ¥ showDocument
// ---------------------------------------------------------------------------------
// load sendry state from current document
- (void)showDocument
{
	// see if we already have a sentryState we read in
	[self setSentryState:[[DocumentSupport sharedInstance] sentryState]];
	if (!sentryState) {
        // no input file specified, open default configuration
        NSFileManager* fm;
		NSString *filePath = nil;
		BOOL status = NO;
        
		fm = [NSFileManager defaultManager];
		// try to use system wide default settings
		NSString* defaultSettingsPath = [AppSupport appPrefsPath:kSettingsFilename];
		if ([fm fileExistsAtPath:defaultSettingsPath]) filePath = defaultSettingsPath;
		else  {
			// no system settings found
			NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
			// copy default configuration to system settings
			if (filePath = [thisBundle pathForResource:@"DefaultRules" ofType:@"nsy"]) {
				if ([fm copyPath:filePath toPath:defaultSettingsPath handler:nil])
					filePath = defaultSettingsPath;
			}
		}
		// read system settings if any
		if (filePath) {
			status = [[DocumentSupport sharedInstance] readFromFile:filePath];
			if (status) {
				// restore application state from file we read in
				[[DocumentSupport sharedInstance] restoreState];
				[self setSentryState:[[DocumentSupport sharedInstance] sentryState]];
				// associate a document with this window controller if needed
				if (![self document]) {
					// create a new document to remember where our settings came from
					SentryDocument* sentryDocument = [[[SentryDocument alloc] init] autorelease];
					[self setDocument:sentryDocument];
				}
				// tell document where our settings came from
				[[self document] setFileName:filePath];
				#ifdef IPNetRouter
					[[self document] setFileType:@"ipnr"];
					if ([filePath isEqualTo:defaultSettingsPath]) {
						// keep generic name
						[[self window] setTitle:@"IPNetRouterX"];
					}
				#else
					[[self document] setFileType:@"nsy"];
					if ([filePath isEqualTo:defaultSettingsPath]) {
						// keep generic name
						[[self window] setTitle:@"IPNetSentryX"];
					}
				#endif
			}
		}
		if (!status) {
			// if that fails, use model
			[self setSentryState:[[SentryModel sharedInstance] sentryState]];
			// keep around for next document to find
			[[DocumentSupport sharedInstance] setSentryState:sentryState];
			// tell document where our settings came from
			[[self document] setFileName:defaultSettingsPath];
			#ifdef IPNetRouter
				[[self window] setTitle:@"IPNetRouterX"];
			#else
				[[self window] setTitle:@"IPNetSentryX"];
			#endif
			syslog(LOG_NOTICE, "Unexpected error restoring default settings.");
		}
	}
	// update rule info
	[self updateRuleCount];
	// apply button
	if ([[sentryState applyPending] intValue]) [applyButton setEnabled:YES];
	else [applyButton setEnabled:NO];
}

// ---------------------------------------------------------------------------------
// ¥ updateRuleCount
// ---------------------------------------------------------------------------------
// update rule info
- (void)updateRuleCount
{
	NSString* str;
	int count = [[outlineViewOutlet dataSource] nodeCount];
	if (count > KFT_filterTableSize) str  = [NSString stringWithFormat:@"%d filter rules, limit exceeded",count];
	else str  = [NSString stringWithFormat:@"%d filter rules",count];
	[ruleCount setStringValue:str];
}

// ---------------------------------------------------------------------------------
// ¥ setupOutlineView
// ---------------------------------------------------------------------------------
- (void)setupOutlineView
{
	NSTableColumn *tableColumn;	
		// outline
	tableColumn = [outlineViewOutlet tableColumnWithIdentifier:CID_NUMBER];
	[outlineViewOutlet setOutlineTableColumn:tableColumn];
    [outlineViewOutlet setAutosaveTableColumns:YES];
    [outlineViewOutlet setAutosaveName:kSentryDocument_columns];
		// set default width for outline column
	[tableColumn setWidth:80.0];
	
    // setup table cells for editing from corresponding nib outlets
        // enabled
    tableColumn = [outlineViewOutlet tableColumnWithIdentifier:CID_ENABLED];
    [tableColumn setDataCell:[ruleEnabledCheckBox cell]];
        // property
    tableColumn = [outlineViewOutlet tableColumnWithIdentifier:CID_PROPERTY];
    [propertyPopUp setBordered:NO];
    [tableColumn setDataCell:[propertyPopUp cell]];
        // relation
    tableColumn = [outlineViewOutlet tableColumnWithIdentifier:CID_RELATION];
    [relationPopUp setBordered:NO];
    [tableColumn setDataCell:[relationPopUp cell]];
        // value
    tableColumn = [outlineViewOutlet tableColumnWithIdentifier:CID_VALUE];
    valueData = [[PSPropertyValue alloc] init];
    [valueData selectProperty:kFilterAny];
#if 0
    [valueComboBox setBordered:NO];
    [tableColumn setDataCell:[valueComboBox cell]];
    [valueComboBox setDataSource:valueData];
#else
	NSComboBoxCell* dataCell = [tableColumn dataCell];
	[dataCell setDataSource:valueData];
#endif
        // action
    tableColumn = [outlineViewOutlet tableColumnWithIdentifier:CID_ACTION];
    [actionPopUp setBordered:NO];
    [tableColumn setDataCell:[actionPopUp cell]];
}

// ---------------------------------------------------------------------------------
// ¥ setupTriggerTable
// ---------------------------------------------------------------------------------
// setup table cells for editing from corresponding nib outlets
- (void)setupTriggerTable
{
	NSTableColumn *tableColumn;
		// type
	tableColumn = [triggerTableView tableColumnWithIdentifier:TT_type];
	[triggerType setBordered:NO];
	[tableColumn setDataCell:[triggerType cell]];
		// duration
	tableColumn = [triggerTableView tableColumnWithIdentifier:TT_duration];
	[triggerDuration setBordered:NO];
	[tableColumn setDataCell:[triggerDuration cell]];
}

// ---------------------------------------------------------------------------------
// ¥ setupInterfaceTable
// ---------------------------------------------------------------------------------
// Setup interfaceTable.
// Assumes we have already restored any previous filter document with interface info
- (void)setupInterfaceTable
{
    // setup table cells for editing from corresponding nib outlets
	NSTableColumn *tableColumn;	
        // firewall
    tableColumn = [interfaceTableView tableColumnWithIdentifier:IT_filterOn];
    [tableColumn setDataCell:[firewallCheckBox cell]];
		// external
    tableColumn = [interfaceTableView tableColumnWithIdentifier:IT_externalOn];
    [tableColumn setDataCell:[externalCheckBox cell]];
	#ifdef IPNetRouter
		// nat
    tableColumn = [interfaceTableView tableColumnWithIdentifier:IT_natOn];
    [tableColumn setDataCell:[natCheckBox cell]];
    #endif
		// bridge
    tableColumn = [interfaceTableView tableColumnWithIdentifier:IT_bridgeOn];
    [tableColumn setDataCell:[bridgeCheckBox cell]];
}
#ifdef IPNetRouter
// ---------------------------------------------------------------------------------
// ¥ setupPortMapTable
// ---------------------------------------------------------------------------------
// setup table cells for editing from corresponding nib outlets
- (void)setupPortMapTable
{
	NSTableColumn *tableColumn;
		// on
	tableColumn = [portMapTableView tableColumnWithIdentifier:PM_enabled];
	[tableColumn setDataCell:[portMapOnButton cell]];
		// local proxy
	tableColumn = [portMapTableView tableColumnWithIdentifier:PM_localProxy];
	if (tableColumn) [tableColumn setDataCell:[portMapLocalProxyButton cell]];
	// load combo boxes
	[self portMapLoadCombos];	
}

- (void)portMapLoadCombos
{
	NSTableColumn *tableColumn;
	NSEnumerator* en;
	InterfaceEntry* interfaceE;
	NSString* str;
	NSRange range;

	// dynamic
	tableColumn = [portMapTableView tableColumnWithIdentifier:PM_dynamic];
	NSComboBoxCell* portMapDynamicCell = [tableColumn dataCell];
	[portMapDynamicCell removeAllItems];
	// apparentAddress
	tableColumn = [portMapTableView tableColumnWithIdentifier:PM_apparentAddress];
	NSComboBoxCell* portMapApparentAddressCell = [tableColumn dataCell];
	[portMapApparentAddressCell removeAllItems];
	[portMapApparentAddressCell addItemWithObjectValue:@"0.0.0.0 (any)"];

	en = [[[interfaceTableView dataSource] interfaceArray] objectEnumerator];
	while (interfaceE = [en nextObject]) {
		// dynamic
		if ([[interfaceE natOn] intValue]) {
			str = bsdNameForInterfaceID([interfaceE interfaceID]);
			[portMapDynamicCell addItemWithObjectValue:str];
		}
		// apparentAddress
		if ([[interfaceE natOn] intValue] && [[interfaceE externalOn] intValue]) {
			str = [interfaceE ifNet];
			range = [str rangeOfString:@"/"];
			if (range.length) str = [str substringToIndex:range.location];
			[portMapApparentAddressCell addItemWithObjectValue:str];
		}
	}
	{	// apparent/actual port
        NSDictionary* portDictionary;
        NSArray* keys;
        NSArray* sorted;
        NSEnumerator* en;
        NSString* str;
        NSString* serviceName;
		NSString* title;		
        portDictionary = [[PSServiceDictionary sharedInstance] tcpServiceNames];
        keys = [portDictionary allKeys];
        sorted = [keys sortedArrayUsingFunction:intSort context:NULL];
        en = [sorted objectEnumerator];
		// apparent port
		tableColumn = [portMapTableView tableColumnWithIdentifier:PM_apparentPort];
		NSComboBoxCell* portMapApparentPortCell = [tableColumn dataCell];
        [portMapApparentPortCell removeAllItems];
		// actual port
		tableColumn = [portMapTableView tableColumnWithIdentifier:PM_actualPort];
		NSComboBoxCell* portMapActualPortCell = [tableColumn dataCell];
		[portMapActualPortCell removeAllItems];        
		while (str = [en nextObject]) {
            serviceName = [portDictionary objectForKey:str];
			title = [NSString stringWithFormat:@"%@ (%@)",str,serviceName];
            [portMapApparentPortCell addItemWithObjectValue:title];
			[portMapActualPortCell addItemWithObjectValue:title];
        }
    }
}
#endif

// ---------------------------------------------------------------------------------
// ¥ restoreState
// ---------------------------------------------------------------------------------
// restore document state
// sentryState -> visible fields
- (void)restoreState
{
	id object;
	NSMutableDictionary* sd = [[DocumentSupport sharedInstance] saveDictionary];
	// current firewall state may be different from document we're viewing
	SentryState *modelState = [[SentryModel sharedInstance] sentryState];
	// restore expanded state
	[[sentryState filterTable] restoreExpandedForOutlineView:outlineViewOutlet];
	// display current firewall state
	[firewallOnCheckBox setObjectValue:[modelState firewallOn]];	
#ifdef IPNetRouter
	// ipForwarding state
	[ipForwarding setObjectValue:[modelState ipForwarding]];
	// exposedHostSelection
	[exposedHostPopUp selectItemAtIndex:[[sentryState exposedHostSelection] intValue]];	
	if ([exposedHostPopUp indexOfSelectedItem] == 1) [exposedHostField setEnabled:YES];
	else [exposedHostField setEnabled:NO];
	// portMapLogging state
	[portMapLogging setObjectValue:[modelState portMapLogging]];
	// unregisteredOnly state
	[unregisteredOnly setObjectValue:[modelState unregisteredOnly]];
#endif
	// blockIPv6 state
	[blockIPv6CheckBox setObjectValue:[modelState blockIPv6]];
	// selectedParameter
	int index = [[sd objectForKey:kSentryDocument_selectedParameter] intValue];
		// note we removed an item from this menu, guard against possible exception
	int last = [parameterPopUp numberOfItems];
	if (index >= last) [parameterPopUp selectItemAtIndex:last-1];
	else [parameterPopUp selectItemAtIndex:index];
	// triggerDefaultDuration
	if ((object = [sentryState triggerDuration])) {
		[triggerDefaultDuration setObjectValue:object];
	}
	else if ((object = [modelState triggerDuration])) {
		[triggerDefaultDuration setObjectValue:object];	
	}
	else if ((object = [[[AppDelegate sharedInstance] prefs] objectForKey:SS_triggerDuration])) {
		[triggerDefaultDuration setObjectValue:object];
	}
}

// ---------------------------------------------------------------------------------
// ¥ saveState
// ---------------------------------------------------------------------------------
// save document state
// visible fields -> sentryState (most are updated on the fly)
- (void)saveState
{
	// remember which nodes were expanded
	[[sentryState filterTable] saveExpandedForOutlineView:outlineViewOutlet];
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
}


// ---------------------------------------------------------------------------------
// ¥ windowDidResignKey
// ---------------------------------------------------------------------------------
- (void)windowDidResignKey:(NSNotification *)aNotification
{
    int row;
    NSTableColumn* column;
    NSString* addressStr;
    
    row = [triggerTableView selectedRow];
    // share our input/results with other tools
    if (row >= 0) {
        column = [triggerTableView tableColumnWithIdentifier:TT_addressString];
        addressStr = [[triggerTableView dataSource] tableView:triggerTableView
            objectValueForTableColumn:column
            row:(int)row];
        saveAddressOrName(addressStr);
    }
}

// ---------------------------------------------------------------------------------
//	¥ windowWillClose
// ---------------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
	
	// save window state
	[self saveState];
    // no longer want SentryState messages
//	[sentryState removeObserver:self];
	[[NKEController sharedInstance] removeObserver:self];
  	// remove document from sentryState
	//[sentryState setWindowController:nil];
	[[SentryModel sharedInstance] setWindowController:nil];
	// no longer want outline view messages
	[outlineViewOutlet setDelegate:nil];
	// release data source objects
	[self setFilterDataSource:nil];
	[self setTriggerDataSource:nil];
	[self setInterfaceDataSource:nil];
#ifdef IPNetRouter
	[self setPortMapDataSource:nil];
#endif

    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kExpertViewName];
    // remember preferences
	[preferences setObject:[NSNumber numberWithInt:[self logDrawerState]] forKey:kSentryDocument_logDrawerOpen];
	NSSize size = [logDrawer contentSize];
	[preferences setObject:[NSNumber numberWithInt:size.height] forKey:kSentryDocument_logDrawerSize];
	// selected tabView
	[preferences setObject:[[tabView selectedTabViewItem] identifier] forKey:kSentryDocument_tabViewIdentifier];
	// release ourself
	[self autorelease];
}


#pragma mark --- ACTIONS ---
// ---------------------------------------------------------------------------
//	¥ receiveNotification
// ---------------------------------------------------------------------------
// Receive notification from SentryState when model state changes
// Update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
- (void)receiveNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;
	NSEnumerator* enumerator;
	NSString* name;
    id key;
    id object;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	do {    
		name = [aNotification name];
		if ([name isEqualTo:SentryLoggerNotification]) {
			if ([logDrawer state] != NSDrawerClosedState) {
				dictionary = [aNotification userInfo];
				[self appendString:[dictionary objectForKey:SentryLoggerNotification]];
			}
			break;
		}
		if ([name isEqualTo:NSWindowWillCloseNotification]) {
			[self windowWillClose:aNotification];
			break;
		}

		dictionary = [aNotification userInfo];
		enumerator = [dictionary keyEnumerator];

		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			object = [dictionary objectForKey:key];

			// status
			if ([key isEqualTo:@"statusInfo"])	{
				[statusInfo setStringValue:object];
				// keep rule counter up to date
				[self updateRuleCount];
				continue;
			}
			if ([key isEqualTo:@"statusInfoAppend"]) {
				NSRange range;
				// ignore ppp0 errors here
				range = [object rangeOfString:@"ppp0"];
				if (!range.length) {
					NSString* str;
					str = [[statusInfo stringValue] stringByAppendingString:object];
					[statusInfo setStringValue:str];
				}
				continue;
			}
			// applyPending
			if ([key isEqualTo:SS_applyPending]) {
				if ([object intValue]) [applyButton setEnabled:YES];
				else [applyButton setEnabled:NO];
				continue;
			}
			// firewallOn
			if ([key isEqualTo:SS_firewallOn]) {
				[firewallOnCheckBox setObjectValue:object];
				continue;
			}
			// triggerDuration
			if ([key isEqualTo:@"triggerDuration"]) {
				[triggerDefaultDuration setObjectValue:object];
				continue;
			}
			// filterTable
			if ([key isEqualTo:SS_filterTable]) {
				[outlineViewOutlet reloadData];
				[self updateRuleCount];
				continue;
			}
			// filterItem
			if ([key isEqualTo:SS_filterItem]) {
				[outlineViewOutlet reloadItem:object];
				continue;
			}
			// filterExpanded
			if ([key isEqualTo:SS_filterExpanded]) {
				// expand values with descriptive info
				[valueData expandEntry:[sentryState filterTable]];
				// restore expanded outline state
				[[sentryState filterTable] restoreExpandedForOutlineView:outlineViewOutlet];
				continue;
			}
			// blockIPv6
			if ([key isEqualTo:SS_blockIPv6]) {
				[blockIPv6CheckBox setObjectValue:object];
				continue;
			}
			// SS_triggerTable
			if ([key isEqualTo:SS_triggerTable]) {
				[triggerTableView reloadData];
				continue;
			}
			// interfaceTable
			if ([key isEqualTo:SS_interfaceTable]) {
				// refresh even if setings haven't been applied (might be from another document)
				
				[interfaceTableView reloadData];
				continue;
			}
	#if IPNetRouter
			// ipForwarding
			if ([key isEqualTo:SS_ipForwarding]) {
				[ipForwarding setObjectValue:object];
				continue;
			}
			// SS_excludeNet
			if ([key isEqualTo:SS_excludeNet]) {
				[excludeNetField setStringValue:[sentryState excludeNet]];
				continue;
			}
			if ([key isEqualTo:SS_exposedHost]) {
				[exposedHostField setStringValue:[sentryState exposedHost]];
				continue;
			}
			if ([key isEqualTo:SS_exposedHostSelection]) {
				[exposedHostPopUp setObjectValue:[sentryState exposedHostSelection]];
				if ([exposedHostPopUp indexOfSelectedItem] == 1) {
					[exposedHostField setEnabled:YES];
				} else {
					[exposedHostField setEnabled:NO];
				}
				continue;
			}		
			// portMapLogging
			if ([key isEqualTo:SS_portMapLogging]) {
				[portMapLogging setObjectValue:object];
				continue;
			}
			// unregisteredOnly
			if ([key isEqualTo:SS_unregisteredOnly]) {
				[unregisteredOnly setObjectValue:object];
				continue;
			}
			// SS_portMapTable
			if ([key isEqualTo:SS_portMapTable]) {
				[portMapTableView reloadData];
				continue;
			}
			// SS_portMapLoadCombos
			if ([key isEqualTo:SS_portMapLoadCombos]) {
				[self portMapLoadCombos];
				continue;
			}
	#endif		
		}	// while ((key = [enumerator nextObject]))
	} while (false);
    [pool release];
}

// ---------------------------------------------------------------------------------
//	¥ firewallOn:
// ---------------------------------------------------------------------------------
- (IBAction)firewallOn:(id)sender
{
	// if setting has changed, update firewall state
	SentryState *modelState = [[SentryModel sharedInstance] sentryState];
	[statusInfo setStringValue:@""];
	[modelState setFirewallOn:[firewallOnCheckBox objectValue]];
	if ([firewallOnCheckBox objectValue]) [modelState updateParameter:SA_apply withObject:self];
}

// ---------------------------------------------------------------------------------
//	¥ apply:
// ---------------------------------------------------------------------------------
// send currently displayed configuration tables to NKE
- (IBAction)apply:(id)sender
{
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// remember which nodes were expanded
	[[sentryState filterTable] saveExpandedForOutlineView:outlineViewOutlet];
	// clear previous status if any
	[statusInfo setStringValue:@""];
	// use our document settings
	[[DocumentSupport sharedInstance] invokeDocumentFirewall];
	// apply no longer pending (mark in [SentryModel -apply])
	//[sentryState setApplyPending:[NSNumber numberWithInt:0]];
}

// ---------------------------------------------------------------------------------
//	¥ showActive:
// ---------------------------------------------------------------------------------
// retrieve currently active rule set from NKE
- (IBAction)showActive:(id)sender
{
	// use currently applied state
	[self setSentryState:[[SentryModel sharedInstance] sentryState]];	
	// clear previous status if any
	[statusInfo setStringValue:@""];
	// invoke action
		// For consistency SentryDocument only calls out to SentryState.
		// SentryModel responds to notifications from SentryState allowing
		// other observers to respond as well.
	[sentryState updateParameter:SA_showActive withObject:self];
	// apply no longer pending
	[sentryState setApplyPending:[NSNumber numberWithInt:0]];
}

// ---------------------------------------------------------------------------
//	¥ testButton
// ---------------------------------------------------------------------------
- (IBAction)testButton:(id)sender
{
	// invoke action
		// For consistency SentryDocument only calls out to SentryState.
		// SentryModel responds to notifications from SentryState allowing
		// other observers to respond as well.
	[sentryState updateParameter:SA_testButton withObject:self];
}

// ---------------------------------------------------------------------------
//	¥ defaultsButton
// ---------------------------------------------------------------------------
// restore default filter set
- (IBAction)defaultsButton:(id)sender
{
	BOOL status;
	NSString *filePath = nil;
	NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	filePath = [thisBundle pathForResource:@"DefaultRules" ofType:@"nsy"];
	// read system settings if any
	if (filePath) {
		status = [[DocumentSupport sharedInstance] readFromFile:filePath];
		if (status) {
			// restore application state from file we read in
			[[DocumentSupport sharedInstance] restoreState];
		}
		[self setSentryState:[[DocumentSupport sharedInstance] sentryState]];
		// extract visible document settings
		[self restoreState];

		[sentryState updateParameter:SS_filterTable withObject:self];
		[sentryState updateParameter:SS_triggerTable withObject:self];
		[sentryState updateParameter:SS_interfaceTable withObject:self];
		[[self document] updateChangeCount:NSChangeDone];
		[sentryState setApplyPending:[NSNumber numberWithInt:1]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ copy:
// ---------------------------------------------------------------------------------
// Edit->Copy selection to clipboard
- (void)copy:(id)sender {
    NSArray* items;
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];

    // get currently selected items
    items = [outlineViewOutlet selectedItems];
    items = [TreeNode treeCover:items];		// copy each item only once
    if ([items count]) {
        [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType,nil] owner:nil];
        [pboard setString:[items description] forType: NSStringPboardType];
    }
}
// ---------------------------------------------------------------------------------
//	¥ cut:
// ---------------------------------------------------------------------------------
// Edit->cut selection to clipboard
- (void)cut:(id)sender {
    [self copy:nil];
    [self delete:nil];
}
// ---------------------------------------------------------------------------------
//	¥ paste:
// ---------------------------------------------------------------------------------
- (void)paste:(id)sender {
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
    FilterEntry* targetItem;
    int childIndex;

    if ([pboard availableTypeFromArray:[NSArray arrayWithObject: NSStringPboardType]]) {
        NSString* string = [pboard stringForType: NSStringPboardType];
        childIndex = NSOutlineViewDropOnItemIndex; 	// -1
        // is there a selected item?
        if ((targetItem = [outlineViewOutlet selectedItem])) {
            // if expanded
            //if ([outlineViewOutlet isItemExpanded:targetItem]) {
			if (createChild) {
                // paste under
                childIndex = 0;
            }
        }
        [self paste:string toTarget:targetItem childIndex:childIndex];
    }
}

// ---------------------------------------------------------------------------------
//	¥ paste:toTarget:childIndex:
// ---------------------------------------------------------------------------------
// Paste items relative to selected target
// Can paste before, after, or as child of target
// If (childIndex >= 0), past as nth child of target
// else if (optionKey) past before target
- (void)paste:(NSString *)string toTarget:(FilterEntry *)targetItem childIndex:(int)childIndex {
    id plist = nil;
    NSMutableDictionary* dictionary = nil;
    FilterEntry* pasteItem;
	NSMutableArray* itemsToSelect;
    BOOL option = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0;
	// remember pasted items to select when were done
	itemsToSelect = [NSMutableArray array];

    NS_DURING
        plist = [string propertyList];
    NS_HANDLER
        NSBeep();
		NSLog(@"Paste data property list not recognized");
    NS_ENDHANDLER
    if ([plist isKindOfClass:[NSArray class]]) {
        NSEnumerator* en;
		// if pasting before, iterate in reverse order
        if (option) en = [plist reverseObjectEnumerator];
        else en = [plist objectEnumerator];		// default to paste after
        while (dictionary = [en nextObject]) {
            if ([dictionary isKindOfClass:[NSDictionary class]]) {
                pasteItem = treeFromDictionary(dictionary);
				[itemsToSelect addObject:pasteItem];
                // is there a target item?
                if (targetItem) {
                    if (childIndex >= 0) {
                        // paste under
                        [targetItem insertChild:pasteItem atIndex:childIndex];
						if (!option) childIndex++;
						// update node numbers
						[targetItem setNodeNumber:nil];
                    }
                    else {
                        if (option) [(FilterEntry *)[targetItem nodeParent] insertChild:pasteItem
                            atIndex:[targetItem nodeIndex]];	// paste before
                        else [targetItem insertNextItem:pasteItem];	// default to paste after
						// update node numbers
						[[targetItem nodeParent] setNodeNumber:nil];
                    }
                }
                else {
                    // paste at end
                    targetItem = [outlineViewOutlet dataSource];
                    [targetItem addChild:pasteItem];
					// update node numbers
					[pasteItem setNodeNumber:nil];
                }
                [outlineViewOutlet reloadData];
            }
        }	// while (dictionary = [en nextObject])
		[outlineViewOutlet selectItems:itemsToSelect byExtendingSelection:NO];
    }
}

// ---------------------------------------------------------------------------
//	¥ tabView:didSelectTabViewItem:
// ---------------------------------------------------------------------------
- (IBAction)tabView:(NSTabView*)view didSelectTabViewItem:(NSTabViewItem*)item
{
#ifdef IPNetRouter
	if ([[item identifier] isEqualTo:@"portMap"]) {
		[self portMapLoadCombos];
	}
#endif
}

#pragma mark --- INTERFACE ---
// ---------------------------------------------------------------------------
//	¥ setInterfaceDataSource
// ---------------------------------------------------------------------------
// set and retain data source for interface table view
- (void)setInterfaceDataSource:(InterfaceTable *)value
{
	InterfaceTable* prev;
	[value retain];
	prev = [interfaceTableView dataSource];
	[interfaceTableView setDataSource:value];
	[prev release];
}

// ---------------------------------------------------------------------------
//	¥ interfaceList
// ---------------------------------------------------------------------------
// refresh interface list and "interfaceIDs
- (IBAction)interfaceList:(id)sender {
	[[SystemConfiguration sharedInstance] purgeInterfaceIDs];
	[[interfaceTableView dataSource] updateFromSCF];
	[interfaceTableView reloadData];
}

#ifdef IPNetRouter
// ---------------------------------------------------------------------------
//	¥ ipForwarding
// ---------------------------------------------------------------------------
- (IBAction)ipForwarding:(id)sender
{
	[sentryState setIpForwarding:[ipForwarding objectValue]];
}

// ---------------------------------------------------------------------------
//	¥ exposedHostPopUp
// ---------------------------------------------------------------------------
- (IBAction)exposedHostPopUp:(id)sender
{
	[sentryState setExposedHostSelection:[exposedHostPopUp objectValue]];
	if ([exposedHostPopUp indexOfSelectedItem] == 1) {
		[exposedHostField setEnabled:YES];
	}
	else {
		[exposedHostField setEnabled:NO];
	}
}

// ---------------------------------------------------------------------------
//	¥ exposedHost
// ---------------------------------------------------------------------------
- (IBAction)exposedHostField:(id)sender
{
	[sentryState setExposedHost:[exposedHostField objectValue]];
}

// ---------------------------------------------------------------------------
//	¥ excludeNetField
// ---------------------------------------------------------------------------
- (IBAction)excludeNetField:(id)sender
{
	[sentryState setExcludeNet:[excludeNetField objectValue]];
}

// ---------------------------------------------------------------------------
//	¥ alternateGateways
// ---------------------------------------------------------------------------
- (IBAction)alternateGateways:(id)sender
{
	[[MenuDispatch sharedInstance] alternateRouteShowWindow:self];
}


#pragma mark --- PORT_MAPPING ---
// ---------------------------------------------------------------------------
//	¥ setPortMapDataSource
// ---------------------------------------------------------------------------
// set and retain data source for port map table view
- (void)setPortMapDataSource:(PortMapTable *)value
{
	PortMapTable* prev;
	[value retain];
	prev = [portMapTableView dataSource];
	[portMapTableView setDataSource:value];
	[prev release];
}

// ---------------------------------------------------------------------------
//	¥ portMapNew
// ---------------------------------------------------------------------------
// create a new port map entry
- (IBAction)portMapNew:(id)sender
{
	PortMapEntry* portMapE;
	InterfaceEntry* interfaceE;
	PortMapTable* portMapT;
	NSString* str;
	NSRange range;
	int port;
	u_int32_t address;
	int result;
	
	portMapT = [portMapTableView dataSource];
	// allocate new entry
	portMapE = [[[PortMapEntry alloc] init] autorelease];
	// look for selected row if any as starting point for new entry
	int selectedRow = [portMapTableView selectedRow];
	if (selectedRow < 0) selectedRow = [portMapT count] - 1; // if none selected, use last row
	// initialize corresponding values
	if (selectedRow >= 0) {
		PortMapEntry* tEntry = [portMapT objectAtIndex:selectedRow];
		// protocol
		[portMapE setEnabled:[tEntry enabled]];
		[portMapE setDynamic:[tEntry dynamic]];
		[portMapE setProtocol:[tEntry protocol]];
		// apparent
		str = [tEntry apparentPort];
		range = [str rangeOfString:@"-"];
		if (range.length) str = [str substringFromIndex:range.location+1];
		port = [str intValue];
		if (port == 0) {
			[portMapE setApparentPort:@"0"];
			address = ipForString([tEntry apparentAddress]);
			[portMapE setApparentAddress:stringForIP(address+1)];
		}
		else {
			[portMapE setApparentPort:[NSString stringWithFormat:@"%d",port+1]];
			[portMapE setApparentAddress:[tEntry apparentAddress]];
		}
		// actual
		str = [tEntry actualPort];
		range = [str rangeOfString:@"-"];
		if (range.length) str = [str substringFromIndex:range.location+1];
		port = [str intValue];
		if (port == 0) {
			[portMapE setActualPort:@"0"];
			address = ipForString([tEntry actualAddress]);
			[portMapE setActualAddress:stringForIP(address+1)];
		}
		else {
			[portMapE setActualPort:[NSString stringWithFormat:@"%d",port+1]];
			[portMapE setActualAddress:[tEntry actualAddress]];
		}
	}
	if ((selectedRow < 0) || ([portMapT containsObject:portMapE])) {
		// nothing selected, use defaults
			// apparent
		interfaceE = [[interfaceTableView dataSource] entryForNat];	
		str = [interfaceE ifNet];
		range = [str rangeOfString:@"/"];
		if (range.length) str = [str substringToIndex:range.location];
		[portMapE setApparentAddress:str];
		[portMapE setApparentPort:@"1"];
		[portMapE setProtocol:@"6 (TCP)"];
			// actual
		interfaceE = [[interfaceTableView dataSource] entryForDhcp];	
		str = [interfaceE ifNet];
		range = [str rangeOfString:@"/"];
		if (range.length) str = [str substringToIndex:range.location];
		[portMapE setActualAddress:str];
		[portMapE setActualPort:@"1"];
	}
	result = [portMapT insertObject:portMapE];
	if (result == 0) [statusInfo setStringValue:@""];
	else if (result > 0) [statusInfo setStringValue:@"Apparent and Actual endpoints must be unique, please edit previous entries"];
	else if (result < 0) [statusInfo setStringValue:@"Internal error allocating port map entry"];
	// select the new entry
	if (selectedRow >= 0) [portMapTableView selectRow:selectedRow+1 byExtendingSelection:NO];
	[portMapTableView reloadData];
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ portMapDelete
// ---------------------------------------------------------------------------
- (IBAction)portMapDelete:(id)sender
{
	PortMapTable* portMapT;
	PortMapEntry* portMapE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	
	portMapT = [portMapTableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[portMapT count]];
	// gather entries to be deleted before altering indexes
	en = [portMapTableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[portMapT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (portMapE = [en nextObject]) [portMapT removeObject:portMapE];
	// refresh tableView
	[portMapTableView reloadData];
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ portMapLogging
// ---------------------------------------------------------------------------
- (IBAction)portMapLogging:(id)sender
{
	[sentryState setPortMapLogging:[portMapLogging objectValue]];
}

// ---------------------------------------------------------------------------
//	¥ unregisteredOnly
// ---------------------------------------------------------------------------
- (IBAction)unregisteredOnly:(id)sender
{
	[sentryState setUnregisteredOnly:[unregisteredOnly objectValue]];
}
#endif

#pragma mark --- FILTERS ---
// ---------------------------------------------------------------------------
//	¥ setFilterDataSource
// ---------------------------------------------------------------------------
// set and retain data source for filter table view
- (void)setFilterDataSource:(FilterTable *)value
{
	FilterTable* prev;
	[value retain];
	prev = [outlineViewOutlet dataSource];
	[outlineViewOutlet setDataSource:value];
	[prev release];
}

// ---------------------------------------------------------------------------
//	¥ selectParameter
// ---------------------------------------------------------------------------
- (IBAction)selectParameter:(id)sender
{
	[sentryState setSelectedParameter:[parameterPopUp objectValue]];
	[statusInfo setStringValue:@""];
	[outlineViewOutlet reloadData];
}


// Edit NSOutlineView
// ---------------------------------------------------------------------------------
//	¥ new:
// ---------------------------------------------------------------------------------
- (IBAction)new:(id)sender
{
    FilterEntry* item;
    FilterEntry* newEntry;
    FilterEntry* parent;
    FilterEntry* previousChild;
    BOOL option = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0;
	BOOL expand = NO;
    // use selected item or root if no item selected
    item = [outlineViewOutlet selectedItem];
    if (!item) item = [outlineViewOutlet dataSource];   // filterTable
    parent = [item nodeParent];
    // create new entry
    newEntry = [FilterEntry filterEntry];
	[newEntry setEnabled:[NSNumber numberWithInt:1]];
    if (createChild || !parent) {
        // add entry as child
		expand = YES;
        if ([item numberOfChildren]) {
            previousChild = [[item childAtIndex:0] retain];
            [item replaceChildAtIndex:0 withChild:newEntry];
            [newEntry addChild:previousChild];
            [previousChild release];
        }
        else [item addChild:newEntry];
		// update node numbers
		[item setNodeNumber:nil];
    }
    else {
        // add entry as sibling
        if (option) [parent insertChild:newEntry atIndex:[item nodeIndex]];
        else [parent insertChild:newEntry atIndex:[item nodeIndex]+1];
		// update node numbers
		[parent setNodeNumber:nil];
    }
    [outlineViewOutlet reloadData];
    if (expand) {
		// expand parent so child is visible
		if ([outlineViewOutlet selectedRow] >= 0) {
			// valid row
	        [outlineViewOutlet expandItem:[outlineViewOutlet selectedItem] expandChildren:YES];
		}
	}
	// select new item
    [outlineViewOutlet selectItem:newEntry];
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
	[self updateRuleCount];
}

// ---------------------------------------------------------------------------------
//	¥ toggleSiblingChild:
// ---------------------------------------------------------------------------------
// Toggle new button between "New Sibling" and "New Child".
// Used to control non-expandable items
- (IBAction)toggleSiblingChild:(id)sender
{
	BOOL option;
	option = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	if (createChild) {
		//[newButton setTitle:NSLocalizedString(@"New Sibling",@"New Sibling")];
		[toggleSiblingChildButton setImage:[NSImage imageNamed:@"collapsed.tiff"]];
		createChild = NO;
		// collapse selected item if any
		if ([outlineViewOutlet selectedRow] >= 0) {
			// valid row
	        [outlineViewOutlet collapseItem:[outlineViewOutlet selectedItem] collapseChildren:option];
		}
	}
	else {
		//[newButton setTitle:NSLocalizedString(@"New Child",@"New Child")];
		[toggleSiblingChildButton setImage:[NSImage imageNamed:@"expanded.tiff"]];
		createChild = YES;    
		// expand selected item if any
		if ([outlineViewOutlet selectedRow] >= 0) {
			// valid row
	        [outlineViewOutlet expandItem:[outlineViewOutlet selectedItem] expandChildren:option];
		}
	}
}

// ---------------------------------------------------------------------------------
//	¥ delete:
// ---------------------------------------------------------------------------------
- (IBAction)delete:(id)sender
{
    NSArray* items;
    FilterEntry* item;
    int row;
    int level;
    // find currently selected items
    row = [outlineViewOutlet selectedRow];
    level = [outlineViewOutlet levelForRow:row];
    items = [outlineViewOutlet selectedItems];
    // remove them
    [self deleteItems:items];
    // update selection
    if (row) {
        item = [outlineViewOutlet selectedItem];
        if (!item) [outlineViewOutlet selectRow:row-1 byExtendingSelection:NO];
        else if ([outlineViewOutlet levelForItem:item] < level)
            [outlineViewOutlet selectRow:row-1 byExtendingSelection:NO];
    }
    [self outlineViewSelectionDidChange:nil];
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
	[self updateRuleCount];
}

// ---------------------------------------------------------------------------------
//	¥ deleteItems:
// ---------------------------------------------------------------------------------
- (void)deleteItems:(NSArray *)items
{
    FilterEntry* item;
    FilterEntry* parent;
    NSMutableArray* orphans = nil;
    NSEnumerator* enReverse;
    int index;
    // remove in reverse order (bottem to top)
    enReverse = [items reverseObjectEnumerator];
    while (item = [enReverse nextObject]) {
        // if children are expanded, try to save them
        if ([outlineViewOutlet isItemExpanded:item]) orphans = [item children];
        index = [item nodeIndex];
        // remove item from parent
        parent = [item nodeParent];
        [parent removeChild:item];
        // add any orphans to parent
        if (orphans) {
            NSEnumerator* en;
            en = [orphans objectEnumerator];
            while (item = [en nextObject]) {
                [parent insertChild:item atIndex:index];
                index += 1;
            }
        }
		// update node numbers
		[parent setNodeNumber:nil];		
    }
    [outlineViewOutlet reloadData];
	[self updateRuleCount];
}

// ---------------------------------------------------------------------------
//	¥ blockIPv6CheckBox
// ---------------------------------------------------------------------------
- (IBAction)blockIPv6CheckBox:(id)sender
{
	[sentryState setBlockIPv6:[blockIPv6CheckBox objectValue]];
}

#pragma mark --- TRIGGER ---
// ---------------------------------------------------------------------------
//	¥ setTriggerDataSource
// ---------------------------------------------------------------------------
// set and retain data source for trigger table view
- (void)setTriggerDataSource:(TriggerTable *)value
{
	TriggerTable* prev;
	[value retain];
	prev = [triggerTableView dataSource];
	[triggerTableView setDataSource:value];
	[prev release];
}

// ---------------------------------------------------------------------------
//	¥ triggerNew
// ---------------------------------------------------------------------------
- (IBAction)triggerNew:(id)sender
{
	int selectedRow;
	TriggerEntry* entry;
	TriggerTable* triggerTable = [triggerTableView dataSource];
	// allocate new entry
	entry = [[[TriggerEntry alloc] init] autorelease];
	// look for selected row if any as starting point for new entry
	selectedRow = [triggerTableView selectedRow];
	if (selectedRow < 0) selectedRow = [triggerTable count] - 1; // if none selected, use last row
	// initialize corresponding values
	if (selectedRow >= 0) {
		TriggerEntry* tEntry = [triggerTable objectAtIndex:selectedRow];
		u_int32_t address = ipForString([tEntry ipAddress]);
		u_int32_t endOffset = [[tEntry endOffset] unsignedIntValue];
		[entry setIpAddress:stringForIP(address+endOffset+1)];
		[entry setType:[tEntry type]];
		[entry setDuration:[tEntry duration]];
	}
	else {
		[entry setIpAddress:stringForIP(1)];
		[entry setType:[NSNumber numberWithInt:kTriggerTypeTrigger]];
		[entry setDuration:[triggerDefaultDuration objectValue]];
	}
	[entry setLastTime:[NSDate date]];
	[triggerTable insertObject:entry];
	[triggerTableView reloadData];
	if (selectedRow >= 0) [triggerTableView selectRow:selectedRow+1 byExtendingSelection:NO];
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ triggerDelete
// ---------------------------------------------------------------------------
- (IBAction)triggerDelete:(id)sender
{
	NSEnumerator* en;
	NSNumber* num;
	TriggerEntry* entry;
	NSString* str;
	NSMutableString* contentStr;
	NSMutableArray* entryArray;
	TriggerTable* triggerTable;
	
	triggerTable = (TriggerTable *)[triggerTableView dataSource];
	// build list of addresses from selected table rows
	contentStr = [[[NSMutableString alloc] init] autorelease];
	entryArray = [[[NSMutableArray alloc] init] autorelease];
	en = [triggerTableView selectedRowEnumerator];
	while (num = [en nextObject]) {
		entry = [triggerTable objectAtIndex:[num intValue]];
		if (entry) {
			[entryArray addObject:entry];
			// convert entry information to address:type string
			str = [NSString stringWithFormat:@"%@:%@",[entry ipAddress],[entry type]];
			if (![contentStr length]) [contentStr appendString:str];
			else [contentStr appendFormat:@",%@",str];
		}
	}
	if ([entryArray count]) {
		// invoke action
			// For consistency SentryDocument only calls out to SentryState.
			// SentryModel responds to notifications from SentryState allowing
			// other observers to respond as well.
		[sentryState updateParameter:SA_triggerDelete withObject:contentStr];
		[triggerTableView deselectAll:sender];
		// remove entries manually in case they are not found in NKE
		en = [entryArray objectEnumerator];
		while (entry = [en nextObject]) {
			[triggerTable removeObject:entry];
		}
		[triggerTableView reloadData];  // in case there's no update message from NKE
	}
	[sentryState setApplyPending:[NSNumber numberWithInt:1]];
}

// ---------------------------------------------------------------------------
//	¥ triggerImport
// ---------------------------------------------------------------------------
- (IBAction)triggerImport:(id)sender
{
	[[MenuDispatch sharedInstance] triggerImportShowWindow:sender];
}

// ---------------------------------------------------------------------------
//	¥ triggerDefaultDuration
// ---------------------------------------------------------------------------
- (IBAction)triggerDefaultDuration:(id)sender
{
	id object = [triggerDefaultDuration objectValue];
	[sentryState setTriggerDuration:object];
	[[SentryModel sharedInstance] enableTriggerDuration:object];
	[[[AppDelegate sharedInstance] prefs] setObject:object forKey:SS_triggerDuration];
	// reload table to show updated expiration times
	[triggerTableView reloadData];
}

- (IBAction)whoisButton:(id)sender
{
    int row;
    TriggerEntry* entry;
    NSString* addressStr;
	NSURL* url;
	BOOL result;
    
    row = [triggerTableView selectedRow];
    // share our input/results with other tools
    if (row >= 0) {
        entry = [(TriggerTable *)[triggerTableView dataSource] objectAtIndex:row];
        addressStr = [entry ipAddress];
		if (addressStr) {
			url = [NSURL URLWithString:[NSString stringWithFormat:
				@"whois://%@@whois.arin.net",addressStr]];
			result = [[NSWorkspace sharedWorkspace] openURL:url];
			//if (!result) [statusInfo setStringValue:@"No helper found for whois:// URL"];
			if (!result) {
				NSString* text;
				text = [NSString stringWithFormat:@"This feature requires a helper application like IPNetMonitorX to handle URLs of the form whois://%@.",addressStr];
				NSRunAlertPanel(PS_PRODUCT_NAME,
					text,
					@"OK",
					nil,
					nil);
			}
		}
    }
}

- (IBAction)traceButton:(id)sender
{
    int row;
    TriggerEntry* entry;
    NSString* addressStr;
	NSURL* url;
	BOOL result;
    
    row = [triggerTableView selectedRow];
    // share our input/results with other tools
    if (row >= 0) {
        entry = [(TriggerTable *)[triggerTableView dataSource] objectAtIndex:row];
        addressStr = [entry ipAddress];
		if (addressStr) {
			url = [NSURL URLWithString:[NSString stringWithFormat:
				@"traceroute://%@",addressStr]];
			result = [[NSWorkspace sharedWorkspace] openURL:url];
			//if (!result) [statusInfo setStringValue:@"No helper found for traceroute:// URL"];
			if (!result) {
				NSString* text;
				text = [NSString stringWithFormat:@"This feature requires a helper application like IPNetMonitorX to handle URLs of the form traceroute://%@.",addressStr];
				NSRunAlertPanel(PS_PRODUCT_NAME,
					text,
					@"OK",
					nil,
					nil);
			}
		}
    }
}


- (IBAction)lookupButton:(id)sender
{
    int row;
    TriggerEntry* entry;
    NSString* addressStr;
	NSString* urlStr;
    
    row = [triggerTableView selectedRow];
    // share our input/results with other tools
    if (row >= 0) {
        entry = [(TriggerTable *)[triggerTableView dataSource] objectAtIndex:row];
        addressStr = [entry ipAddress];
		if (addressStr) {
			urlStr = [NSString stringWithFormat:@"lookup://%@",addressStr];
			// create a lookup Window
			MenuDispatch *menuDispatch = [MenuDispatch sharedInstance];
			[menuDispatch lookupShowWindow:self];
			// lookup corresponding target
			[[menuDispatch lookupWindowC] lookupWithURL:urlStr];
		}
    }
}

#pragma mark --- NSOUTLINEVIEW_DELEGATE_METHODS ---
// =================================================================================
// NSOutlineView Delegate methods
// =================================================================================

// NSTableView replacements
//- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item;

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    int returnValue = NO;
    if ([[tableColumn identifier] isEqualTo:CID_NAME]) returnValue = YES;
	else if ([[tableColumn identifier] isEqualTo:CID_PARAMETER]) returnValue = YES;
    else if ([[tableColumn identifier] isEqualTo:CID_VALUE]) returnValue = YES;
    return returnValue;
}
//- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView;
//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
//- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectTableColumn:(NSTableColumn *)tableColumn;

// NSOutlineView specific
// ---------------------------------------------------------------------------------
//	¥ outlineViewItemDidExpand:
// ---------------------------------------------------------------------------------
- (void)outlineViewItemDidExpand:(NSNotification *)notification {
    id item;
	item = [[notification userInfo] objectForKey:@"NSObject"];
	if ([item isEqual:[outlineViewOutlet selectedItem]]) {
		//[newButton setTitle:NSLocalizedString(@"New Child",@"New Child")];
		createChild = YES;    
	}
	// update node numbers (defensive - expanding will refresh node numbers)
	[item setNodeNumber:nil];
}
// ---------------------------------------------------------------------------------
//	¥ outlineViewItemDidCollapse:
// ---------------------------------------------------------------------------------
- (void)outlineViewItemDidCollapse:(NSNotification *)notification {
	id item;
	item = [[notification userInfo] objectForKey:@"NSObject"];
	if ([item isEqual:[outlineViewOutlet selectedItem]]) {
		//[newButton setTitle:NSLocalizedString(@"New Sibling",@"New Sibling")];
		createChild = NO;
	}
}

//- (void)outlineView:(NSOutlineView *)outlineView willDisplayOutlineCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item;

// ---------------------------------------------------------------------------------
//	¥ outlineViewSelectionDidChange:
// ---------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{
    // enable New and Delete based on row selected
    if ([outlineViewOutlet selectedRow] >= 0) {
        // valid row
        // update New Button based on whether item is expanded
        if ([outlineViewOutlet isItemExpanded:[outlineViewOutlet selectedItem]]) {
            //[newButton setTitle:NSLocalizedString(@"New Child",@"New Child")];
			[toggleSiblingChildButton setImage:[NSImage imageNamed:@"expanded.tiff"]];
            createChild = YES;    
        }
        else {
            //[newButton setTitle:NSLocalizedString(@"New Sibling",@"New Sibling")];
			[toggleSiblingChildButton setImage:[NSImage imageNamed:@"collapsed.tiff"]];
            createChild = NO;
        }
        [newButton setEnabled:YES];
        [deleteButton setEnabled:YES];

        // set value list based on property
        NSNumber* property = [[outlineViewOutlet selectedItem] valueForKey:FE_property];
        [self selectProperty:[property intValue]];
    }
    else {
        // no row selected
        if ([[outlineViewOutlet dataSource] numberOfChildren]) [newButton setEnabled:NO];
        else {
            //[newButton setTitle:NSLocalizedString(@"New Child",@"New Child")];
            [newButton setEnabled:YES];
        }
        [deleteButton setEnabled:NO];
    }    
}

// ---------------------------------------------------------------------------------
//	¥ outlineView:willDisplayCell:forTableColumn:item:
// ---------------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([[tableColumn identifier] isEqualTo:CID_VALUE]) {
        // set value list based on property
        NSNumber* property = [[outlineViewOutlet selectedItem] valueForKey:FE_property];
        [self selectProperty:[property intValue]];
	}
}

@end
