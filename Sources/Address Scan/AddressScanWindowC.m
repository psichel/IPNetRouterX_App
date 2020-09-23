//
//  AddressScanWindowC.m
//  IPNetMonitorX
//
//  Created by psichel on Fri Feb 01 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.

#import "AddressScanWindowC.h"
#import "IPNMDocument.h"
#import "AddressScanServer.h"
#import "AddressScanEntry.h"
#import "AddressScanTable.h"
#import "AddressScanUserInfo.h"
#import "IPLookupController.h"
#import "PSURL.h"
#import "AddressScanHistory.h"
#import "PSSharedDictionary.h"
#import "PSServiceDictionary.h"
#import "PSHostDictionary.h"
#ifdef IPNetMonitor
#import "MenuDispatch.h"
#import "PortScanWindowC.h"
#endif
#import "IPValue.h"
#import "IPValueFormatter.h"
#import "IPSupport.h"
#import "kftSupport.h"
#import "PSSupport.h"
#import "ICMPController.h"
#import "PSEthernetDictionary.h"
#import "SystemConfiguration.h"
#import <string.h>
#import <arpa/inet.h>

@interface AddressScanWindowC (PrivateMethods)
- (void)localInfo;
- (void)testComplete;
- (NSString *)setURL:(NSString *)inString;
- (NSString *)URL;
- (void)logResult;
@end

@implementation AddressScanWindowC

// ---------------------------------------------------------------------------------
//	¥ awakeFromNib
// ---------------------------------------------------------------------------------
- (void)awakeFromNib {
    NSString* str;
    int count;
    mRequestInProgress = NO;
	mGetNamesInProgress = NO;
    mClient = nil;
    mLookupTimer = nil;
    mLookupController = nil;
    mLocalAddresses = nil;
	mLocalHardware = nil;
	mLocalHosts = nil;
    mScanType = kScanTypeLookAround;
	[logTextView setRichText:NO];
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];

	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
		[scanButton setEnabled:YES];
	}
	else {
		[scanButton setEnabled:NO];
		[statusInfo setStringValue:NSLocalizedString(@"Trial period expired",
			@"Trial period expired")];
	}
	// load history with interface names and subnets
	[self localInfo];
    [targetField setUsesDataSource:YES];
    [targetField setDataSource:[AddressScanHistory sharedInstance]];
    // restore settings
    count = instanceCount([AddressScanWindowC class]);
    @try {
        [continuousScan setIntValue:[preferences integerForKey:instanceName(kAddressScan_continuousScan,count-1)]];
        [listAll setIntValue:[preferences integerForKey:instanceName(kAddressScan_listAll,count-1)]];
        if ((str = [preferences objectForKey:instanceName(kAddressScan_scanType,count-1)]))
            [scanType selectItemWithTitle:str];
		[self selectType:self];
        if ((str = [preferences objectForKey:instanceName(kAddressScan_scanProtocol,count-1)]))
            [scanProtocol selectItemWithTitle:str];
        if ((str = [preferences objectForKey:instanceName(kAddressScan_retryLimit,count-1)]))
            [selectRetryLimit selectItemWithTitle:str];
        [self selectProtocol:self];
    }
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSLog(@"Exception during AddressScanWindowC.m -awakeFromNib");
	}
    // set double click action
    [tableView setTarget:self];
	[tableView setAutosaveName:@"AddressScanTable"];
    [tableView setDoubleAction:@selector(doubleAction:)];
    // get image strings for table display
    if ([[PSSharedDictionary sharedInstance] objectForKey:@"greenCheck"] == nil) {
        NSString* path=[[NSBundle mainBundle] pathForImageResource:@"greenCheck"];
        NSFileWrapper* wrapper=[[[NSFileWrapper alloc] initWithPath:path] autorelease];
        NSTextAttachment* attachment=[[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
        NSAttributedString* string=[NSAttributedString attributedStringWithAttachment:attachment];
        [[PSSharedDictionary sharedInstance] setObject:string forKey:@"greenCheck"];
    }
    if ([[PSSharedDictionary sharedInstance] objectForKey:@"redX"] == nil) {
        NSString* path=[[NSBundle mainBundle] pathForImageResource:@"redX"];
        NSFileWrapper* wrapper=[[[NSFileWrapper alloc] initWithPath:path] autorelease];
        NSTextAttachment* attachment=[[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
        NSAttributedString* string=[NSAttributedString attributedStringWithAttachment:attachment];
        [[PSSharedDictionary sharedInstance] setObject:string forKey:@"redX"];
    }
	// allow editing user info for LookAround scan
	if (mScanType == kScanTypeLookAround) [self editingEnabled:YES];
	else [self editingEnabled:NO];
	[[AddressScanUserInfo sharedInstance] restore];
}

// ---------------------------------------------------------------------------------
//	¥ localInfo
// ---------------------------------------------------------------------------------
// load history with interface names and subnets
- (void)localInfo
{
	NSArray* interfaceTitles;
	NSArray* serviceIDs = nil;
	int i, count;
	NSString* serviceID;
	NSString* userName;
	NSString* title;
	NSString* addressStr;
	NSString* maskStr;
	NSString* hardwareStr;
	u_int32_t address;
	u_int32_t mask;
	AddressScanHistory* addressScanHistory;
	addressScanHistory = [AddressScanHistory sharedInstance];
	// initialize for local interface info
	if (!mLocalAddresses) mLocalAddresses = [[NSMutableArray alloc] init];
	else [mLocalAddresses removeAllObjects];
	if (!mLocalHardware) mLocalHardware = [[NSMutableArray alloc] init];
	else [mLocalHardware removeAllObjects];
	// load address scan history
	interfaceTitles = [[SystemConfiguration sharedInstance] interfaceTitlesAndServiceIDs:&serviceIDs];
	count = [serviceIDs count];
	for (i=count-1; i>=0; i--) {
		serviceID = [serviceIDs objectAtIndex:i];
		// try to get network number
		do {
			// IP address part
			addressStr = [[SystemConfiguration sharedInstance]
				service:serviceID interfaceDataForKey:@"grantAddress"];
			if (!addressStr) continue;
			[mLocalAddresses addObject:addressStr];	// remember localhost addresses
			address = ipForString(addressStr);
			// hardwareAddress
			hardwareStr = [[SystemConfiguration sharedInstance]
				service:serviceID interfaceDataForKey:@"hardwareAddress"];
			if (!hardwareStr) hardwareStr = @"";
			[mLocalHardware addObject:hardwareStr];
			// mask part
			maskStr = [[SystemConfiguration sharedInstance]
				service:serviceID interfaceDataForKey:@"subnetMask"];
			if (!maskStr) continue;
			mask = ipForString(maskStr);
			if (mask == 0) continue;
			// set menu item
			title = stringForNetNumber(address, mask);
			userName = [interfaceTitles objectAtIndex:i];
			title = [NSString stringWithFormat:@"%@ (%@)",title,userName];    
			[addressScanHistory addTemp:title];
		} while (false);
	}
}

// ---------------------------------------------------------------------------------
//	¥ windowWillClose
// ---------------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
{
    NSWindow* theWindow;
    NSNumber* object;
    int count;
    
	// tell server to stop
	[mClient abortWithTimeout:0.25];
	[mClient setCallbackTarget:nil];
    [mClient release];		mClient = nil;
    // name lookup
    [mLookupTimer invalidate];	mLookupTimer = nil;
    if (mLookupController) {
        [mLookupController abort];
        [mLookupController release];
        mLookupController = nil;
    }
    [mLocalAddresses release];	mLocalAddresses = nil;
	[mLocalHardware release];	mLocalHardware = nil;
	[mLocalHosts release];		mLocalHosts = nil;
    // get instance count, try dictionary first
    object = [[PSSharedDictionary sharedInstance] objectForKey:@"instanceCount"];
    if (object) count = [object intValue];
    else count = instanceCount([AddressScanWindowC class]);
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:instanceName(kAddressScanName,count-1)];
    // remember settings
		NSString *str;
    [preferences setInteger:[continuousScan intValue] forKey:instanceName(kAddressScan_continuousScan,count-1)];
    [preferences setInteger:[listAll intValue] forKey:instanceName(kAddressScan_listAll,count-1)];
		str = [scanType titleOfSelectedItem];
	if ([str length]) [preferences setObject:str forKey:instanceName(kAddressScan_scanType,count-1)];
		str = [selectRetryLimit titleOfSelectedItem];
    if ([str length]) [preferences setObject:str forKey:instanceName(kAddressScan_retryLimit,count-1)];
    [preferences setObject:[targetField stringValue] forKey:instanceName(kAddressScan_target,count-1)];
		str = [scanProtocol titleOfSelectedItem];
    if ([str length]) [preferences setObject:str forKey:instanceName(kAddressScan_scanProtocol,count-1)];
	[[AddressScanUserInfo sharedInstance] save];
	// stop service name searching
	[[PSHostDictionary sharedInstance] stopUpdate];
    // release ourself
    [self autorelease];
}

// ---------------------------------------------------------------------------------
//	¥ windowDidBecomeKey
// ---------------------------------------------------------------------------------
// select first responder
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    [[self window] makeFirstResponder:targetField];
}

// ---------------------------------------------------------------------------------
//	¥ windowDidResignKey
// ---------------------------------------------------------------------------------
- (void)windowDidResignKey:(NSNotification *)aNotification
{
    int row;
    NSTableColumn* column;
    NSString* nameStr = nil;
    NSString* addressStr = nil;
    
    row = [tableView selectedRow];
    // share our input/results with other tools
    if (row >= 0) {
        column = [tableView tableColumnWithIdentifier:@"Address"];
        addressStr = [[tableView dataSource] tableView:tableView
            objectValueForTableColumn:column
            row:(int)row];
        if (mScanType == kScanTypeDomainName) {
            column = [tableView tableColumnWithIdentifier:@"Comment"];
            nameStr = [[tableView dataSource] tableView:tableView
                objectValueForTableColumn:column
                row:(int)row];
        }
        saveAddressAndName(addressStr, nameStr);
    }
}

// ---------------------------------------------------------------------------------
//	¥ selectType
// ---------------------------------------------------------------------------------
- (IBAction)selectType:(id)sender
{
    mScanType = [scanType indexOfSelectedItem];
    if (mScanType == kScanTypeLastSeen) {
		//[listAll setHidden:YES];
		hideView(listAll);
		//[seenLabel setHidden:NO];
		unhideView(seenLabel);
		//[seenInfo setHidden:NO];
		unhideView(seenInfo);
		[self editingEnabled:NO];
	}
    else {
		//[listAll setHidden:NO];
		unhideView(listAll);
		//[seenLabel setHidden:YES];
		hideView(seenLabel);
		//[seenInfo setHidden:YES];
		hideView(seenInfo);
	}
    if (mScanType == kScanTypeLookAround) {
		[continuousScan setEnabled:YES];
		[self editingEnabled:YES];
	}
    else {
		[continuousScan setEnabled:NO];
		[self editingEnabled:NO];
	}
	// begin searching for names
	if (mScanType == kScanTypeLookAround) [[PSHostDictionary sharedInstance] startUpdate];
}

- (void)editingEnabled:(BOOL)flag
{
	NSTableColumn* tableColumn;
    tableColumn = [tableView tableColumnWithIdentifier:@"Name"];
	[tableColumn setEditable:flag];
    tableColumn = [tableView tableColumnWithIdentifier:@"Comment"];
	[tableColumn setEditable:flag];
}

// ---------------------------------------------------------------------------------
//	¥ selectProtocol
// ---------------------------------------------------------------------------------
- (IBAction)selectProtocol:(id)sender
{
    PSServiceDictionary* serviceDictionary;
    NSDictionary* portDictionary;
    NSArray* keys;
    NSArray* sorted;
    int i, count;
    
    serviceDictionary = [PSServiceDictionary sharedInstance];
    switch ([scanProtocol indexOfSelectedItem]) {
    default:
    case 0:	// ping
		//[selectServicePopUp setHidden:YES];
		hideView(selectServicePopUp);
		//[selectRetryLimit setHidden:NO];
		unhideView(selectRetryLimit);
		//[selectRetryLabel setHidden:NO];
		unhideView(selectRetryLabel);
		//[continuousScan setHidden:NO];
		unhideView(continuousScan);
        break;
    case 1:	// UDP
        [selectServicePopUp removeAllItems];
        [selectServicePopUp addItemWithTitle:@"Select Service"];
        // UDP port list
        portDictionary = [serviceDictionary udpServiceNames];
        keys = [portDictionary allKeys];
        sorted = [keys sortedArrayUsingFunction:intSort context:NULL];
		count = [keys count];
        for (i=0; i<count; i++) {
            [selectServicePopUp addItemWithTitle:[portDictionary
                objectForKey:[sorted objectAtIndex:i]]];
        }
		//[selectRetryLimit setHidden:YES];
		hideView(selectRetryLimit);
		//[selectRetryLabel setHidden:YES];
		hideView(selectRetryLabel);
		//[continuousScan setHidden:YES];
		hideView(continuousScan);
        //[selectServicePopUp setHidden:NO];
		unhideView(selectServicePopUp);
        break;
    case 2:	// TCP
        [selectServicePopUp removeAllItems];
        [selectServicePopUp addItemWithTitle:@"Select Service"];
        // TCP port list
        portDictionary = [serviceDictionary tcpServiceNames];
        keys = [portDictionary allKeys];
        sorted = [keys sortedArrayUsingFunction:intSort context:NULL];
		count = [keys count];
        for (i=0; i<count; i++) {
            [selectServicePopUp addItemWithTitle:[portDictionary
                objectForKey:[sorted objectAtIndex:i]]];
        }
		//[selectRetryLimit setHidden:YES];
		hideView(selectRetryLimit);
		//[selectRetryLabel setHidden:YES];
		hideView(selectRetryLabel);
		//[continuousScan setHidden:YES];
		hideView(continuousScan);
        //[selectServicePopUp setHidden:NO];
		unhideView(selectServicePopUp);
        break;
    }
}

// ---------------------------------------------------------------------------------
//	¥ selectRetryLimit
// ---------------------------------------------------------------------------------
- (IBAction)selectRetryLimit:(id)sender
{
	if (mRequestInProgress) {
		[mClient startService:kServerApply withObject:
			[NSDictionary dictionaryWithObject:
				[selectRetryLimit titleOfSelectedItem] forKey:kRetryLimitStr]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ continuousScan
// ---------------------------------------------------------------------------------
- (IBAction)continuousScan:(id)sender
{
	// if scan in progress, abort
	if (mRequestInProgress) {
		[mClient startService:kServerApply withObject:
			[NSDictionary dictionaryWithObject:
				[NSString stringWithFormat:@"%d",[continuousScan intValue]] forKey:kContinuousScanStr]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ selectService
// ---------------------------------------------------------------------------------
- (IBAction)selectService:(id)sender
{
    IPValue* ipv;
    IPValueFormatter* formatter;
    NSString* port = nil;
    NSString* error = nil;
    int protocol = IPPROTO_TCP;
    if ([scanProtocol indexOfSelectedItem] == 1) protocol = IPPROTO_UDP;
    if ([scanProtocol indexOfSelectedItem] == 2) protocol = IPPROTO_TCP;
    
    port = [[PSServiceDictionary sharedInstance]
        servicePortForName:[selectServicePopUp titleOfSelectedItem]
        protocol:protocol];
    [port retain];
    formatter = [[IPValueFormatter alloc] init];
    if ([formatter getObjectValue:&ipv forString:[targetField stringValue] errorDescription:&error]) {
        if (!error) {
            [ipv setStartPort:[port intValue]];
            [targetField setStringValue:[ipv stringValue]];
        }
    }
    [formatter release];
    [port release];
    //[sender selectItemAtIndex:0];
}

// ---------------------------------------------------------------------------------
//	¥ copy
// ---------------------------------------------------------------------------------
// Edit->Copy selection to clipboard
- (void)copy:(id)sender {
    NSEnumerator* en;
    NSNumber* rowNumber;
    PSArrayTable* data;
    AddressScanEntry* entry;
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	NSMutableString * tString;

	[pboard declareTypes:[NSArray arrayWithObjects:NSTabularTextPboardType,NSStringPboardType,nil] owner:nil];
    tString = [[NSMutableString alloc] initWithCapacity:1024];
    // setup access to each selected row
    data = [tableView dataSource];
    en = [tableView selectedRowEnumerator];
    while ((rowNumber = [en nextObject])) {
        if ([rowNumber intValue] == 0) {
            // include headings with first row
            [tString appendString:@"<"];
            [tString appendString:[self URL]];
            [tString appendString:@">"];
            [tString appendString:[NSString stringWithFormat:@"\nAddress\tSent\tRcvd\tSeconds\tComment"]];        
        }
        entry = [data objectAtIndex:[rowNumber intValue]];
        [tString appendString:@"\n"];
        [tString appendString:[entry description]];
    }
    [pboard setString:tString forType: NSTabularTextPboardType];
    [pboard setString:tString forType: NSStringPboardType];
    [tString release];
}

#ifdef IPNetMonitor
// ---------------------------------------------------------------------------------
//	¥ doubleAction
// ---------------------------------------------------------------------------------
- (void)doubleAction:(id)sender
{
    int row;
    NSTableColumn* column;
    NSString* str;
    MenuDispatch* menuDispatch = [MenuDispatch sharedInstance];
    PortScanWindowC* portScanController;
    NSEnumerator* en;
    NSWindow* window;
    
    row = [tableView selectedRow];
    column = [tableView tableColumnWithIdentifier:@"Address"];
    // share our input/results with other tools
    if (row >= 0) {
        str = [[tableView dataSource] tableView:tableView
            objectValueForTableColumn:column
            row:(int)row];
        saveAddressOrName(str);
        // look for a Port Scan Window
        portScanController = nil;
        en = [[NSApp windows] objectEnumerator];
        while (window = [en nextObject]) {
            if ([[window delegate] isKindOfClass:[PortScanWindowC class]]) break;
        }
        if (!window) {
            // create one
            [menuDispatch portScanShowWindow:self];
            en = [[NSApp windows] objectEnumerator];
            while (window = [en nextObject]) {
                if ([[window delegate] isKindOfClass:[PortScanWindowC class]]) break;
            }
        }
        if (window) {
            [window makeKeyAndOrderFront:self];
            portScanController = [window delegate];
            [portScanController setFields:[PSSharedDictionary sharedInstance]];
            [portScanController scan:self];
        }
    }
}
#endif

// ---------------------------------------------------------------------------------
//	¥ setFields
// ---------------------------------------------------------------------------------
// initialize window fields from dictionary
- (BOOL)setFields:(NSDictionary *)aDictionary
{
    NSString* str;
    BOOL result = NO;

    if ((str = [aDictionary objectForKey:@"address"])) {
        [targetField setStringValue:str];
        result = YES;
    }
    else if ((str = [aDictionary objectForKey:@"name"])) {
        [targetField setStringValue:str];
        result = YES;
    }
    else {
        // restore settings
        int count;
        count = instanceCount([AddressScanWindowC class]);
    	if ((str = [preferences objectForKey:instanceName(kAddressScan_target,count-1)])) {
            [targetField setStringValue:str];
            result = YES;
        }
    }

    [[self window] makeFirstResponder:targetField];
    return result;
}

// ---------------------------------------------------------------------------------
//	¥ setURL:
// ---------------------------------------------------------------------------------
//	Set window fields from URL
//	Returns nil on success, or error message
//	scan://target;limit=n;scanType=lastSeen;retryLimit=1;continuousScan=1;listAll=1;
//  <target> := a.a.a.a-b.b.b.b | a.a.a.a/prefixLength | <domainName>
- (NSString *)setURL:(NSString *)inString
{
    PSURL* url;
    NSString* str;
    NSString* returnValue = nil;
    
    url = [[[PSURL alloc] init] autorelease];
    [url setStringValue:inString];
	// target
	{
		NSString* addressStr = [url host];
		NSString* path = [url path];
		if (path) addressStr = [addressStr stringByAppendingFormat:@"/%@",path];
		[targetField setStringValue:addressStr];
	}
	// limit
	if ((str = [url paramValueForKey:@"limit"])) {
		IPValueFormatter* ipValueFormatter=nil;
		IPValue* ipValue;
		NSString* errorStr;
		int start;
		ipValueFormatter = [[[IPValueFormatter alloc] init] autorelease];
		if ([ipValueFormatter getObjectValue:&ipValue
				forString:[targetField stringValue] errorDescription:&errorStr]) {
			start = [ipValue ipAddress];
			if (![ipValue endAddress] && ![ipValue prefixLen] && ([str intValue] > 0)) {
				[ipValue setEndAddress:start + [str intValue] - 1];
				[targetField setStringValue:[ipValue stringValue]];
			}
		}
	}
	// get scan type
	str = [url paramValueForKey:@"scanType"];
	if (str) {
		if ([str isEqualTo:kScanTypeLookAroundStr]) [scanType selectItemAtIndex:kScanTypeLookAround];
		else if ([str isEqualTo:kScanTypeLastSeenStr]) [scanType selectItemAtIndex:kScanTypeLastSeen];
		else if ([str isEqualTo:kScanTypeDomainNameStr]) [scanType selectItemAtIndex:kScanTypeDomainName];
	}
	else [scanType selectItemAtIndex:kScanTypeLookAround];	// default to look around
	// get scan protocol
	str = [url paramValueForKey:@"scanProtocol"];
	if (str) {
		if ([str isEqualTo:kScanProtocolPingStr]) [scanProtocol selectItemAtIndex:kScanProtocolPing];
		else if ([str isEqualTo:kScanProtocolUDPStr]) [scanProtocol selectItemAtIndex:kScanProtocolUDP];
		else if ([str isEqualTo:kScanProtocolTCPStr]) [scanProtocol selectItemAtIndex:kScanProtocolTCP];
	}
	else [scanProtocol selectItemAtIndex:kScanProtocolPing];	// default to ping
	// continuousScan
	str = [url paramValueForKey:@"continuousScan"];
	if ([str isEqualTo:@"1"]) [continuousScan setIntValue:1];
	else  [continuousScan setIntValue:0];
	// list all option
	str = [url paramValueForKey:@"listAll"];
	if ([str isEqualTo:@"1"]) [listAll setIntValue:1];
	else [listAll setIntValue:0];
	// retry limit
	str = [url paramValueForKey:@"retryLimit"];
	if (str) [selectRetryLimit selectItemWithTitle:str];
    return returnValue;
}

// override isDigit() with macro definition
// macro is not compatible with expression
//#define isDigit(a) ((a >= '0') && (a <= '9'))
// ---------------------------------------------------------------------------------
//	¥ URL
// ---------------------------------------------------------------------------------
//	Build and return address scan URL based on window fields
- (NSString *)URL
{
    PSURL* url;
    url = [[[PSURL alloc] init] autorelease];
    // collect window params to build a URL
    // <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
    // scan://target;limit=n;scanType=lastSeen;listAll=1;
    // targetField is an IP value 
    [url setScheme:@"scan"];
    do {
        IPValueFormatter* ipValueFormatter=nil;
        IPValue* ipValue;
        UInt32 start;
        UInt32 end;
        UInt32 netMask;
        int prefixLen;
        int limit;
        int type;
        UInt16 port;
        NSString* str;
        // is it an IP address?
        ipValueFormatter = [[[IPValueFormatter alloc] init] autorelease];
        if ([ipValueFormatter getObjectValue:&ipValue
                forString:[targetField stringValue] errorDescription:&str]) {
            start = [ipValue ipAddress];
            end = [ipValue endAddress];
            prefixLen = [ipValue prefixLen];
            port = [ipValue startPort];
            if (start == 0) {
                [statusInfo setStringValue:NSLocalizedString(@"Please specify a target",@"specify target")];
                break;            
            }
            if (prefixLen != 0) {
                netMask = 0xFFFFFFFF << (32 - prefixLen);
                start = start & netMask;
                end = start + (0xFFFFFFFF & ~netMask);
                // skip network and broadcast address
                if (prefixLen < 31) {
                    start += 1;
                    end -= 1;
                }
                limit = end - start + 1;
            }
            else {
                limit = 32;
                if (end >= start) limit = end - start + 1;
            }
            [ipValue init];
            [ipValue setIpAddress:start];
			int protocol = IPPROTO_TCP;
			if ([scanProtocol indexOfSelectedItem] == 1) protocol = IPPROTO_UDP;
			if ([scanProtocol indexOfSelectedItem] == 2) protocol = IPPROTO_TCP;
			if (!port) {
				// try to get port from service menu
				port = [[[PSServiceDictionary sharedInstance]
					servicePortForName:[selectServicePopUp titleOfSelectedItem]
					protocol:protocol] intValue];
			}
            if (port) {
				[ipValue setStartPort:port];
				// update service menu to match port
				str = [[PSServiceDictionary sharedInstance]
					serviceNameForPort:port
					protocol:protocol];
				if (str) [selectServicePopUp selectItemWithTitle:str];
				else [selectServicePopUp selectItemAtIndex:0];
			}
            [url setHost:[ipValue stringValue]];
            [url setParamValue:[NSString stringWithFormat:@"%d",limit] forKey:@"limit"];
        }
        else {
            // is last character a digit (not a valid domain name)?
            NSRange range;
            char cbuf[16];
            str = [targetField stringValue];
            // skip :<port> if any
            range = [str rangeOfString:@":"];
            if (range.length) str = [str substringToIndex:range.location];
            str = [str substringFromIndex:[str length]-1];
			[str getCString:&cbuf[0] maxLength:16 encoding:NSUTF8StringEncoding];
			if ( isDigit(cbuf[0]) ) {
                [statusInfo setStringValue:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
                break;
            }
            // not an address, use name and default limit
            [url setHost:[targetField stringValue]];
            [url setParamValue:@"32" forKey:@"limit"];
        }
        // get scan type
        type = [scanType indexOfSelectedItem];
        switch (type) {
            default:
            case kScanTypeLookAround:
                [url setParamValue:@"lookAround" forKey:@"scanType"];
                break;
            case kScanTypeLastSeen:
                [url setParamValue:@"lastSeen" forKey:@"scanType"];
                break;
            case kScanTypeDomainName:
                [url setParamValue:@"domainName" forKey:@"scanType"];
                break;
        }
        // get scan protocol
        [url setParamValue:[scanProtocol titleOfSelectedItem] forKey:@"scanProtocol"];
        // continuousScan option
        if ([continuousScan intValue]) [url setParamValue:@"1" forKey:@"continuousScan"];
        // list all option
        if ([listAll intValue]) [url setParamValue:@"1" forKey:@"listAll"];
		// retry limit
		if ([selectRetryLimit indexOfSelectedItem] >= 0) 
			[url setParamValue:[selectRetryLimit titleOfSelectedItem] forKey:@"retryLimit"];
    } while (false);
    return [url stringValue];
}

// ---------------------------------------------------------------------------------
//	¥ invokeWithURL:
// ---------------------------------------------------------------------------------
//	Set window fields from URL and start test
//	scan://target;limit=n;scanType=lastSeen;listAll=1;
//  <target> := a.a.a.a-b.b.b.b | a.a.a.a/prefixLength | <domainName>
- (void)invokeWithURL:(NSString *)inString
{
	if (!mRequestInProgress) {
		[self setURL:inString];
		[self scanWithURL:inString];
	}
	else NSBeep();
}

// ---------------------------------------------------------------------------------
//	¥ scan:
// ---------------------------------------------------------------------------------
//	Initiate address scan based on window fields
//	Called when user presses the "Test" button.
- (IBAction)scan:(id)sender
{
	// complete any fields being edited
	NSWindow* myWindow;
	myWindow = [self window];
	if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
	// initiate scan
	[self scanWithURL:[self URL]];
}
// ---------------------------------------------------------------------------------
//	¥ scanWithURL
// ---------------------------------------------------------------------------------
- (void)scanWithURL:(NSString *)inString
{
    if (![scanButton isEnabled]) return;
	// test if starting or aborting
    if (mRequestInProgress) {
		[mLookupTimer invalidate];	mLookupTimer = nil;
        // tell server to stop
		[mClient abortWithTimeout:2.1];
    }
    else {
		// complete any fields being edited
		NSWindow* myWindow;
		myWindow = [self window];
		if (![myWindow makeFirstResponder:myWindow]) [myWindow endEditingFor:nil];
		// clear previous log
		[logTextView setString:@""];
        // capture history
        [self historyAdd:self];
        // get scan type selected
        [self selectType:self];
		// start ICMP controller from main thread if needed
		[[ICMPController sharedInstance] startReceiving];
        // create Address Scan Server object running as a detached thread
		if (!mClient) {
			mClient = [[PsClient alloc] init];
			[mClient setCallbackTarget:self];
			[mClient setServerClass:[AddressScanServer class]];
		}
		if (![mClient isConnected]) [mClient createNewServer:[AddressScanServer class]];
        if ([mClient isConnected]) {
            // start test
            [scanButton setTitle:NSLocalizedString(@"Abort", @"Abort")];
            mRequestInProgress = YES;
			// start service name searching (if not already in progress)
			//[[PSHostDictionary sharedInstance] startUpdate];
            // clear any previous results
            [[tableView dataSource] removeAllObjects];
            [tableView reloadData];
            [statusInfo setStringValue:@""];
            // launch address scan
            [mClient startService:inString withObject:nil];
            if (mScanType == kScanTypeDomainName) {
                // start lookup timer
                [mLookupTimer invalidate];	mLookupTimer = nil;
                mLookupTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)0.1
                    target:self
                    selector:@selector(getNames:)
                    userInfo:nil
                    repeats:YES];
            }
			// update window title
            [[self window] setTitle:[self testResultTitle]];
        }
        else [statusInfo setStringValue:@"Failure creating Address Scan server"];
    }
}

// ---------------------------------------------------------------------------------
//	¥ requestInProgress
// ---------------------------------------------------------------------------------
- (BOOL)requestInProgress {
	return mRequestInProgress;
}

// ---------------------------------------------------------------------------------
//	¥ testComplete
// ---------------------------------------------------------------------------------
- (void)testComplete {
    [scanButton setTitle:NSLocalizedString(@"Scan",@"Scan")];
    mRequestInProgress = NO;
	// stop service name searching
	//[[PSHostDictionary sharedInstance] stopUpdate];
}

#pragma mark --- name lookup ---
// ---------------------------------------------------------------------------------
//	¥ getNames
// ---------------------------------------------------------------------------------
- (void)getNames:(id)timer {
    int count;
    int index;
    PSArrayTable* data;
    AddressScanEntry* entry;
    NSString* name;
    NSDictionary* aDictionary;
    BOOL needLookup;
    
	// don't allow multiples
	if (!mGetNamesInProgress) {
		mGetNamesInProgress = YES;
		do {
			// get a name lookup controller
			if (mLookupController == nil) mLookupController = [[IPLookupController alloc] init];
			if (![mLookupController ready]) break;	
			data = [tableView dataSource];
			count = [data count];
			needLookup = NO;
			for (index=0; index<count; index++) {
				entry = [data objectAtIndex:index];
				name = [entry name];
				if (([entry address] != nil) && (name == nil)) {
					needLookup = YES;
					aDictionary = [NSDictionary
						dictionaryWithObject:[NSNumber numberWithInt:index]
						forKey:@"index"];
					[mLookupController lookup:[entry address] callbackObject:self
						withSelector:@selector(lookupCompleted:)
						userInfo:aDictionary];
					break;
				}
			}
			if (!needLookup && !mRequestInProgress) {
				// stop lookup timer
				[mLookupTimer invalidate];	mLookupTimer = nil;
			}
		} while (false);
		mGetNamesInProgress = NO;
	}
}

// ---------------------------------------------------------------------------------
//	¥ lookupCompleted
// ---------------------------------------------------------------------------------
// have a lookup result, update table
- (void)lookupCompleted:(NSNotification *)aNotification {
    int index;
    PSArrayTable* data;
    AddressScanEntry* entry;
    NSString* name;
    index = [[[aNotification userInfo] objectForKey:@"index"] intValue];
    data = [tableView dataSource];
    entry = [data objectAtIndex:index];
    name = [[aNotification object] result];
    [entry setName:name];
    [tableView reloadData];
}

#pragma mark -- log drawer and help --

#define END_RANGE NSMakeRange([[logTextView string]length],0)
- (void)appendString:(NSString *)inString
{
    [logTextView replaceCharactersInRange:END_RANGE withString:inString];
	// scroll for update
	{
		NSRect bounds;
		NSRect visible;
		bounds = [[logScrollView documentView] bounds];
		visible = [logScrollView documentVisibleRect];
		if (visible.origin.y+visible.size.height+20 >= bounds.size.height) {
			[logTextView scrollRangeToVisible:END_RANGE];
		}
	}
}

// ---------------------------------------------------------------------------
// ¥ logDrawer
// ---------------------------------------------------------------------------
- (IBAction)logDrawer:(id)sender
{
	int state = [logDrawer state];
	
	if (state == NSDrawerClosedState) {
		[logDrawer open];
		// display existing text if any
		//[logTextView setString:[linkRateLogger string]];
	}
	else if (state == NSDrawerOpenState) [logDrawer close];
}

// ---------------------------------------------------------------------------------
//	¥ myHelp
// ---------------------------------------------------------------------------------
- (IBAction)myHelp:(id)sender
{
    openHelpAnchor(@"AddressScanHelp");
}

#pragma mark --- history menu ---

// ---------------------------------------------------------------------------------
//	¥ historyAdd
// ---------------------------------------------------------------------------------
- (void)historyAdd:(id)sender
{
    // capture history information
    AddressScanHistory* addressScanHistory;
    addressScanHistory = [AddressScanHistory sharedInstance];
    [addressScanHistory addHistory:[targetField stringValue]];
    [targetField noteNumberOfItemsChanged];
    [targetField reloadData];
    [targetField numberOfItems];	// force combo box to update
    // share input/results with other tools
    saveAddressOrName([targetField stringValue]);
}
// ---------------------------------------------------------------------------------
//	¥ historyAddFavorite
// ---------------------------------------------------------------------------------
- (void)historyAddFavorite:(id)sender
{
    // capture history information
    AddressScanHistory* addressScanHistory;
    addressScanHistory = [AddressScanHistory sharedInstance];
    [addressScanHistory addFavorite:[targetField stringValue]];
    [targetField noteNumberOfItemsChanged];
    [targetField reloadData];
    [targetField numberOfItems];	// force combo box to update
    // share input/results with other tools
    saveAddressOrName([targetField stringValue]);
}
// ---------------------------------------------------------------------------------
//	¥ historyRemove
// ---------------------------------------------------------------------------------
- (void)historyRemove:(id)sender
{
    // capture history information
    AddressScanHistory* addressScanHistory;
    addressScanHistory = [AddressScanHistory sharedInstance];
    [addressScanHistory removeObject:[targetField stringValue]];
    [targetField noteNumberOfItemsChanged];
    [targetField reloadData];
    [targetField numberOfItems];	// force combo box to update
}
// ---------------------------------------------------------------------------------
//	¥ historyClear
// ---------------------------------------------------------------------------------
- (void)historyClear:(id)sender
{
    // capture history information
    AddressScanHistory* addressScanHistory;
    addressScanHistory = [AddressScanHistory sharedInstance];
    [addressScanHistory clearHistory];
    [targetField noteNumberOfItemsChanged];
    [targetField reloadData];
    [targetField numberOfItems];	// force combo box to update
	// clear name cache
	cacheRemoveAllObjects();
}
// ---------------------------------------------------------------------------------
//	¥ historyClearFavorites
// ---------------------------------------------------------------------------------
- (void)historyClearFavorites:(id)sender
{
    // capture history information
    AddressScanHistory* addressScanHistory;
    addressScanHistory = [AddressScanHistory sharedInstance];
    [addressScanHistory clearFavorites];
    [targetField noteNumberOfItemsChanged];
    [targetField reloadData];
    [targetField numberOfItems];	// force combo box to update
	// clear name cache
	cacheRemoveAllObjects();
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
	NSString* toolStr = NSLocalizedString(@"Address Scan",@"Address Scan");
	NSString* title = [NSString stringWithFormat:@"%@ (%@)",toolStr,[targetField stringValue]];
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

#pragma mark --- <ControllerFromThread> ---

// ---------------------------------------------------------------------------------
//	¥ receiveDictionary:
// ---------------------------------------------------------------------------------
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
				// ping status
				else if ([key isEqualTo:@"statusInfo"])	[statusInfo setStringValue:object];
				// input parameters
				else if ([key isEqualTo:@"targetField"])	[targetField setStringValue:object];
				// ping stats
				else if ([key isEqualTo:@"sentInfo"])	[sentInfo setStringValue:object];
				else if ([key isEqualTo:@"receivedInfo"])	[receivedInfo setStringValue:object];
				else if ([key isEqualTo:@"lostInfo"])	[lostInfo setStringValue:object];
				else if ([key isEqualTo:@"minInfo"])	[minInfo setStringValue:object];
				else if ([key isEqualTo:@"aveInfo"])	[aveInfo setStringValue:object];
				else if ([key isEqualTo:@"maxInfo"])	[maxInfo setStringValue:object];
				else if ([key isEqualTo:@"latencyInfo"]) [latencyInfo setStringValue:object];
				else if ([key isEqualTo:@"seenInfo"])	[seenInfo setStringValue:object];
				else if ([key isEqualTo:@"startTime"])	[startTime setStringValue:object];
				else if ([key isEqualTo:@"logText"])	[self appendString:object];
				else if ([key isEqualTo:@"logResult"])	[self logResult];
			}
			else if ([object isKindOfClass:[AddressScanEntry class]]) {	// update table entry
				PSArrayTable* tableData;
				AddressScanEntry* tableE;
				AddressScanEntry* rowE;
				int row;    
				tableData = [tableView dataSource];
				row = [object number]-1;	// NSArray starts from 0 but we count pings from 1
				rowE = object;
				// update comment based on scan type
				if (mScanType == kScanTypeLookAround) {
					NSString* str;
					NSString* org;
					NSUInteger index = NSNotFound;
					// look around scan, check for localhost
					NS_DURING
					{
						int i, count;
						u_int32_t rowAddress, localAddress;
						index = NSNotFound;
						count = [mLocalAddresses count];
						rowAddress = ipForString([rowE address]);
						for (i=0; i<count; i++) {
							localAddress = ipForString([mLocalAddresses objectAtIndex:i]);
							if (localAddress == rowAddress) {
								index = i;
								break;
							}
						}
					}
					NS_HANDLER
					NS_ENDHANDLER
					if (index != NSNotFound) {
						[rowE setName:@"localhost"];
						str = [mLocalHardware objectAtIndex:index];
						str = [str uppercaseString];
						[rowE setMacAddress:str];
						org = [[PSEthernetDictionary sharedInstance] orgForEthernetAddress:str];
						if (org) [rowE setComment:org];
					}
					else {
						// get host name if any for macAddress
						str = [rowE macAddress];
						if (str) str = [[PSHostDictionary sharedInstance] hostNameForAddress:str];
						if (str) [rowE setName:str];
						else {	// check local hosts file
							if (!mLocalHosts) mLocalHosts = 
								[[NSString stringWithContentsOfFile:@"/etc/hosts" encoding:NSUTF8StringEncoding error:nil] retain];
							if (mLocalHosts) {
								NSRange range;
								str = mLocalHosts;
								range = [str rangeOfString:[rowE address]];
								while (range.length) {
									// skip matching string
									str = [str substringFromIndex:range.location+range.length];
									if ([str hasPrefix:@" "] || [str hasPrefix:@"\t"]) {
										// complete match, find end of line
										range = [str rangeOfString:@"\n"];
										if (range.length) {
											str = [str substringToIndex:range.location];
											str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
											[rowE setName:str];
										}
										break;
									}
									else {
										// partial match, look for another
										range = [str rangeOfString:[rowE address]];
										continue;
									}
								}	// while (range.length) {
							}
						}	// else check local hosts file
					}
					{	// user info if any
						NSString *key, *name, *comment;
						key = [rowE macAddress];
						if ([key length]) {
							name = [[AddressScanUserInfo sharedInstance] nameForKey:key];
							if ([name length]) [rowE setName:name];
							comment = [[AddressScanUserInfo sharedInstance] commentForKey:key];
							if ([comment length]) [rowE setComment:comment];
						}
					}					
				}
				else if (mScanType == kScanTypeDomainName) {
					if ([listAll intValue]) {
						// if domain name scan, transfer previous comment if any
						tableE = [tableData objectAtIndex:row];
						[rowE setComment:[tableE comment]];
						[rowE setName:[tableE name]];
					}
				}
				// update entry in table
				if ([listAll intValue] || (mScanType == kScanTypeLastSeen)) {
					// replace entry
					[tableData replaceObjectAtIndex:row withObject:rowE];
					// log last seen updates
					if ((mScanType == kScanTypeLastSeen) && [rowE comment] && ([rowE status] != kPingSent)) {
						[self appendString:[NSString stringWithFormat:@"\n%@",[rowE description]] ];
					}
				}
				else {
					// notice responses can arrive out of order
					// try to insert new entry in correct address order
					u_int32_t rowAddress, tableAddress;
					rowAddress = ipForString([rowE address]);
					int index = [tableData count];
					while (index > 0) {
						tableE = [tableData objectAtIndex:index-1];
						tableAddress = ipForString([tableE address]);
						if (rowAddress < tableAddress) {
							// new entry is before row-1
							index -= 1;
							continue;
						}
						else {
							if (rowAddress > tableAddress) {
								// if not listAll and timed out, don't show it
								if (![listAll intValue] && ([rowE status] == kPingTimedOut)) break;
								// insert entry after row-1
								[tableData insertObject:object atIndex:index];
							}
							else {
								// duplicate address
								[tableData replaceObjectAtIndex:index-1 withObject:object];
							}
							break;
						}
					}
					if (index == 0) [tableData insertObject:object atIndex:index];
					row = [tableData count]-1;	// update row for scrolling
				}
				[tableView reloadData];
				// scroll for update
				{
					NSRect bounds;
					NSRect visible;
					bounds = [[scrollView documentView] bounds];
					visible = [scrollView documentVisibleRect];
					if (visible.origin.y+visible.size.height+20 >= bounds.size.height) {
						if (row > [tableData count]-10) [tableView scrollRowToVisible:row];
					}
				}
			}
		} // while ((key = [enumerator nextObject]))
	}
}


// ---------------------------------------------------------------------------------
//	¥ logResult
// ---------------------------------------------------------------------------------
- (void)logResult
{
	NSString* str = [NSString stringWithFormat:
		@"\n%@ Address Scan sent:%@ received:%@ lost:%@ ave:%@",
		[[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"
			timeZone:nil locale:nil],
		[sentInfo stringValue],
		[receivedInfo stringValue],
		[lostInfo stringValue],
		[aveInfo stringValue]
	];
	[self appendString:str];
}

@end
