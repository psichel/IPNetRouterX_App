//
//  PreferencesController.m
//  IPNetSentryX
//
//  Created by Peter Sichel Dec 2002.
//  Copyright (c) 2002-04 Sustainable Softworks, Inc. All rights reserved.
//
//  Preferences are part of SentryState so we access them via that object.

#import "PreferencesController.h"
#import "AppDelegate.h"
#import "PSSharedDictionary.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "SentryLogger.h"
#ifdef IPNetRouter
#import "DHCPLogger.h"
#endif
#import "BandwidthAccounting.h"
#import "ConnectionLog.h"
#import "TrafficDiscoveryModel.h"

@implementation PreferencesController
- init
{
    if (self = [super init]) {
        // initialize instance vars
		// use awakeFromNib
		sentryModel = nil;
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	// use windowWillClose
    [super dealloc];
}

// ---------------------------------------------------------------------------
//	¥ awakeFromNib
// ---------------------------------------------------------------------------
- (void)awakeFromNib {
    NSString* str;
	sentryModel = [SentryModel sharedInstance];   // leave as is
	SentryState* sentryState = [sentryModel sentryState];
	
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	// restore settings
	[logFormatPopUp selectItemAtIndex:[[sentryState logFormat] intValue]];
    if ((str = [sentryState logUpdateInterval]))
        [logUpdateIntervalPopUp selectItemWithTitle:str];
	[saveToCheckBox setObjectValue:[sentryState saveToCheckBox]];
    if ((str = [sentryState emailToField]))
        [emailToField setStringValue:str];
	[emailBandwidthLogCheckBox setObjectValue:[sentryState emailBandwidthLog]];
	[emailConnectionLogCheckBox setObjectValue:[sentryState emailConnectionLog]];
	[emailDHCPLogCheckBox setObjectValue:[sentryState emailDHCPLog]];
	[emailSecurityLogCheckBox setObjectValue:[sentryState emailSecurityLog]];

    if ((str = [sentryState accountingInterval]))
        [accountingIntervalPopUp selectItemWithTitle:str];
	[bandwidthAccountingCheckBox setObjectValue:[sentryState bandwidthAccounting]];
	[writeIntervalCheckBox setObjectValue:[sentryState writeInterval]];
	[connectionLoggingCheckBox setObjectValue:[sentryState connectionLogging]];

	[disableAlertsCheckBox setObjectValue:[sentryState disableAlerts]];
	[disableCommandQ setObjectValue:[sentryState disableCommandQ]];
	
    if ((str = [sentryState appleScriptFile]))
        [appleScriptFileField setStringValue:str];
	
	// disable test button if "Email To" is empty
	if (![[emailToField stringValue] length]) [emailTestButton setEnabled:NO];
	
	// setup to receive messages from SentryState
	[sentryState addObserver:self withSelector:@selector(receiveNotification:)];
		
	// use Internet Config for setting up message framework
	do {
		int result;
		ICInstance icRef;
		#ifdef IPNetRouter
			u_int32_t sig = 'IPnl';
		#else
			#if IPNetSentry
				u_int32_t sig = 'NScp';
			#else
				u_int32_t sig = 'MIPR';
			#endif
		#endif
		char buf[255];
		ICAttr attributes;
		long size;
		
		// start
		result = ICStart(&icRef, sig);
		if (result != 0) break;
		
		// read prefs
		attributes = kICAttrNoChange;
		size = 255;
		result = ICGetPref(icRef, kICRealName, &attributes, &buf[0], &size);
		if (result == 0) {
			str = [[[NSString alloc] initWithBytes:&buf[1] length:buf[0] encoding:NSUTF8StringEncoding] autorelease];
			[realNameField setStringValue:str];
		}
		attributes = kICAttrNoChange;
		size = 255;
		result = ICGetPref(icRef, kICEmail, &attributes, &buf[0], &size);
		if (result == 0) {
			str = [[[NSString alloc] initWithBytes:&buf[1] length:buf[0] encoding:NSUTF8StringEncoding] autorelease];
			[emailAddressField setStringValue:str];
		}
		attributes = kICAttrNoChange;
		size = 255;
		result = ICGetPref(icRef, kICSMTPHost, &attributes, &buf[0], &size);
		if (result == 0) {
			str = [[[NSString alloc] initWithBytes:&buf[1] length:buf[0] encoding:NSUTF8StringEncoding] autorelease];
			[smtpHostField setStringValue:str];
		}
		
		// stop
		result = ICStop(icRef);
		if (result != 0) NSLog(@"ICStop(icRef) failed with error: %d",result);
	} while (false);
}

// ---------------------------------------------------------------------------
//	¥ windowWillClose
// ---------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
    // save Email To field since user might not have pressed a field action key
	[self emailToField:self];
	// no longer wish to be notified
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kPreferencesName];
    // release ourself
    [self autorelease];
}

// ---------------------------------------------------------------------------
//	¥ receiveNotification
// ---------------------------------------------------------------------------
// perform corresponding action when state changes
- (void)receiveNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;
	NSEnumerator* enumerator;
    id key;
    id object;

	dictionary = [aNotification userInfo];
    enumerator = [dictionary keyEnumerator];

	while ((key = [enumerator nextObject])) { 
		/* code that uses the returned key */
		if (![key isKindOfClass:[NSString class]]) continue; 
		object = [dictionary objectForKey:key];

		// firewallOn
		// connectionLogging
		if ([key isEqualTo:SS_connectionLogging]) {
			[connectionLoggingCheckBox setObjectValue:object];
		}
		// disableAlerts
		if ([key isEqualTo:kPreferences_disableAlerts]) {
			[disableAlertsCheckBox setObjectValue:object];
		}
		// disableCommandQ
		if ([key isEqualTo:kPreferences_disableCommandQ]) {
			[disableCommandQ setObjectValue:object];
		}
		// bandwidthAccounting
		else if ([key isEqualTo:SS_bandwidthAccounting]) {
			[bandwidthAccountingCheckBox setObjectValue:object];
		}
		// accountingInterval
		else if ([key isEqualTo:SS_accountingInterval]) {
			[accountingIntervalPopUp selectItemWithTitle:object];
		}
		// writeInterval
		else if ([key isEqualTo:SS_writeInterval]) {
			[writeIntervalCheckBox setObjectValue:object];
		}
		// logUpdateInterval
		else if ([key isEqualTo:SS_logUpdateInterval]) {
			[logUpdateIntervalPopUp selectItemWithTitle:object];
		}
	}	// while ((key = [enumerator nextObject]))
}


#pragma mark --- IBAction ---
- (IBAction)logFormatPopUp:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setLogFormat:[NSNumber numberWithInt:[logFormatPopUp indexOfSelectedItem]]];
}

- (IBAction)logUpdateIntervalPopUp:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setLogUpdateInterval:[[logUpdateIntervalPopUp selectedItem] title]];
	[[SentryLogger sharedInstance] sentryLogStart];
}

- (IBAction)updateLogsNowButton:(id)sender
{
	// write out remaining Sentry log text if any
	[[SentryLogger sharedInstance] logTextSaveForDate:nil];
#ifdef IPNetRouter
	[[DHCPLogger sharedInstance] logTextSaveForDate:nil];
#endif
	// write out bandwidth accounting info if any
	[[BandwidthAccounting sharedInstance] accountingSaveForDate:nil];
	// write out connection log info if any
	[[ConnectionLog sharedInstance] connectionLogSaveForDate:nil];
	// write out traffic discovery log info if any
	[[TrafficDiscoveryModel sharedInstance] trafficDiscoverySaveForDate:nil];
}

- (IBAction)saveToCheckBox:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setSaveToCheckBox:[saveToCheckBox objectValue]];
}

- (IBAction)emailToField:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setEmailToField:[emailToField stringValue]];
	// disable test button if no "Email To"
	if ([[emailToField stringValue] length]) [emailTestButton setEnabled:YES];
	else [emailTestButton setEnabled:NO];
}

- (IBAction)emailBandwidthLogCB:(id)sender {
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setEmailBandwidthLog:[emailBandwidthLogCheckBox objectValue]];
}
- (IBAction)emailConnectionLogCB:(id)sender {
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setEmailConnectionLog:[emailConnectionLogCheckBox objectValue]];
}
- (IBAction)emailDHCPLogCB:(id)sender {
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setEmailDHCPLog:[emailDHCPLogCheckBox objectValue]];
}
- (IBAction)emailSecurityLogCB:(id)sender {
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setEmailSecurityLog:[emailSecurityLogCheckBox objectValue]];
}

- (IBAction)emailTestButton:(id)sender
{
	[self emailToField:self];
	#ifdef IPNetRouter
	[[SentryLogger sharedInstance] sendEmail:@"Email test complete." withSubject:@"--- IPNetRouter Log Test ---"];
	#else
	[[SentryLogger sharedInstance] sendEmail:@"Email test complete." withSubject:@"--- IPNetSentry Log Test ---"];
	#endif
}

// apply new Email settings to Internet Config
- (IBAction)applyButton:(id)sender
{
	// use Internet Config for setting up message framework
	// kICRealName, KICEmail, kICSMTPHost
	do {
		int result;
		ICInstance icRef;
		#ifdef IPNetRouter
		u_int32_t sig = 'IPnl';
		#else
		u_int32_t sig = 'NScp';
		#endif
		char buf[255];
		ICAttr attributes;
		long size;
		NSString* str;
		
		// start
		result = ICStart(&icRef, sig);
		if (result != 0) break;
		
		// write prefs
		attributes = kICAttrNoChange;
		str = [realNameField stringValue];
		size = [str length];
		buf[0] = size;
		[str getCString:&buf[1] maxLength:253 encoding:NSUTF8StringEncoding];
		result = ICSetPref(icRef, kICRealName, attributes, &buf[0], size);
		if (result != 0) NSLog(@"ICSetPref: %d",result);
		// save as preference
		[[[AppDelegate sharedInstance] prefs] setObject:str forKey:kPreferences_emailNameField];

		attributes = kICAttrNoChange;
		str = [emailAddressField stringValue];
		size = [str length];
		buf[0] = size;
		[str getCString:&buf[1] maxLength:253 encoding:NSUTF8StringEncoding];
		result = ICSetPref(icRef, kICEmail, attributes, &buf[0], size);
		if (result != 0) NSLog(@"ICSetPref: %d",result);
		// save as preference
		[[[AppDelegate sharedInstance] prefs] setObject:str forKey:kPreferences_emailFromField];

		attributes = kICAttrNoChange;
		str = [smtpHostField stringValue];
		size = [str length];
		buf[0] = size;
		[str getCString:&buf[1] maxLength:253 encoding:NSUTF8StringEncoding];
		result = ICSetPref(icRef, kICSMTPHost, attributes, &buf[0], size);
		if (result != 0) NSLog(@"ICSetPref: %d",result);
		
		// stop
		result = ICStop(icRef);
		if (result != 0) NSLog(@"ICStop(icRef) failed with error: %d",result);
	} while (false);
}

- (IBAction)disableAlertsCheckBox:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setDisableAlerts:[disableAlertsCheckBox objectValue]];
}

- (IBAction)disableCommandQ:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setDisableCommandQ:[disableCommandQ objectValue]];
}

- (IBAction)setAppleScriptButton:(id)sender
{
	NSSavePanel* panel;
	NSString* directory;
	NSString* filename;
	SentryState* sentryState = [sentryModel sentryState];

	panel = [NSOpenPanel openPanel];
	if ((directory = [sentryState appleScriptFile])) {
		filename = [directory lastPathComponent];
		directory = [directory stringByDeletingLastPathComponent];
	}
	else {
		directory = @"";
		filename = @"";
	}
	if ([panel runModalForDirectory:directory file:filename] == NSFileHandlingPanelOKButton) {
		[appleScriptFileField setStringValue:[panel filename]];
		[sentryState setAppleScriptFile:[appleScriptFileField stringValue]];
	}
}


- (IBAction)connectionLoggingCheckBox:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setConnectionLogging:[connectionLoggingCheckBox objectValue]];
}

- (IBAction)bandwidthAccountingCheckBox:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setBandwidthAccounting:[bandwidthAccountingCheckBox objectValue]];
}

- (IBAction)accountingIntervalPopUp:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setAccountingInterval:[[accountingIntervalPopUp selectedItem] title]];
}

- (IBAction)writeIntervalCheckBox:(id)sender
{
	SentryState* sentryState = [sentryModel sentryState];
	[sentryState setWriteInterval:[writeIntervalCheckBox objectValue]];
}

@end
