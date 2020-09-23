#import "UpgradeController.h"
#import "AppDelegate.h"
#import "PSSupport.h"

@implementation UpgradeController
- init
{
    if (self = [super init]) {
        // initialize instance vars
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
    [super dealloc];
}
- (void)awakeFromNib
{
	[self retain];	// Retain ourself so caller can release reference.  Released in windowWillClose;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self autorelease];
}

// ---------------------------------------------------------------------------------
//	• upgrade
// ---------------------------------------------------------------------------------
- (IBAction)upgrade:(id)sender
{
    [NSApp stopModal];
	[self close];
	// send browser to registration page
	NSURL *regURL;
#if IPNetRouter
	regURL = [NSURL URLWithString:@"http://www.sustworks.com/site/reg.html#ipnetrouterx_upgrade"];
#else
	regURL = [NSURL URLWithString:@"http://www.sustworks.com/site/reg.html#ipnetsentryx_upgrade"];
#endif
	if (regURL) {
		[[NSWorkspace sharedWorkspace] openURL:regURL];
	}
}

// ---------------------------------------------------------------------------------
//	• notYet
// ---------------------------------------------------------------------------------
- (IBAction)notYet:(id)sender
{
    [NSApp stopModal];
    [self close];
}

// ---------------------------------------------------------------------------------
//	• releaseNotes
// ---------------------------------------------------------------------------------
- (IBAction)releaseNotes:(id)sender
{
	// send browser to registration page
	NSURL *regURL;
#if IPNetRouter
	regURL = [NSURL URLWithString:@"http://sustworks.com/site/prod_ipnrx_relnotes.html"];
#else
	regURL = [NSURL URLWithString:@"http://sustworks.com/site/prod_sentryx_relnotes.html"];
#endif
	if (regURL) {
		[[NSWorkspace sharedWorkspace] openURL:regURL];
	}
}

// ---------------------------------------------------------------------------------
//	• help
// ---------------------------------------------------------------------------------
- (IBAction)help:(id)sender {
	// point browser at help page
	NSURL *regURL;
#if IPNetRouter
	regURL = [NSURL URLWithString:@"http://www.sustworks.com/site/prod_ipnrx_help/html/RegistrationHelp.html"];
#else
	regURL = [NSURL URLWithString:@"http://www.sustworks.com/site/prod_sentryx_help/html/RegistrationHelp.html"];
#endif
	if (regURL) {
		[[NSWorkspace sharedWorkspace] openURL:regURL];
	}
}

// ---------------------------------------------------------------------------------
//	• setReleaseDate
// ---------------------------------------------------------------------------------
- (void)setReleaseDate:(NSString *)value
{
	if (value) [releaseDateField setObjectValue:value];
	else [releaseDateField setObjectValue:@""];
}

// ---------------------------------------------------------------------------------
//	• setRegisterDate
// ---------------------------------------------------------------------------------
- (void)setRegisterDate:(NSString *)value
{
	if (value) [registerDateField setObjectValue:value];
	else [registerDateField setObjectValue:@""];
}

// ---------------------------------------------------------------------------------
//	• setDiscount
// ---------------------------------------------------------------------------------
- (void)setDiscount:(NSString *)value
{
	if (value) {
		[discountLabel setHidden:NO];
		[discountCodeField setObjectValue:value];
	}
	else {
		[discountLabel setHidden:YES];
		[discountCodeField setObjectValue:@""];
	}
}

@end

// ---------------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------------
