//
//  DiagnosticWC.h
//  IPNetRouterX
//
//  Created by psichel on Fri Dec 8 2006.
//  Copyright (c) 2006 Sustainable Softworks. All rights reserved.
//
//  Window controller for viewing NKE memory diagnostic

#include "Test_In_Client.h"
#import "DiagnosticWC.h"
#import "DiagnosticModel.h"
#import "PSSharedDictionary.h"
#import "SentryController.h"
#import "PSSupport.h"
#import "SentryModel.h"

@implementation DiagnosticWC
- init
{
    if (self = [super init]) {
        // initialize instance vars
		// use awakeFromNib
		diagnosticModel = nil;
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	// use windowWillClose
    [super dealloc];
}

// initialize
- (void)awakeFromNib {
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	// initialize instance vars
	diagnosticModel = [DiagnosticModel sharedInstance];
	// double action
	//[tableView setDoubleAction:@selector(doubleAction:)];
	// setup to receive messages from DiagnosticModel
	[diagnosticModel addObserver:self withSelector:@selector(receiveNotification:)];
	// display current state
	[memoryUseTableView setDataSource:diagnosticModel];
	[memoryUseTableView reloadData];
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;

	[diagnosticModel removeObserver:self];
	// remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kDiagnosticName];
    // remember settings
 	
    [self autorelease];
}

#pragma mark -- Actions --
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
    //id object;
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
			if ([key isEqualTo:@"memStatUpdate"]) [memoryUseTableView reloadData];
			//object = [dictionary objectForKey:key];
			
		}	// while ((key = [enumerator nextObject]))
	} while (false);
    [pool release];
}


// ---------------------------------------------------------------------------------
//	¥ reportMemoryUse
// ---------------------------------------------------------------------------------
// toggle memStatUpdate flag in NKE
- (IBAction)reportMemoryUse:(id)sender
{
	NSNumber* value = [sender objectValue];
	#if TEST_IN_CLIENT
		if ([value intValue]) PROJECT_flags |= kFlag_memStats;
		else PROJECT_flags &= ~kFlag_memStats;
	#else
		int result;
		NSString* str = [NSString stringWithFormat:@"%@;%@=%@",kKFTSetFlags,kFlagId_memStats,[value stringValue]];
		result = [[SentryController sharedInstance] sendURL:str];
		if (result != 0) NSLog(@"reportMemoryUse encountered an unexpected error: %s",strerror(errno));
	#endif
}

// ---------------------------------------------------------------------------------
//	¥ myHelp
// ---------------------------------------------------------------------------------
- (IBAction)myHelp:(id)sender
{
    openHelpAnchor(@"DiagnosticHelp");
}

@end
