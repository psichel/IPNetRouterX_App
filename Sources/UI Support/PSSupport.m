//
//  PSSupport.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on Thu Sep 26 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Common UI support functions

#import "PSSupport.h"

// ---------------------------------------------------------------------------------
//	� instanceName
// ---------------------------------------------------------------------------------
    // Append index to key to form instance name key_index
    // By convention count window instances from zero
NSString*	instanceName(NSString* key, int index)
{
    return [NSString stringWithFormat:@"%@_%d",key,index];
}

// ---------------------------------------------------------------------------------
//	� instanceCount
// ---------------------------------------------------------------------------------
// count number of open windows of given type (controller class)
int instanceCount(Class windowControllerClass)
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:windowControllerClass]) count += 1;
    }
    return count;
}

// ---------------------------------------------------------------------------------
//	� hideView
// ---------------------------------------------------------------------------------
// Hide and unhide views backward compatible with 10.2 (setHidden is 10.3 or later)
// To hide a view, we move it off-screen by adding 10000 to it's y-coordinate
void hideView(NSView* theView)
{
	[theView setHidden:YES];
}
// ---------------------------------------------------------------------------------
//	� unhideView
// ---------------------------------------------------------------------------------
void unhideView(NSView* theView)
{
	[theView setHidden:NO];
}

// ---------------------------------------------------------------------------------
//	� openHelpAnchor
// ---------------------------------------------------------------------------------
// open help file in default browser or help viewer if requested
void openHelpAnchor(NSString* anchor)
{
    if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
		openHelpFile(anchor);
		//NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
		//[[NSHelpManager sharedHelpManager] openHelpAnchor:anchor inBook:locBookName];
    }
	else {
		//openHelpFile(anchor);
		NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
		[[NSHelpManager sharedHelpManager] openHelpAnchor:anchor inBook:locBookName];
	}
}

// ---------------------------------------------------------------------------------
//	� openHelpFile
// ---------------------------------------------------------------------------------
// open help file in default browser
BOOL openHelpFile(NSString* fileName)
{
	BOOL returnValue = NO;
	NSString *filePath;
	NSURL *fileURL;
	NSBundle *thisBundle = [NSBundle mainBundle];
	int result;
	
	filePath = [thisBundle pathForResource:fileName ofType:@"html" inDirectory:PS_HELP_DIRECTORY];
	if (!filePath) filePath = [thisBundle pathForResource:fileName ofType:@"html" inDirectory:PS_HELP_DIRECTORY2];
    if (filePath) {
		if ((fileURL = [NSURL fileURLWithPath:filePath])) do {
			CFURLRef targetURL;
			FSRef outAppRef;
			UInt8 path[256];
			
			targetURL = CFURLCreateWithString(nil, CFSTR("http://www.apple.com"), nil);
			result = LSGetApplicationForURL(targetURL, kLSRolesViewer, &outAppRef, nil);			
			//returnValue = [[NSWorkspace sharedWorkspace] openURL:fileURL];
			result = FSRefMakePath(&outAppRef, path, 255);
			if (result != 0) {
				CFRelease(targetURL);
				break;
			}
			NSBundle* theBundle = [NSBundle bundleWithPath:[NSString stringWithCString:(char *)path encoding:NSUTF8StringEncoding]];
			returnValue = [[NSWorkspace sharedWorkspace]
				openURLs:[NSArray arrayWithObject:fileURL]		// (NSArray *)urls
				withAppBundleIdentifier:[theBundle bundleIdentifier]	// (NSString *)bundleIdentifier
				options:(NSWorkspaceLaunchOptions)nil					// (NSWorkspaceLaunchOptions)options
				additionalEventParamDescriptor:nil				// (NSAppleEventDescriptor *)descriptor
				launchIdentifiers:nil							// (NSArray **)identifiers
			];
			CFRelease(targetURL);
		} while (false);
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	� 
// ---------------------------------------------------------------------------------
