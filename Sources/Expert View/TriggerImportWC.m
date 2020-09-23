//
//  TriggerImportWC.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Mon Jul 17 2006.
//  Copyright (c) 2006 Sustainable Softworks, Inc. All rights reserved.
//
//	Import/Export for Trigger table
//	File format is simple list of IP addresses, one per line.
//	Other columns are set from this dialog

#import "TriggerImportWC.h"
#import "SentryModel.h"
#import "DocumentSupport.h"
#import "TriggerTable.h"
#import "TriggerEntry.h"

#define preferences [NSUserDefaults standardUserDefaults]

@implementation TriggerImportWC
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

// ---------------------------------------------------------------------------------
//	¥ awakeFromNib
// ---------------------------------------------------------------------------------
- (void)awakeFromNib {
	NSString* str;
	NSNumber* num;
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	// triggerType
	num = [preferences objectForKey:kTriggerImport_triggerType];
	if (num) [triggerTypePopUp setObjectValue:num];
	// triggeredBy
	str = [preferences objectForKey:kTriggerImport_triggeredBy];
	if (str) [triggeredByField setStringValue:str];
	// triggerDuration
	num = [preferences objectForKey:kTriggerImport_triggerDuration];
	if (num) [triggerDurationPopUp setObjectValue:num];
}

// ---------------------------------------------------------------------------
//	¥ windowWillClose
// ---------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kTriggerImportName];
    // remember settings
	[preferences setObject:[triggerTypePopUp objectValue] forKey:kTriggerImport_triggerType];
	[preferences setObject:[triggeredByField stringValue] forKey:kTriggerImport_triggeredBy];
	[preferences setObject:[triggerDurationPopUp objectValue] forKey:kTriggerImport_triggerDuration];
    // release ourself
	[self autorelease];
}

// ---------------------------------------------------------------------------
//	¥ import
// ---------------------------------------------------------------------------
- (IBAction)import:(id)sender
{
	NSOpenPanel* panel;
	NSString* directory;
	NSString* filename;

	panel = [NSOpenPanel openPanel];
	if (directory = [preferences objectForKey:kTriggerImport_filePath]) {
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
		[preferences setObject:str forKey:kTriggerImport_filePath];
		if ([str length]) {
			NSDictionary* defaults = [NSDictionary dictionaryWithObjectsAndKeys:
				[triggerTypePopUp objectValue],kTriggerImport_triggerType,
				[triggeredByField objectValue],kTriggerImport_triggeredBy,
				[triggerDurationPopUp objectValue],kTriggerImport_triggerDuration,
				nil];
			BOOL result = [[DocumentSupport sharedInstance] triggerImportFromFile:str useDefaults:defaults];
			if (!result) [statusInfo setStringValue:@"Read from file failed"];
			else [self close];
		}
	}
}

// ---------------------------------------------------------------------------
//	¥ export
// ---------------------------------------------------------------------------
- (IBAction)export:(id)sender
{
	NSSavePanel* panel;
	NSString* directory;
	NSString* filename;

	panel = [NSSavePanel savePanel];
	if (directory = [preferences objectForKey:kTriggerImport_filePath]) {
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
		[preferences setObject:[panel filename] forKey:kTriggerImport_filePath];
		// perform export if filename given
		NSString* str = [panel filename];
		if ([str length]) {
			BOOL result = [[DocumentSupport sharedInstance] triggerExportToFile:str];
			if (!result) {
				[statusInfo setStringValue:@"Write to file failed"];
				NSBeep();
			}
			else [self close];
		}
	}
}

// ---------------------------------------------------------------------------
//	¥ cancel
// ---------------------------------------------------------------------------
- (IBAction)cancel:(id)sender
{
	[self close];
}

// ---------------------------------------------------------------------------------
//	¥ myHelp
// ---------------------------------------------------------------------------------
- (IBAction)myHelp:(id)sender
{
    NSString *filePath;
	NSURL *fileURL;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    
    if (filePath = [thisBundle pathForResource:@"TriggerImportHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY])
		if (fileURL = [NSURL fileURLWithPath:filePath])
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
}

@end
