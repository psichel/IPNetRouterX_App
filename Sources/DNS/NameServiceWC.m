//
//  NameServiceWC.m
//  IPNetRouterX
//
//  Created by psichel on Tue Jan 03 2006.
//  Copyright (c) 2006 Sustainable Softworks. All rights reserved.
//
//  Window controller for configuring UNIX bind BIND

#import "NameServiceWC.h"
#import "NameServiceModel.h"
#import "PSSharedDictionary.h"
#import "PSSupport.h"
#import "SentryModel.h"
#import "InterfaceTable.h"
#import "InterfaceEntry.h"
#import "SystemConfiguration.h"
#import "Authorization.h"
#import "LocalNetworksDS.h"
#import "HostNamesDS.h"

@interface NameServiceWC (PrivateMethods)
- (void)updateZones;
@end

@implementation NameServiceWC

// initialize
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

- (void)awakeFromNib {
	//SentryModel* sentryModel = [SentryModel sharedInstance];
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	
	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
		[applyButton setEnabled:YES];
		[startButton setEnabled:YES];
	}
	else {
		[applyButton setEnabled:NO];
		[startButton setEnabled:NO];
	}

	previousTitle = nil;
	refreshTimer = nil;
	nameServiceModel = [NameServiceModel sharedInstance];
	[nameServiceModel addObserver:self withSelector:@selector(receiveNotification:)];
	
	// *** Temporary *** move to Sentry Restore state so window just shows current status
	// restore state to make sure templates are loaded
	// [nameServiceModel nameServiceRestore];
	
	// load templateFile menu
	{
		[self updateZones];
		[templateFilePopUp selectItemWithTitle:kDNS_named_conf];
		[self templateFilePopUp:nil];
		[self setPreviousTitle:[[templateFilePopUp selectedItem] title]];
	}
	
	// setup templateView attributes
	NSTextStorage* ts = [templateView textStorage];
	[ts setFont:[NSFont fontWithName:@"Monaco" size:10]];
	
	// show named state
	[nameServiceModel serverState];
	// refresh named state
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
		target:self
		selector:@selector(refreshTimer:)
		userInfo:nil
		repeats:YES];					
}

- (void)updateZones
{
	NSEnumerator* en;
	NSString* network;
	NSString* zoneName;
	NSString* title;
	[templateFilePopUp removeAllItems];
	// add standard items
	[templateFilePopUp addItemWithTitle:kDNS_named_conf];
	[templateFilePopUp addItemWithTitle:kDNS_named_cache];
	[templateFilePopUp addItemWithTitle:kDNS_localhost_zone];
	[templateFilePopUp addItemWithTitle:kDNS_localhost_rev];
	// separator
	[[templateFilePopUp menu] addItem:[NSMenuItem separatorItem]];
	// walk zone list
	en = [[nameServiceModel enabledInternals] objectEnumerator];
	while (network = [en nextObject]) {
		zoneName = [nameServiceModel zoneNameForNetwork:network]; 
		// forward
		title = [NSString stringWithFormat:@"%@.zone",zoneName];
		[templateFilePopUp addItemWithTitle:title];
		// reverse
		title = [NSString stringWithFormat:@"%@.rev",zoneName];
		[templateFilePopUp addItemWithTitle:title];
	}
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
	
	// no longer want timer events
	[refreshTimer invalidate];   refreshTimer = nil;
	[nameServiceModel removeObserver:self];
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kNameService_name];
 	
    [self autorelease];
}

- (NSString *)previousTitle { return previousTitle; }
- (void)setPreviousTitle:(NSString *)value
{
	[value retain];
	[previousTitle release];
	previousTitle = value;
}

#pragma mark -- Display Functions --
// ---------------------------------------------------------------------------------
//	¥ templateFilePopUp
// ---------------------------------------------------------------------------------
// show current templetEdit
- (IBAction)templateFilePopUp:(id)sender
{
	NSMutableDictionary* templateEdit = [nameServiceModel templateEdit];
	NSDictionary* templateDefault = [nameServiceModel templateDefault];
	NSString* text;
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// transfer edited textview to templateEdit
	if (previousTitle) {
		text = clean([templateView string]);
		[templateEdit setObject:text forKey:previousTitle];
	}
	// display requested template
	NSString* title = [[templateFilePopUp selectedItem] title];
	text = [templateEdit objectForKey:title];
	if (text) [templateView setString:text];
	else {
		// if not found, use default
		text = [templateDefault objectForKey:title];
		if (text) [templateView setString:text];
		else {
			// if not a default template, copy lan.zone or lan.rev
			if ([title hasSuffix:@"zone"]) text = [templateDefault objectForKey:kDNS_lan_zone];
			else text = [templateDefault objectForKey:kDNS_lan_rev];
			if (text) [templateView setString:text];
			[templateView setString:@""];
		}
	}
	// remember previously selected title
	[self setPreviousTitle:title];
}

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

			// window fields
			if ([key isEqualTo:@"statusInfo"])	[statusInfo setStringValue:object];
			else if ([key isEqualTo:@"startButton"])	[startButton setTitle:object];
			else if ([key isEqualTo:@"nameServerState"])	[nameServerState setStringValue:object];
			else if ([key isEqualTo:@"stateDescription"])	[stateDescription setStringValue:object];
			else if ([key isEqualTo:@"templateFilePopUp"])	[templateFilePopUp setObjectValue:object];			
			else if ([key isEqualTo:@"templateView"])	[templateView setString:object];
			else if ([key isEqualTo:kLocalNetworksTableView])	[localNetworksTableView reloadData];
			else if ([key isEqualTo:kHostNamesTableView])	[hostNamesTableView reloadData];
			else if ([key isEqualTo:@"refreshTemplate"])	[self refreshTemplate];
			else if ([key isEqualTo:@"updateZones"])	[self updateZones];			
		}	// while ((key = [enumerator nextObject]))
	} while (false);
    [pool release];
}

// ---------------------------------------------------------------------------------
//	¥ myHelp
// ---------------------------------------------------------------------------------
- (IBAction)myHelp:(id)sender
{
	//NSString* tabID;
	NSString* document = @"DNSServerHelp";

	//tabID = [[tabView selectedTabViewItem] identifier];
//	if ([tabID isEqualTo:@"filters"])  document = @"FirewallDocument"; // Filters
	openHelpAnchor(document);
}

// ---------------------------------------------------------------------------------
//	¥ showLog
// ---------------------------------------------------------------------------------
- (IBAction)showLog:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:@"/Library/Logs/named.log" withApplication:@"Console"];
}

#pragma mark -- ACTIONS --

// ---------------------------------------------------------------------------
//	¥ startButton
// ---------------------------------------------------------------------------
- (IBAction)startButton:(id)sender
{
	// get current state
	NSNumber* value;
	if ([nameServiceModel namedIsRunning]) value = [NSNumber numberWithInt:0];
	else value = [NSNumber numberWithInt:1];
	// perform request
	[nameServiceModel setNameServiceOn:value];
}

// ---------------------------------------------------------------------------
//	¥ saveButton
// ---------------------------------------------------------------------------
// save active settings
- (IBAction)saveButton:(id)sender
{
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// transfer edited textview to templateEdit
	NSString* title = [[templateFilePopUp selectedItem] title];
	NSString* text = clean([templateView string]);
	[[nameServiceModel templateEdit] setObject:text forKey:title];
	// copy templateEdit to templateActive
	[nameServiceModel setTemplateActive:[nameServiceModel templateEdit]];
	// save active settings
	[nameServiceModel nameServiceSave];
}

// ---------------------------------------------------------------------------
//	¥ revertButton
// ---------------------------------------------------------------------------
// revert text view to previously saved configuration
- (IBAction)revertButton:(id)sender
{
	[nameServiceModel nameServiceRestore];
}

// ---------------------------------------------------------------------------
//	¥ applyButton
// ---------------------------------------------------------------------------
// templateActive <= templateEdit	! transfer edited settings to active
// nameServiceApply					! Apply active settings
- (IBAction)applyButton:(id)sender
{
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// transfer edited textview to templateEdit
	NSString* title = [[templateFilePopUp selectedItem] title];
	NSString* text = clean([templateView string]);
	[[nameServiceModel templateEdit] setObject:text forKey:title];
	// set active settings
	[nameServiceModel setTemplateActive:[nameServiceModel templateEdit]];
	[nameServiceModel nameServiceApply];
}

// ---------------------------------------------------------------------------
//	¥ resetToDefaultButton
// ---------------------------------------------------------------------------
// reset selected template to its default in edit view
- (IBAction)resetToDefaultButton:(id)sender
{
	NSString* title = [[templateFilePopUp selectedItem] title];
	NSString* defaultText = [[nameServiceModel templateDefault] objectForKey:title];
	if (!defaultText) {
		// if not a default template, copy lan.zone or lan.rev
		if ([title hasSuffix:@"zone"]) defaultText = [[nameServiceModel templateDefault] objectForKey:kDNS_lan_zone];
		else defaultText = [[nameServiceModel templateDefault] objectForKey:kDNS_lan_rev];
	}
	[[nameServiceModel templateEdit] setObject:defaultText forKey:title];
	// refresh display
	[templateView setString:defaultText];
	[statusInfo setObjectValue:[NSString stringWithFormat:@"Default %@ restored.",title]];
	// setup templateView attributes
	NSTextStorage* ts = [templateView textStorage];
	[ts setFont:[NSFont fontWithName:@"Monaco" size:10]];
}

// ---------------------------------------------------------------------------
//	¥ fillInTemplateButton
// ---------------------------------------------------------------------------
// fill in selected template in edit view
- (IBAction)fillInTemplateButton:(id)sender
{
	NSString* title = [[templateFilePopUp selectedItem] title];
	if ([title isEqualTo:kDNS_named_conf]) [nameServiceModel doTemplate_named_conf];
	else if ([title isEqualTo:kDNS_named_cache]) [nameServiceModel doTemplate_named_cache];
	else [nameServiceModel doTemplate_zone:title];

	// refresh display
	NSString* text = [[nameServiceModel templateEdit] objectForKey:title];
	[templateView setString:text];
//	[statusInfo setObjectValue:[NSString stringWithFormat:@"Template %@ filled.",title]];
}

// ---------------------------------------------------------------------------
//	¥ refreshTemplate
// ---------------------------------------------------------------------------
// fill in selected template in edit view
- (void)refreshTemplate
{
	NSString* title = [[templateFilePopUp selectedItem] title];
	// refresh display
	NSString* text = [[nameServiceModel templateEdit] objectForKey:title];
	[templateView setString:text];
//	[statusInfo setObjectValue:[NSString stringWithFormat:@"Template %@ filled.",title]];
}

// ---------------------------------------------------------------------------
//	¥ refreshTimer:
// ---------------------------------------------------------------------------
// check named state at regular intervals
- (void)refreshTimer:(id)timer
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	// show named state
	if ([[nameServiceModel nameServiceOn] intValue]) [nameServiceModel serverState];
	[pool release];
}


@end

// ---------------------------------------------------------------------------------
//	¥ clean
// ---------------------------------------------------------------------------------
NSString* clean(NSString* inText)
{
//	NSString* working = [[inText copy] autorelease];
	NSMutableString* working = [NSMutableString stringWithString:inText];	
	[working replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0,[working length])];
	return (NSString*)working;
}
