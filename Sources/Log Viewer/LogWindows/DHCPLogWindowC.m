#import "DHCPLogWindowC.h"
#import "DHCPLogger.h"
#import "PSSharedDictionary.h"
#import "PSURL.h"

@implementation DHCPLogWindowC

- (void)awakeFromNib {
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
    [outputText setRichText:NO];
	// display existing text if any
	[outputText setString:[[DHCPLogger sharedInstance] string]];
	// setup to receive Event Log messages
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(receiveNotification:)
		name:DHCPLoggerNotification
		object:[DHCPLogger sharedInstance]
		];
    // restore settings
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kDHCPLogName];
    // remember settings
    // release ourself
    [self autorelease];
}

- (void)receiveNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;

	dictionary = [aNotification userInfo];
	[self appendString:[dictionary objectForKey:DHCPLoggerNotification]];
}

#define END_RANGE NSMakeRange([[outputText string]length],0)
- (void)appendString:(NSString *)inString
{
    [outputText replaceCharactersInRange:END_RANGE withString:inString];
	// scroll for update
	{
		NSRect bounds;
		NSRect visible;
		bounds = [[scrollView documentView] bounds];
		visible = [scrollView documentVisibleRect];
		if (visible.origin.y+visible.size.height+20 >= bounds.size.height) {
			[outputText scrollRangeToVisible:END_RANGE];
		}
	}
    // scroll to make new text visible
//    if ([[outputText window] isVisible]) {
//		[outputText scrollRangeToVisible:END_RANGE];
//    }
	//[outputText setNeedsDisplay:YES];
}

// ---------------------------------------------------------------------------
// ¥ historyClear
// ---------------------------------------------------------------------------
// clear previous log window contents, does not affect log file
- (void)historyClear:(id)sender
{
	// release existing text if any
	[outputText setString:@""];
}

@end
