//
//  AppSupport.m
//  IPNetX
//
//  Created by Peter Sichel on 3-Dec-2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Application Support methods for accessing AppSupport files.

#import "AppSupport.h"
#import "IPICMPSocket.h"		// OpenICMP
#if !BUILD_AS_HELPER_TOOL
#import "Authorization.h"
#endif
#import <syslog.h>

// global system version info obtained during app startup
extern int gStartupItem;
extern int gMajorVersion, gMinorVersion, gMinorMinorVersion;

NSString *gStartupAuthContext = @"You must have Administrator privileges to complete the installation process.";

// Module wide
static BOOL newHelperTools = NO;
static BOOL useHomeDirForSupportSustworks = NO;
static BOOL useHomeDirForPreferences = NO;
static BOOL keepPrefsInFolder = YES;
static int ignoreSig = 0;


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
//	• initAppSupportFolderNamed
// ---------------------------------------------------------------------------------
// Make sure we have a named folder and preload it with our default presets
+ (NSString *)initAppSupportFolderNamed:(NSString *)inName
{
	NSString* dst;
	NSString* resourcePath;
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL result = YES;
	
	dst = [self appSupportFolder];
	dst = [dst stringByAppendingPathComponent:inName];
	// does it exist
	if (![fm fileExistsAtPath:dst]) {
		result = [fm createDirectoryAtPath:dst attributes:nil];
		if (!result) {
			// copy our resource
			resourcePath = [[NSBundle mainBundle] pathForResource:inName ofType:nil];
			result = [self copyPath:resourcePath toPath:dst];
		}
	}
	return dst;
}

// ---------------------------------------------------------------------------------
//	• updateAppSupportFolderNamed:
// ---------------------------------------------------------------------------------
// Copy individual files to update named folder in Application Support folder
+ (void)updateAppSupportFolderNamed:(NSString *)inName
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
	dst = [dst stringByAppendingPathComponent:inName];
	resourcePath = [[NSBundle mainBundle] pathForResource:inName ofType:nil];
	list = [fm directoryContentsAtPath:resourcePath];
	en = [list objectEnumerator];
	while (name = [en nextObject]) {
		srcPath = [resourcePath stringByAppendingPathComponent:name];
		dstPath = [dst stringByAppendingPathComponent:name];
		result = [self copyPath:srcPath toPath:dstPath];
	}
}


// ---------------------------------------------------------------------------------
//	• anotherAppSupportFolderNamed
// ---------------------------------------------------------------------------------
// Is there another AppSupport folder in ~/L/AS/.. with the name given
+ (NSString *)anotherAppSupportFolderNamed:(NSString *)inName
{
	NSString* path;
	NSFileManager* fm = [NSFileManager defaultManager];
	
	path = [self appSupportFolder];
	if ([path hasPrefix:@"/Library"]) {
		path = [NSString stringWithFormat:@"~%@",path];
		path = [path stringByExpandingTildeInPath];
		path = [path stringByAppendingPathComponent:inName];
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
	
	path = kAppSupportFolderPath;
	if (![fm fileExistsAtPath:path isDirectory:&result]) {
		#if BUILD_AS_HELPER_TOOL
			[self helperToolFail:@"/Library/Application Support/<app-name>/ does not exist."];
		#else
			int authResult = 0;
			result = [fm createDirectoryAtPath:path attributes:nil];
			if (!result) do {
				// failed to create folder, try using our authorize tool
				if ([[Authorization sharedInstance] doAuthorization:gStartupAuthContext]) {
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
		#endif
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
	NSString *path1, *path2;	
	NSFileManager* fm = [NSFileManager defaultManager];
	
	// shared location /Library/Application Support/
	path1 = kAppSupportSustworksPath;
	path1 = [path1 stringByAppendingPathComponent:name];
	
	// check users home directory as well
	path2 = [NSString stringWithFormat:@"~%@",path1];
	path2 = [path2 stringByExpandingTildeInPath];
	
	// use homedir first if found
	if ([fm fileExistsAtPath:path2]) return path2;
	if ([fm fileExistsAtPath:path1]) return path1;
	return nil;
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
	
	path = [self appSupportFolder];
	path = [path stringByAppendingPathComponent:kAppHelperToolsFolder];
	// does it exist
	if (![fm fileExistsAtPath:path]) {
		newHelperTools = YES;
		#if BUILD_AS_HELPER_TOOL
			[self helperToolFail:@"/Library/Application Support/<app-name>/HelperTools/ does not exist."];
		#else
			BOOL status = YES;
			int authResult = 0;
			status = [fm createDirectoryAtPath:path attributes:nil];
			if (!status) do {
				// failed to create folder, try using our authorize tool
				if ([[Authorization sharedInstance] doAuthorization:gStartupAuthContext]) {
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
		#endif
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
//	• checkTool:
// ---------------------------------------------------------------------------------
// check for named tool, if not, try to restore from app bundle    
// return 181 for identify confirmed, needs athorization
// return -3 for copy failed, permission denied
+ (int)checkTool:(NSString *)name
{
    NSString* path;
    int result;

	#if BUILD_AS_HELPER_TOOL
		// get path to our tool
		path = [self helperToolPath:name];
		// check if it exists
		NSFileManager* fm = [NSFileManager defaultManager];
		if ([fm fileExistsAtPath:path]) result = 0;
		else result = -1;
	#else
		// Check tool versions and copy named tool from app bundle to HelperTools folder if needed
		NSString* resourcePath;
		resourcePath = [self bundleToolPath:name];
		result = [self getHelperToolFromPath:resourcePath outPath:&path];
		sync();
	#endif
	if (result >= 0) {
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
    NSFileManager* fm = [NSFileManager defaultManager];
	NSDictionary* sourceAttribute;
    int result = 0;
    
	#if BUILD_AS_HELPER_TOOL
		// get path to our tool
		path = [self helperToolPath:name];
		// check if it exists
		if ([fm fileExistsAtPath:path]) result = 0;
		else result = -1;
	#else
		// Check tool versions and copy named tool from app bundle to HelperTools folder if needed
		NSString* resourcePath;
		resourcePath = [self bundleToolPath:name];
		result = [self getHelperToolFromPath:resourcePath outPath:&path];
	#endif
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
	result = [AppSupport validateSignedCodeAtPath:path];
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
	
	@try {
		result = [self doPipedTask:path arguments:[NSArray arrayWithObject:@"-identify"]
			output:fp];
	}
	@catch( NSException *theException ) {
			// might fail if user not in admin group
			result = EPERM;
	}
	#if 0
	if (result == 0) {  // if tool says it is already root
		// check for SUID root attribute
		NSUInteger permissions;
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

#if !BUILD_AS_HELPER_TOOL
// ---------------------------------------------------------------------------------
//	• getHelperToolFromPath: outPath:(NSString **)outPath
// ---------------------------------------------------------------------------------
// Check tool versions and copy named tool from app bundle to HelperTools folder if needed
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
		NSString* helperToolsPath = [self initAppHelperToolsFolder];
		dest = [helperToolsPath stringByAppendingPathComponent:kHelperToolsVersionPlist];
		resourcePath = [[NSBundle mainBundle] pathForResource:kHelperToolsVersion ofType:@"plist"];
		if (![fm fileExistsAtPath:dest]) {
			// No previous HelperToolsVersion.plist found, assume versions do not match
			versionMatch = NO;
			if (!newHelperTools) [self remove:helperToolsPath];	// remove old HelperTools folder
		}
		else {
			// check whether tool versions match
			NSDictionary *resourceD = [NSDictionary dictionaryWithContentsOfFile:resourcePath];
			NSDictionary *toolD = [NSDictionary dictionaryWithContentsOfFile:dest];
			NSString *resourceStr = [resourceD objectForKey:kToolBuildNumber];
			NSString *toolStr = [toolD objectForKey:kToolBuildNumber];
			if ([resourceStr isEqualTo:toolStr]) versionMatch = YES;
			else {
				versionMatch = NO;
				[self remove:helperToolsPath];	// remove old HelperTools folder
			}
		}

		// get desired path to our tool
		name = [inPath lastPathComponent];
		dest = [self toolPathForName:name fileExists:&fileExists];
		// if not found, try to copy from inPath (typically app bundle)
		if (!fileExists) {
			// does original exist
			if (![fm fileExistsAtPath:inPath]) {
				[Authorization reinstall:name];
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
//	• remove:
// ---------------------------------------------------------------------------------
// Try to remove a file path using NSFileManager, but if that fails (insufficient privs),
// fallback to using our authorize tool and wait for removal to complete.
+ (BOOL)remove:(NSString *)inPath
{
	BOOL status = NO;
	int authResult = 0;
	NSFileManager* fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:inPath]) {
		// try to remove using FM
		status = [fm removeFileAtPath:inPath handler:nil];
		if (!status) {
			// first try failed, try using our authorize tool
			if ([[Authorization sharedInstance] doAuthorization:gStartupAuthContext]) {
				NSArray *authorizeList = [NSArray arrayWithObject:inPath];
				authResult = [[Authorization sharedInstance] authorize:authorizeList withCommand:@"-remove"];
				if (authResult == 0) status = YES;
				else NSLog(@"Authorize tool failed to remove %@",inPath);
			}
			else {
				NSLog(@"Authorization failed while trying to remove %@",inPath);
			}
			if (status) {
				// wait for it
				BOOL keepWaiting;
				int count = 0;
				do {
					keepWaiting = NO;
					if ([fm fileExistsAtPath:inPath]) {
						keepWaiting = YES;
						count += 1;
						[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
					}
				} while (keepWaiting && (count < 20));
				//NSLog(@"remove path wait count %d",count);
			}
		}
	}
	return status;
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
		if ([[Authorization sharedInstance] doAuthorization:nil]) {
			NSArray *authorizeList = [NSArray arrayWithObjects:fromPath, toPath, nil];
			authResult = [[Authorization sharedInstance] authorize:authorizeList withCommand:@"-copy"];
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
#endif

// ---------------------------------------------------------------------------------
//	• helperToolFail
// ---------------------------------------------------------------------------------
// do not allow application to proceed if launched as a Helper Tool
+ (void)helperToolFail:(NSString *)reason
{
#if BUILD_AS_HELPER_TOOL
	NSLog(@"%@ This helper tool may not be used until First Run Authentication has completed.",PS_PRODUCT_NAME);	
	syslog(LOG_NOTICE, "%s", [reason UTF8String]);
	// force program to exit
	exit(1);
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

#pragma mark -- code signing --
// ---------------------------------------------------------------------------------
//	• validateSignedCodeAtPath:
// ---------------------------------------------------------------------------------
+ (int)validateSignedCodeAtPath:(NSString *)inPath
{
	int result = 0;
	NSString* toolPath;
	
	// don't try this on Tiger or if launched as startup item
	if ( !((gMajorVersion == 10) && (gMinorVersion < 5)) && (!ignoreSig)
//		&& (!gStartupItem) 
	) {
		// make sure we have read access before attempting validation
		NSFileManager* fm = [NSFileManager defaultManager];
		int retry = 3;
		while (![fm isReadableFileAtPath:inPath] && (retry > 0)) {
			// pause and try again
			retry -= 1;
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];
		}
		if (retry <= 0) return -EPERM;
        // run tool to validate signature
		// 0 = all tests passed
		// 1 = failed to satisfy code requirements
		// 2 = parameter error
        toolPath = @"/usr/bin/codesign";
        result = [AppSupport doTask:toolPath arguments:[NSArray arrayWithObjects:
			@"-v",
            @"-R=certificate leaf H\"c9a6d793fe9c80c4b040053fa5b5e8c134e540ab\"",
            inPath,
            nil] output:nil];
		if ((result != 0) && (!ignoreSig)) {
			#if BUILD_AS_HELPER_TOOL
				NSString *text = [NSString stringWithFormat:@"Unable to validate the code signature for helper tool: %@", inPath];
				[self helperToolFail:text];
			#else
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
					dest = [[AppSupport initAppHelperToolsFolder] stringByAppendingPathComponent:kHelperToolsVersionPlist];
					[fm removeFileAtPath:dest handler:nil];
					// terminate app
					[NSApp terminate:self];
				}
			#endif
		}
	}
	return result;
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
+ (int)doTask:(NSString *)path arguments:(NSArray *)args input:(NSString *)input output:(NSString **)output error:(NSString **)error
    // run a unix command line tool
    // args is an array of NSStrings, one argument per element
    // input is an NSString of text sent to stdin
    // returns output as NSString
{
    int returnValue=0;
    NSData* data = nil;
    NSTask *theTask;	
    NSPipe* standardInputPipe;
    NSPipe* standardOutputPipe;
    NSPipe* standardErrorPipe;
    NSFileHandle* standardInputHandle = nil;
    NSFileHandle* standardOutputHandle = nil;
    NSFileHandle* standardErrorHandle = nil;

    theTask = [[NSTask alloc] init];
	[theTask setLaunchPath:path];
	if (input) {
		standardInputPipe = [NSPipe pipe];
		standardInputHandle = [standardInputPipe fileHandleForWriting];
        data = [input dataUsingEncoding:NSUTF8StringEncoding];
        [standardInputHandle writeData:data];
        [standardInputHandle closeFile];	// signal end of file to tool        
        [theTask setStandardInput:standardInputPipe];
	}
	if (output) {
		standardOutputPipe = [NSPipe pipe];
		standardOutputHandle = [standardOutputPipe fileHandleForReading];
		[theTask setStandardOutput:standardOutputPipe];
	}
	if (error) {
		standardErrorPipe = [NSPipe pipe];
		standardErrorHandle = [standardErrorPipe fileHandleForReading];
		[theTask setStandardError:standardErrorPipe];
	}
	if (args) [theTask setArguments:args];
	[theTask launch];
	if (output) {
		int result = 0;
		NSData *data;
		NSString *str;
		NSMutableString *outputString = [NSMutableString string];
		while (result >= 0) {
			// block waiting for data if any
			data = nil;
			result = readFileHandle(standardOutputHandle, &data);
			if ([data length] != 0) {
				str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				[outputString appendString:str];
				[str release];
			}
		}
		*output = outputString;
	}
    [theTask waitUntilExit];
    returnValue = [theTask terminationStatus];
    [theTask release];
	if (error) {
		data = [standardErrorHandle readDataToEndOfFile];
		if ( (data != nil) && ([data length] != 0) ) {
			NSString *errorString;
			errorString = [[[NSString alloc]initWithData:data
				encoding:NSUTF8StringEncoding] autorelease];
			*error = errorString;
		}
	}
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	• doPipedTask:arguments:output
// ---------------------------------------------------------------------------------
+ (int)doPipedTask:(NSString *)path arguments:(NSArray *)args output:(id)output
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
			// don't block indefinitely
			[theTask performSelector:@selector(terminate) withObject:nil afterDelay:10];
		[theTask waitUntilExit];
		returnValue = [theTask terminationStatus];
			// cancel pending performSelector if needed
			[[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:theTask];
	}
	@catch( NSException *theException ) {
		NSLog(@"Exception during AppSupport.m +doTask: %@, reason: %@",path,[theException reason]);
		returnValue = -1;
	}
    [theTask release];
    
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
	
	@try {
		data = [NSPropertyListSerialization dataFromPropertyList:inPlist
			format:NSPropertyListXMLFormat_v1_0
			errorDescription:&errorDescription];
		
		if (data) {
			returnValue = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			[returnValue autorelease];
		}
		else if (errorDescription) NSLog(@"%@", errorDescription);
	}
	@catch( NSException *theException ) {
		NSLog(@"Exception during stringForPlist");
	}
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
	
	@try {
		data = [inString dataUsingEncoding:NSUTF8StringEncoding];
		returnValue = [NSPropertyListSerialization propertyListFromData:data
			mutabilityOption:NSPropertyListImmutable
			format:&format
			errorDescription:&errorDescription];
		
		if (errorDescription) {
			NSLog(@"%@", errorDescription);
			[errorDescription release];
		}
	}
	@catch( NSException *theException ) {
		NSLog(@"Exception during plistForString");
	}
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
	
	@try {
		data = [inString dataUsingEncoding:NSUTF8StringEncoding];
		returnValue = [NSPropertyListSerialization propertyListFromData:data
			mutabilityOption:kCFPropertyListMutableContainers
			format:&format
			errorDescription:&errorDescription];
		
		if (errorDescription) {
			NSLog(@"%@", errorDescription);
			[errorDescription release];
		}
	}
	@catch( NSException *theException ) {
		NSLog(@"Exception during mutablePlistForString");
	}
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
