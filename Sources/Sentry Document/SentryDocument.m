//
//  SentryDocument.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Wed Jul 24 2002.
//  Copyright (c) 2001 Sustainable Softworks, Inc. All rights reserved.
//
//  Encapsulate IPNetSentryX/IPNetRouterX document as part of MVC design.
//
//  SentryDocument displays the current model and interprets user input to change model state.
//  SentryState maintains the model state and notifies observers when it changes.
//  SentryModel observes state changes and performs the corresponding model action.
//
//  SentryDocument plays two basic roles:
//  (1) receive state change notifications from SentryState and update
//  	the displayed state accordingly;
//  (2) interpret user input and call SentryState or SentryModel to modify the
//		model accordingly.
//
//	Serves as delegate for Filter window and outline view
#define preferences [NSUserDefaults standardUserDefaults]

#import "SentryDocument.h"
#import "DocumentSupport.h"
#import "ExpertViewWC.h"
#import "BasicSetupWC.h"
#import "MenuDispatch.h"

#import "FilterTable.h"
#import "FilterEntry.h"
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

// Private Methods
@interface SentryDocument (PrivateMethods)
- (void)saveState;
- (void)restoreState;
@end


@implementation SentryDocument

// ---------------------------------------------------------------------------------
// � init
// ---------------------------------------------------------------------------------
- (SentryDocument *)init {
    if (self = [super init]) {
        // initialize our instance variables
		sentryState = nil;
    }
    return self;
}

#pragma mark --- NSDOCUMENT ---
    // Subclasses may override this to create the initial window controller(s) for the document.  The base class implementation will create an NSWindowController with the -windowNibName and with the document as the file's owner if -windowNibName returns a name.  If you override to create your own window controllers, be sure to use -addWindowController: to add them to the document after creating them.  This method is called by NSDocumentController's -open... methods, but you might want to call it directly in some circumstances.
- (void)makeWindowControllers
{
	// create window controller
	ExpertViewWC* expertView = [[MenuDispatch sharedInstance] expertViewMakeWindowController:nil];
	// associate window controller with document
	[self addWindowController:expertView];
	// display document
	[expertView showDocument];
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    // Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

//    data = [[dictionary description] dataUsingEncoding:NSUTF8StringEncoding];
//    return data;
    return nil;
}

// ---------------------------------------------------------------------------------
//	� loadActive
// ---------------------------------------------------------------------------------
// retrieve currently active rule set from NKE
- (void)loadActive
{
	// use currently applied state
	sentryState = [[SentryModel sharedInstance] sentryState];	
}

// ---------------------------------------------------------------------------------
//	� prepareSavePanel
// ---------------------------------------------------------------------------------
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	// set default save location
	if (![self fileURL]) {
		// set default save location		
		NSString* path;
		path = [AppSupport appPrefsFolder];
		[savePanel setDirectoryURL:[NSURL URLWithString:path]];
	}
	return YES;
}

// ---------------------------------------------------------------------------------
//	� writeToFile
// ---------------------------------------------------------------------------------
- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type
{
    BOOL returnValue;

	// complete any fields being edited
	NSArray* list = [self windowControllers];
	NSEnumerator* en = [list objectEnumerator];
	SentryWC* controller;
	NSWindow* myWindow;
	while (controller = [en nextObject]) {
		myWindow = [controller window];
		if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
		[controller saveState];
	}
	// use visible document settings
	[[DocumentSupport sharedInstance] setSentryState:sentryState];
	// transfer application state to save dictionary
	[[DocumentSupport sharedInstance] saveState];

	// save to disk
    returnValue = [[DocumentSupport sharedInstance] writeToFile:fileName];
	if (returnValue) {
		[[[self windowControllers] lastObject] setDocumentEdited:NO];
		[self updateChangeCount:NSChangeCleared];
	}
    return returnValue;
}


- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    // Insert code here to read your document from the given data.  You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.
    return YES;
}

// ---------------------------------------------------------------------------------
//	� readFromFile
// ---------------------------------------------------------------------------------
- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType
{
    BOOL returnValue;
	
	returnValue = [[DocumentSupport sharedInstance] readFromFile:fileName];

	if (returnValue) {
		// transfer application state
		[[DocumentSupport sharedInstance] restoreState];
		// set our sentryState to what we just read in
		sentryState = [[DocumentSupport sharedInstance] sentryState];
		// extract visible document settings
//		[self restoreState];
		NSArray* list = [self windowControllers];
		NSEnumerator* en = [list objectEnumerator];
		SentryWC* controller;
		while (controller = [en nextObject]) {
			[controller showDocument];
		}
		// reset edit status
		[self updateChangeCount:NSChangeCleared];
	}
	return returnValue;
}


- (IBAction)saveDocument:(id)sender
{
	NSString* path;
	if ([self fileURL] == nil) {
		// suggest where to put our settings
		path = [AppSupport appPrefsPath:kSettingsFilename];
		[self setFileURL:[NSURL URLWithString:path]];
		#ifdef IPNetRouter
			[self setFileType:@"ipnr"];
		#else
			[self setFileType:@"nsy"];
		#endif
	}
	// transfer application state to save dictionary
	[self loadActive];
	DocumentSupport* ds = [DocumentSupport sharedInstance];
	[ds setSentryState:sentryState];
	[ds saveState];
	// do save
	[super saveDocument:sender];
}

- (IBAction)saveDocumentAs:(id)sender
{
	if ([self fileURL] == nil) {
		// suggest where to put our settings
		NSString* path = [AppSupport appPrefsPath:kSettingsFilename];
		[self setFileURL:[NSURL URLWithString:path]];
		#ifdef IPNetRouter
			[self setFileType:@"ipnr"];
		#else
			[self setFileType:@"nsy"];
		#endif
	}
	// transfer application state to save dictionary
	[self loadActive];
	DocumentSupport* ds = [DocumentSupport sharedInstance];
	[ds setSentryState:sentryState];
	[ds saveState];
	// do save
	[super saveDocumentAs:sender];
}

@end
