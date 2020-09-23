//
//  AddressScanWindowC.h
//  IPNetMonitorX
//
//  Created by psichel on Fri Feb 01 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.

#import <Cocoa/Cocoa.h>
#import <AppKit/NSWindowController.h>
#import "PSServerInterface.h"
@class PsClient;
@class IPLookupController;
@class PSURL;

@interface AddressScanWindowC : NSWindowController
{
    IBOutlet NSButton *scanButton;
    IBOutlet NSPopUpButton *scanType;
    IBOutlet NSPopUpButton *scanProtocol;
	IBOutlet NSPopUpButton *selectRetryLimit;
	IBOutlet NSTextField *selectRetryLabel;
    IBOutlet NSPopUpButton *selectServicePopUp;
	IBOutlet NSButton* continuousScan;
    IBOutlet NSButton* listAll;
    IBOutlet NSTextField *startTime;
    IBOutlet NSTextField *statusInfo;
    IBOutlet NSTableView *tableView;
	IBOutlet NSScrollView *scrollView;
    IBOutlet NSComboBox *targetField;

    IBOutlet NSTextField *sentInfo;
    IBOutlet NSTextField *receivedInfo;
    IBOutlet NSTextField *lostInfo;
    IBOutlet NSTextField *minInfo;
    IBOutlet NSTextField *aveInfo;
    IBOutlet NSTextField *maxInfo;
	IBOutlet NSTextField *latencyInfo;
    IBOutlet NSTextField *seenLabel;
	IBOutlet NSTextField *seenInfo;
	// logging
	IBOutlet NSDrawer   *logDrawer;
    IBOutlet NSTextView *logTextView;
	IBOutlet NSScrollView *logScrollView;
    
    BOOL		mRequestInProgress;
	BOOL		mGetNamesInProgress;
    PsClient*	mClient;
    int			mScanType;
    // name lookup
    IPLookupController* mLookupController;
    NSTimer*	mLookupTimer;
    NSMutableArray*	mLocalAddresses;
	NSMutableArray* mLocalHardware;
	NSString* mLocalHosts;
}

- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignKey:(NSNotification *)aNotification;
- (IBAction)selectType:(id)sender;
- (void)editingEnabled:(BOOL)flag;
- (IBAction)selectProtocol:(id)sender;
- (IBAction)selectRetryLimit:(id)sender;
- (IBAction)continuousScan:(id)sender;
- (IBAction)selectService:(id)sender;
- (void)copy:(id)sender;
#ifdef IPNetMonitor
- (void)doubleAction:(id)sender;
#endif
- (BOOL)setFields:(NSDictionary *)aDictionary;
- (void)invokeWithURL:(NSString *)inString;
- (IBAction)scan:(id)sender;
- (void)scanWithURL:(NSString *)inString;
- (BOOL)requestInProgress;
// name lookup
- (void)getNames:(id)timer;
- (void)lookupCompleted:(NSNotification *)aNotification;
// log drawer and help
- (void)appendString:(NSString *)string;
- (IBAction)logDrawer:(id)sender;
- (IBAction)myHelp:(id)sender;
// history menu
- (void)historyAdd:(id)sender;
- (void)historyAddFavorite:(id)sender;
- (void)historyRemove:(id)sender;
- (void)historyClear:(id)sender;
- (void)historyClearFavorites:(id)sender;
// save url
- (void)saveDocument:(id)sender;
- (void)saveDocumentAs:(id)sender;
- (NSString *)testResultTitle;
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
// PsClient
- (void)receiveDictionary:(NSDictionary *)dictionary;
@end

#define kAddressScanName		@"AddressScan"
#define kAddressScan_scanType	@"AddressScan_scanType"
#define kAddressScan_scanProtocol	@"AddressScan_scanProtocol"
#define kAddressScan_retryLimit	@"AddressScan_retryLimit"
#define kAddressScan_continuousScan	@"AddressScan_continuousScan"
#define kAddressScan_listAll	@"AddressScan_listAll"
#define kAddressScan_target	@"AddressScan_target"
#define kAddressScan_open	@"AddressScan_open"
