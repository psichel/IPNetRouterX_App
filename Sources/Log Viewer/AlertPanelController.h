#import <Cocoa/Cocoa.h>

@interface AlertPanelController : NSWindowController
{
    IBOutlet NSTextField* alertTextField;
	NSString* address;
	NSDate* lastSound;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)dismiss:(id)sender;
- (void)showLog:(id)sender;
- (void)whoisButton:(id)sender;
- (void)traceButton:(id)sender;
- (void)triggerButton:(id)sender;
- (void)setAlertText:(NSString *)text;
- (void)setAddress:(NSString *)value;
- (void)setLastSound:(NSDate *)value;
@end

#define kAlertPanelName	@"AlertPanel"
#define kAlertPanel_open		@"AlertPanel_open"
