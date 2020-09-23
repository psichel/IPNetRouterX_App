//
//  RegSupport.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on 3/12/09.
//  Copyright 2009 Sustainable Softworks. All rights reserved.
//

#import "RegSupport.h"
#import "AppSupport.h"
#import "PSSharedDictionary.h"
#import "nmCypher.h"
#import "nmHash.h"
#import "DemoController.h"
#import "UpgradeController.h"
#import <Carbon/Carbon.h>	// GetCurrentKeyModifiers()

@interface RegSupport (PrivateMethods)
- (NSDate *)expireDate;
- (NSString *)doHash:(NSString *)inStr;
@end


@implementation RegSupport
+ (RegSupport *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[RegSupport alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- init
{
    if (self = [super init]) {
        // initialize instance vars
		_splashTime = nil;	// not retained
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	[_splashTime release]; _splashTime = nil;
    [super dealloc];
}

#pragma mark -- startup --
// ---------------------------------------------------------------------------------
//	• regStartup
// ---------------------------------------------------------------------------------
// Application startup registration processing
- (void)regStartup {
    NSDate* xDate;
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];

	_sheetEnding = NO;
	_askForUpgradeCompleted = NO;

	// look for key in Pasteboard
	if (![self isRegisteredOption:kOptionSkipDialog]) [self checkPasteboardFromWindow:nil];

	// check registration
    if ([self isRegisteredOption:0] &&
		[[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
        BOOL cmdKeyDown = ((GetCurrentKeyModifiers() & cmdKey) != 0) ? YES : NO;
        if (!cmdKeyDown) {
            [self splash:self];
            _splashTime = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)1.8];
        }
    }
    else {
		// look for expiration
        xDate = [self expireDate];        
        // show demo startup
		[self showDemo:xDate];
    }
}

// ---------------------------------------------------------------------------------
//	• regSplashDown
// ---------------------------------------------------------------------------------
// Remote splash screen as needed
- (void)regSplashDown {
    // wait for splash timer to continue
    if (_splashTime) {
        [NSThread  sleepUntilDate:_splashTime];
		_splashTime = nil;
        [splashWindow close];
    }
}

// ---------------------------------------------------------------------------------
//	• splash
// ---------------------------------------------------------------------------------
- (IBAction)splash:(id)sender
{
    NSDictionary* regData;
    // get reg data
	regData = [self readRegistration];
	if (regData) {
		// display info
        [licenseName setStringValue:[regData objectForKey:kName]];
        [licenseOrganization setStringValue:[regData objectForKey:kOrganization]];
        [licenseCopies setStringValue:[regData objectForKey:kLicensedCopies]];
		[version setStringValue:[[[NSBundle mainBundle] infoDictionary]
			objectForKey:@"CFBundleShortVersionString"]];
		// position and display
		[splashWindow center];
		[splashWindow makeKeyAndOrderFront:self];
    }
}

// ---------------------------------------------------------------------------------
//	• showDemo
// ---------------------------------------------------------------------------------
- (void)showDemo:(NSDate *)xDate
{
    DemoController *demoController;
    // create window controller and make it the windows owner
    demoController = [DemoController alloc];
    demoController = [demoController initWithWindowNibName:kDemoName owner:demoController];
    if (demoController) {
        NSWindow* window;
        //[[demoController window] setFrameUsingName:kDemoName];
        window = [demoController window];
        [demoController setDate:xDate];
		[window center];
        [NSApp runModalForWindow:window];
    }
	[demoController autorelease];
}

// ---------------------------------------------------------------------------------
//	• expireDate
// ---------------------------------------------------------------------------------
// get trial expiration date if any
// returns nil if expired and no date available
- (NSDate *)expireDate
{
    NSDictionary* myDictionary;
    NSString* pathA;
    NSString* pathB;
	NSString* name;
    NSDate* appDate = nil;
    NSDate* prefDate = nil;
    NSDate* xDate = nil;
	NSDate* newExpireDate;
    NSDate* returnValue = nil;
    NSString* kDate = @"date";
    NSTimeInterval trialPeriod;
    
    // get expiration dates if present
        // application support directory
    pathA = [AppSupport appSupportPath:@"expireDate"];
	myDictionary = [NSDictionary dictionaryWithContentsOfFile:pathA];
	appDate = [myDictionary objectForKey:kDate];
        // preferences
    prefDate = [preferences objectForKey:kDate];
        // application support sustworks	
    #ifdef IPNetRouter
	name = @".xRouter";
	#else
	name = @".xSentry";
	#endif
    pathB = [AppSupport appSupportSustworksPathRO:name];
	if (pathB) {
        myDictionary = [NSDictionary dictionaryWithContentsOfFile:pathB];
        xDate = [myDictionary objectForKey:kDate];
    }
    // calculate new expire date
    trialPeriod = 60*60*24*21;	// sec*min*hour*days
    newExpireDate = [NSDate dateWithTimeIntervalSinceNow:trialPeriod];
	returnValue = newExpireDate;
    // use the earliest date found if any
    if (appDate) returnValue = [appDate earlierDate:returnValue];
    if (prefDate) returnValue = [prefDate earlierDate:returnValue];
    if (xDate) returnValue = [xDate earlierDate:returnValue];
	// if hidden expire date is more than a year ago, allow a new trial period
	if (((xDate == nil) && _askForUpgradeCompleted) ||
		((xDate != nil) && ([xDate timeIntervalSinceNow] < (double)-31536000)) ) {
		returnValue = newExpireDate;
		appDate = nil;
		prefDate = nil;
		xDate = nil;
	}
    // write out any missing dates
    myDictionary = [NSDictionary dictionaryWithObject:returnValue forKey:kDate];
    if (!appDate) [myDictionary writeToFile:pathA atomically:YES];
    if (!prefDate) [preferences setObject:returnValue forKey:kDate];
    if (!xDate) {
		pathB = [AppSupport appSupportSustworksPath:name];
		[myDictionary writeToFile:pathB atomically:YES];
	}
    return returnValue;
}


#pragma mark -- Registration Input --
// ---------------------------------------------------------------------------------
//	• checkPasteboardFromWindow:
// ---------------------------------------------------------------------------------
// returns: kRegAccepted, kRegNotAccepted, kRegInvalid, kRegNotFound
- (int)checkPasteboardFromWindow:(NSWindow *)aWindow
{
	int returnValue = kRegNotFound;
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	if (!_sheetEnding) {
		if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]]) {
			NSString* string = [pboard stringForType:NSStringPboardType];
			returnValue = [self doRegistrationInput:string fromWindow:aWindow option:kOptionSkipDialog];
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• doRegistrationInput
// ---------------------------------------------------------------------------------
// returns: kRegAccepted, kRegNotAccepted, kRegInvalid, kRegNotFound
// options: 0=none, 1=skip dialog if not found
- (int)doRegistrationInput:(NSString *)regDataString fromWindow:(NSWindow *)aWindow option:(int)option
{
	NSDictionary* regData = nil;
	NSRange range;
    int returnValue = kRegNotFound;
	do {
		if ([regDataString length] == 0) break;
        // strip extra text from beginning or end of XML
		range = [regDataString rangeOfString:@"<?xml"];
		if (range.length) regDataString = [regDataString substringFromIndex:range.location];
		else break;
		range = [regDataString rangeOfString:@"</plist>" options:NSBackwardsSearch];
		if (range.length) regDataString = [regDataString substringToIndex:range.location+range.length];
		else break;
		// try to process new reg data
        NS_DURING
            //regData = [regDataString propertyList];
			regData = plistForString(regDataString);
            if ([self checkRegistrationKey:regData]) returnValue = kRegAccepted;
			else returnValue = kRegNotAccepted;
        NS_HANDLER
			returnValue = kRegInvalid;
        NS_ENDHANDLER
    } while (false);
	NSString* userNotice;
	if (returnValue == kRegAccepted) {	
		// registration data confirmed write key to file
		[self writeRegistration:regData];
		// tell user what we got
		if ([self isRegisteredOption:option]) userNotice = @"Registration confirmed.  Thanks!";
		else userNotice = @"Registration data confirmed, an upgrade is required to unlock this version.  Thanks!";
		// display alert
		//if (!aWindow) {
		if (nil) {		// [PAS ***]
			NSRunAlertPanel(PS_PRODUCT_NAME,
				userNotice,
				@"OK",
				nil,
				nil
			);
		}
		else {
			_sheetEnding = YES;
			NSBeginAlertSheet(
				PS_PRODUCT_NAME,
				@"OK",
				nil,
				nil,
				aWindow,		// docWindow
				self,			// modalDelegate
				nil,			// willEndSelector
				@selector(sheetDidEnd:returnCode:contextInfo:),
				nil,			// contextInfo
				userNotice
			);
		}
	}
	else {
		if (option == kOptionSkipDialog) {
			// do nothing if registration data was not found in clipboard
		}
		else {
			// registration was not accepted
			userNotice = @"Sorry, your registration data was not recognized.  Press Help for further assistance.";
			// display alert
			if (!aWindow) {
				int answer = NSRunAlertPanel(PS_PRODUCT_NAME,
					userNotice,
					@"OK",
					@"Help",
					nil
				);
				if (answer == NSAlertAlternateReturn) {		// show help information
					NSString *filePath;
					NSURL *fileURL;
					NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];		
					if (filePath = [thisBundle pathForResource:@"RegistrationHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY])
					if (fileURL = [NSURL fileURLWithPath:filePath]) [[NSWorkspace sharedWorkspace] openURL:fileURL];
				}
			}
			else {
				_sheetEnding = YES;
				NSBeginAlertSheet(
					PS_PRODUCT_NAME,
					@"OK",
					@"Help",
					nil,
					aWindow,		// docWindow
					self,			// modalDelegate
					nil,			// willEndSelector
					@selector(sheetDidEnd:returnCode:contextInfo:),
					@"RegistrationHelp",			// contextInfo
					userNotice
				);
			}
		}
	}
    return returnValue;
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	_sheetEnding = NO;
	if (contextInfo) {
		if (returnCode == NSAlertAlternateReturn) {		// show help information
			NSString *filePath;
			NSURL *fileURL;
			NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];		
			if (filePath = [thisBundle pathForResource:@"RegistrationHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY])
			if (fileURL = [NSURL fileURLWithPath:filePath]) [[NSWorkspace sharedWorkspace] openURL:fileURL];
		}
	}
}

// ---------------------------------------------------------------------------------
//	• writeRegistration
// ---------------------------------------------------------------------------------
- (void)writeRegistration:(NSDictionary *)regData
{
    NSString* regDataString;
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	
	regDataString = stringForPlist(regData);
	// IPNetRouterKey in /Library/Application Support/Sustainable Softworks/
	path = [AppSupport appSupportSustworksPath:PS_KEY_FILENAME];
	// check if previous key exists
	if ([fm fileExistsAtPath:path]) {
		[AppSupport remove:path];
	}
	// try to write out new Key
	if (![regDataString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
		NSLog(@"Unable to write out key file at path: %@", path);
	}
}

#pragma mark -- isRegistered --
// ---------------------------------------------------------------------------------
//	• isRegistered
// ---------------------------------------------------------------------------------
// check if we're already registered
// options: kOptionSkipDialog
- (BOOL)isRegisteredOption:(int)option {
    BOOL returnValue = NO;
    NSDictionary* regData;

	regData = [self readRegistration];
	// check dictionary
	returnValue = [self checkRegistrationKey:regData];
	if (returnValue) {
		// check if upgrade needed
		returnValue = [self checkNoUpgradeNeeded:regData option:option];
	}
	if (!returnValue) {
		// simulate that we're registered for trial period
		NSDate* date = [self expireDate];
		NSTimeInterval trialPeriod = 60*60*24*21;	// sec*min*hour*days
		PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
		if (([date timeIntervalSinceNow] > 0) && ([date timeIntervalSinceNow] < trialPeriod)) {
			[sd setObject:[NSNumber numberWithInt:1] forKey:kCheck1];
		}
		if (([date timeIntervalSinceNow] > 0) && ([date timeIntervalSinceNow] < trialPeriod)) {
			[sd setObject:[NSNumber numberWithInt:1] forKey:kCheck2];
		}
		if (([date timeIntervalSinceNow] > 0) && ([date timeIntervalSinceNow] < trialPeriod)) {
			[sd setObject:[NSNumber numberWithInt:1] forKey:kCheck3];
		}
	}
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	• readRegistration
// ---------------------------------------------------------------------------------
// read registration data and return corresponding dictionary
- (NSDictionary *)readRegistration
{
    NSString* path;
    NSDictionary* regData = nil;

    // read key file into dictionary
    path = [self keyPath];
    if (path) {
		NSString* str;
        str = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
		regData = plistForString(str);		
	}
	return regData;
}

// ---------------------------------------------------------------------------------
//	• keyPath
// ---------------------------------------------------------------------------------
// find and return path to registration key file
- (NSString *)keyPath
{
    NSString* path;
    NSFileManager* fm = [NSFileManager defaultManager];
    
    do {
		// Application Support Folder
            // library/application support/Sustainable Softworks/
		path = [AppSupport appSupportSustworksPathRO:PS_KEY_FILENAME];
        if (path) break;            
            // library/application support/Sustainable Softworks/registrationKey
		path = [AppSupport appSupportSustworksPathRO:@"registrationKey"];
		if (path) break;
        // Application Folder
        path = [[NSBundle mainBundle] bundlePath];
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByAppendingPathComponent:PS_KEY_FILENAME];
        if ([fm fileExistsAtPath:path]) break;
            // registrationKey
        path = [[NSBundle mainBundle] bundlePath];
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByAppendingPathComponent:@"registrationKey"];
        if ([fm fileExistsAtPath:path]) break;
		path = nil;
		// if (path == nil) file not found
    } while (false);
    return path;
}

// ---------------------------------------------------------------------------------
//	• checkRegistrationKey
// ---------------------------------------------------------------------------------
// check registration dictionary to see if it contains valid registration data
- (BOOL)checkRegistrationKey:(NSDictionary*)regData {
    BOOL returnValue = NO;
    NSString* regCode;
    NSDate* expireDate;
    NSScanner* myScanner;
    nmCypher_ctx context;
    UInt32 hash[6];
    NSString* key;
    NSString* str;
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];

    do {
        // decode registration key
        regCode = [regData objectForKey:PS_KEY_NAME];
		#ifdef IPNetRouter
        str = [NSString stringWithFormat:@"IPNetRouterX %@",[self doHash:@"030710"]];
		#else
        str = [NSString stringWithFormat:@"IPNetSentryX %@",[self doHash:@"021009"]];
		#endif
        key = [str substringToIndex:56];
		if (!regCode) break;
        myScanner = [NSScanner scannerWithString:regCode];
        if (![myScanner scanHexInt:(unsigned *)&hash[0]]) break;
        if (![myScanner scanHexInt:(unsigned *)&hash[1]]) break;
        if (![myScanner scanHexInt:(unsigned *)&hash[2]]) break;
        if (![myScanner scanHexInt:(unsigned *)&hash[3]]) break;
        if (![myScanner scanHexInt:(unsigned *)&hash[4]]) break;
        if (![myScanner scanHexInt:(unsigned *)&hash[5]]) break;        
        nmCypher_init(&context, [key UTF8String], strlen([key UTF8String]));
        nmCypher_encrypt(&context, &hash[0], &hash[1]);
        nmCypher_encrypt(&context, &hash[2], &hash[3]);
        nmCypher_encrypt(&context, &hash[4], &hash[5]);
        if (hash[5] == 0) {
            key = [NSString stringWithFormat:@"%08x %08x %08x %08x %08x",
                hash[0],hash[1],hash[2],hash[3],hash[4]];
        } else {
            key = [NSString stringWithFormat:@"%08x %08x %08x %08x %08x %08x",
                hash[0],hash[1],hash[2],hash[3],hash[4], hash[5]];        
        }
        // hash regData
        str = [NSString stringWithFormat:@"%@%@%@",
            [regData objectForKey:kName],
            [regData objectForKey:kOrganization],
            [regData objectForKey:kLicensedCopies]];
        // check if key contains expireDate
        expireDate = [regData objectForKey:kExpireDate];
        if (expireDate) {
            NSString* expireStr;
            if ([expireDate timeIntervalSinceNow] < 0) break; // expired?
            expireStr = [NSString stringWithFormat:@"%.0f",
                [expireDate timeIntervalSinceReferenceDate]];
            str = [str stringByAppendingString:expireStr];
        }
        str = [self doHash:str];
        // compare
        if ([str isEqualTo:key]) {
			returnValue = YES;
			[sd setObject:[NSNumber numberWithInt:1] forKey:kCheck1];
		}
        if ([str isEqualTo:key]) [sd setObject:[NSNumber numberWithInt:1] forKey:kCheck2];
		if ([str isEqualTo:key]) [sd setObject:[NSNumber numberWithInt:1] forKey:kCheck3];
    } while (false);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	• checkNoUpgradeNeeded
// ---------------------------------------------------------------------------------
// check if we need an upgrade key and look for it
// options: kOptionSkipDialog
- (BOOL)checkNoUpgradeNeeded:(NSDictionary*)regPlist option:(int)option {
	BOOL returnValue = YES;
	NSDate *registerDate;
	NSCalendarDate *versionDate;
	// date registered
	registerDate = [regPlist objectForKey:kRegisterDate];
	// date of this program version
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString* infoYear = [info objectForKey:@"fileReleaseDateY"];
	NSString* infoMonth = [info objectForKey:@"fileReleaseDateM"];
	NSString* infoDay = [info objectForKey:@"fileReleaseDateD"];
	versionDate = [[[NSCalendarDate alloc] initWithYear:[infoYear intValue] 
		month:[infoMonth intValue] day:[infoDay intValue] hour:12 minute:0 second:0 
		timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]] autorelease];
	// calculate time difference
	NSTimeInterval versionDelta = [versionDate timeIntervalSinceDate:registerDate];
	NSTimeInterval registerDelta = -[registerDate timeIntervalSinceNow];
	// is versionDate > 2 years after registrationDate
	if (versionDelta > (kSecondsPerDay * 365 * 2)) {
		// Yes, some upgrade is needed
		
		returnValue = NO;
		// reset registered flags
		PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
		[sd removeObjectForKey:kCheck1];
		[sd removeObjectForKey:kCheck2];
		[sd removeObjectForKey:kCheck3];
		if (option != kOptionSkipDialog) {
			_askForUpgradeCompleted = YES;	// remember we have asked for upgrade
			// setup window
			UpgradeController *upgradeController = [UpgradeController alloc];
			upgradeController = [upgradeController initWithWindowNibName:kUpgradeName owner:upgradeController];
			[upgradeController autorelease];
			NSWindow* window = [upgradeController window];
			[window center];
			// if registration was less than 3 years ago, offer an "Upgrade now discount code"
			if (registerDelta < (kSecondsPerDay * 365 * 3)) {
				NSString *year = [infoYear substringFromIndex:2];
				NSString *month;
				switch ([infoMonth intValue]) {
					case 1:
					case 2:
					case 3:
					default:
						month = @"A";
						break;
					case 4:
					case 5:
					case 6:
						month = @"B";
						break;
					case 7:
					case 8:
					case 9:
						month = @"C";
						break;
					case 10:
					case 11:
					case 12:
						month = @"D";
						break;
				}
#if IPNetRouter
				NSString *upgradeCode = [NSString stringWithFormat:@"IPRx%@%@",year,month];
#else
				NSString *upgradeCode = [NSString stringWithFormat:@"IPSx%@%@",year,month];
#endif
				[upgradeController setReleaseDate:[NSString stringWithFormat:@"%@-%@-%@",infoYear,infoMonth,infoDay]];
				[upgradeController setRegisterDate:[registerDate descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil]];
				[upgradeController setDiscount:upgradeCode];
			}
			else {
				[upgradeController setReleaseDate:[NSString stringWithFormat:@"%@-%@-%@",infoYear,infoMonth,infoDay]];
				[upgradeController setRegisterDate:[registerDate descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil]];
				[upgradeController setDiscount:nil];
			}
			// Wait for modal response and release window
			[NSApp runModalForWindow:window];
			//[window makeKeyAndOrderFront:self];
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• doHash
// ---------------------------------------------------------------------------------
- (NSString *)doHash:(NSString *)inStr {
    NSMutableData*	regData;
    UInt32	hash[5];
    int result;
    NSString* outStr;
    
    // use NSMutableData as buffer for input data
    regData = [NSMutableData dataWithCapacity:kRegDataLength];
    [regData appendBytes:[inStr UTF8String] length:strlen([inStr UTF8String])];
    // calculate sha1
    result = nmHash([regData mutableBytes], [regData length], kRegDataLength, hash);
    // show result
    outStr = nil;
    if (result == 0) {
		if(NTOHL(hash[0]));	// OK
		if(NTOHL(hash[1]));
		if(NTOHL(hash[2]));
		if(NTOHL(hash[3]));
		if(NTOHL(hash[4]));
		if(NTOHL(hash[5]));
        outStr = [NSString stringWithFormat:@"%08x %08x %08x %08x %08x",
            hash[0],hash[1],hash[2],hash[3],hash[4]];
    }
    return outStr;
}

@end

// ---------------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------------
