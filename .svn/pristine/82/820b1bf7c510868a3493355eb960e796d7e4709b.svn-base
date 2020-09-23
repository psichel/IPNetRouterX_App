//
//  PreferencesController.h
//  IPNetSentryX
//
//  Created by Peter Sichel Dec 2002.
//  Copyright (c) 2002-03 Sustainable Softworks, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class SentryModel;

@interface PreferencesController : NSWindowController
{
    IBOutlet NSPopUpButton* logFormatPopUp;
	IBOutlet NSPopUpButton*	logUpdateIntervalPopUp;
	IBOutlet NSButton*		saveToCheckBox;
	IBOutlet NSTextField*	emailToField;
	IBOutlet NSButton*		emailTestButton;
	IBOutlet NSButton*		emailBandwidthLogCheckBox;
	IBOutlet NSButton*		emailConnectionLogCheckBox;
	IBOutlet NSButton*		emailDHCPLogCheckBox;
	IBOutlet NSButton*		emailSecurityLogCheckBox;

	IBOutlet NSButton*		bandwidthAccountingCheckBox;
	IBOutlet NSPopUpButton*	accountingIntervalPopUp;
	IBOutlet NSButton*		writeIntervalCheckBox;
	IBOutlet NSButton*		connectionLoggingCheckBox;
	IBOutlet NSButton*		disableAlertsCheckBox;
	IBOutlet NSButton*		disableCommandQ;
	IBOutlet NSTextField*	appleScriptFileField;
	
	IBOutlet NSTextField*	realNameField;
	IBOutlet NSTextField*	emailAddressField;
	IBOutlet NSTextField*	smtpHostField;
	
	SentryModel* sentryModel;
}
- (void)receiveNotification:(NSNotification *)aNotification;

- (IBAction)logFormatPopUp:(id)sender;
- (IBAction)logUpdateIntervalPopUp:(id)sender;
- (IBAction)saveToCheckBox:(id)sender;
- (IBAction)updateLogsNowButton:(id)sender;
- (IBAction)emailToField:(id)sender;
- (IBAction)emailTestButton:(id)sender;
- (IBAction)applyButton:(id)sender;

- (IBAction)emailBandwidthLogCB:(id)sender;
- (IBAction)emailConnectionLogCB:(id)sender;
- (IBAction)emailDHCPLogCB:(id)sender;
- (IBAction)emailSecurityLogCB:(id)sender;

- (IBAction)setAppleScriptButton:(id)sender;
- (IBAction)connectionLoggingCheckBox:(id)sender;
- (IBAction)disableAlertsCheckBox:(id)sender;
- (IBAction)disableCommandQ:(id)sender;
- (IBAction)bandwidthAccountingCheckBox:(id)sender;
- (IBAction)accountingIntervalPopUp:(id)sender;
- (IBAction)writeIntervalCheckBox:(id)sender;
@end

#define kPreferencesName				@"Preferences"
#define kPreferences_open				@"Preferences_open"

