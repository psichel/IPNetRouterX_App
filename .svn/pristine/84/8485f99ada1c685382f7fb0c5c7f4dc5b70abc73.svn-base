//
//  DHCPServer.m
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  DHCP client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import "DHCPServer.h"
#import "AppSupport.h"
#import "PSURL.h"
#import "DHCPAction.h"
#import "DHCPState.h"
#import "DHCPSupport.h"
#import "NSException_Extensions.h"

#if DHCPServer_app
// registration
#import "PSSharedDictionary.h"
#import "nmCypher.h"
// registration data dictionary keys
#define kName @"name"
#define kOrganization @"organization"
#define kLicensedCopies @"licensedCopies"
#define kCode @"IPNetRouterX_key"
#define kExpireDate @"expireDate"
// doRegistrationInput results
#define kRegAccepted 0
#define kRegNotAccepted 1
#define kRegInvalid 2
#define kRegNotFound 3
// more registration
#define kRegDataLength 512
//#define kDefaultSettingsPath	@"/Library/Preferences/com.sustworks.IPNetRouterX.ipnr"
#define kPrefsPath				@"/Library/Preferences/com.sustworks.IPNetRouterX.prefs.plist"
#endif


@interface DHCPServer (PrivateMethods)
- (int)serverWriteStatus:(NSDictionary *)plist;
#if DHCPServer_app
// Registration
- (NSDictionary *)readPrefs;
- (BOOL)isRegistered;
- (NSDictionary *)readRegistration;
- (NSString *)keyPath;
- (NSDate *)expireDate;
// - validation
- (BOOL)checkRegistrationKey:(NSDictionary*)regData;
- (NSString *)doHash:(NSString *)inStr;
#endif
@end

@implementation DHCPServer

+ (DHCPServer *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[DHCPServer alloc] init];
	}
	return sharedTask;
}

- init {
    if (self = [super init]) {
		// initialize our instance variables
		dhcpAction = [DHCPAction sharedInstance];
		// set local proxy so others can find us
		[dhcpAction setDelegate:self];
		prefs = nil;
    }
    return self;
}

- (void) dealloc {
    [dhcpAction setDelegate:nil];
	[prefs release]; prefs = nil;
    [super dealloc];
}

// ---------------------------------------------------------------------------
//	¥ synchStartService:fromController:withObject:
// ---------------------------------------------------------------------------
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	// override to perform thread services
	int result = 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSString* str = nil;

	@try {    
		// The following line is an interesting optimisation.  We tell our proxy
		// to the controller object about the methods that we're going to
		// send to the proxy.    
		[controller setProtocolForProxy:@protocol(ControllerFromThread)];
		// init method vars
		[self setController:controller];

		// extract parameters
		str = inURL;
		if (!str) str = [anObject objectForKey:kServerRequest];
		// dispatch commands
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}
		else if ([str hasPrefix:kServerStart])
			result = [self serverStart:anObject];
		else if ([str hasPrefix:kServerStop])
			result = [self serverStop:anObject];
		else if ([str hasPrefix:kServerTerminate])
			result = [self serverTerminate:anObject];
		else if ([str hasPrefix:kServerApply])
			result = [self serverApply:anObject];
		else if ([str hasPrefix:kServerShowActive])
			result = [self serverShowActive:anObject];
		else if ([str hasPrefix:kServerWriteStatus])
			result = [self serverWriteStatus:anObject];
		else {
			[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
		}
	}
	@catch( NSException *theException ) {
		NSString* statusInfo = @"Exception during DHCPServer.m synchStartService";
		NSLog(statusInfo);
		[self updateParameter:@"statusInfo" withObject:statusInfo];
		if (str) NSLog(str);
		// try to print symbolic stack trace
		[theException printStackTrace];
	}

    [pool release]; pool = nil;
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ serverRestore
// ---------------------------------------------------------------------------------
// Restore DHCP Server state from /Library/Preferences/IPNetRouterX/dhcpServerConfig.plist
// Stand alone server process never writes out DHCP state, but rather updates UI client to handle that.
- (BOOL)serverRestore
{
	BOOL returnValue = NO;
	DHCPState* newState;
	NSString* path;
	NSDictionary* saveDictionary = readDhcpSettings();
	if (!saveDictionary) {
		path = [AppSupport findAlternateFor:@"dhcpServerConfig.plist"];
		saveDictionary = [NSDictionary dictionaryWithContentsOfFile:path];
		saveDictionary = [saveDictionary objectForKey:kSentryDocument_dhcpState];
	}
	if (saveDictionary) {
		newState = dhcpStateForSaveDictionary(saveDictionary);
		[dhcpAction setDhcpState:newState];
		if ([[newState dhcpServerOn] intValue]) [dhcpAction startServing];
		else [dhcpAction stopServing];
		returnValue = YES;
	}
#if DHCPServer_app
	// read saved preferences
	[prefs release]; prefs = nil;
	prefs = [[self readPrefs] retain];
#endif
	return returnValue;
}

#pragma mark -- actions --
- (int)serverStart:(NSDictionary *)plist
{
	int result = -1;
	do {
#if DHCPServer_app
		// check registration
		// check registration
		PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
		[self isRegistered];
		if ([[sd objectForKey:kCheck1] intValue] &&
			[[sd objectForKey:kCheck2] intValue] &&
			[[sd objectForKey:kCheck3] intValue]) {
			// registered or in trial period
		}
		else {
			NSLog(@"DHCP Server trial period has expired.");
			//[self serverStop:nil];
			break;
		}
#endif
		result = [dhcpAction startServing];
	} while (0);
	return result;
}

- (int)serverStop:(NSDictionary *)plist
{
	return [dhcpAction stopServing];
}

- (int)serverApply:(NSDictionary *)plist
{
	NSEnumerator* en = [plist keyEnumerator];
	NSString* key;
	NSString* prefix;
	NSRange range;
	id inValue;
	DHCPState* dhcpState;
	id target;
	BOOL updateStatus = NO;
	
	dhcpState = [dhcpAction dhcpState];
	target = dhcpState;
	while (key = [en nextObject]) {
		inValue = [plist objectForKey:key];
		if (([inValue isKindOfClass:[NSString class]]) &&
			([@"nil" isEqualTo:inValue])) inValue = nil;
		// expand flattened key
		range = [key rangeOfString:@"/"];
		while (range.length) {
			prefix = [key substringToIndex:range.location];
			key = [key substringFromIndex:range.location+1];
			target = [target valueForKey:prefix];
			range = [key rangeOfString:@"/"];
		}
		[target takeValue:inValue forKey:key];
		if ([key isEqualTo:DS_statusEntry]) updateStatus = YES;
	}
	if (updateStatus) [dhcpAction writeStatusTable];
	return 0;
}

- (int)serverShowActive:(NSDictionary *)plist
{
	NSEnumerator* en = [plist keyEnumerator];
	NSString* key;
	NSString* prefix;
	NSRange range;
	id object;
	DHCPState* dhcpState;
	id target;
	
	dhcpState = [dhcpAction dhcpState];
//	[dhcpAction readStatusTable];
	while (key = [en nextObject]) {
		target = dhcpState;
		// expand flattened key
		range = [key rangeOfString:@"/"];
		while (range.length) {
			prefix = [key substringToIndex:range.location];
			key = [key substringFromIndex:range.location+1];
			target = [target valueForKey:prefix];
			range = [key rangeOfString:@"/"];
		}
		// use key value coding to report state
		object = [target valueForKey:key];
		if (!object) object = @"nil";
		[self updateParameter:key withObject:object];
	}
	return 0;
}

- (int)serverWriteStatus:(NSDictionary *)plist
{
	[dhcpAction writeStatusTable];
	return 0;
}

- (int)serverTerminate:(NSDictionary *)plist
{
	[dhcpAction stopServing];
	[self finish];
	return 0;
}

- (void)cleanUp {
    // override to clean-up when server is killed
	if (!mCleanUpFlag) {	// don't allow multiples
		mCleanUpFlag = YES;
        [dhcpAction stopServing];   // reset any persistant dhcp state
        [self setController:nil];
    }
}

#if DHCPServer_app
#pragma mark - Registration -
// ---------------------------------------------------------------------------------
//	¥ Read Preferences
// ---------------------------------------------------------------------------------
- (NSDictionary *)readPrefs
{
	NSDictionary* returnValue;
	NSString* path;
	// read saved preferences
	path = kPrefsPath;
	returnValue = [NSDictionary dictionaryWithContentsOfFile:path];
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ isRegistered
// ---------------------------------------------------------------------------------
// check if we're already registered
- (BOOL)isRegistered {
    BOOL returnValue = NO;
    NSDictionary* regData;

	regData = [self readRegistration];
	// check dictionary
	returnValue = [self checkRegistrationKey:regData];
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
//	¥ readRegistration
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
        str = [NSString stringWithContentsOfFile:path];
		regData = plistForString(str);		
		//regData = [NSDictionary dictionaryWithContentsOfFile:path];
	}
	return regData;
}

// ---------------------------------------------------------------------------------
//	¥ keyPath
// ---------------------------------------------------------------------------------
// find and return path to registration key file
- (NSString *)keyPath
{
    NSString* path;
    NSFileManager* manager;
    
    manager = [NSFileManager defaultManager];
    do {
        // get path to file
        path = [[NSBundle mainBundle] bundlePath];
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByAppendingString:@"/IPNetRouterKey"];
        // check if file exists
        if ([manager fileExistsAtPath:path]) break;
        // try alternate key locations
            // registrationKey
        path = [[NSBundle mainBundle] bundlePath];
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByAppendingString:@"/registrationKey"];
        if ([manager fileExistsAtPath:path]) break;
        path = @"/Library/Application Support/Sustainable Softworks/IPNetRouterKey";
        if ([manager fileExistsAtPath:path]) break;            
            // library/application support/Sustainable Softworks/registrationKey
        path = @"/Library/Application Support/Sustainable Softworks/registrationKey";
        if ([manager fileExistsAtPath:path]) break;
        // file not found
        path = nil;
    } while (false);
    return path;
}

// ---------------------------------------------------------------------------------
//	¥ expireDate
// ---------------------------------------------------------------------------------
// get trial expiration date if any
// returns nil if expired and no date available
- (NSDate *)expireDate
{
    NSDictionary* myDictionary;
    NSFileManager* manager;
//    NSString* pathA;
    NSString* pathB;
    NSDate* appDate = nil;
    NSDate* prefDate = nil;
    NSDate* xDate = nil;
	NSDate* newExpireDate;
    NSDate* returnValue = nil;
    NSString* kDate = @"date";
    NSTimeInterval trialPeriod;
    BOOL flag = YES;

@try {    
    manager = [NSFileManager defaultManager];
    // get expiration dates if present
        // application bundle
#if 0
    pathA = [[NSBundle mainBundle] pathForResource:@"expireDate" ofType:nil];
    if (pathA) {
        myDictionary = [NSDictionary dictionaryWithContentsOfFile:pathA];
        appDate = [myDictionary objectForKey:kDate];
    }
    else {
        pathA = [[NSBundle mainBundle] resourcePath];
        pathA = [pathA stringByAppendingString:@"/expireDate"];
    }
#endif
        // preferences
    prefDate = [prefs objectForKey:kDate];
        // application support

    pathB = @"/Library/Application Support/Sustainable Softworks";
    if (![manager fileExistsAtPath:pathB isDirectory:&flag]) {
        flag = [manager createDirectoryAtPath:pathB attributes:nil];
    }
	pathB = @"/Library/Application Support/Sustainable Softworks/.xIPNetRouter";
    if ([manager fileExistsAtPath:pathB]) {
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
	if ( (xDate != nil) && ([xDate timeIntervalSinceNow] < (double)-31536000) ) {
		returnValue = newExpireDate;
		appDate = nil;
		prefDate = nil;
		xDate = nil;
	}
    // write out any missing dates
    myDictionary = [NSDictionary dictionaryWithObject:returnValue forKey:kDate];
//    if (!appDate) [myDictionary writeToFile:pathA atomically:YES];
//    if (!prefDate) [prefs setObject:returnValue forKey:kDate];
    if (!xDate) [myDictionary writeToFile:pathB atomically:YES];
}
@catch( NSException *theException ) {
	//[theException printStackTrace];
	NSLog(@"Possibly corrupt preferrence file ~/Library/Preferences/com.sustworks.IPNetRouterX.plist");
}
    return returnValue;
}

#pragma mark - validation -

// ---------------------------------------------------------------------------------
//	¥ checkRegistrationKey
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
        regCode = [regData objectForKey:kCode];
        str = [NSString stringWithFormat:@"IPNetRouterX %@",[self doHash:@"030710"]];
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
//	¥ doHash
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
		NTOHL(hash[0]);	// OK
		NTOHL(hash[1]);
		NTOHL(hash[2]);
		NTOHL(hash[3]);
		NTOHL(hash[4]);
		NTOHL(hash[5]);
        outStr = [NSString stringWithFormat:@"%08x %08x %08x %08x %08x",
            hash[0],hash[1],hash[2],hash[3],hash[4]];
    }
    return outStr;
}
#endif
@end
