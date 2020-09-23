#import "AlertPanelController.h"
#import "SentryLogger.h"
#import "SentryDocument.h"
#import "NSDate_Extensions.h"
#import "PSURL.h"
#import "MenuDispatch.h"
// add trigger
#import "SentryModel.h"
#import "SentryState.h"
#import "TriggerTable.h"
#import "TriggerEntry.h"

@implementation AlertPanelController

- (void)awakeFromNib {
    lastSound = nil;
	address = nil;
	[[self window] setLevel:NSStatusWindowLevel];
	// restore settings
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kAlertPanelName];
    // remember settings
    // release ourself
	[self setLastSound:nil];
	[self setAddress:nil];
    [self autorelease];
}

- (void)dismiss:(id)sender
{
	[self close];
}

// ---------------------------------------------------------------------------
//	¥ showLog
// ---------------------------------------------------------------------------
- (void)showLog:(id)sender
{
	[[MenuDispatch sharedInstance] sentryLogShowWindow:self];
}


// ---------------------------------------------------------------------------
//	¥ whoisButton
// ---------------------------------------------------------------------------
- (void)whoisButton:(id)sender
{
	NSURL* url;
	BOOL result;
	if (address) {
		url = [NSURL URLWithString:[NSString stringWithFormat:
			@"whois://%@@whois.arin.net",address]];
		result = [[NSWorkspace sharedWorkspace] openURL:url];
		if (!result) {
			NSString* text;
			text = [NSString stringWithFormat:@"This feature requires a helper application like IPNetMonitorX to handle URLs of the form whois://%@.",address];
			NSRunAlertPanel(PS_PRODUCT_NAME,
				text,
				@"OK",
				nil,
				nil);
		}
	}
}

// ---------------------------------------------------------------------------
//	¥ traceButton
// ---------------------------------------------------------------------------
- (void)traceButton:(id)sender
{
	NSURL* url;
	BOOL result;
	if (address) {
		url = [NSURL URLWithString:[NSString stringWithFormat:
			@"traceroute://%@",address]];
		result = [[NSWorkspace sharedWorkspace] openURL:url];
		if (!result) {
			NSString* text;
			text = [NSString stringWithFormat:@"This feature requires a helper application like IPNetMonitorX to handle URLs of the form traceroute://%@.",address];
			NSRunAlertPanel(PS_PRODUCT_NAME,
				text,
				@"OK",
				nil,
				nil);
		}
	}	
}

// ---------------------------------------------------------------------------
//	¥ triggerButton
// ---------------------------------------------------------------------------
- (void)triggerButton:(id)sender
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	TriggerEntry* entry = [[[TriggerEntry alloc] init] autorelease];
	TriggerEntry* foundEntry;

	// create trigger entry, add to trigger table in active SentryState, send as message to NKE
	[entry setIpAddress:address];
	[entry setType:[NSNumber numberWithInt:kTriggerTypeTrigger]];
	[entry setLastTime:[NSDate date]];
	[entry setDuration:[sentryState triggerDuration]];
	// check if there's already a matching entry
	foundEntry = [[sentryState triggerTable] objectForKey:entry];
	if (!foundEntry) {
		// add to table
		[[sentryState triggerTable] insertObject:entry];
		// send to NKE
		[[SentryModel sharedInstance] downloadTriggerEntry:entry];
	}
}

// ---------------------------------------------------------------------------
//	¥ setAlertText
// ---------------------------------------------------------------------------
- (void)setAlertText:(NSString *)text
{
	[alertTextField setStringValue:text];
	if (!lastSound) {
		[self setLastSound:[NSDate psDate]];
		NSBeep();
	}
	if ([lastSound timeIntervalSinceNow] < -3) {
		[self setLastSound:[NSDate psDate]];
		NSBeep();
	}
}

// ---------------------------------------------------------------------------
//	¥ setLastSound
// ---------------------------------------------------------------------------
- (void)setLastSound:(NSDate *)value
{
	[value retain];
	[lastSound release];
	lastSound = value;
}

// ---------------------------------------------------------------------------
//	¥ setAddress
// ---------------------------------------------------------------------------
- (void)setAddress:(NSString *)value
{
	[value retain];
	[address release];
	address = value;
}
@end
