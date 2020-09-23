//
//  AlternateRouteWC.m
//  IPNetRouterX
//
//  Created by psichel on Wed Jan 3 2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Window controller for Alternate Route table and settings

#import "AlternateRouteWC.h"
#import "AlternateRouteModel.h"
#import "AppDelegate.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "DocumentSupport.h"
#import "AlternateRouteTable.h"
#import "SystemConfiguration.h"
#import "PSSupport.h"
#import "PSSharedDictionary.h"

@implementation AlternateRouteWC

// initialize
- init
{
    if (self = [super init]) {
        // initialize instance vars
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
    [super dealloc];
}

- (void)awakeFromNib {
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	// initialize instance vars

	// show current settings
	model = [AlternateRouteModel sharedInstance];
	sentryState = [[SentryModel sharedInstance] sentryState];
	// set data source for alternateRoute table
	if (![model alternateRouteTable])
		[model setAlternateRouteTable:[[[AlternateRouteTable alloc] init] autorelease]];
	[tableView setDataSource:model];
	// load interface combo box
	{
		NSTableColumn *column;
		NSComboBoxCell *cell;
		NSArray *list;
		NSEnumerator *en;
		NSString* bsdName;
		
		column = [tableView tableColumnWithIdentifier:AR_interface];
		cell = [column dataCell];
		list = [[SystemConfiguration sharedInstance] bsdTitlesAndServiceIDs:nil];
		en = [list objectEnumerator];
		while (bsdName = [en nextObject]) [cell addItemWithObjectValue:bsdName];
	}
	// automaticFailover state
	[automaticFailover setObjectValue:[sentryState automaticFailover]];
	// loadBalance state
	[loadBalance setObjectValue:[sentryState loadBalance]];
	// sourceAwareRouting state
	[sourceAwareRouting setObjectValue:[sentryState sourceAwareRouting]];

	// double action
	//[tableView setDoubleAction:@selector(doubleAction:)];
	// setup to receive messages from SentryState
	[model addObserver:self withSelector:@selector(receiveNotification:)];
	[sentryState addObserver:self withSelector:@selector(receiveNotification:)];
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
	
	[model removeObserver:self];
	[sentryState removeObserver:self];
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kAlternateRouteName];
    // remember settings
 	
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
			// route entry
			if ([key isEqualTo:AR_routeEntry])	{
				[tableView reloadData];
				continue;
			}
			// alternateRouteTable
			if ([key isEqualTo:SS_alternateRouteTable])	{
				[tableView reloadData];
				continue;
			}
			// automaticFailover
			if ([key isEqualTo:SS_automaticFailover]) {
				[automaticFailover setObjectValue:object];
				continue;
			}
			// loadBalance
			if ([key isEqualTo:SS_loadBalance]) {
				[loadBalance setObjectValue:object];
				continue;
			}
			// sourceAwareRouting
			if ([key isEqualTo:SS_sourceAwareRouting]) {
				[sourceAwareRouting setObjectValue:object];
				continue;
			}
			
		}	// while ((key = [enumerator nextObject]))
	} while (false);
    [pool release];
}


// actions
- (IBAction)addGateway:(id)sender
{
	AlternateRouteTable *routeT;
	AlternateRouteEntry *routeE;
	// create entry
	routeE = [[[AlternateRouteEntry alloc] init] autorelease];
	// add to table
	routeT = [[tableView dataSource] alternateRouteTable];
	[routeT addObject:routeE];
	// refresh table
	[tableView reloadData];
}

- (IBAction)removeGateway:(id)sender
{
	AlternateRouteTable *routeT;
	NSEnumerator *en;
	NSNumber *rowNumber;
	
	routeT = [[tableView dataSource] alternateRouteTable];
	en = [tableView selectedRowEnumerator];
	while (rowNumber = [en nextObject]) {
		[routeT removeObjectAtIndex:[rowNumber intValue]];
	}	
	// refresh table
	[tableView reloadData];
}

// ---------------------------------------------------------------------------
//	¥ automaticFailover
// ---------------------------------------------------------------------------
- (IBAction)automaticFailover:(id)sender
{
	[sentryState setAutomaticFailover:[automaticFailover objectValue]];
}

// ---------------------------------------------------------------------------
//	¥ loadBalance
// ---------------------------------------------------------------------------
- (IBAction)loadBalance:(id)sender
{
	[sentryState setLoadBalance:[loadBalance objectValue]];
}

// ---------------------------------------------------------------------------
//	¥ sourceAwareRouting
// ---------------------------------------------------------------------------
- (IBAction)sourceAwareRouting:(id)sender
{
	[sentryState setSourceAwareRouting:[sourceAwareRouting objectValue]];
}


#pragma mark -- Save & Help --
- (IBAction)saveButton:(id)sender
{
	[model alternateRouteSave];
}

- (IBAction)revertButton:(id)sender
{
	[model alternateRouteRevert];
}

- (IBAction)applyButton:(id)sender
{
	[statusInfo setStringValue:@""];
	[model alternateRouteApply];
}

- (IBAction)myHelp:(id)sender
{
    openHelpAnchor(@"AlternateRouteHelp");
}

@end
