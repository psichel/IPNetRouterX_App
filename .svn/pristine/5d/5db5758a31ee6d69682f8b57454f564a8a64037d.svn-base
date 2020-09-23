#import "RegistrationWindowM.h"
#import "RegistrationController.h"

@implementation RegistrationWindowM

- (IBAction)showWindow:(id)sender
{
    // show/edit registration data
    RegistrationController *registrationController;
    NSEnumerator* en;
    NSWindow* window;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[RegistrationController class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        registrationController = [RegistrationController alloc];
        registrationController = [registrationController initWithWindowNibName:kRegistrationName owner:registrationController];
        if (registrationController) {
            [[registrationController window] setFrameUsingName:kRegistrationName];
            [[registrationController window] makeKeyAndOrderFront:sender];
        }
    }
}

@end
