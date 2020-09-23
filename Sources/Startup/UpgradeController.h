#import <Cocoa/Cocoa.h>

@interface UpgradeController : NSWindowController
{
    IBOutlet NSTextField* releaseDateField;
    IBOutlet NSTextField* registerDateField;
	IBOutlet NSTextField* discountLabel;
	IBOutlet NSTextField* discountCodeField;

}
- (void)windowWillClose:(NSNotification *)aNotification;
- (IBAction)upgrade:(id)sender;
- (IBAction)notYet:(id)sender;
- (IBAction)releaseNotes:(id)sender;
- (IBAction)help:(id)sender;

- (void)setReleaseDate:(NSString *)value;
- (void)setRegisterDate:(NSString *)value;
- (void)setDiscount:(NSString *)value;
@end

#define kUpgradeName	@"Upgrade"
