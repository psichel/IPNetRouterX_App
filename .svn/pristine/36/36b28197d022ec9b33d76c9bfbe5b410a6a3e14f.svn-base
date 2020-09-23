#import "MenuDispatch.h"
#import "PSSharedDictionary.h"
#import "PSSupport.h"
#import "NSException_Extensions.h"

/*
As declared in NSGeometry.h

typedef struct _NSPoint {
    CGFloat x;
    CGFloat y;
} NSPoint;

typedef struct _NSSize {
    CGFloat width;		// should never be negative
    CGFloat height;		// should never be negative
} NSSize;

typedef struct _NSRect {
    NSPoint origin;
    NSSize size;
} NSRect;

Save frame using name stores a string of 8 numbers (space delimited) representing two rects,
the window, and the screen. The key used is: "NSWindow Frame someName"
*/

#import "PreferencesController.h"
#import "DiagnosticWC.h"
#import "RegistrationController.h"
#import "Apple80211.h"
#import "AirPortConfigurationWindowC.h"
#import "ConnectToServerWC.h"
#import "AdministratorsWC.h"
#import "IPNetClient.h"
#import "TCPConnection.h"
#if IPNetRouter
#import "DHCPServerWindowC.h"
#import "DHCPLogWindowC.h"
#import "NATViewWindowC.h"
#import "NameServiceWC.h"
#import "RouteWindowC.h"
#import "AlternateRouteWC.h"
#endif
#import "TrafficDiscoveryWC.h"
#import "BasicSetupWC.h"
#import "ExpertViewWC.h"
#import "TriggerImportWC.h"
#import "SentryLogWindowC.h"

@implementation MenuDispatch

// ---------------------------------------------------------------------------------
//	¥ sharedInstance
// ---------------------------------------------------------------------------------
+ (MenuDispatch *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[MenuDispatch alloc] init];
	}
	return sharedTask;
}

- (id)init {
    if (self = [super init]) {
		mAddressScanWindowC = nil;
		mLogWindowC = nil;
		mLookupWindowC = nil;
		mSubnetWindowC = nil;
    }
    return self;
}
// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	[mAddressScanWindowC release];	mAddressScanWindowC = nil;
	[mLogWindowC release];			mLogWindowC = nil;
	[mLookupWindowC release];		mLookupWindowC = nil;
	[mSubnetWindowC release];		mSubnetWindowC = nil;
	
    [super dealloc];
}

#pragma mark -- Validation --

// ---------------------------------------------------------------------------------
//	¥ validateMenuItem
// ---------------------------------------------------------------------------------
- (BOOL)validateMenuItem:(NSMenuItem*)anItem {
    NSMenu* menu = [anItem menu];
	if ([[anItem title] hasPrefix:@"AirPort"]) {
		if ( WirelessIsAvailable() ) return YES;
		else return NO;
    }
	if ([[menu title] isEqualTo:@"Remote"]) {
		if ([anItem tag] == 1) {	// Connect To Server
			if ([[IPNetClient sharedInstance] connectionCount] == 0) return NO;
			else return NO;
		}
		else if ([anItem tag] == 2) {	// Connect To Local Server
			if ([[IPNetClient sharedInstance] connectionCount] == 0) return NO;
			else return NO;
		}
		else if ([anItem tag] == 3) {	// Disconnect
			if ([[IPNetClient sharedInstance] connectionCount] > 0) return NO;
			else return NO;
		}
		else if ([anItem tag] == 4) {	// Administrators...
			return NO;
		}
		
	}
    return YES;
}

#pragma mark -- Preferences --
- (IBAction)preferencesShowWindow:(id)sender
{
    PreferencesController *preferencesController;
    NSEnumerator* en;
    NSWindow* window;
    // Only one preferences window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[PreferencesController class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        preferencesController = [PreferencesController alloc];
        preferencesController = [preferencesController
            initWithWindowNibName:kPreferencesName owner:preferencesController];
        if (preferencesController) {
            [[preferencesController window] setFrameUsingName:kPreferencesName];
            [[preferencesController window] makeKeyAndOrderFront:sender];
        }
		[preferencesController autorelease];
    }
}

// count number of open windows
- (unsigned)preferencesCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[PreferencesController class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)preferencesCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[PreferencesController class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- Diagnostic --
- (IBAction)diagnosticShowWindow:(id)sender
{
    DiagnosticWC *diagnosticWC;
    NSEnumerator* en;
    NSWindow* window;
    // Only one diagnostic window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DiagnosticWC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        diagnosticWC = [DiagnosticWC alloc];
        diagnosticWC = [diagnosticWC
            initWithWindowNibName:kDiagnosticName owner:diagnosticWC];
        if (diagnosticWC) {
            [[diagnosticWC window] setFrameUsingName:kDiagnosticName];
            [[diagnosticWC window] makeKeyAndOrderFront:sender];
        }
		[diagnosticWC autorelease];
    }
}

// count number of open windows
- (unsigned)diagnosticCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DiagnosticWC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)diagnosticCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DiagnosticWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}


#pragma mark -- Registration --
// ---------------------------------------------------------------------------------
//	¥ registrationShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)registrationShowWindow:(id)sender
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
		[registrationController autorelease];
    }
}


#pragma mark -- AirPort Configuration --
- (IBAction)airPortConfigurationShowWindow:(id)sender
{
    AirPortConfigurationWindowC *airPortController;
    NSEnumerator* en;
    NSWindow* window;
    // Only one AirPortConfiguration server window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AirPortConfigurationWindowC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        airPortController = [AirPortConfigurationWindowC alloc];
        airPortController = [airPortController
            initWithWindowNibName:kAirPortConfigurationName owner:airPortController];
        if (airPortController) {
            [[airPortController window] setFrameUsingName:kAirPortConfigurationName];
            [[airPortController window] makeKeyAndOrderFront:sender];
        }
		[airPortController autorelease];
    }
}

// close open windows and return how many we found
- (int)airPortConfigurationCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AirPortConfigurationWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- remote --

// ---------------------------------------------------------------------------------
//	¥ connectToServer
// ---------------------------------------------------------------------------------
- (IBAction)connectToLocalServer:(id)sender
{
	NSHost* host;
	TCPConnection* connection;
	// Look to see if we are already connected
	host = [NSHost currentHost];
	connection = [[IPNetClient sharedInstance] findConnection:[host name]];
	if (!connection) {
		// create one
		//connection = [[IPNetClient sharedInstance] connectToHost:host];
		//...
	}
}

// ---------------------------------------------------------------------------------
//	¥ disconnect
// ---------------------------------------------------------------------------------
- (IBAction)disconnect:(id)sender
{
	TCPConnection* connection;
	connection = [[IPNetClient sharedInstance] findConnection:nil];
	[connection invalidate];
}


#pragma mark -- connectToServer --
// ---------------------------------------------------------------------------------
//	¥ connectToServerShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)connectToServerShowWindow:(id)sender
{
    // show/edit registration data
    ConnectToServerWC *connectToServer;
    NSEnumerator* en;
    NSWindow* window;
    // Only one ConnectToServerWC window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[ConnectToServerWC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        connectToServer = [ConnectToServerWC alloc];
        connectToServer = [connectToServer
            initWithWindowNibName:kConnectToServer_name owner:connectToServer];
        if (connectToServer) {
//            [[connectToServer window] setFrameUsingName:kConnectToServer_name];
            [[connectToServer window] makeKeyAndOrderFront:sender];
        }
		[connectToServer autorelease];
    }
}

// close open windows and return how many we found
- (int)connectToServerCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[ConnectToServerWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}
#pragma mark -- Administrators --
// ---------------------------------------------------------------------------------
//	¥ administratorsShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)administratorsShowWindow:(id)sender
{
    // show/edit registration data
    AdministratorsWC *administrators;
    NSEnumerator* en;
    NSWindow* window;
    // Only one AdministratorsWC window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AdministratorsWC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        administrators = [AdministratorsWC alloc];
        administrators = [administrators
            initWithWindowNibName:kAdministrators_name owner:administrators];
        if (administrators) {
//            [[administrators window] setFrameUsingName:kAdministrators_name];
            [[administrators window] makeKeyAndOrderFront:sender];
        }
		[administrators autorelease];
    }
}

// close open windows and return how many we found
- (int)administratorsCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AdministratorsWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}



#if IPNetRouter
#pragma mark -- DHCP Server --
// ---------------------------------------------------------------------------------
//	¥ dhcpServerShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)dhcpServerShowWindow:(id)sender
{
    DHCPServerWindowC *dhcpServerController;
    NSEnumerator* en;
    NSWindow* window;
	@try {
		// Only one DHCP server window
		// check if it already exists, if so bring to front, else create it
		en = [[NSApp windows] objectEnumerator];
		while (window = [en nextObject]) {
			if ([[window delegate] isKindOfClass:[DHCPServerWindowC class]]) break;
		}
		if (window) {
			[window makeKeyAndOrderFront:sender];
			// force window to display new state
			[[window delegate] awakeFromNib];
		}
		else {
			// create window controller and make it the windows owner
			dhcpServerController = [[DHCPServerWindowC alloc] initWithWindowNibName:kDHCPServerName];
			if (dhcpServerController) {
				window = [dhcpServerController window];
				[window setFrameUsingName:kDHCPServerName];
				[window makeKeyAndOrderFront:sender];
			}
			[dhcpServerController autorelease];
		}
	}
	@catch( NSException *theException ) {
		[theException printStackTrace];
	}
}

// count number of open windows
- (int)dhcpServerCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DHCPServerWindowC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)dhcpServerCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DHCPServerWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}


#pragma mark -- DHCP Log Window --
// ---------------------------------------------------------------------------------
//	¥ dhcpLogShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)dhcpLogShowWindow:(id)sender
{
    DHCPLogWindowC *sentryLogWindowC;
    NSEnumerator* en;
    NSWindow* window;
    // Only one log viewer window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DHCPLogWindowC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        sentryLogWindowC = [DHCPLogWindowC alloc];
        sentryLogWindowC = [sentryLogWindowC
            initWithWindowNibName:kDHCPLogName owner:sentryLogWindowC];
        if (sentryLogWindowC) {
            [[sentryLogWindowC window] setFrameUsingName:kDHCPLogName];
            [[sentryLogWindowC window] makeKeyAndOrderFront:sender];
        }
		[sentryLogWindowC autorelease];
    }
}

// count number of open windows
- (unsigned)dhcpLogCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DHCPLogWindowC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)dhcpLogCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[DHCPLogWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}


#pragma mark -- NAT View --
// ---------------------------------------------------------------------------------
//	¥ natViewShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)natViewShowWindow:(id)sender
{
    NATViewWindowC *natViewController;
    NSEnumerator* en;
    NSWindow* window;
    // Only one natView window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[NATViewWindowC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        natViewController = [NATViewWindowC alloc];
        natViewController = [natViewController
            initWithWindowNibName:kNATViewName owner:natViewController];
        if (natViewController) {
            [[natViewController window] setFrameUsingName:kNATViewName];
            [[natViewController window] makeKeyAndOrderFront:sender];
        }
		[natViewController autorelease];
    }
}

// count number of open windows
- (unsigned)natViewCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[NATViewWindowC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)natViewCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[NATViewWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}


#pragma mark -- Name Service --
// ---------------------------------------------------------------------------------
//	¥ nameServiceShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)nameServiceShowWindow:(id)sender
{
    // show/edit registration data
    NameServiceWC *nameService;
    NSEnumerator* en;
    NSWindow* window;
    // Only one NameServiceWC window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[NameServiceWC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        nameService = [NameServiceWC alloc];
        nameService = [nameService
            initWithWindowNibName:kNameService_name owner:nameService];
        if (nameService) {
            [[nameService window] setFrameUsingName:kNameService_name];
            [[nameService window] makeKeyAndOrderFront:sender];
        }
		[nameService autorelease];
    }
}

// close open windows and return how many we found
- (int)nameServiceCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[NameServiceWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- Route --
// ---------------------------------------------------------------------------------
//	¥ routeShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)routeShowWindow:(id)sender
{
    RouteWindowC *routesController;
    NSEnumerator* en;
    NSWindow* window;
    // Only one routes window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[RouteWindowC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        routesController = [RouteWindowC alloc];
        routesController = [routesController
            initWithWindowNibName:kRouteName owner:routesController];
        if (routesController) {
            [[routesController window] setFrameUsingName:kRouteName];
            [[routesController window] makeKeyAndOrderFront:sender];
        }
		[routesController autorelease];
    }
}

// count number of open windows
- (unsigned)routeCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[RouteWindowC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)routeCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[RouteWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- Alternate Route --
// ---------------------------------------------------------------------------------
//	¥ alternateRouteShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)alternateRouteShowWindow:(id)sender
{
    AlternateRouteWC *alternateRouteWC;
    NSEnumerator* en;
    NSWindow* window;
    // Only one alternateRoute window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AlternateRouteWC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        alternateRouteWC = [AlternateRouteWC alloc];
        alternateRouteWC = [alternateRouteWC
            initWithWindowNibName:kAlternateRouteName owner:alternateRouteWC];
        if (alternateRouteWC) {
            [[alternateRouteWC window] setFrameUsingName:kAlternateRouteName];
            [[alternateRouteWC window] makeKeyAndOrderFront:sender];
        }
		[alternateRouteWC autorelease];
    }
}

// count number of open windows
- (unsigned)alternateRouteCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AlternateRouteWC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)alternateRouteCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AlternateRouteWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#endif

#pragma mark -- Traffic Discovery --
// ---------------------------------------------------------------------------------
//	¥ trafficDiscoveryShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)trafficDiscoveryShowWindow:(id)sender
{
    // show/edit registration data
    TrafficDiscoveryWC *trafficDiscovery;
    NSWindow* window;
	int count;
    // count how many we have so far
    count = instanceCount([TrafficDiscoveryWC class]);
    // create window controller and make it the windows owner
    trafficDiscovery = [TrafficDiscoveryWC alloc];
    trafficDiscovery = [trafficDiscovery
        initWithWindowNibName:kTrafficDiscovery_name owner:trafficDiscovery];
    if (trafficDiscovery) {
        window = [trafficDiscovery window];
        if (![window setFrameUsingName:instanceName(kTrafficDiscovery_name,count)])
        {	// offset multiples
            NSRect rect;
            count = count % 4;
            rect = [window frame];
            rect = NSOffsetRect(rect, count*16, -count*16);
            [window setFrameOrigin:rect.origin];
        }
        [window makeKeyAndOrderFront:sender];
    }
	[trafficDiscovery autorelease];
}

// close open windows and return how many we found
- (int)trafficDiscoveryCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[TrafficDiscoveryWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- Basic Setup --
// ---------------------------------------------------------------------------------
//	¥ basicSetupShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)basicSetupShowWindow:(id)sender
{
	BasicSetupWC* wc;
	wc = [self basicSetupMakeWindowController:sender];
	[wc showDocument];
}

- (BasicSetupWC*)basicSetupMakeWindowController:(id)sender
{
    // show/edit registration data
    BasicSetupWC *basicSetup = nil;
    NSEnumerator* en;
    NSWindow* window;
    // Only one BasicSetup window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[BasicSetupWC class]]) break;
    }
    if (window) {
        // bring to front
		[window makeKeyAndOrderFront:sender];
		// return the window controller we found
		basicSetup = [window delegate];
    }
    else {
        // create window controller and make it the windows owner
        basicSetup = [BasicSetupWC alloc];
        basicSetup = [basicSetup
            initWithWindowNibName:kBasicSetupName owner:basicSetup];
        if (basicSetup) {
            [[basicSetup window] setFrameUsingName:kBasicSetupName];
            [[basicSetup window] makeKeyAndOrderFront:sender];
        }
		[basicSetup autorelease];
    }
	return basicSetup;
}

// close open windows and return how many we found
- (int)basicSetupCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[BasicSetupWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- Expert View --
// ---------------------------------------------------------------------------------
//	¥ expertViewShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)expertViewShowWindow:(id)sender
{
	ExpertViewWC* wc;
	wc = [self expertViewMakeWindowController:sender];
	[wc showDocument];
}

- (ExpertViewWC*)expertViewMakeWindowController:(id)sender
{
    // show/edit registration data
    ExpertViewWC *expertView = nil;
    NSEnumerator* en;
    NSWindow* window;
    // Only one ExpertView window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[ExpertViewWC class]]) break;
    }
    if (window) {
        // bring to front
		[window makeKeyAndOrderFront:sender];
		// return the window controller we found
		expertView = [window delegate];
    }
    else {
        // create window controller and make it the windows owner
        expertView = [ExpertViewWC alloc];
        expertView = [expertView
            initWithWindowNibName:kExpertViewName owner:expertView];
        if (expertView) {
            [[expertView window] setFrameUsingName:kExpertViewName];
            [[expertView window] makeKeyAndOrderFront:sender];
        }
		[expertView autorelease];
    }
	return expertView;
}

// close open windows and return how many we found
- (int)expertViewCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[ExpertViewWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- Trigger Import --
// ---------------------------------------------------------------------------------
//	¥ triggerImportShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)triggerImportShowWindow:(id)sender
{
    // show/edit registration data
    TriggerImportWC *triggerImport;
    NSEnumerator* en;
    NSWindow* window;
    // Only one TriggerImport window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[TriggerImportWC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        triggerImport = [TriggerImportWC alloc];
        triggerImport = [triggerImport
            initWithWindowNibName:kTriggerImportName owner:triggerImport];
        if (triggerImport) {
//            [[triggerImport window] setFrameUsingName:kTriggerImportName];
            [[triggerImport window] makeKeyAndOrderFront:sender];
        }
		[triggerImport autorelease];
    }
}

// close open windows and return how many we found
- (int)triggerImportCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[TriggerImportWC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}


#pragma mark -- Sentry Log Window --
// ---------------------------------------------------------------------------------
//	¥ sentryLogShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)sentryLogShowWindow:(id)sender
{
    SentryLogWindowC *sentryLogWindowC;
    NSEnumerator* en;
    NSWindow* window;
    // Only one log viewer window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[SentryLogWindowC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        sentryLogWindowC = [SentryLogWindowC alloc];
        sentryLogWindowC = [sentryLogWindowC
            initWithWindowNibName:kSentryLogName owner:sentryLogWindowC];
        if (sentryLogWindowC) {
            [[sentryLogWindowC window] setFrameUsingName:kSentryLogName];
            [[sentryLogWindowC window] makeKeyAndOrderFront:sender];
        }
		[sentryLogWindowC autorelease];
    }
}

// count number of open windows
- (unsigned)sentryLogCount
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[SentryLogWindowC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)sentryLogCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[SentryLogWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

#pragma mark -- Address Scan -- 
// ---------------------------------------------------------------------------------
//	¥ addressScanShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)addressScanShowWindow:(id)sender
{
    NSWindow* window;
    int count = 0;
	// count how many we have so far
	count = instanceCount([AddressScanWindowC class]);
	// create window controller and make it the windows owner
	mAddressScanWindowC = [AddressScanWindowC alloc];
	mAddressScanWindowC = [mAddressScanWindowC initWithWindowNibName:kAddressScanName owner:mAddressScanWindowC];
	if (mAddressScanWindowC) {
		window = [mAddressScanWindowC window];
		if (![window setFrameUsingName:instanceName(kAddressScanName,count)])
		{	// offset multiples
			NSRect rect;
			count = count % 4;
			rect = [window frame];
			rect = NSOffsetRect(rect, count*16, -count*16);
			[window setFrameOrigin:rect.origin];
		}
		[window makeKeyAndOrderFront:sender];
		[mAddressScanWindowC setFields:[PSSharedDictionary sharedInstance]];
	}
}

// close open windows and return how many we found
- (int)addressScanCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AddressScanWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

- (AddressScanWindowC *)addressScanWindowC { return mAddressScanWindowC; }


#pragma mark -- Log --
// ---------------------------------------------------------------------------------
//	¥ logShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)logShowWindow:(id)sender
{
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    count = instanceCount([LogWindowC class]);
    // create window controller and make it the windows owner
    mLogWindowC = [LogWindowC alloc];
    mLogWindowC = [mLogWindowC
        initWithWindowNibName:kLogName owner:mLogWindowC];
    if (mLogWindowC) {
        window = [mLogWindowC window];
        if (![window setFrameUsingName:instanceName(kLogName,count)])
        {	// offset multiples
            NSRect rect;
            count = count % 4;
            rect = [window frame];
            rect = NSOffsetRect(rect, count*16, -count*16);
            [window setFrameOrigin:rect.origin];
        }
        [window makeKeyAndOrderFront:sender];
    }
}

// close open windows and return how many we found
- (int)logCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[LogWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

- (LogWindowC *)logWindowC { return mLogWindowC; }


#pragma mark -- Lookup --
// ---------------------------------------------------------------------------------
//	¥ lookupShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)lookupShowWindow:(id)sender
{
    NSWindow* window;
    int count = 0;
	// count how many we have so far
	count = instanceCount([LookupWindowC class]);
	// create window controller and make it the windows owner
	mLookupWindowC = [LookupWindowC alloc];
	mLookupWindowC = [mLookupWindowC initWithWindowNibName:kLookupName owner:mLookupWindowC];
	if (mLookupWindowC) {
		window = [mLookupWindowC window];
		if (![window setFrameUsingName:instanceName(kLookupName,count)])
		{	// offset multiples
			NSRect rect;
			count = count % 4;
			rect = [window frame];
			rect = NSOffsetRect(rect, count*16, -count*16);
			[window setFrameOrigin:rect.origin];
		}
		[window makeKeyAndOrderFront:sender];
		[mLookupWindowC setFields:[PSSharedDictionary sharedInstance]];
	}
}

// close open windows and return how many we found
- (int)lookupCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count=0;
    // walk the list to close each one
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[LookupWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

- (LookupWindowC *)lookupWindowC { return mLookupWindowC; }


#pragma mark -- Subnet Calculator --
// ---------------------------------------------------------------------------------
//	¥ subnetShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)subnetShowWindow:(id)sender
{
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    count = instanceCount([SubnetWindowC class]);
    // create window controller and make it the windows owner
    mSubnetWindowC = [SubnetWindowC alloc];
    mSubnetWindowC = [mSubnetWindowC initWithWindowNibName:kSubnetName owner:mSubnetWindowC];
    if (mSubnetWindowC) {
        window = [mSubnetWindowC window];
        if (![window setFrameUsingName:instanceName(kSubnetName,count)])
        {	// offset multiples
            NSRect rect;
            count = count % 4;
            rect = [window frame];
            rect = NSOffsetRect(rect, count*16, -count*16);
            [window setFrameOrigin:rect.origin];
        }
        [window makeKeyAndOrderFront:sender];
        [mSubnetWindowC setFields:[PSSharedDictionary sharedInstance]];
    }
}

// close open windows and return how many we found
- (int)subnetCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[SubnetWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

- (SubnetWindowC *)subnetWindowC { return mSubnetWindowC; }


#pragma mark -- TCP Dump --
// ---------------------------------------------------------------------------------
//	¥ tcpDumpShowWindow
// ---------------------------------------------------------------------------------
- (IBAction)tcpDumpShowWindow:(id)sender
{
    TCPDumpWindowC* tcpDumpController;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    count = instanceCount([TCPDumpWindowC class]);
    // create window controller and make it the windows owner
    tcpDumpController = [TCPDumpWindowC alloc];
    tcpDumpController = [tcpDumpController
        initWithWindowNibName:kTCPDumpName owner:tcpDumpController];
    if (tcpDumpController) {
        window = [tcpDumpController window];
        if (![window setFrameUsingName:instanceName(kTCPDumpName,count)])
        {	// offset multiples
            NSRect rect;
            count = count % 4;
            rect = [window frame];
            rect = NSOffsetRect(rect, count*16, -count*16);
            [window setFrameOrigin:rect.origin];
        }
        [window makeKeyAndOrderFront:sender];
    }
	[tcpDumpController autorelease];
}

// close open windows and return how many we found
- (int)tcpDumpCloseAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[TCPDumpWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

@end

// ---------------------------------------------------------------------------------
//	¥ 
// ---------------------------------------------------------------------------------

