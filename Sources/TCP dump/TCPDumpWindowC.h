#import <Cocoa/Cocoa.h>
#import "PSServerInterface.h"
@class PsClient;

#define preferences [NSUserDefaults standardUserDefaults]

@interface TCPDumpWindowC : NSWindowController
{
    IBOutlet NSPopUpButton* portMenu;
	IBOutlet NSButton* useTCPFlowCheckBox;
    IBOutlet NSComboBox* options;
    IBOutlet NSButton* startButton;
    IBOutlet NSTextView* outputText;
	IBOutlet NSScrollView *scrollView;
    IBOutlet NSTextField* statusInfo;
    
    BOOL			mRequestInProgress;
    PsClient*		mClient;
    int				mPid;
	int				mFd;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (IBAction)useTCPFlow:(id)sender;
- (IBAction)monitor:(id)sender;
- (BOOL)requestInProgress;
- (void)testComplete;
- (void)appendString:(NSString *)string newLine:(BOOL)newLine;
- (IBAction)myHelp:(id)sender;
// history menu
- (void)historyAdd:(id)sender;
- (void)historyAddFavorite:(id)sender;
- (void)historyRemove:(id)sender;
- (void)historyClear:(id)sender;
- (void)historyClearFavorites:(id)sender;
- (void)receiveDictionary:(NSDictionary *)dictionary;
@end

#define kTCPDumpName	@"TCPDump"
#define kTCPDump_portMenu @"TCPDump_portMenu"
#define kTCPDump_useTCPFlow @"TCPDump_useTCPFlow"
#define kTCPDump_options @"TCPDump_options"
#define kTCPDump_open @"TCPDump_open"
