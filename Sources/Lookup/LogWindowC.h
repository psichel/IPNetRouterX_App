#import <Cocoa/Cocoa.h>

extern NSString *LoggerNotification;

@interface LogWindowC : NSWindowController
{
    IBOutlet NSTextView* outputText;
	IBOutlet NSScrollView *scrollView;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)receiveNotification:(NSNotification *)aNotification;
- (void)appendString:(NSString *)string;
- (void)historyClear:(id)sender;
- (void)setTitle:(NSString *)title;
@end

#define kLogName		@"Log"
#define kLog_open		@"Log_open"
