#import <Cocoa/Cocoa.h>
#import "PSServerInterface.h"
@class PsClient;

@interface LookupWindowC : NSWindowController
{
    IBOutlet NSComboBox* lookupField;
    IBOutlet NSTextView* resultField;
    IBOutlet NSTextView* verificationField;
	IBOutlet NSTextField* elapsedInfo;
    IBOutlet NSTextField* statusInfo;
    IBOutlet NSButton* testButton;
    
    PsClient*		mClient;
	BOOL			mRequestInProgress;
    int				mVerification;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (BOOL)setFields:(NSDictionary *)aDictionary;
- (NSString *)setURL:(NSString *)inString;
- (NSString *)URL;
- (IBAction)lookup:(id)sender;
- (void)lookupWithURL:(NSString *)inString;
- (IBAction)flushcache:(id)sender;
- (IBAction)showDNS:(id)sender;
- (BOOL)requestInProgress;
- (void)testComplete;
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

#define kLookupName	@"Lookup"
#define kLookup_open @"Lookup_open"
#define kLookupWC_target @"Lookup_target"

