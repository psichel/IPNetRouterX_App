//
//  AppSupport.h
//  IPNetX
//
//  Created by Peter Sichel on 3-Dec-2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Application Support methods for accessing AppSupport files.
//	Daemon safe (does not use window manager or AppKit) except for
//	Authorization, and re-install

#import <Cocoa/Cocoa.h>
// globals
extern NSString* ps_nke_name;		// run time name IPNetRouter_NKE
extern NSString* ps_kext_name;		// IPNetRouter_NKE.kext


@interface AppSupport : NSObject {
}
+ (AppSupport *)sharedInstance; // returns a shared instance of the class

// App Prefs Paths
+ (NSString *)appPrefsFile;
+ (NSString *)appPrefsFolder;
+ (NSString *)appPrefsPath:(NSString *)name;
+ (NSString *)initTunerDocumentsFolder;
+ (void)updateTunerDocumentsFolder;
+ (NSString *)tunerDocumentsFolder2;
// App Support Paths
+ (NSString *)appSupportFolder;
+ (NSString *)appSupportPath:(NSString *)name;
+ (NSString *)appSupportSustworksPath:(NSString *)name;
+ (NSString *)appSupportSustworksPathRO:(NSString *)name;
// Helper Tool Paths
+ (NSString *)initAppHelperToolsFolder;
+ (NSString *)helperToolPath:(NSString *)name;
+ (NSString *)bundleToolPath:(NSString *)name;
+ (NSString *)toolPathForName:(NSString *)name fileExists:(BOOL *)fileExists;
// Tool checking
+ (int)validateSignedCodeAtPath:(NSString *)inPath;
+ (int)checkTool:(NSString *)name;
+ (int)checkNKE:(NSString *)name;
+ (int)getHelperToolFromPath:(NSString *)inPath outPath:(NSString **)outPath;
+ (int)checkToolAuthorization:(NSString *)path;
+ (BOOL)copyPath:(NSString *)fromPath toPath:(NSString *)toPath;
+ (void)reinstall:(NSString *)name;
// migration
+ (NSString *)findAlternateFor:(NSString *)filename;
+ (BOOL)removeAlternatesFor:(NSString *)filename;
// authorization
+ (BOOL)doAuthorization;
+ (void)authorizationNotCompleted;
// do task
+ (int)doTask:(NSString *)path arguments:(NSArray *)args output:(id)output;
+ (int)doTask:(NSString *)path arguments:(NSArray *)args input:(NSString *)input output:(NSString **)output;
@end

// get a list of file names with extension of type
NSMutableArray *filenamesAtPathOfType(NSString *path, NSString* type);

// Convert between plists and strings using NSPropertyListSerialization
// to specify plist format
NSString* stringForPlist(id inPlist);
id plistForString(NSString* inString);
id mutablePlistForString(NSString* inString);


#if IPNetRouter
	#define kAppSupportFolderPath	@"/Library/Application Support/IPNetRouterX"
	#define kAppPrefsFolderPath		@"/Library/Preferences/IPNetRouterX"
	#define kPrefsFilePath			@"/Library/Preferences/com.sustworks.IPNetRouterX.prefs.plist"
	#define kPrefsFilename			@"com.sustworks.IPNetRouterX.prefs.plist"
	#define kSettingsFilename		@"com.sustworks.IPNetRouterX.ipnr"
#else
	#define kAppSupportFolderPath	@"/Library/Application Support/IPNetSentryX"
	#define kAppPrefsFolderPath		@"/Library/Preferences/IPNetSentryX"
	#define kPrefsFilePath			@"/Library/Preferences/com.sustworks.IPNetSentryX.prefs.plist"
	#define kPrefsFilename			@"com.sustworks.IPNetSentryX.prefs.plist"
	#define kSettingsFilename		@"com.sustworks.IPNetSentryX.nsy"
#endif
#define kAppSupportSustworksPath @"/Library/Application Support/Sustainable Softworks"
#define kAppHelperToolsFolder	@"HelperTools"
#define kTunerDocumentsFolder   @"Tuner Documents"
#define kTunerPresetsFolder		@"TunerPresets"
#define kHelperToolsVersion		@"HelperToolsVersion"
#define kHelperToolsVersionPlist @"HelperToolsVersion.plist"
#define kToolBuildNumber		@"Tool Build Number"
