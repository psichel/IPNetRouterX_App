#import "AdministratorsWC.h"

@implementation AdministratorsWC
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
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self autorelease];
}

- (IBAction)newButton:(id)sender
{
}

// ---------------------------------------------------------------------------------
//	¥ editButton
// ---------------------------------------------------------------------------------
- (IBAction)editButton:(id)sender
{
	// display edit sheet view
	[NSApp beginSheet:editPanel modalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}


- (IBAction)deleteButton:(id)sender
{
}

- (IBAction)doneButton:(id)sender
{
}

// edit sheet
- (IBAction)editSaveButton:(id)sender
{
	[editPanel close];
	[NSApp endSheet:editPanel];
}

- (IBAction)editCancelButton:(id)sender
{
	[editPanel close];
	[NSApp endSheet:editPanel];
}


@end
