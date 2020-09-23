#import "SubnetWindowC.h"
#import "IPValue.h"
#import "IPSupport.h"
#import "PSSharedDictionary.h"
#import "PSSupport.h"
#import "PingHistory.h"
#import <string.h>

@implementation SubnetWindowC

// initialize
- (id)init {
    if (self = [super init]) {
        // initialize our instance variables
    }
    return self;
}
- (void)dealloc {
    [super dealloc];
}
- (void)awakeFromNib {
    [prefixLengthStepper setIntValue:24];
    mPrefixMatch = YES;
	mNetworkStep = 0;
    mHostStep = 0;
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];

	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
		[ipAddressCombo setEnabled:YES];
	}
	else {
		[ipAddressCombo setEnabled:NO];
	}

	[[PingHistory sharedInstance] loadDefaultTargets:kTargetMaskRouterDNSLocalhost];
    [ipAddressCombo setUsesDataSource:YES];
    [ipAddressCombo setDataSource:[PingHistory sharedInstance]];
    
    [ipAddressCombo registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
}

- (void)windowWillClose:(NSNotification *)aNotification
{    
    NSWindow* theWindow;
    NSNumber* object;
    int count;

    // get instance count, try dictionary first
    object = [[PSSharedDictionary sharedInstance] objectForKey:@"instanceCount"];
    if (object) count = [object intValue];
    else count = instanceCount([SubnetWindowC class]);
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:instanceName(kSubnetName,count-1)];
    [preferences setObject:[ipAddressCombo stringValue] forKey:instanceName(kSubnet_target,count-1)];

    [self autorelease];
}

// select first responder
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    [[self window] makeFirstResponder:ipAddressCombo];
}

// initialize window fields from dictionary
- (BOOL)setFields:(NSDictionary *)aDictionary
{
    NSString* str;
    BOOL result = NO;

    if ((str = [aDictionary objectForKey:@"address"])) {
        [ipAddressCombo setStringValue:str];
        result = YES;
    }
    else if ((str = [aDictionary objectForKey:@"name"])) {
        [ipAddressCombo setStringValue:str];
        result = YES;
    }
    else {
        // restore settings
        int count;
        count = instanceCount([SubnetWindowC class]);
    	if ((str = [preferences objectForKey:instanceName(kSubnet_target,count-1)])) {
            [ipAddressCombo setStringValue:str];
            result = YES;
        }
    }

    [[self window] makeFirstResponder:ipAddressCombo];	// restore first responder
    return result;
}

// update fields based on new input
- (void)update {
    IPValue*		addressO;
    IPValue*		maskO;
    IPValue*		networkO;
    IPValue*		hostO;
    UInt8		prefixLength;
    NSMutableString	*classString;
    UInt32		netMask;
    UInt32		hostMask;
    UInt32		netNumber;
    SInt32		numberAddresses;
    UInt8		classLength;
    
	if (![ipAddressCombo isEnabled]) return;
    // get input from prefixLength and IP address field
    prefixLength= [prefixLengthField intValue];
	addressO = [[[IPValue alloc] init] autorelease];
    [addressO setStringValue:[ipAddressCombo stringValue]];
    // update other fields based on input
        // net mask
    netMask = 0xFFFFFFFF << (32 - prefixLength);
    maskO = [[[IPValue alloc] init] autorelease];
    [maskO setIpAddress:netMask];
    [maskField setObjectValue:maskO];
        // net number
    networkO = [[[IPValue alloc] init] autorelease];
    netNumber = (netMask & [addressO ipAddress]);
    // address range?
    if (mRange.delta) netNumber = netMask & ([addressO ipAddress] + mRange.aggregateBlocks);
    [networkO setIpAddress:netNumber];
    [networkO setPrefixLen:prefixLength];
    [networkField setObjectValue:networkO];    
        // host number
    hostMask = ~netMask;
    hostO = [[[IPValue alloc] init] autorelease];
    // if CIDR network number, show host range
    if ([addressO prefixLen]) {
        [hostO setIpAddress:netNumber];
        [hostO setEndAddress:(netNumber | hostMask)];
    }
    else [hostO setIpAddress:(hostMask & [addressO ipAddress])];
    [hostField setObjectValue:hostO];
        // class
    // Update number of addresses and IP adress class
    // Display is based on whether number of address
    // is less than a classful network
    //	Class C			or		n Class C
    //  n addresses				networks
    classString = [[[NSMutableString alloc] init] autorelease];
    classLength	= GetIPAddressClass([networkO ipAddress], classString);
    numberAddresses = (UInt32)1 << (32 - prefixLength);
    if (prefixLength < 8) [classString setString:@""];	// leave blank for special addresses
    else {
        if (classLength < prefixLength) {	// subnet of addresses
            if (numberAddresses > 8192) [classString appendFormat:@"\n%dK", numberAddresses/1024];
            else [classString appendFormat:@"\n%d", numberAddresses];
            if (numberAddresses > 1) [classString appendFormat:@" addresses"];
            else [classString appendFormat:@" addresses"];
        } else {	// block of networks
            numberAddresses = numberAddresses >> (32 - classLength);
            if (numberAddresses > 1) [classString appendFormat:@"\n%d networks", numberAddresses];
            else [classString appendFormat:@"\n%d network", numberAddresses];
        }
    }
    [classField setObjectValue:classString];
        // stepper
    [prefixLengthStepper setIntValue:prefixLength];
    // share our input/results with other tools
    saveAddressOrName([ipAddressCombo stringValue]);
}

// IP address field has changed
- (IBAction)addressChange:(id)sender
{
    IPValue*	addressO;
    UInt32		address;
    UInt32		address2;
    UInt8		prefixLength;
    UInt8		ipClass;

    // get input from IP address field
	addressO = [[[IPValue alloc] init] autorelease];
	[addressO setStringValue:[ipAddressCombo stringValue]];
    prefixLength = [addressO prefixLen];
    address	= [addressO ipAddress];
    address2	= [addressO endAddress];
    // determine prefixLength
    ipClass	= GetIPAddressClass(address, nil);
    //if (ipClass == NMIPAddressLoopback) ipClass = NMIPAddressClassA;	// use 8 for loopback
    if (prefixLength == 0) {	// if no length specified in field
		if (mPrefixMatch) {		// did previous length match class?
			prefixLength = ipClass;
			if (prefixLength < 8) prefixLength = 8;
		}
		else prefixLength = [prefixLengthField intValue];
    }
    // check for address range
    if (address < address2) {
        UInt32	rangeDelta, rangeBlock, rangeAddress;
        SInt32	index;        
        // get difference bits
        rangeDelta = address2 - address;
        // add one to network range to be inclusive
            // start with address class
        mRange.right = GetIPAddressClass(address2, nil);
        if (mRange.right < 8) mRange.right = 8;
            // adjust for CIDR alignment if needed
        index = FindRightBit(rangeDelta, 32);
        if (index > mRange.right) mRange.right = index;
            // increment network range
        rangeDelta += (UInt32)0x01 << (32-mRange.right);
        // find left most difference bit to bound block size
        mRange.left = FindLeftBit(rangeDelta, 1);
        // address range has changed (or user pressed enter),
        // reset aggregate length
        mRange.delta = rangeDelta;
        mRange.aggregateBlocks = 0;
        // get current aggregate address
        rangeAddress = address + mRange.aggregateBlocks;
        // get current aggregate prefix length
        // (the size of the next rangeDelta block to add)
        // find largest block remaining
        rangeDelta = mRange.delta - mRange.aggregateBlocks;	// subtract used blocks			
        rangeBlock = FindLeftBit(rangeDelta, 1);
        // look for right most 1 bit in agg address within remaining range
        index = FindRightBit(rangeAddress, mRange.right);
        // if not found, use largest block remaining
        if (index < rangeBlock) index = rangeBlock;
        mRange.aggregateLen = index;        
        // set prefix length from aggregate length
        prefixLength = mRange.aggregateLen;
    } else {
        mRange.delta = 0;
        mRange.aggregateLen = 0;
    }
    // update prefixLength
    [prefixLengthField setIntValue:prefixLength];
    
    // update other fields accordingly
    [self update];
}

- (IBAction)prefixLengthStep:(id)sender
{
    IPValue*	addressO;
	UInt8		prefixLength;
	UInt8		ipClass;
    
    // set new value from stepper
	prefixLength = [sender intValue];
    [prefixLengthField setIntValue:prefixLength];
    // remove prefix length if any from address field
	addressO = [[[IPValue alloc] init] autorelease];
    [addressO setStringValue:[ipAddressCombo stringValue]];
    [addressO setPrefixLen:0];
    [ipAddressCombo setStringValue:[addressO stringValue]];
	// update whether prefixLength matches address class
	ipClass	= GetIPAddressClass([addressO ipAddress], nil);
	if (ipClass < 8) ipClass = 8;
	if (ipClass == prefixLength) mPrefixMatch = YES;
	else mPrefixMatch = NO;
    // update other fields accordingly
    [self update];
}

- (IBAction)networkStep:(id)sender
{
    IPValue*	addressO;
    UInt32		netMask;
    UInt32		netNumber;
    UInt32		hostMask;
    UInt32		hostNumber;
    UInt8		prefixLength;
    UInt8		value;
    UInt32		rangeDelta, rangeBlock, rangeAddress;
    SInt32		index;        

    // get input from prefixLength and IP address field
    prefixLength= [prefixLengthField intValue];
	addressO = [[[IPValue alloc] init] autorelease];
    [addressO setStringValue:[ipAddressCombo stringValue]];
    netMask	= 0xFFFFFFFF << (32 - prefixLength);
    netNumber	= [addressO ipAddress] & netMask;
    hostMask	= ~netMask;
    hostNumber	= [addressO ipAddress] & hostMask;
    // get current stepper value
    value = [sender intValue];
    // compare to previous
    if (value == (mNetworkStep+1)%3) {
        // increment
        if (mRange.delta == 0) {		// address range?
            netNumber = netNumber >> (32-prefixLength);
            netNumber += 1;
            netNumber = netNumber << (32-prefixLength);
            netNumber &= netMask;
            [addressO setIpAddress:(netNumber+hostNumber)];
            [ipAddressCombo setStringValue:[addressO stringValue]];
        }
        else {
            // address range, get next CIDR aggregate if any
            // add current block size to get next address
            rangeBlock = (UInt32)0x01 << (32-mRange.aggregateLen);
            rangeAddress = [addressO ipAddress] + mRange.aggregateBlocks;
            rangeAddress += rangeBlock;
            // if still within range
            if (rangeAddress <= [addressO endAddress]) {
                // indicate block has been added
                mRange.aggregateBlocks += rangeBlock;
                // get new aggregate prefix length
                // (the size of the next rangeDelta block to add)
                // find largest block remaining
                rangeDelta = mRange.delta - mRange.aggregateBlocks;	// subtract used blocks			
                rangeBlock = FindLeftBit(rangeDelta, 1);
                // look for right most 1 bit in agg address within remaining range
                index = FindRightBit(rangeAddress, mRange.right);
                // if not found, use largest block remaining
                if (index < rangeBlock) index = rangeBlock;
                mRange.aggregateLen = index;
                // set prefix length from aggregate length
                prefixLength = mRange.aggregateLen;
                [prefixLengthField setIntValue:prefixLength];
            }
        }
    }
    else {
        // decrement
        if (mRange.delta == 0) {		// address range?
            netNumber = netNumber >> (32-prefixLength);
            netNumber -= 1;
            netNumber = netNumber << (32-prefixLength);
            netNumber &= netMask;
            [addressO setIpAddress:(netNumber+hostNumber)];
            [ipAddressCombo setStringValue:[addressO stringValue]];
        }
        else {
            // address range, get previous CIDR aggregate if any
            // (current aggregate minus the largest rangeDelta block we can subtract)
            // find largest block added
            rangeBlock = FindLeftBit(mRange.aggregateBlocks, 1);
            rangeAddress = [addressO ipAddress] + mRange.aggregateBlocks;
            if (rangeBlock != 0) {
                // look for right most 1 bit in agg address within remaining range
                // otherwise use largest block added
                index = FindRightBit(rangeAddress, mRange.right);
                if (index < rangeBlock) index = rangeBlock;
                // subtract block size to get prev CIDR address
                rangeBlock = (UInt32)0x01 << (32-index);
                rangeAddress -= rangeBlock;
                // if address is still in range
                if (rangeAddress >= [addressO ipAddress]) {
                    // indicate block no longer included in aggregate
                    mRange.aggregateBlocks -= rangeBlock;
                    mRange.aggregateLen = index;
                    // set prefix length from aggregate length
                    prefixLength = mRange.aggregateLen;
                    [prefixLengthField setIntValue:prefixLength];
                }
            }
        }
    }
    // update values
    mNetworkStep = value;
    [self update];
}

- (IBAction)hostStep:(id)sender
{
    IPValue*	addressO;
    UInt32		netMask;
    UInt32		netNumber;
    UInt32		hostMask;
    UInt32		hostNumber;
    UInt8		prefixLength;
    UInt8		value;

    // get input from prefixLength and IP address field
    prefixLength= [prefixLengthField intValue];
	addressO = [[[IPValue alloc] init] autorelease];
    [addressO setStringValue:[ipAddressCombo stringValue]];
    netMask	= 0xFFFFFFFF << (32 - prefixLength);
    netNumber	= [addressO ipAddress] & netMask;
    hostMask	= ~netMask;
    hostNumber	= [addressO ipAddress] & hostMask;
    // remove prefix length if any from address field
    [addressO setPrefixLen:0];
    // get current stepper value
    value = [sender intValue];
    // compare to previous
    if (value == (mHostStep+1)%3) {
        // increment
        hostNumber += 1;
        hostNumber &= hostMask;
        [addressO setIpAddress:(netNumber+hostNumber)];
        [ipAddressCombo setStringValue:[addressO stringValue]];
    }
    else {
        // decrement
        hostNumber -= 1;
        hostNumber &= hostMask;
        [addressO setIpAddress:(netNumber+hostNumber)];
        [ipAddressCombo setStringValue:[addressO stringValue]];
    }    // update values
    mHostStep = value;
    [self update];
}

#pragma mark -- history menu --
- (void)historyAdd:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory addHistory:[ipAddressCombo stringValue]];
    [ipAddressCombo noteNumberOfItemsChanged];
    [ipAddressCombo reloadData];
    [ipAddressCombo numberOfItems];	// force combo box to update
    // share our input/results with other tools
    saveAddressOrName([ipAddressCombo stringValue]);
}
- (void)historyAddFavorite:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory addFavorite:[ipAddressCombo stringValue]];
    [ipAddressCombo noteNumberOfItemsChanged];
    [ipAddressCombo reloadData];
    [ipAddressCombo numberOfItems];	// force combo box to update
    // share our input/results with other tools
    saveAddressOrName([ipAddressCombo stringValue]);
}
- (void)historyRemove:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory removeObject:[ipAddressCombo stringValue]];
    [ipAddressCombo noteNumberOfItemsChanged];
    [ipAddressCombo reloadData];
    [ipAddressCombo numberOfItems];	// force combo box to update
}
- (void)historyClear:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory clearHistory];
    [ipAddressCombo noteNumberOfItemsChanged];
    [ipAddressCombo reloadData];
    [ipAddressCombo numberOfItems];	// force combo box to update
}
- (void)historyClearFavorites:(id)sender
{
    // capture history information
    PingHistory* pingHistory;
    pingHistory = [PingHistory sharedInstance];
    [pingHistory clearFavorites];
	[pingHistory loadDefaultTargets:kTargetMaskRouterDNSLocalhost];
    [ipAddressCombo noteNumberOfItemsChanged];
    [ipAddressCombo reloadData];
    [ipAddressCombo numberOfItems];	// force combo box to update
}

#pragma mark -- help --
- (IBAction)myHelp:(id)sender
{
    openHelpAnchor(@"SubnetCalculatorHelp");
}

@end
