//
//  AppDelegate.h
//  IPNetX
//
//  Created by psichel on Sun Aug 19 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Delegate of NSApplication used invoke startup processing
#import <Cocoa/Cocoa.h>
#import "AppSupport.h"
@class MenuDispatch;
@class RegSupport;

// global Mac OS X startup item flag
extern int gStartupItem;


@interface AppDelegate : NSObject
{
	MenuDispatch* menuDispatch;
	RegSupport* regSupport;
    
	NSMutableDictionary* prefs;
    BOOL readPrefsCompleted;
	BOOL authorizationCompleted;
}
+ (AppDelegate *)sharedInstance;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void)applicationWillTerminate:(NSNotification *)notification;
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
- (void)startupItemFail:(NSString *)reason;
- (IBAction)myHelp:(id)sender;
- (IBAction)readMe:(id)sender;
- (IBAction)license:(id)sender;
- (IBAction)releaseNotes:(id)sender;
- (IBAction)feedback:(id)sender;
- (IBAction)checkForUpdate:(id)sender;
// read/write prefs
- (NSMutableDictionary*)prefs;
- (void)setPrefs:(NSMutableDictionary*)value;
- (BOOL)readPrefs;
- (BOOL)writePrefs;
// authorization
- (BOOL)authorizationCompleted;
- (IBAction)unloadNKE:(id)sender;
- (int)doUnloadNKE;
- (int)authorizeTools:(id)sender;
// Save and Restore Documents
- (IBAction)saveDocument:(id)sender;
- (IBAction)saveDocumentAs:(id)sender;
- (IBAction)revertDocumentToSaved:(id)sender;

@end
