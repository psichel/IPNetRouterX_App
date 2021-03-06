#import "TCPDumpWindowC.h"
#import "TCPDumpServer.h"
#import "TCPDumpHistory.h"
#import	"TCPFlowHistory.h"
#import "PsClient.h"
#import "PSSharedDictionary.h"
#import "SystemConfiguration.h"
#import "AppDelegate.h"
#import "PSSupport.h"
#import "unp.h"

@implementation TCPDumpWindowC

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

- (void)awakeFromNib {
    NSString* str;
    NSArray* portList;
    int count;
    mRequestInProgress = NO;
    mClient = nil;
    mPid = 0;
	mFd = 0;
    [outputText setRichText:NO];
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];
	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	

	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
		[startButton setEnabled:YES];
	}
	else {
		[startButton setEnabled:NO];
		[statusInfo setStringValue:NSLocalizedString(@"Trial period expired",
			@"Trial period expired")];
	}
    // load port menu
	[portMenu removeAllItems];
	portList = [[SystemConfiguration sharedInstance] currentInterfaceTitles];
    if ([portList count] == 0) {
        [portMenu addItemWithTitle:@"No configured interfaces"];
        [portMenu setEnabled:NO];
    }
	else [portMenu addItemsWithTitles:portList];
    // restore settings
    count = instanceCount([TCPDumpWindowC class]);
    NS_DURING
        if ((str = [preferences objectForKey:instanceName(kTCPDump_portMenu,count-1)]))
            [portMenu selectItemWithTitle:str];
        [useTCPFlowCheckBox setIntValue:[preferences integerForKey:instanceName(kTCPDump_useTCPFlow,count-1)]];
		if ((str = [preferences objectForKey:instanceName(kTCPDump_options,count-1)]))
            [options setStringValue:str];
        else {
            [options setStringValue:@"-n -p -t"];
        }
    NS_HANDLER
		NSLog(@"Exception during TCPDumpWindowC.m awakeFromNib");
    NS_ENDHANDLER
    // enable options history
    [options setUsesDataSource:YES];
	if ([useTCPFlowCheckBox intValue]) [options setDataSource:[TCPFlowHistory sharedInstance]];
    else [options setDataSource:[TCPDumpHistory sharedInstance]];
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    NSNumber* object;
    int count;
    
    if (mPid) {
        // kill tcpdump we started if any
        kill(mPid, SIGKILL);
        mPid = 0;
    }
    if (mFd) {
        // kill PseudoTTy we started if any
		Close(mFd);
        mFd = 0;
    }
    [mClient setCallbackTarget:nil];
	[mClient release];  mClient = nil;
    // get instance count, try dictionary first
    object = [[PSSharedDictionary sharedInstance] objectForKey:@"instanceCount"];
    if (object) count = [object intValue];
    else count = instanceCount([TCPDumpWindowC class]);
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:instanceName(kTCPDumpName,count-1)];
    // remember settings
    [preferences setObject:[[portMenu selectedItem] title] forKey:instanceName(kTCPDump_portMenu,count-1)];
    [preferences setInteger:[useTCPFlowCheckBox intValue] forKey:instanceName(kTCPDump_useTCPFlow,count-1)];
    [preferences setObject:[options stringValue] forKey:instanceName(kTCPDump_options,count-1)];
    // release ourself
    [self autorelease];
}

// ---------------------------------------------------------------------------------
//	� useTCPFlow:
// ---------------------------------------------------------------------------------
//	Update history popup to use TCPFlowHistory
- (IBAction)useTCPFlow:(id)sender
{
	if ([useTCPFlowCheckBox intValue]) [options setDataSource:[TCPFlowHistory sharedInstance]];
    else [options setDataSource:[TCPDumpHistory sharedInstance]];
	[options setStringValue:@""];
	[options reloadData];
}

// ---------------------------------------------------------------------------------
//	� monitor:
// ---------------------------------------------------------------------------------
- (IBAction)monitor:(id)sender
{
	if (![startButton isEnabled]) return;
	// test if starting or aborting
    if (mRequestInProgress) {
        // wait for server to finish
        // if no response force it to abort
		[mClient abortWithTimeout:2.2];
        if (mPid) {
            // kill tcpdump we started if any
            kill(mPid, SIGKILL);
            mPid = 0;
        }
		if (mFd) {
			// kill PseudoTTy we started if any
			Close(mFd);
			mFd = 0;
		}
    }
    else {
        NSString* url;
        NSString* scheme;
        NSString* server;
        NSString* interface;
        NSString* optionStr;
		// complete any fields being edited
		NSWindow* myWindow;
		myWindow = [self window];
		if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
        // capture history information
        [self historyAdd:self];
        // collect window params to build a URL
        // <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
        // tcpdump://interface@server;options
		if ([useTCPFlowCheckBox intValue])
			scheme = @"tcpflow";
		else scheme = @"tcpdump";
        // interface
        interface = bsdNameForTitle([[portMenu selectedItem] title]);
        // @server
        server = @"@localhost";
        // ;options
        if ([[options stringValue] length]) {
            NSRange range;
            optionStr = [NSString stringWithFormat:@";options=%@",[options stringValue]];
            // remove comment (if any) from end of options
            range = [optionStr rangeOfString:@"//"];
            if (range.length) {
                optionStr = [optionStr substringToIndex:range.location];
            }
			optionStr = [optionStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        else optionStr = @"";
        // build url
        url = [NSString stringWithFormat:@"%@://%@%@%@",
            scheme,interface,server,optionStr];
        // create TCPDump Server object running as a detached thread
		if (!mClient) {
			mClient = [[PsClient alloc] init];
			[mClient setCallbackTarget:self];
			[mClient setServerClass:[TCPDumpServer class]];
		}
        if (![mClient isConnected]) [mClient createNewServer:[TCPDumpServer class]];
        // start test
        if ([mClient isConnected]) {
            [startButton setTitle:NSLocalizedString(@"Stop",@"Stop")];
            [outputText setString:@""];
            [self appendString:url newLine:YES];
            mRequestInProgress = YES;
            // clear any previous results
            [statusInfo setStringValue:@""];
            // launch service
            [mClient startService:url withObject:nil];
			// update window title
            NSString* toolStr;
            toolStr = NSLocalizedString(@"TCP Dump",@"TCP Dump");
            [[self window] setTitle:[NSString stringWithFormat:@"%@ (%@)",toolStr,interface]];
        }
    }
}

#define END_RANGE NSMakeRange([[outputText string]length],0)
- (void)appendString:(NSString *)inString newLine:(BOOL)newLine
{
    // remove some history if it gets too long
	if ([[outputText string] length] > 262144) {
		[outputText replaceCharactersInRange:NSMakeRange(0,32768) withString:@""];
	}
	
	// append new text
	[outputText replaceCharactersInRange:END_RANGE withString:inString];
    if (newLine)
        [outputText replaceCharactersInRange:END_RANGE withString:@"\n"];
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
}

- (BOOL)requestInProgress {
	return mRequestInProgress;
}

- (void)testComplete {
    [startButton setTitle:NSLocalizedString(@"Start",@"Start")];
    [statusInfo setStringValue:NSLocalizedString(@"Monitoring stopped",@"Monitoring stopped")];
    mRequestInProgress = NO;
}

#pragma mark -- help --
- (IBAction)myHelp:(id)sender
{
    openHelpAnchor(@"TCPDumpHelp");
}

//
// -- history menu --
//
- (void)historyAdd:(id)sender
{
	// capture history information
	if ([useTCPFlowCheckBox intValue]) {
		TCPFlowHistory* tcpFlowHistory;
		tcpFlowHistory = [TCPFlowHistory sharedInstance];
		[tcpFlowHistory addHistory:[options stringValue]];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
	else {
		TCPDumpHistory* tcpDumpHistory;
		tcpDumpHistory = [TCPDumpHistory sharedInstance];
		[tcpDumpHistory addHistory:[options stringValue]];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
}
- (void)historyAddFavorite:(id)sender
{
	// capture history information
	if ([useTCPFlowCheckBox intValue]) {
		TCPFlowHistory* tcpFlowHistory;
		tcpFlowHistory = [TCPFlowHistory sharedInstance];
		[tcpFlowHistory addFavorite:[options stringValue]];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
	else {
		TCPDumpHistory* tcpDumpHistory;
		tcpDumpHistory = [TCPDumpHistory sharedInstance];
		[tcpDumpHistory addHistory:[options stringValue]];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
}
- (void)historyRemove:(id)sender
{
	if ([useTCPFlowCheckBox intValue]) {
		TCPFlowHistory* tcpFlowHistory;
		tcpFlowHistory = [TCPFlowHistory sharedInstance];
		[tcpFlowHistory removeObject:[options stringValue]];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
	else {
		TCPDumpHistory* tcpDumpHistory;
		tcpDumpHistory = [TCPDumpHistory sharedInstance];
		[tcpDumpHistory removeObject:[options stringValue]];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
}
- (void)historyClear:(id)sender
{
	if ([useTCPFlowCheckBox intValue]) {
		TCPFlowHistory* tcpFlowHistory;
		tcpFlowHistory = [TCPFlowHistory sharedInstance];
		[tcpFlowHistory clearHistory];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
	else {
		TCPDumpHistory* tcpDumpHistory;
		tcpDumpHistory = [TCPDumpHistory sharedInstance];
		[tcpDumpHistory clearHistory];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
}
- (void)historyClearFavorites:(id)sender
{
	if ([useTCPFlowCheckBox intValue]) {
		TCPFlowHistory* tcpFlowHistory;
		tcpFlowHistory = [TCPFlowHistory sharedInstance];
		[tcpFlowHistory clearFavorites];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
	else {
		TCPDumpHistory* tcpDumpHistory;
		tcpDumpHistory = [TCPDumpHistory sharedInstance];
		[tcpDumpHistory clearFavorites];
		[options noteNumberOfItemsChanged];
		[options reloadData];
		[options numberOfItems];	// force combo box to update
	}
}


// -- <ControllerFromThread> --
// ---------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSEnumerator *enumerator = [dictionary keyEnumerator];
    id key;
    id object;

	if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
		mPid = 0;
		mFd = 0;
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
				else if ([key isEqualTo:@"processIdentifier"]) mPid = [object intValue];
				else if ([key isEqualTo:@"fileDescriptor"]) mFd = [object intValue];
				// input parameters
				else if ([key isEqualTo:@"portMenu"]) [portMenu selectItemWithTitle:object];
				else if ([key isEqualTo:@"outputText"]) {
					// use empty string to clear
					if ([(NSString*)object length] == 0) [outputText setString:object];
					// otherwise append
					[self appendString:(NSString*)object newLine:NO];
				}
			}
		}	// while ((key = [enumerator nextObject]))
	}
}

@end
