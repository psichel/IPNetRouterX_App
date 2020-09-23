#import <Cocoa/Cocoa.h>

@interface SentryLogWindowC : NSWindowController
{
    IBOutlet NSTextView* outputText;
	IBOutlet NSScrollView *scrollView;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)receiveNotification:(NSNotification *)aNotification;
- (void)appendString:(NSString *)string;
- (void)historyClear:(id)sender;
@end

#define kSentryLogName		@"SentryLog"
#define kSentryLog_open		@"SentryLog_open"
