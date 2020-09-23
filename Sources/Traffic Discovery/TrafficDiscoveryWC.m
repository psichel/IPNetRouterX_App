//
//  TrafficDiscoveryWC.m
//  IPNetRouterX
//
//  Created by psichel on Tue Feb 28 2006.
//  Copyright (c) 2006 Sustainable Softworks. All rights reserved.
//
//  Window controller for viewing service and device traffic data

#import "TrafficDiscoveryWC.h"
#import "TrafficDiscoveryModel.h"
#import "TrafficDiscoveryState.h"
#import "PSSharedDictionary.h"
#import "TDEntry.h"
#import "PSNumberFormatter.h"
#import "PSPlotView.h"
#import "PSPlotEntry.h"
#import "PSSupport.h"

#define preferences [NSUserDefaults standardUserDefaults]

@implementation TrafficDiscoveryWC
- init
{
    if (self = [super init]) {
        // initialize instance vars
		trafficDiscoveryState = nil;
		trafficDiscoveryModel = nil;
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	// no longer want trafficDiscovery updates
	[trafficDiscoveryState removeObserver:self];
	[trafficDiscoveryModel removeObserver:self];
    [super dealloc];
}
// initialize
- (void)awakeFromNib {

	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
	NSString* str;
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	
	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
		[stepGo setEnabled:YES];
		[trafficDiscoveryOn setEnabled:YES];
	}
	else {
		[stepGo setEnabled:NO];
		[trafficDiscoveryOn setEnabled:NO];
	}
	// initialize instance vars
	trafficDiscoveryModel = [TrafficDiscoveryModel sharedInstance];
	// setup table cells for display
	NSTableColumn* tableColumn;
	[numberField setBordered:NO];
	[numberField setFormatter:[[[PSNumberFormatter alloc] init] autorelease] ];
	tableColumn = [tableView tableColumnWithIdentifier:TDE_bytesIn];
	[tableColumn setDataCell:[numberField cell]];
	tableColumn = [tableView tableColumnWithIdentifier:TDE_bytesOut];
	[tableColumn setDataCell:[numberField cell]];
	tableColumn = [tableView tableColumnWithIdentifier:TDE_totalIn];
	[tableColumn setDataCell:[numberField cell]];
	tableColumn = [tableView tableColumnWithIdentifier:TDE_totalOut];
	[tableColumn setDataCell:[numberField cell]];
	tableColumn = [tableView tableColumnWithIdentifier:TDE_maxIn];
	[tableColumn setDataCell:[numberField cell]];
	tableColumn = [tableView tableColumnWithIdentifier:TDE_maxOut];
	[tableColumn setDataCell:[numberField cell]];
	// highlighted table column
	[self viewByPopUp:nil];
	tableColumn = [tableView tableColumnWithIdentifier:TDE_service];
	[tableView setHighlightedTableColumn:tableColumn];
	// double action
	[tableView setDoubleAction:@selector(doubleAction:)];
	
	[stepReverse setContinuous:YES];
	[stepForward setContinuous:YES];

    // restore settings
    int count = instanceCount([TrafficDiscoveryWC class]);
    NS_DURING
        if ((str = [preferences objectForKey:instanceName(kTrafficDiscovery_plotType,count-1)]))
            [plotType selectItemWithTitle:str];
        if ((str = [preferences objectForKey:instanceName(kTrafficDiscovery_viewBy,count-1)])) {
            [viewByPopUp selectItemWithTitle:str];
			[self viewByPopUp:nil];
		}
        if ((str = [preferences objectForKey:instanceName(kTrafficDiscovery_interval,count-1)]))
            [intervalPopUp selectItemWithTitle:str];
    NS_HANDLER
		NSLog(@"Exception during TrafficDiscovery.m awakeFromNib");
    NS_ENDHANDLER
	trafficDiscoveryState = [TrafficDiscoveryState sharedInstance];
	// setup to receive messages from SentryState
	[trafficDiscoveryState addObserver:self withSelector:@selector(receiveNotification:)];
	// setup to receive messages from TrafficDiscoveryModel
	[trafficDiscoveryModel addObserver:self withSelector:@selector(receiveNotification:)];
	[tableView setDataSource:trafficDiscoveryModel];
	// display current state
	[trafficDiscoveryOn setObjectValue:[trafficDiscoveryState trafficDiscovery]];
	[deviceButton setObjectValue:[trafficDiscoveryState tdDevice]];
	[serviceButton setObjectValue:[trafficDiscoveryState tdService]];
	[netflowButton setObjectValue:[trafficDiscoveryState tdNetflow]];
	// start the show
	nowPlaying = NO;	// initialize before using
	[self setShowNow:[[trafficDiscoveryState trafficDiscovery] intValue]];
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
	NSNumber* object;
	int count;
	
	[trafficDiscoveryState removeObserver:self];
//	[[NameServiceModel sharedInstance] removeObserver:self];
	// no longer want trafficDiscovery updates
	[trafficDiscoveryModel removeObserver:self];
	// get instance count, try dictionary first
    object = [[PSSharedDictionary sharedInstance] objectForKey:@"instanceCount"];
    if (object) count = [object intValue];
    else count = instanceCount([TrafficDiscoveryWC class]);
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:instanceName(kTrafficDiscovery_name,count-1)];
    // remember settings
    [preferences setObject:[[plotType selectedItem] title]
		forKey:instanceName(kTrafficDiscovery_plotType,count-1)];
    [preferences setObject:[[viewByPopUp selectedItem] title]
		forKey:instanceName(kTrafficDiscovery_viewBy,count-1)];
    [preferences setObject:[[intervalPopUp selectedItem] title]
		forKey:instanceName(kTrafficDiscovery_interval,count-1)];
 	
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
	NSString* name;
	
	do {    
		name = [aNotification name];
		if ([name isEqualTo:NSWindowWillCloseNotification]) {
			[self windowWillClose:aNotification];
			break;
		}
		[self receiveDictionary:[aNotification userInfo]];
	} while (false);
}

// ---------------------------------------------------------------------------------
//	¥ receiveDictionary:
// ---------------------------------------------------------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSEnumerator* enumerator;
    id key;
	id object;

	enumerator = [dictionary keyEnumerator];
	while ((key = [enumerator nextObject])) { 
		/* code that uses the returned key */
		if (![key isKindOfClass:[NSString class]]) continue; 
		object = [dictionary objectForKey:key];

		// window fields
		//if ([key isEqualTo:@"statusInfo"])	[statusInfo setStringValue:object];
		if (nowPlaying) {
			if ([key isEqualTo:TDNotification]) {
				if (showNow) {
					[self checkSort];
					[tableView reloadData];
					[self movePlot:1];
					//NSLog(TDNotification);
				}
				else {
					[self stepForward:nil];
				}
			}
			else if ([key isEqualTo:@"dateField"]) {
				if (showNow) {
					[dateField setObjectValue:object];
				}
			}
			else if ([key isEqualTo:@"eventTimer"]) {
				[self stepForward:nil];
				//NSLog(@"eventTimer");
			}
			else if ([key isEqualTo:@"lookupComplete"]) {
				if (showNow) {
					[tableView reloadData];
				}
			}
		}
		if ([key isEqualTo:TDNewGroup]) {
			[tableView reloadData];
			if ([tableView selectedRow] >= 0) [self reloadPlot];
		}
		else if ([key isEqualTo:SS_trafficDiscovery]) [trafficDiscoveryOn setObjectValue:object];
		else if ([key isEqualTo:SS_tdDevice]) [deviceButton setObjectValue:object];
		else if ([key isEqualTo:SS_tdService]) [serviceButton setObjectValue:object];
		else if ([key isEqualTo:SS_tdNetflow]) [netflowButton setObjectValue:object];
		
	}	// while ((key = [enumerator nextObject]))
	[pool release];
}

// ---------------------------------------------------------------------------------
//	¥ checkSort
// ---------------------------------------------------------------------------------
// if sorting on traffic stats and interval=kIntervalSecond, update sort periodically
- (void)checkSort
{
	if ([self interval] == kIntervalSecond) {
		NSString* sortBy = [[tableView highlightedTableColumn] identifier];
		if ([sortBy hasPrefix:@"percent"] || [sortBy hasPrefix:@"bytes"] || [sortBy hasPrefix:@"max"]) {
			// every 5 seconds
			if ([[self showDate] secondOfMinute] % 5 == 0) {
				// reset sort keys
				NSString* filePrefix;
				NSString* fileName = nil;
				filePrefix = filePrefixForViewBy([self viewBy]);
				fileName = fileNameWithDate(filePrefix, [self showDate]);
				if (fileName) [trafficDiscoveryModel updateIndex:fileName];
			}
		}
	}
}

// ---------------------------------------------------------------------------------
//	¥ movePlot
// ---------------------------------------------------------------------------------
// update plotView from table data by adding on either end
// direction: 1=forward; 0=back
- (void)movePlot:(int)direction
{
	PSPlotEntry* pEntry;
	int plotIndex;
	
	// add empty entry to move plot
	pEntry = [[[PSPlotEntry alloc] init] autorelease];
	if (direction == 1) plotIndex = [bytePlotView addEntry:pEntry];
	else plotIndex = [bytePlotView addEntryBack:pEntry];
	int selectedRow, row;
	TDDayGroup* dayGroup;
	TDEntry* tdEntry;
	NSCalendarDate* date;

	date = [self showDate];
	if (direction == 0) date = [date dateByAddingTimeInterval:-60];
	selectedRow = [tableView selectedRow];
	if (selectedRow < 0) row = 0;
	else row = selectedRow;
	dayGroup = [trafficDiscoveryModel dayGroupForDate:date tableView:tableView row:row];
	tdEntry = [dayGroup tdEntryForDate:date interval:[self interval]];
	// update entry at index
	[tdEntry setPlotIndex:plotIndex];
	[self loadPlotEntry:tdEntry];
}


// ---------------------------------------------------------------------------------
//	¥ reloadPlot
// ---------------------------------------------------------------------------------
// reload plotView from table data
- (void)reloadPlot
{
	int selectedRow, row;
	TDDayGroup* dayGroup;
	TDEntry* tdEntry;
	NSCalendarDate* date;
	int i;

	// desired row
	selectedRow = [tableView selectedRow];
	if (selectedRow < 0) row = 0;
	else row = selectedRow;
	// date range
	date = [self showDate];
	int interval = [intervalPopUp indexOfSelectedItem];
	int seconds = tdSecondsForInterval(interval);
	for (i=0; i<=60; i++) {
		dayGroup = [trafficDiscoveryModel dayGroupForDate:date tableView:tableView row:row];
		tdEntry = [dayGroup tdEntryForDate:date interval:interval];
		[tdEntry setPlotIndex:i];
		[self loadPlotEntry:tdEntry];
		// advance date for next entry
		date = [date dateByAddingTimeInterval:-seconds];
	}
}

// ---------------------------------------------------------------------------------
//	¥ setShowNow
// ---------------------------------------------------------------------------------
- (BOOL)showNow { return showNow; }
- (void)setShowNow:(BOOL)value
{
	if (value) {
		// showNow set to YES
		[showNowButton setEnabled:NO];
		[stepForward setEnabled:NO];
		[intervalPopUp selectItemAtIndex:kIntervalSecond];
		[dateField setObjectValue:[NSCalendarDate date]];
		[self reloadPlot];
		if (!nowPlaying) [self stepGo:nil];	// play
	}
	else {
		// showNow set to NO
		[showNowButton setEnabled:YES];
		[stepForward setEnabled:YES];
		if (nowPlaying) [self stepGo:nil]; // pause
	}
	showNow = value;
}

#pragma mark -- delegate --
// ---------------------------------------------------------------------------------
//	¥ viewBy
// ---------------------------------------------------------------------------------
// return popup setting for use by dataSource
- (int)viewBy
{
	return [viewByPopUp indexOfSelectedItem];
}

// ---------------------------------------------------------------------------------
//	¥ sortBy
// ---------------------------------------------------------------------------------
// return popup setting for use by dataSource
- (NSString *)sortBy
{
	return [[tableView highlightedTableColumn] identifier];
}

// ---------------------------------------------------------------------------------
//	¥ interval
// ---------------------------------------------------------------------------------
// return popup setting for use by dataSource
- (int)interval
{
	return [intervalPopUp indexOfSelectedItem];
}

// ---------------------------------------------------------------------------------
//	¥ showDate
// ---------------------------------------------------------------------------------
// return dateField setting for use by dataSource
- (NSCalendarDate *)showDate
{
	return [dateField objectValue];
}

// ---------------------------------------------------------------------------------
//	¥ dayGroupKey
// ---------------------------------------------------------------------------------
- (NSString *)dayGroupKey
{
	NSString* dayGroupKey = nil;
	int selectedRow, row;

	// find selected row or use first row if none selected
	selectedRow = [tableView selectedRow];
	if (selectedRow < 0) row = 0;
	else row = selectedRow;
	if ([tableView numberOfRows] > row) {
		// get content from "identifier" column
		NSTableColumn* tableColumn = [tableView tableColumnWithIdentifier:TDE_identifier];
		dayGroupKey = [[tableView dataSource] tableView:tableView
			objectValueForTableColumn:tableColumn row:row];
	}
	return dayGroupKey;
}

// ---------------------------------------------------------------------------------
//	¥ loadPlotEntry
// ---------------------------------------------------------------------------------
- (void)loadPlotEntry:(TDEntry *)tdEntry
{
	PSPlotEntry* pEntry;
	int type = [plotType indexOfSelectedItem];
	int selectedRow = [tableView selectedRow];

	if (type == kPlotBytesOfTotal) {	
		// bytes of total
		pEntry = [[[PSPlotEntry alloc] init] autorelease];
		if (selectedRow >= 0) {
			[pEntry setReceived:[[tdEntry bytesIn] unsignedLongValue]];
			[pEntry setSent:[[tdEntry bytesOut] unsignedLongValue]];
		}
		[pEntry setDuplicate:[[tdEntry attachBytesIn] unsignedLongValue]];
		[pEntry setRetransmit:[[tdEntry attachBytesOut] unsignedLongValue]];
		[bytePlotView setEntry:pEntry atIndex:[tdEntry plotIndex]];
	}
	else if (type == kPlotBytes) {
		// bytes of total
		pEntry = [[[PSPlotEntry alloc] init] autorelease];
		[pEntry setReceived:[[tdEntry bytesIn] unsignedLongValue]];
		[pEntry setSent:[[tdEntry bytesOut] unsignedLongValue]];
		[bytePlotView setEntry:pEntry atIndex:[tdEntry plotIndex]];
	}
	else if (type == kPlotPercent) {
		// percent
		pEntry = [[[PSPlotEntry alloc] init] autorelease];
		[pEntry setReceived:[[tdEntry percentIn] unsignedLongValue]];
		[pEntry setSent:[[tdEntry percentOut] unsignedLongValue]];
		[bytePlotView setEntry:pEntry atIndex:[tdEntry plotIndex]];
	}
}

#pragma mark --- IB actions ---
- (IBAction)intervalPopUp:(id)sender
{
	int interval = [intervalPopUp indexOfSelectedItem];
	if (interval != kIntervalSecond) {
		[self setShowNow:NO];
		// check if we need to resort based on new column content
		NSString* sortBy = [[tableView highlightedTableColumn] identifier];
		if ([sortBy hasPrefix:@"percent"] || [sortBy hasPrefix:@"bytes"] || [sortBy hasPrefix:@"max"]) {
			NSString* filePrefix;
			NSString* fileName = nil;
			filePrefix = filePrefixForViewBy([self viewBy]);
			fileName = fileNameWithDate(filePrefix, [self showDate]);
			if (fileName) [trafficDiscoveryModel updateIndex:fileName];
		}
	}
	[self reloadPlot];
	[tableView reloadData];
}

- (IBAction)stepReverse:(id)sender
{
	NSCalendarDate* trafficDiscoveryDate = [dateField objectValue];
	int interval = [intervalPopUp indexOfSelectedItem];
	int seconds = tdSecondsForInterval(interval);
	// show recorded
	[self setShowNow:NO];
	trafficDiscoveryDate = [trafficDiscoveryDate dateByAddingTimeInterval:-seconds];
	[dateField setObjectValue:trafficDiscoveryDate];
	if (interval == kIntervalSecond) [self movePlot:0];
	else [self reloadPlot];
	// update sort order if needed
	[self checkSort];
	[tableView reloadData];
}

- (IBAction)stepGo:(id)sender
{
	nowPlaying = !nowPlaying;
	if (nowPlaying) {
		[stepGo setTitle:@"||"];
	}
	else {
		[stepGo setTitle:@">"];
		[self setShowNow:NO];
	}
}

- (IBAction)stepForward:(id)sender
{
	NSCalendarDate* trafficDiscoveryDate = [dateField objectValue];
	int interval = [intervalPopUp indexOfSelectedItem];
	int seconds = tdSecondsForInterval(interval);
	// show recorded (stepForward is only enabled when showNow=NO)
	trafficDiscoveryDate = [trafficDiscoveryDate dateByAddingTimeInterval:seconds];
	[dateField setObjectValue:trafficDiscoveryDate];
	if (interval == kIntervalSecond) [self movePlot:1];
	else [self reloadPlot];
	// update sort order if needed
	[self checkSort];
	[tableView reloadData];
}

- (IBAction)showNowButton:(id)sender
{
	[self setShowNow:YES];
}

- (IBAction)trafficDiscoveryOn:(id)sender
{
	[trafficDiscoveryState setTrafficDiscovery:[trafficDiscoveryOn objectValue]];
}

- (IBAction)viewByPopUp:(id)sender
{
	NSTableColumn* tableColumn;
	tableColumn = [tableView tableColumnWithIdentifier:TDE_service];
	[[tableColumn headerCell] setStringValue:[[viewByPopUp selectedItem] title]];
	int index = [viewByPopUp indexOfSelectedItem];
	if (index == kViewByDevice) [tableColumn setWidth:110];
	if (index == kViewByService) [tableColumn setWidth:80];
	if (index == kViewByNetflow) [tableColumn setWidth:300];
	[tableView reloadData];
	[self reloadPlot];
}

- (IBAction)dateField:(id)sender
{
	[tableView reloadData];
	[self reloadPlot];
}

- (IBAction)plotType:(id)sender
{
	[self reloadPlot];
}

// ---------------------------------------------------------------------------------
//	¥ doubleAction
// ---------------------------------------------------------------------------------
// get lastTime for corresponding row and move to that date
- (void)doubleAction:(id)sender
{
	int selectedRow;
	NSCalendarDate* lastTime;
	
	selectedRow = [tableView selectedRow];
	TDDayGroup *dayGroup = [trafficDiscoveryModel dayGroupForDate:[self showDate] tableView:tableView row:selectedRow];
	lastTime = [dayGroup lastTime];
	if (lastTime) {
		[self setShowNow:NO];
		[dateField setObjectValue:lastTime];
		[tableView reloadData];
		[self reloadPlot];
	}
}

- (IBAction)deviceButton:(id)sender
{
	[trafficDiscoveryState setTdDevice:[deviceButton objectValue]];
}
- (IBAction)serviceButton:(id)sender
{
	[trafficDiscoveryState setTdService:[serviceButton objectValue]];
}
- (IBAction)netflowButton:(id)sender
{
	[trafficDiscoveryState setTdNetflow:[netflowButton objectValue]];
}

- (void)moveLeft:(id)sender
{
	[self stepReverse:sender];
}

- (void)moveRight:(id)sender
{
	[self stepForward:sender];
}

// ---------------------------------------------------------------------------------
//	¥ copy
// ---------------------------------------------------------------------------------
// Edit->Copy selection to clipboard
- (void)copy:(id)sender {
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	__block NSMutableString *tString;

	[pboard declareTypes:[NSArray arrayWithObjects:NSTabularTextPboardType,NSStringPboardType,nil] owner:nil];
    tString = [[NSMutableString alloc] initWithCapacity:1024];
    // setup access to each selected row
    //en = [tableView selectedRowEnumerator];
    NSIndexSet *set = [tableView selectedRowIndexes];
    [set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id value;
        NSRange range;
        int row = idx;
		if (row == 0) {
            // include headings with first row
			NSString* identifier = nil;
			int viewBy = [self viewBy];
			if (viewBy == kViewByDevice) identifier = @"Device";
			else if (viewBy == kViewByService) identifier = @"Service";
			else identifier = @"Net Flow";
            [tString appendString:[NSString stringWithFormat:
                                   @"\nName\t%@\tInfo\tNet\tLastTime\t%% In\tBytes\tMax\t%% Out\tBytes\tMax",identifier]];
        }
        [tString appendString:@"\n"];
		NSArray* tableColumns;
		NSTableColumn* tableColumn;
		tableColumns = [tableView tableColumns];
		NSEnumerator* en2 = [tableColumns objectEnumerator];
		while (tableColumn = [en2 nextObject]) {
			value = [[tableView dataSource] tableView:tableView objectValueForTableColumn:tableColumn row:row];
			// can be NSString or NSNumber
			[tString appendFormat:@"%@\t",value];
		}
		// remove ending tab
		range.location = [tString length]-1;
		range.length = 1;
		[tString deleteCharactersInRange:range];
    }];
    
    [pboard setString:tString forType: NSTabularTextPboardType];
    [pboard setString:tString forType: NSStringPboardType];
    [tString release];
}

// ---------------------------------------------------------------------------------
//	¥ myHelp
// ---------------------------------------------------------------------------------
- (IBAction)myHelp:(id)sender
{
    NSString *filePath;
	NSURL *fileURL;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    
    if ((filePath = [thisBundle pathForResource:@"TrafficDiscoveryHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY]))
		if ((fileURL = [NSURL fileURLWithPath:filePath]))
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
}

#pragma mark -- tableView delegate --

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self reloadPlot];
}
- (void)tableView:(NSTableView *)inTableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	// remove previous selection if any
	[tableView deselectAll:nil];
	// update column used for sorting
	[inTableView setHighlightedTableColumn:tableColumn];
	NSString* filePrefix;
	NSString* fileName = nil;
	filePrefix = filePrefixForViewBy([self viewBy]);
	fileName = fileNameWithDate(filePrefix, [self showDate]);
	if (fileName) [trafficDiscoveryModel updateIndex:fileName];
	[tableView reloadData];
}
@end
