//
//  RegSupport.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on 3/12/09.
//  Copyright 2009 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define preferences [NSUserDefaults standardUserDefaults]
#define kRegDataLength 512

// registration data dictionary keys
#define kName @"name"
#define kOrganization @"organization"
#define kLicensedCopies @"licensedCopies"
//#define kCode @"IPNetMonitorX_key"
//#define kUpgradeCode @"IPNetMonitorX Upgrade_key"
#define kRegisterDate @"date"
#define kExpireDate @"expireDate"
#define kSecondsPerDay 86400

// doRegistrationInput results
#define kRegAccepted 0
#define kRegNotAccepted 1
#define kRegInvalid 2
#define kRegNotFound 3


@interface RegSupport : NSObject {
    IBOutlet id splashWindow;
    IBOutlet id licenseName;
    IBOutlet id licenseOrganization;
    IBOutlet id licenseCopies;
    IBOutlet id version;

	NSDate* _splashTime;
	BOOL _sheetEnding;
	BOOL _askForUpgradeCompleted;
}
+ (RegSupport *)sharedInstance; // returns a shared instance of the class
// startup
- (void)regStartup;
- (void)regSplashDown;
- (IBAction)splash:(id)sender;
- (void)showDemo:(NSDate *)xDate;
// registration input
- (int)checkPasteboardFromWindow:(NSWindow *)aWindow;
- (int)doRegistrationInput:(NSString *)regDataString fromWindow:(NSWindow *)aWindow option:(int)option;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)writeRegistration:(NSDictionary *)regData;
// isRegistered
- (BOOL)isRegisteredOption:(int)option;
- (NSDictionary *)readRegistration;
- (NSString *)keyPath;
- (BOOL)checkRegistrationKey:(NSDictionary*)regData;
- (BOOL)checkNoUpgradeNeeded:(NSDictionary*)regData option:(int)option;
@end

#define kOptionNone 0
#define kOptionSkipDialog 1
