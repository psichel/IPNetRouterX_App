#import "PsClient.h"
#import "LookupWindowC.h"
#import "IPNMDocument.h"
#import "LookupServer.h"
#import "MenuDispatch.h"
#import "LogWindowC.h"
#import "AppSupport.h"
#import "PSSharedDictionary.h"
#import "PingHistory.h"
#import "PSSupport.h"
#import "PSURL.h"
#import "AppDelegate.h"

// global system version info obtained during app startup
extern int gMajorVersion, gMinorVersion, gMinorMinorVersion;

@implementation LookupWindowC

- (void)awakeFromNib {
	mRequestInProgress = NO;
    mVerification = 0;
    mClient = nil;
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];

	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
		[testButton setEnabled:YES];
	}
	else {
		[testButton setEnabled:NO];
		[statusInfo setStringValue:NSLocalizedString(@"Trial period expired",
			@"Trial period expired")];
	}

	[[PingHistory sharedInstance] loadDefaultTargets:kTargetMaskRouterDNS];
    [lookupField registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
    [lookupField setUsesDataSource:YES];
    [lookupField setDataSource:[PingHistory sharedInstance]];

}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    NSNumber* object;
    int count;
    
    if ([mClient isConnected]) {
		// tell server to stop
		[mClient abortWithTimeout:0.25];
		[mClient startService:@"stop://" withObject:nil];
        [NSThread  sleepUntilDate:[NSDate
            dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1] ];        
    }
	[mClient setCallbackTarget:nil];
	[mClient release];  mClient = nil;
    // get instance count, try dictionary first
    object = [[PSSharedDictionary sharedInstance] objectForKey:@"instanceCount"];
    if (object) count = [object intValue];
    else count = instanceCount([LookupWindowC class]);
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:instanceName(kLookupName,count-1)];
    // remember settings
    [preferences setObject:[lookupField stringValue] forKey:instanceName(kLookupWC_target,count-1)];
    [self autorelease];
}

// select first responder
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    [[self window] makeFirstResponder:lookupField];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
    // share selected result with other tools
	if ([lookupField currentEditor]) {
        saveAddressOrName([lookupField stringValue]);
    }
	else {
        saveAddressOrName([resultField string]);
    }
}

// initialize window fields from dictionary
- (BOOL)setFields:(NSDictionary *)aDictionary
{
    NSString* str;
    BOOL result = NO;

    if ((str = [aDictionary objectForKey:@"name"])) {
        [lookupField setStringValue:str];
        result = YES;
    }
    else if ((str = [aDictionary objectForKey:@"address"])) {
        [lookupField setStringValue:str];
        result = YES;
    }
    else {
        // restore settings
        int count;
        count = instanceCount([LookupWindowC class]);
    	if ((str = [preferences objectForKey:instanceName(kLookupWC_target,count-1)])) {
            [lookupField setStringValue:str];
            result = YES;
        }
    }

    [[self window] makeFirstResponder:lookupField];	// restore first responder
    return result;
}

// ---------------------------------------------------------------------------------
//	¥ setURL:
// ---------------------------------------------------------------------------------
//	Set window fields from URL
//	Returns nil on success, or error message
- (NSString *)setURL:(NSString *)inString
{
    PSURL* url;
    NSString* returnValue = nil;
    
    do {
        url = [[[PSURL alloc] init] autorelease];
        [url setStringValue:inString];
		[lookupField setStringValue:[url host]];
	} while (false);
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ URL
// ---------------------------------------------------------------------------------
//	Build and return URL based on window fields
- (NSString *)URL
{
    PSURL* url;
	// collect window params to build a URL
	// <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
	// lookup://host
    url = [[[PSURL alloc] init] autorelease];
    [url setScheme:@"lookup"];
    [url setHost:[lookupField stringValue]];
    return [url stringValue];
}

// ---------------------------------------------------------------------------------
//	¥ lookup:
// ---------------------------------------------------------------------------------
//	Initiate lookup based on window fields
//	Called when user presses the "Test" button.
- (IBAction)lookup:(id)sender
{
	// invoke test
	[self lookupWithURL:[self URL]];
}
- (void)lookupWithURL:(NSString *)inString
{
    if (![testButton isEnabled]) return;
    // test if starting or aborting
    if (mRequestInProgress) {
        // kill it immediately since there's no way to abort lookups.
		[mClient abort];
        [statusInfo setStringValue:NSLocalizedString(@"Request aborted",@"Request aborted")];
    }
    else {
		// complete any fields being edited
		NSWindow* myWindow;
		myWindow = [self window];
		if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
		// capture history
		[self historyAdd:self];
        // collect window params to build a URL
        // <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
        [resultField setString:@""];
        [verificationField setString:@""];
        // create Lookup Server object running as a detached thread if needed
        if (!mClient) {
            mClient = [[PsClient alloc] init];
			[mClient setCallbackTarget:self];
			[mClient setServerClass:[LookupServer class]];
        }
		if (![mClient isConnected]) [mClient createNewServer:[LookupServer class]];
        // start test
        if ([mClient isConnected]) {
            [testButton setTitle:NSLocalizedString(@"Abort", @"Abort")];
            mRequestInProgress = YES;
            mVerification = 0;
            // clear any previous results
            [statusInfo setStringValue:@""];
            // launch service
            [mClient startService:inString withObject:nil];
			// update window title
            [[self window] setTitle:[self testResultTitle]];
        }
    }
}

- (IBAction)flushcache:(id)sender {
	NSString* path;
	NSArray* args;
	int result;
	if ((gMajorVersion >= 10) && (gMinorVersion <= 4)) {
		// Tiger or earlier
		path = @"/usr/sbin/lookupd";
		args = [NSArray arrayWithObject:@"-flushcache"];
		result = [AppSupport doTask:path arguments:args output:nil];
		if (result) NSLog(@"lookupd -flushcache result %d", result);
	}
	else {
		// Leopard
		path = @"/usr/bin/dscacheutil";
		args = [NSArray arrayWithObject:@"-flushcache"];
		result = [AppSupport doTask:path arguments:args output:nil];
		if (result) NSLog(@"dscacheutil -flushcache result %d", result);
	}
}

- (IBAction)showDNS:(id)sender
{
	// get DNS configuration using "scutil --dns"
	NSString *path;
	NSArray *args;
	NSString* output = nil;
	path = @"/usr/sbin/scutil";
	args = [NSArray arrayWithObjects:@"--dns", nil];
	int status = [AppSupport doTask:path arguments:args input:nil output:&output error:nil];
	if (status) NSLog(@"scutil returned status: %d",status); 
	else {
		// open a log window to display it
		MenuDispatch *md = [MenuDispatch sharedInstance];
		LogWindowC *logWindowC;
		[md logShowWindow:nil];
		logWindowC = [md logWindowC];
		[logWindowC setTitle:@"DNS Configuration"];
		[logWindowC appendString:output];
	}
}


- (BOOL)requestInProgress {
	return mRequestInProgress;
}

- (void)testComplete {
    [testButton setTitle:NSLocalizedString(@"Lookup",@"Lookup")];
    mRequestInProgress = NO;
    mVerification = 0;
}

#pragma mark -- help --
- (IBAction)myHelp:(id)sender
{
    openHelpAnchor(@"LookupHelp");
}

//
// -- history menu --
//
- (void)historyAdd:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory addHistory:[lookupField stringValue]];
    [lookupField noteNumberOfItemsChanged];
    [lookupField reloadData];
    [lookupField numberOfItems];	// force combo box to update
    // share our input/results with other tools
    saveAddressOrName([lookupField stringValue]);
}
- (void)historyAddFavorite:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory addFavorite:[lookupField stringValue]];
    [lookupField noteNumberOfItemsChanged];
    [lookupField reloadData];
    [lookupField numberOfItems];	// force combo box to update
    // share our input/results with other tools
    saveAddressOrName([lookupField stringValue]);
}
- (void)historyRemove:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory removeObject:[lookupField stringValue]];
    [lookupField noteNumberOfItemsChanged];
    [lookupField reloadData];
    [lookupField numberOfItems];	// force combo box to update
}
- (void)historyClear:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory clearHistory];
    [lookupField noteNumberOfItemsChanged];
    [lookupField reloadData];
    [lookupField numberOfItems];	// force combo box to update
}
- (void)historyClearFavorites:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory clearFavorites];
	[pingHistory loadDefaultTargets:kTargetMaskRouterDNS];
    [lookupField noteNumberOfItemsChanged];
    [lookupField reloadData];
    [lookupField numberOfItems];	// force combo box to update
}

#pragma mark -- save url --
// ---------------------------------------------------------------------------------
//	¥ saveDocument
// ---------------------------------------------------------------------------------
- (void)saveDocument:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"<%@>",[self URL]];
	NSSavePanel* savePanel = [NSSavePanel savePanel];
	[savePanel setRequiredFileType:@"ipnm"];
	[savePanel setMessage:@"Save this URL as:"];
	[[[savePanel defaultButtonCell] controlView] setToolTip:url];
	IPNMDocument* document = [self document];
	NSString* filename = [document fileName];
	if (filename) {
		filename = [filename stringByDeletingLastPathComponent];
		filename = [filename stringByAppendingPathComponent:[self testResultTitle]];
		filename = [filename stringByAppendingPathExtension:@"ipnm"];
		[document setDataString:url];
		[document writeToFile:filename ofType:@"ipnm"];
	}
	else [savePanel beginSheetForDirectory:filename file:[self testResultTitle]
		modalForWindow:[self window] modalDelegate:self
		didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:[url retain]];
}
// ---------------------------------------------------------------------------------
//	¥ saveDocumentAs
// ---------------------------------------------------------------------------------
- (void)saveDocumentAs:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"<%@>",[self URL]];
	NSSavePanel* savePanel = [NSSavePanel savePanel];
	[savePanel setRequiredFileType:@"ipnm"];
	[savePanel setMessage:@"Save this URL as:"];
	[[[savePanel defaultButtonCell] controlView] setToolTip:url];

	[savePanel beginSheetForDirectory:nil file:[self testResultTitle]
		modalForWindow:[self window] modalDelegate:self
		didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:[url retain]];
}
// ---------------------------------------------------------------------------------
//	¥ testResultTitle
// ---------------------------------------------------------------------------------
// Calculate window title for this test result
- (NSString *)testResultTitle
{
	// determine window title
	NSString* toolStr = NSLocalizedString(@"Lookup",@"Lookup");
	NSString* title = [NSString stringWithFormat:@"%@ (%@)",toolStr,[lookupField stringValue]];
	return title;
}
// ---------------------------------------------------------------------------------
//	¥ savePanelDidEnd
// ---------------------------------------------------------------------------------
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	NSString* url = (NSString*)contextInfo;
	if (returnCode == NSOKButton) {
		//[url writeToFile:[sheet filename] atomically:NO];
		IPNMDocument* document = [[[IPNMDocument alloc] initWithType:@"ipnm" error:nil] autorelease];
		[[NSDocumentController sharedDocumentController] addDocument:document];
		[document addWindowController:self];
		[document setFileName:[sheet filename]];
		[document setDataString:url];
		[document writeToFile:[sheet filename] ofType:@"ipnm"];
	}
	[url release];
}

#pragma mark -- <ControllerFromThread> --
// ---------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSEnumerator *enumerator = [dictionary keyEnumerator];
    id key;
    id object;

	if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
		[self testComplete];
	}
	
	else {

		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			object = [dictionary objectForKey:key];
			if ([object isKindOfClass:[NSString class]]) {	// assign string values
				if (NO);
				// status
				else if ([key isEqualTo:@"statusInfo"]) [statusInfo setStringValue:object];
				else if ([key isEqualTo:@"elapsedInfo"]) {
					if (mVerification == 0) [elapsedInfo setStringValue:object];
				}
				else if ([key isEqualTo:@"lookupComplete"]) {
					if ((mVerification == 0) && ([[resultField string] length])) {
						mVerification += 1;
						NSString* url;
						NSRange range; 
						NSString* firstLine = [resultField string];
						range = [firstLine rangeOfString:@"\r"];
						if (range.length) firstLine = [firstLine substringToIndex:range.location];
						url = [NSString stringWithFormat:@"lookup://%@;listAll=1",firstLine];
						[mClient startService:url withObject:nil];
					}
					else if (mVerification == 1) {
						if ([[verificationField string] hasSuffix:@".in-addr.arpa"]) {
							NSString* url;
							mVerification += 1;
							url = [NSString stringWithFormat:@"lookup://%@;listAll=1",[verificationField string]];
							[mClient startService:url withObject:nil];
						}
						else  [self testComplete];
					}
					else if (mVerification == 2) {
						if (
							([[statusInfo stringValue] isEqualTo:NSLocalizedString(@"No name found",@"No name found")]) ||
							([[statusInfo stringValue] isEqualTo:NSLocalizedString(@"No address found",@"No address found")])
							)  [statusInfo setStringValue:NSLocalizedString(@"RFC 2317 reverse delegation",@"RFC 2317 reverse delegation")];
						[self testComplete];
					}
					else [self testComplete];
				}
				// input parameters
				else if ([key isEqualTo:kLookupField]) [lookupField setStringValue:object];
				else if ([key isEqualTo:kResultField]) {
					if (mVerification == 0) {
						[resultField setString:object];
					}
					else {
						[verificationField setString:object];
					}
				}
			}
		} // while ((key = [enumerator nextObject]))
    }	// key for PSAction is not "server finished" or "report error", treat as parameter update
}

@end
