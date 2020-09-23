#import "RegistrationController.h"
#import "RegSupport.h"

@interface RegistrationController (PrivateMethods)
- (void)displayRegInfo;
@end

@implementation RegistrationController
- init
{
    if (self = [super init]) {
        // initialize instance vars
		// use awakeFromNib
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	// use windowWillClose
    [super dealloc];
}

- (void)awakeFromNib
{
	NSString* str;
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];
	
	// display info
	[self displayRegInfo];
    str = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	[version setStringValue:str];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    NSWindow* theWindow;
    
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kRegistrationName];

    [self autorelease];
}

// ---------------------------------------------------------------------------------
//	¥ displayRegInfo
// ---------------------------------------------------------------------------------
- (void)displayRegInfo
{
    NSDictionary* regData;

    // read key file into dictionary
    regData = [[RegSupport sharedInstance] readRegistration];
    // display info
    if (regData) {
        [licenseName setStringValue:[regData objectForKey:kName]];
        [licenseOrganization setStringValue:[regData objectForKey:kOrganization]];
        [licenseCopies setStringValue:[regData objectForKey:kLicensedCopies]];
    }
}

// ---------------------------------------------------------------------------------
//	¥ windowDidBecomeKey
// ---------------------------------------------------------------------------------
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	int result;
	// check for key in Pasteboard
	if (![[RegSupport sharedInstance] isRegisteredOption:kOptionSkipDialog]) {
		result = [[RegSupport sharedInstance] checkPasteboardFromWindow:[self window]];
		if (result == kRegAccepted) [self displayRegInfo];
	}
}

// ---------------------------------------------------------------------------------
//	¥ registrationField
// ---------------------------------------------------------------------------------
- (IBAction)registrationField:(id)sender
{
	int result;
    result = [[RegSupport sharedInstance] doRegistrationInput:[registrationData stringValue]
		fromWindow:[self window] option:0];
	if (result == kRegAccepted) [self displayRegInfo];
}

// ---------------------------------------------------------------------------------
//	¥ applyButton
// ---------------------------------------------------------------------------------
- (IBAction)applyButton:(id)sender
{
	[self registrationField:sender];
}

// ---------------------------------------------------------------------------------
//	¥ cancelButton
// ---------------------------------------------------------------------------------
- (IBAction)cancelButton:(id)sender
{
	[[self window] performClose:sender];
}

// ---------------------------------------------------------------------------------
//	¥ buyButton
// ---------------------------------------------------------------------------------
- (IBAction)buyButton:(id)sender
{
	if ([[registrationData stringValue] length]) [self registrationField:sender];
	// direct user to registration page
	NSURL *regURL;
	if ((regURL = [NSURL URLWithString:@"http://www.sustworks.com/site/reg.html"])) {
		[[NSWorkspace sharedWorkspace] openURL:regURL];
	}
}

@end
