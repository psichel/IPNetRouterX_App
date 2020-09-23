#import "ConnectToServerWC.h"

@implementation ConnectToServerWC
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
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self autorelease];
}

- (IBAction)Cancel:(id)sender
{
	[self close];
}

- (IBAction)Connect:(id)sender
{
	[self close];
}

@end
