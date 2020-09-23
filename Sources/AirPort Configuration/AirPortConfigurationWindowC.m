//
//  AirPortConfigurationWindowC.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Mon Dec 29 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.

#import "AirPortConfigurationWindowC.h"
//#import <Apple80211/Apple80211.h>
#import "Apple80211.h"
#import "DocumentSupport.h"

@implementation AirPortConfigurationWindowC
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

// ---------------------------------------------------------------------------
//	¥ awakeFromNib
// ---------------------------------------------------------------------------
- (void)awakeFromNib {
	WirelessRef ref;
	int unit = 0;
	WirelessError result;
	WirelessInfo info;

	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];		
	do {
		// attach to driver
		result = WirelessAttach(&ref, unit);
		if (result != errWirelessNoError) {
			[statusInfo setStringValue:@"WirelessAttach filed"];
			break;
		}
		
		// get info
		result = WirelessGetInfo(ref, &info);
		if (result != errWirelessNoError) {
			[statusInfo setStringValue:@"WirelessGetInfo failed"];
			break;
		}
		// refresh portType
		if (info.linkStatus == kLinkStatusDisabled) {
			[statusInfo setStringValue:@"Link Status: disabled"];
		}
		switch (info.portType) {
			case kInfoPortTypeClient:
				[portType selectItemAtIndex:0];
				break;
			case kInfoPortTypeSWBS:
				[portType selectItemAtIndex:1];
				break;
			case kInfoPortTypeIBSS:
				[portType selectItemAtIndex:2];
				break;
		}
		
		// display previously saved settings if any
		NSMutableDictionary* sd = [[DocumentSupport sharedInstance] saveDictionary];
		id object;
		// restore
		object = [sd objectForKey:kAirPort_restore];
		if (object) [restoreCB setObjectValue:object];
		// network name
		object = [sd objectForKey:kAirPort_networkName];
		if (object) [networkName setStringValue:object];
		// channel
		object = [sd objectForKey:kAirPort_channel];
		if (object) [channel setObjectValue:object];
		// apMode
		object = [sd objectForKey:kAirPort_apMode];
		if (object) [apMode setObjectValue:object];
		// encryptionType
		object = [sd objectForKey:kAirPort_encryptionType];
		if (object) [encryptionType setObjectValue:object];
		// password
		object = [sd objectForKey:kAirPort_password];
		if (object) {
			NSString* str = [[[NSString alloc] initWithData:object encoding:NSUTF8StringEncoding] autorelease];
			[password setStringValue:str];
			[confirm setStringValue:str];
		}
	} while (false);
	// detach from driver
	WirelessDetach(ref);
}

// ---------------------------------------------------------------------------
//	¥ windowWillClose
// ---------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kAirPortConfigurationName];
    // remember settings
		// handled by Apply
    // release ourself
	[self autorelease];
}

// ---------------------------------------------------------------------------
//	¥ apply:
// ---------------------------------------------------------------------------
- (IBAction)apply:(id)sender
{
	WirelessRef ref = 0;
	int unit = 0;
	WirelessError result;
	WirelessInfo info;
	NSString* str;
	
	do {
		// clear previous status
		[statusInfo setStringValue:@""];
		
		// collect parameters from window and save in document
		NSMutableDictionary* sd = [[DocumentSupport sharedInstance] saveDictionary];
		// restore
		[sd setObject:[restoreCB objectValue] forKey:kAirPort_restore];
		// port type
		[sd setObject:[portType objectValue] forKey:kAirPort_portType];
		// network name
		if ([portType indexOfSelectedItem] && [[networkName stringValue] isEqualTo:@""]) {
			[statusInfo setStringValue:@"Please specify a network name"];
			break;
		}
		[sd setObject:[networkName stringValue] forKey:kAirPort_networkName];
		// channel
		[sd setObject:[channel objectValue] forKey:kAirPort_channel];
		// apMode
		[sd setObject:[apMode objectValue] forKey:kAirPort_apMode];
		// encryptionType
		[sd setObject:[encryptionType objectValue] forKey:kAirPort_encryptionType];
		// password
		if ([encryptionType indexOfSelectedItem] && [[password stringValue] isEqualTo:@""]) {
			[statusInfo setStringValue:@"Please specify a password"];
			break;
		}
		if ([[password stringValue] isEqualTo:[confirm stringValue]]) {
			[sd setObject:[password stringValue] forKey:kAirPort_password];
		}
		else {
			[statusInfo setStringValue:@"Password does not match confirm field"];
			break;
		}
		
		// apply saved parameters from document
		[[DocumentSupport sharedInstance] setDelegate:self];
		[[DocumentSupport sharedInstance] airPortApply];
		[[DocumentSupport sharedInstance] setDelegate:nil];

		// attach to driver
		result = WirelessAttach(&ref, unit);
		if (result != errWirelessNoError) {
			str = [NSString stringWithFormat:@"WirelessAttach failed: %@",stringForWirelessError(result)];
			[statusInfo setStringValue:str];
			break;
		}
		// get info
		result = WirelessGetInfo(ref, &info);
		if (result != errWirelessNoError) {
			str = [NSString stringWithFormat:@"WirelessGetInfo failed: %@",stringForWirelessError(result)];
			[statusInfo setStringValue:str];
			break;
		}
		// refresh portType
		[portType setEnabled:YES];
		switch (info.portType) {
			case kInfoPortTypeClient:
				[portType selectItemAtIndex:0];
				break;
			case kInfoPortTypeSWBS:
				[portType selectItemAtIndex:1];
				break;
			case kInfoPortTypeIBSS:
				[portType selectItemAtIndex:2];
				break;
		}
		
	} while (false);
	// detach from driver
	if (ref) WirelessDetach(ref);
}

// ---------------------------------------------------------------------------
//	¥ updateParameter:withObject:
// ---------------------------------------------------------------------------
- (BOOL)updateParameter:(NSString *)name withObject:(id)object
{
	BOOL returnValue = NO;
	if ([name isEqualTo:@"statusInfo"]) {
		[statusInfo setStringValue:object];
		returnValue = YES;
	}
	return returnValue;
}

#pragma mark -- help --
- (IBAction)myHelp:(id)sender
{
    NSString *filePath;
	NSURL *fileURL;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    
    if ((filePath = [thisBundle pathForResource:@"AirPortConfigurationHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY]))
		if ((fileURL = [NSURL fileURLWithPath:filePath]))
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
}

@end
