//
//  AppSupport.m
//  IPNetX
//
//  Created by Peter Sichel on 3-Dec-2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Application Support methods for accessing AppSupport files.

#import "AppSupport.h"
#import "Authorization.h"
#import "IPICMPSocket.h"		// OpenICMP

// global system version info obtained during app startup
extern int gStartupItem;
extern int gMajorVersion, gMinorVersion, gMinorMinorVersion;

#if !DHCPServer_app
// Module wide
static BOOL useHomeDirForSupportSustworks = NO;
static BOOL useHomeDirForPreferences = NO;
static BOOL keepPrefsInFolder = YES;
static int ignoreSig = 0;
#endif

@implementation AppSupport
+ (AppSupport *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[AppSupport alloc] init];
	}
	return sharedTask;
}


#pragma mark -- App Prefs Paths --
// ---------------------------------------------------------------------------------
//	• appPrefsFile
// ---------------------------------------------------------------------------------
// Encapsulate path to our /Library/Preferences/com.sustworks.<app-name>.prefs.plist
// Assume app prefers system wide prefs or would just use NSUserDefaults
+ (NSString *)appPrefsFile
{
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL result = YES;
	
	if (keepPrefsInFolder) {
		// prefs if /Library/Preferences/<app-name>/com.sustworks.IPNetX.prefs.plist
		path = [AppSupport appPrefsPath:kPrefsFilename];
		return path;
	}
	
	path = kPrefsFilePath;
	if (useHomeDirForPreferences) {
		result = NO;
	}
	else {
		// test if we can write prefs
		NSString* tPath = @"/Library/Preferences";
		result = [fm isWritableFileAtPath:tPath];
	}
	if (!result) {
		//if (!useHomeDirForPreferences) NSLog(@"Unable to create or write file at: %@",path);
		// if we don't have permission to access /Library/Preferences/
		// try users home directory instead
		path = [NSString stringWithFormat:@"~%@",path];
		path = [path stringByExpandingTildeInPath];
		if (!useHomeDirForPreferences) NSLog(@"Using %@",path);
		useHomeDirForPreferences = YES;
	}
	return path;
}

// ---------------------------------------------------------------------------------
//	• appPrefsFolder
// ---------------------------------------------------------------------------------
// Encapsulate path to our /Library/Preferences/IPNetMonitorX folder
+ (NSString *)appPrefsFolder
{
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL result = YES;
	
	path = kAppPrefsFolderPath;
	if (useHomeDirForPreferences) {
		result = NO;
	}
	else {
		if (![fm fileExistsAtPath:path isDirectory:&result]) {
			result = [fm createDirectoryAtPath:path attributes:nil];
		}
		else {
			// folder exists, make sure we can write to it
			result = [fm isWritableFileAtPath:path];
		}
	}
	if (!result) {
		//if (!useHomeDirForPreferences) NSLog(@"Unable to create or write to directory at: %@",path);
		// if we don't have permission to access /Library/Preferences/
		// try users home directory instead
		path = [NSString stringWithFormat:@"~%@",path];
		path = [path stringByExpandingTildeInPath];
		// check if it already exists or try to create it
		if ([fm fileExistsAtPath:path] || [fm createDirectoryAtPath:path attributes:nil]) {
			if (!useHomeDirForPreferences) NSLog(@"Using %@",path);
			useHomeDirForPreferences = YES;
		}
	}
	return path;
}

// ---------------------------------------------------------------------------------
//	• appPrefsPath:
// ---------------------------------------------------------------------------------
// Return path to named item in App Prefs folder
+ (NSString *)appPrefsPath:(NSString *)name
{
	NSString* path;	
	path = [self appPrefsFolder];
	path = [path stringByAppendingPathComponent:name];
	return path;
}

// ---------------------------------------------------------------------------------
//	• initTunerDocumentsFolder
// ---------------------------------------------------------------------------------
// Make sure we have a Tuner Documents folder and preload it with our default presets
+ (NSString *)initTunerDocumentsFolder
{
	NSString* dst;
	NSString* resourcePath;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL result = YES;
	
	dst = [self appSupportFolder];
	dst = [dst stringByAppendingPathComponent:kTunerDocumentsFolder];
	// does it exist
	if (![fm fileExistsAtPath:dst]) {
		// copy our resource
		resourcePath = [[NSBundle mainBundle] pathForResource:kTunerPresetsFolder ofType:nil];
		result = [fm copyPath:resourcePath toPath:dst handler:nil];
	}
	return dst;
}

// ---------------------------------------------------------------------------------
//	• updateTunerDocumentsFolder
// ---------------------------------------------------------------------------------
// Copy individual files to update tuner documents folder
+ (void)updateTunerDocumentsFolder
{
	NSString* dst;
	NSString* resourcePath;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL result = YES;
	NSArray *list;
	NSString *name;
	NSString *srcPath, *dstPath;
	NSEnumerator *en;
	
	dst = [self appSupportFolder];
	dst = [dst stringByAppendingPathComponent:kTunerDocumentsFolder];
	resourcePath = [[NSBundle mainBundle] pathForResource:kTunerPresetsFolder ofType:nil];
	list = [fm directoryContentsAtPath:resourcePath];
	en = [list objectEnumerator];
	while (name = [en nextObject]) {
		srcPath = [resourcePath stringByAppendingPathComponent:name];
		dstPath = [dst stringByAppendingPathComponent:name];
		result = [fm removeFileAtPath:dstPath handler:nil];
		if (!result) NSLog(@"Did not remove file at path: %@", dstPath);
		result = [fm copyPath:srcPath toPath:dstPath handler:nil];
		if (!result) NSLog(@"Did not copy file to path: %@", dstPath);
	}
}


// ---------------------------------------------------------------------------------
//	• tunerDocumentsFolder2
// ---------------------------------------------------------------------------------
// Are there more tuner documents in ~/Library/...?
+ (NSString *)tunerDocumentsFolder2
{
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	
	path = [self appSupportFolder];
	if ([path hasPrefix:@"/Library"]) {
		path = [NSString stringWithFormat:@"~%@",path];
		path = [path stringByExpandingTildeInPath];
		path = [path stringByAppendingPathComponent:kTunerDocumentsFolder];
		// does it exist
		if (![fm fileExistsAtPath:path]) path = nil;
	}
	else path = nil;
	return path;
}


#pragma mark -- App Support Paths --
// ---------------------------------------------------------------------------------
//	• appSupportFolder
// ---------------------------------------------------------------------------------
// Encapsulate path to our /Library/Application Support/<app-name>/ folder
// Create /Library/Application Support/<app-name>/ if needed
+ (NSString *)appSupportFolder
{
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL result = YES;
	int authResult = 0;
	
	path = kAppSupportFolderPath;
	if (![fm fileExistsAtPath:path isDirectory:&result]) {
		result = [fm createDirectoryAtPath:path attributes:nil];
		if (!result) do {
			// failed to create folder, try using our authorize tool
			if ([self doAuthorization]) {
                NSArray *authorizeList = [NSArray arrayWithObject:path];
				authResult = [[Authorization sharedInstance] authorize:authorizeList
					withCommand:@"-createfolder"];
				if (authResult != 0) NSLog(@"failed to create directory at: %@",path);
            }
			else {
				NSLog(@"failed to create directory at: %@",path);
				break;
			}
		} while (false);
	}
	return path;
}

// ---------------------------------------------------------------------------------
//	• appSupportPath:
// ---------------------------------------------------------------------------------
// Return path to named item in App Support folder
// Create /Library/Application Support/<app-name>/ if needed
+ (NSString *)appSupportPath:(NSString *)name
{
	NSString* path;	
	path = [self appSupportFolder];
	path = [path stringByAppendingPathComponent:name];
	return path;
}

// ---------------------------------------------------------------------------------
//	• appSupportSustworksPath:
// ---------------------------------------------------------------------------------
// Return path to named item in Application Support/Sustainable Softworks folder
// Caller wishes read/write access for saving data
+ (NSString *)appSupportSustworksPath:(NSString *)name
{
	NSString* path;	
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL result = YES;
	
	path = kAppSupportSustworksPath;
	
	if (useHomeDirForSupportSustworks) {
		result = NO;
	}
	else {	
		if (![fm fileExistsAtPath:path isDirectory:&result]) {
			result = [fm createDirectoryAtPath:path attributes:nil];
		}
		else {
			// folder exists, make sure we can write to it
			result = [fm isWritableFileAtPath:path];
		}
	}
	if (!result) {
		//NSLog(@"Unable to create directory at: %@",path);
		// if we don't have permission to access /Library/Application Support/
		// try users home directory instead
		path = [NSString stringWithFormat:@"~%@",path];
		path = [path stringByExpandingTildeInPath];
		// check if it already exists or try to create it
		if ([fm fileExistsAtPath:path] || [fm createDirectoryAtPath:path attributes:nil]) {
			if (!useHomeDirForSupportSustworks) NSLog(@"Using %@",path);
			useHomeDirForSupportSustworks = YES;
		}
	}
	path = [path stringByAppendingPathComponent:name];
	return path;
}

// ---------------------------------------------------------------------------------
//	• appSupportSustworksPathRO:
// ---------------------------------------------------------------------------------
// Return path to named item in Application Support/Sustainable Softworks folder
// Caller is looking for existing file, read only access is sufficient.
// Don't create folder if it doesn't exist
// Return nil if file not found
+ (NSString *)appSupportSustworksPathRO:(NSString *)name
{
	NSString* path;	
	NSFileManager* fm = [NSFileManager defaultManager];
	
	path = kAppSupportSustworksPath;
	path = [path stringByAppendingPathComponent:name];
	if (![fm fileExistsAtPath:path]) {
		// File not found at /Library/Application Support/
		// try users home directory instead
		path = [NSString stringWithFormat:@"~%@",path];
		path = [path stringByExpandingTildeInPath];
		// check if file exists
		if (![fm fileExistsAtPath:path]) {
			// nope, there's no such file
			path = nil;
		}
	}
	return path;
}


#pragma mark -- Helper Tool Paths --
// ---------------------------------------------------------------------------------
//	• initAppHelperToolsFolder
// ---------------------------------------------------------------------------------
// Make sure we have a HelperTools folder
+ (NSString *)initAppHelperToolsFolder
{
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL status = YES;
	int authResult = 0;
	
	path = [self appSupportFolder];
	path = [path stringByAppendingPathComponent:kAppHelperToolsFolder];
	// does it exist
	if (![fm fileExistsAtPath:path]) {
		status = [fm createDirectoryAtPath:path attributes:nil];
		if (!status) do {
			// failed to create folder, try using our authorize tool
			if ([self doAuthorization]) {
                NSArray *authorizeList = [NSArray arrayWithObject:path];
				authResult = [[Authorization sharedInstance] authorize:authorizeList
					withCommand:@"-createfolder"];
				if (authResult != 0) NSLog(@"failed to create directory at: %@",path);
            }
			else {
				NSLog(@"failed to create directory at: %@",path);
				break;
			}
		} while (false);
	}
	return path;
}

// ---------------------------------------------------------------------------------
//	• helperToolPath:
// ---------------------------------------------------------------------------------
// Return path to named item in HelperTools folder
// Create /Library/Application Support/<app-name>/ if needed
// Create HelperTools folder if needed
+ (NSString *)helperToolPath:(NSString *)name
{
	NSString* path;
	path = [self initAppHelperToolsFolder];
	path = [path stringByAppendingPathComponent:name];
	return path;
}

// ---------------------------------------------------------------------------------
//	• bundleToolPath:
// ---------------------------------------------------------------------------------
// Encapsulate file path to named auxiliary helper tool in app bundle.
// Notice tools may be moved to our Application Support directory.
+ (NSString *)bundleToolPath:(NSString *)name
{
	NSString* path;
	path = [[NSBundle mainBundle] pathForAuxiliaryExecutable:name];
	return path; 
}

// ---------------------------------------------------------------------------------
//	• toolPathForName:
// ---------------------------------------------------------------------------------
// Encapsulate file path to named auxiliary helper tool.
// Create /Library/Application Support/<app-name>/ if needed and report whether tool file exists
+ (NSString *)toolPathForName:(NSString *)name fileExists:(BOOL *)fileExists
{
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	path = [self appSupportFolder];
	path = [path stringByAppendingPathComponent:kAppHelperToolsFolder];
	path = [path stringByAppendingPathComponent:name];
	// does it exist
	if (fileExists) {
		if ([fm fileExistsAtPath:path]) *fileExists = YES;
		else *fileExists = NO;
	}
	return path; 
}


// ---------------------------------------------------------------------------------
//	• validateSignedCodeAtPath:
// ---------------------------------------------------------------------------------
+ (int)validateSignedCodeAtPath:(NSString *)inPath
{
	int result = 0;
	NSString* toolPath;
	
	// don't try this on Tiger or if launched as startup item
	if ((gMajorVersion >= 10) && (gMinorVersion >= 5) && (!gStartupItem) && (!ignoreSig)) {
		// make sure we have read access before attempting validation
		NSFileManager* fm = [NSFileManager defaultManager];
		if (![fm isReadableFileAtPath:inPath]) return -EPERM;
        // run tool to validate signature
		// 0 = all tests passed
		// 1 = failed to satisfy code requirements
		// 2 = parameter error
        toolPath = @"/usr/bin/codesign";
        result = [self doTask:toolPath arguments:[NSArray arrayWithObjects:
			@"-v",
            @"-R=certificate leaf H\"c9a6d793fe9c80c4b040053fa5b5e8c134e540ab\"",
            inPath,
            nil] output:nil];
#if !DHCPServer_app
		if ((result != 0) && (!ignoreSig)) {
			int userResponse;
			userResponse = NSRunAlertPanel([NSString stringWithFormat:@"%@ Code Signing",PS_PRODUCT_NAME],
				[NSString stringWithFormat:@"Unable to validate the code signature for helper tool: %@", inPath],
				@"Continue",
				@"Ignore Similar",
				@"Quit");
			if (userResponse == NSAlertAlternateReturn) {
				ignoreSig = 1;
				result = 0;
			}
			if (userResponse == NSAlertOtherReturn) {
				// User has selected "Quit"
				// remove HelperToolsVersion.plist so app will re-install our tools on next launch
				NSString* dest;
				dest = [[self initAppHelperToolsFolder] stringByAppendingPathComponent:kHelperToolsVersionPlist];
				[fm removeFileAtPath:dest handler:nil];
				// terminate app
				[NSApp terminate:self];
			}
		}
#endif
	}
	return result;
}

// ---------------------------------------------------------------------------------
//	• checkTool:
// ---------------------------------------------------------------------------------
// check for named tool, if not, try to restore from app bundle    
// return 181 for identify confirmed, needs athorization
// return -3 for copy failed, permission denied
+ (int)checkTool:(NSString *)name
{
    NSString* path;
	NSString* resourcePath;
    int result;

	resourcePath = [self bundleToolPath:name];
	result = [self getHelperToolFromPath:resourcePath outPath:&path];
	if (result >= 0) {
		sync();
		result = [self checkToolAuthorization:path];
	}
    return result;
}

// ---------------------------------------------------------------------------------
//	• checkNKE:
// ---------------------------------------------------------------------------------
// name will be of form IPNetMonitor_NKE.kext (or IPNetMonitor_TNKE for Tiger)
// need different mechanism to verify since we can't call NKEs directly.
+ (int)checkNKE:(NSString *)name
{
    // check for our NKE, if not, try to restore it    
    NSString* path;
    NSString* resourcePath;
    NSFileManager* fm = [NSFileManager defaultManager];
	NSDictionary* sourceAttribute;
    int result = 0;
    
    // get path to our tool
	resourcePath = [self bundleToolPath:name];
	result = [self getHelperToolFromPath:resourcePath outPath:&path];
	if (result >= 0) {
       // if not owned by root, it needs authorization
        sourceAttribute = [fm fileAttributesAtPath:path traverseLink:NO];
        if (![[sourceAttribute objectForKey:@"NSFileOwnerAccountName"] isEqualTo:@"root"]) {
            // confirm it needs authorization
            result = 181;
        }
		else {
			// if NKE is owned by root, might still need authorization
			// if App itself was installed from root account
			// check if we are running as root
			if (geteuid() == 0) result = 181;
		}
	}
    return result;
}

// ---------------------------------------------------------------------------------
//	• getHelperToolFromPath: outPath:(NSString **)outPath
// ---------------------------------------------------------------------------------
// Copy named tool from app bundle to HelperTools folder
// -3 = copy failed, insuficcient privs or other error
// -2 = no such tool found in App bundle
//  0 = found previously existing version
//  1 = tool was copied
//  2 = version mismatch, need authorization
+ (int)getHelperToolFromPath:(NSString *)inPath outPath:(NSString **)outPath
{
    // check for our tool, if not, try to restore it
	NSString* dest = nil;
	BOOL fileExists;
	NSString* name;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL versionMatch = NO;
	BOOL status;
    int returnValue = 0;

	do {
		// get paths for HelperToolsVersion.plist
		NSString *resourcePath;
		dest = [[self initAppHelperToolsFolder] stringByAppendingPathComponent:kHelperToolsVersionPlist];
		resourcePath = [[NSBundle mainBundle] pathForResource:kHelperToolsVersion ofType:@"plist"];
		if (![fm fileExistsAtPath:dest]) {
			// No previous HelperToolsVersion.plist found, assume versions do not match
			versionMatch = NO;
		}
		else {
			// check whether tool versions match
			NSDictionary *resourceD = [NSDictionary dictionaryWithContentsOfFile:resourcePath];
			NSDictionary *toolD = [NSDictionary dictionaryWithContentsOfFile:dest];
			NSString *resourceStr = [resourceD objectForKey:kToolBuildNumber];
			NSString *toolStr = [toolD objectForKey:kToolBuildNumber];
			if ([resourceStr isEqualTo:toolStr]) versionMatch = YES;
		}

		// get desired path to our tool
		name = [inPath lastPathComponent];
		dest = [self toolPathForName:name fileExists:&fileExists];
		// if not found, try to copy from inPath (typically app bundle)
		if (!fileExists) {
			// does original exist
			if (![fm fileExistsAtPath:inPath]) {
				[self reinstall:name];
				returnValue = -2;
				break;
			}
			dest = [self helperToolPath:name];	// Create HelperTools folder if needed
			status = [self copyPath:inPath toPath:dest];
			if (!status) {
				NSLog(@"copy toPath %@ failed",dest);
				returnValue = -3;
				break;
			}
			returnValue = 1;
			break;
		}
		else if (!versionMatch) {
			// copy the named tool itself
			dest = [self helperToolPath:name];
			status = [self copyPath:inPath toPath:dest];
			if (!status) {
				NSLog(@"copyPath:toPath:%@ failed",dest);
				returnValue = -3;
				break;
			}
			returnValue = 2;
		}
	} while (0);
	if (outPath) *outPath = dest;
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	• checkToolAuthorization
// ---------------------------------------------------------------------------------
// check tool identity and authorization
// return 181 for identify confirmed, needs athorization
+ (int)checkToolAuthorization:(NSString *)path
{
	int result;
	int	fd[2] = { -1, -1 };
	NSFileHandle* fp;
	NSString* response;
	char buf[32];
	int bytesRead=0;
	NSString *name = [path lastPathComponent];
	
	// check signed code on 10.5 or later
	result = [self validateSignedCodeAtPath:path];
	if (result != 0) {
		if (result == -EPERM) NSLog(@"Could not access file to validate signature at path: %@",path);
		return result;
	}
	// create a stream pipe to read from our tool
	if ( socketpair( AF_UNIX, SOCK_STREAM, 0, fd ) == -1 ) {
		NSLog(@"Cannot create a socket pair");
		return -1;
	}
	fp = [[NSFileHandle alloc] initWithFileDescriptor:fd[1] closeOnDealloc:NO];
	
	NS_DURING
	result = [self doTask:path arguments:[NSArray arrayWithObject:@"-identify"]
		output:fp];
	NS_HANDLER
		// might fail if user not in admin group
		result = EPERM;
	NS_ENDHANDLER
	#if 0
	if (result == 0) {  // if tool says it is already root
		// check for SUID root attribute
		u_long permissions;
		sourceAttribute = [fm fileAttributesAtPath:path traverseLink:NO];
		permissions = [sourceAttribute filePosixPermissions];
		if (permissions & S_ISUID == 0) result = 181; // need authorization
	}
	#endif
	
	// confirm tool identity matches
	close(fd[1]);
	bytesRead = read(fd[0], buf, 32);
	if (bytesRead) {
		buf[bytesRead] = 0;
		response = [NSString stringWithUTF8String:buf];
		if (![response isEqualTo:name]) result = 0;
	}
	else result = 0;
	
	close(fd[0]);
	[fp release];
	return result;
}

// ---------------------------------------------------------------------------------
//	• copyPath:toPath:
// ---------------------------------------------------------------------------------
// Try to copy tool using NSFileManager, but if that fails (insufficient privs),
// fallback to using our authorize tool.
+ (BOOL)copyPath:(NSString *)fromPath toPath:(NSString *)toPath
{
	BOOL status = NO;
	int authResult = 0;
	NSFileManager* fm = [NSFileManager defaultManager];
	//NSLog(@"copoyPath: %@ toPath: %@",fromPath, toPath);
	do {
		if ([fm fileExistsAtPath:toPath]) {
			// remove previous version if any (defensive)
			status = [fm removeFileAtPath:toPath handler:nil];
			if (!status) break;
			sync();
		}
		status = [fm copyPath:fromPath toPath:toPath handler:nil];
		if (!status) break;
	} while (false);
	
	if (!status) do {
		// first try failed, try using our authorize tool
		if ([self doAuthorization]) {
			NSArray *authorizeList = [NSArray arrayWithObjects:fromPath, toPath, nil];
			authResult = [[Authorization sharedInstance] authorize:authorizeList
				withCommand:@"-copy"];
			if (authResult == 0) status = YES;
			else NSLog(@"failed to copy from %@ to %@",fromPath,toPath);
		}
		else {
			NSLog(@"failed to copy from %@ to %@",fromPath,toPath);
			break;
		}
	} while (false);
	return status;
}


// ---------------------------------------------------------------------------------
//	• reinstall
// ---------------------------------------------------------------------------------
+ (void)reinstall:(NSString *)name
{
    NSString* userNotice = [NSString stringWithFormat:@"The application appears to be missing one or more components (%@), please re-install.",name];
	NSLog(@"%@ %@",PS_PRODUCT_NAME,userNotice);
#if !DHCPServer_app
	NSRunAlertPanel(PS_PRODUCT_NAME,
        userNotice,
        @"OK",
        nil,
        nil);
    [NSApp terminate:self];
#endif
}


#pragma mark -- migration --
// ---------------------------------------------------------------------------------
//	• findAlternateFor
// ---------------------------------------------------------------------------------
// Return an alternate path to the requested settings file.
// Used to migrate old setting files to a new location.
+ (NSString *)findAlternateFor:(NSString *)filename
{
	NSString* path = nil;
	NSString* defaultSettings = @"com.sustworks.IPNetRouterX.ipnr";
	NSString* dhcpStatus = @"dhcpStatus";
	NSString* triggerTable = @"triggerTable";
	NSString* dhcpServerConfig = @"dhcpServerConfig.plist";
	
	if ([filename isEqualTo:defaultSettings]) {
		path = @"/Library/Preferences/com.sustworks.IPNetRouterX.ipnr";
	}
	else if ([filename isEqualTo:dhcpStatus]) {
		//path = @"/Library/Application Support/Sustainable Softworks/dhcpStatus";
		path = [self appSupportSustworksPath:dhcpStatus];
	}
	else if ([filename isEqualTo:triggerTable]) {
		//path = @"/Library/Application Support/Sustainable Softworks/triggerTable";
		path = [self appSupportSustworksPath:triggerTable];
	}
	else if ([filename isEqualTo:dhcpServerConfig]) {
		path = @"/Library/Preferences/com.sustworks.IPNetRouterX.ipnr";
	}

	return path;
}

// ---------------------------------------------------------------------------------
//	• removeAlternatesFor
// ---------------------------------------------------------------------------------
+ (BOOL)removeAlternatesFor:(NSString *)filename
{
	return NO;
}


#pragma mark --- Authorization ---
// ---------------------------------------------------------------------------------
//	• doAuthorization
// ---------------------------------------------------------------------------------
+ (BOOL)doAuthorization
{
    BOOL returnValue = NO;
    int answer;
    
    // check if we are aleady authorized
	sync();
    if ([[Authorization sharedInstance] isAuthenticated]) return YES;
    // otherwise prompt user for authorization
	do {
		answer = NSRunAlertPanel([NSString stringWithFormat:@"%@ First Run",PS_PRODUCT_NAME],
			@"You must have Administrator privileges to complete the installation process.",
			//@"You must have Administrator privileges to complete the installation process.  Press Help for more information.",
			@"OK",
			@"Cancel",
			nil );
			//@"Help");
		if (answer == NSAlertDefaultReturn) {
			returnValue = [[Authorization sharedInstance] authenticate];
		}
		else if (answer == NSAlertAlternateReturn) [self authorizationNotCompleted];
		else if (answer == NSAlertOtherReturn) {		// show help information
			NSString *filePath;
			NSURL *fileURL;
			NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];		
			if (filePath = [thisBundle pathForResource:@"AuthenticationHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY])
			if (fileURL = [NSURL fileURLWithPath:filePath]) [[NSWorkspace sharedWorkspace] openURL:fileURL];
			[NSThread  sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)1.0]];
		}
	} while (answer == NSAlertOtherReturn);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	• authorizationNotCompleted
// ---------------------------------------------------------------------------------
// Show an alert for Authentication not completed
+ (void)authorizationNotCompleted
{
    NSRunAlertPanel(PS_PRODUCT_NAME,
        @"Authentication was not completed, some features may not be available.",
        @"OK",
        nil,
        nil);
}


#pragma mark -- do task --
// ---------------------------------------------------------------------------------
//	• doTask:arguments:output
// ---------------------------------------------------------------------------------
+ (int)doTask:(NSString *)path arguments:(NSArray *)args output:(id)output
    // args is an array of NSStrings, one argument per element
    // input and output are NSPipes
{
	int returnValue;
    NSTask *theTask = [[NSTask alloc] init];
	[theTask setLaunchPath:path];
	if (args) [theTask setArguments:args];
	if (output) {
		[theTask setStandardOutput:output];
		[theTask setStandardError:output];
	}
	@try {
		[theTask launch];
		[theTask waitUntilExit];
		returnValue = [theTask terminationStatus];
	}
	@catch( NSException *theException ) {
		NSLog(@"Exception during AppSupport.m +doTask: %@, reason: %@",path,[theException reason]);
		returnValue = -1;
	}
    [theTask release];
    
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	• doTask:arguments:input:output
// ---------------------------------------------------------------------------------
+ (int)doTask:(NSString *)path arguments:(NSArray *)args input:(NSString *)input output:(NSString **)output
    // run a unix command line tool
    // args is an array of NSStrings, one argument per element
    // input is an NSString of text sent to stdin
    // returns output as NSString
{
    int returnValue=0;
    NSString* outputString = nil;
    NSData* data = nil;
    NSTask *theTask;
    NSPipe* standardOutputPipe = [NSPipe pipe];
    NSFileHandle* standardOutputHandle = [standardOutputPipe fileHandleForReading];
    NSPipe* standardInputPipe = [NSPipe pipe];
    NSFileHandle* standardInputHandle = [standardInputPipe fileHandleForWriting];

    theTask = [[NSTask alloc] init];
	[theTask setLaunchPath:path];
	if (args) [theTask setArguments:args];
	if (input) {
        data = [input dataUsingEncoding:NSUTF8StringEncoding];
        [standardInputHandle writeData:data];
        [standardInputHandle closeFile];	// signal end of file to tool        
        [theTask setStandardInput:standardInputPipe];
    }
	[theTask setStandardOutput:standardOutputPipe];
	[theTask launch];
    [theTask waitUntilExit];
    returnValue = [theTask terminationStatus];
    [theTask release];
    
    data = [standardOutputHandle availableData];
    if ( (data != nil) && ([data length] != 0) ) {
        outputString = [[[NSString alloc]initWithData:data
            encoding:NSUTF8StringEncoding] autorelease];
		if (output) *output = outputString;
    }
    return returnValue;
}

@end

// ---------------------------------------------------------------------------------
//	• stringForPlist
// ---------------------------------------------------------------------------------
NSString* stringForPlist(id inPlist)
{
	NSString* returnValue = nil;
	NSData* data;
	NSString* errorDescription = nil;
	
	NS_DURING
		data = [NSPropertyListSerialization dataFromPropertyList:inPlist
			format:NSPropertyListXMLFormat_v1_0
			errorDescription:&errorDescription];
		
		if (data) {
			returnValue = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			[returnValue autorelease];
		}
		else if (errorDescription) NSLog(errorDescription);
	NS_HANDLER
	NS_ENDHANDLER
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• plistForString
// ---------------------------------------------------------------------------------
id plistForString(NSString* inString)
{
	id returnValue = nil;
	NSData* data;
	NSPropertyListFormat format;
	NSString* errorDescription = nil;
	
	NS_DURING
		data = [inString dataUsingEncoding:NSUTF8StringEncoding];
		returnValue = [NSPropertyListSerialization propertyListFromData:data
			mutabilityOption:NSPropertyListImmutable
			format:&format
			errorDescription:&errorDescription];
		
		if (errorDescription) NSLog(errorDescription);
	NS_HANDLER
	NS_ENDHANDLER
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	• mutablePlistForString
// ---------------------------------------------------------------------------------
id mutablePlistForString(NSString* inString)
{
	id returnValue = nil;
	NSData* data;
	NSPropertyListFormat format;
	NSString* errorDescription = nil;
	
	NS_DURING
		data = [inString dataUsingEncoding:NSUTF8StringEncoding];
		returnValue = [NSPropertyListSerialization propertyListFromData:data
			mutabilityOption:kCFPropertyListMutableContainers
			format:&format
			errorDescription:&errorDescription];
		
		if (errorDescription) NSLog(errorDescription);
	NS_HANDLER
	NS_ENDHANDLER
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• filenamesAtPathOfType
// ---------------------------------------------------------------------------------
NSMutableArray *filenamesAtPathOfType(NSString *path, NSString* type)
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator* en;
	NSString* fileName;
	NSMutableArray* list = [[[NSMutableArray alloc] init] autorelease];
	
	// look for files of matching type
	en = [fm enumeratorAtPath:path];
	while (fileName = [en nextObject]) {
		if ([fileName hasPrefix:@"."]) continue;
		if (!type || [[fileName pathExtension] isEqualTo:type]) [list addObject:fileName];
	}
	return list;
}

// ---------------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------------
