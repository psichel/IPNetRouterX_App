#import <Cocoa/Cocoa.h>

@interface DemoController : NSWindowController
{
    IBOutlet NSTextField* expirationText;
    IBOutlet NSTextField* expirationDate;
    IBOutlet NSTextView* licenseText;
    IBOutlet NSTextView* registrationData;
    
    NSDate* date;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (IBAction)tryButton:(id)sender;
- (IBAction)buyButton:(id)sender;
- (IBAction)doNotAccept:(id)sender;
- (IBAction)help:(id)sender;
- (void)setDate:(NSDate *)value;
@end

#define kDemoName	@"Demo"