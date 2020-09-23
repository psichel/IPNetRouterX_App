#import <Cocoa/Cocoa.h>

@interface DHCPLogWindowC : NSWindowController
{
    IBOutlet NSTextView* outputText;
	IBOutlet NSScrollView *scrollView;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)receiveNotification:(NSNotification *)aNotification;
- (void)appendString:(NSString *)string;
- (void)historyClear:(id)sender;
@end

#define kDHCPLogName		@"DHCPLog"
#define kDHCPLog_open		@"DHCPLog_open"
