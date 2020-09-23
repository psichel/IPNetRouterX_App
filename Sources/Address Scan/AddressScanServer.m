//
//  AddressScanServer.m
//  IPNetMonitorX
//
//  Created by psichel on Fri Feb 01 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing a ping test in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
#import "AddressScanServer.h"
//#import <Foundation/Foundation.h>
#import "IPSupport.h"
#import "IPValue.h"
#import "IPValueFormatter.h"
#import "IPKSupport.h"
#import "arp.h"
#import "ArpOutput.h"
#import "IPHost.h"
#import "IPICMPSocket.h"
#import "IPTCPSocket.h"
#import "PSArrayTable.h"
#import "AddressScanEntry.h"
#import "PSURL.h"
#import "IPNetMessage.h"
#import "ping.h"
#import "ICMPController.h"
#import "ICMPNotifications.h"
#import "AppDelegate.h"
#import "PSEthernetDictionary.h"
#import "PSHostDictionary.h"
#import "HardwareAddress.h"
#import "NSDate_Extensions.h"
#import <string.h>
#define kMaxRetryLimit 6

@interface AddressScanServer (PrivateMethods)
- (int)startScanWithURL:(NSString*)inURL object:(id)object;
- (void)startTest;
    // start ping test with parameters specified
- (BOOL)setup;
    // setup for new test
- (NSDate *)checkSend;
    // send ping if needed and return time for next send or nil if done
- (NSDate *)checkTimeout;
    // Check if any probes have timed out and return time for next probe to timeout
    // or nil if all probes have been acknowledged or timed out.
- (void)doProbe;
- (int)sendPingForEntry:(AddressScanEntry *)entry;
    // send a ping datagram using [ICMPServer sharedInstance]
- (int)sendUDP:(IPHost *)target;
- (int)sendTCP;
- (void)messageNotification:(NSNotification *)aNotification;
    // receive ICMP message notification
- (void)receiveData:(IPNetMessage *)inMessage;
    // process receive network data
// update window parameters
- (void)updateStats;
- (void)updateTableEntry:(AddressScanEntry *)entry;
@end

@implementation AddressScanServer

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
	if (self = [super init]) {
        // initialize our instance variables
		eventTimer = nil;
		messageQ = nil;
		mDataFlag = NO;
		
		mTableData = nil;
		mUDPSocket = nil;
		mSendBuf = nil;
		mTarget = nil;
		mURL = nil;
		
		mStartTime = nil;
		mLastSendTime = nil;
		mRetryLimit = 1;
		mListAll = NO;
		mRepeats = NO;
		mRepeatCount = 0;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	[self cleanUp];
    [super dealloc];
}

#pragma mark -- ThreadFromController --
// ---------------------------------------------------------------------------
//	¥ synchStartService:fromController:withObject:
// ---------------------------------------------------------------------------
// WARNING
// This method should not be used by a remote client if the server is already
// running and can possibly make two-way blocking call (such as "didUserAbort")
// to the client thread as this could result in a deadlock with each thread
// waiting for the other to respond.
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	int result = 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSString* str = nil;

	@try {    
		// The following line is an interesting optimisation.  We tell our proxy
		// to the controller object about the methods that we're going to
		// send to the proxy.    
		[controller setProtocolForProxy:@protocol(ControllerFromThread)];
		// init method vars
		[self setController:controller];

		// extract parameters
		str = inURL;
		if (!str) str = [(NSDictionary *)anObject objectForKey:kServerRequest];
		// dispatch commands
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}

		else if ([str hasPrefix:@"scan"])
			result = [self startScanWithURL:inURL object:anObject];

//		else if ([str hasPrefix:kServerStart])
//			result = [self serverStart:anObject];
		else if ([str hasPrefix:kServerStop])
			result = [self serverStop:anObject];
		else if ([str hasPrefix:kServerTerminate])
			result = [self serverTerminate:anObject];
		else if ([str hasPrefix:kServerApply])
			result = [self serverApply:anObject];
		else if ([str hasPrefix:kServerShowActive])
			result = [self serverShowActive:anObject];
		else {
			[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
		}
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSString* statusInfo = @"Exception during AddressScanServer.m -synchStartService";
		NSLog(@"%@",statusInfo);
		[self updateParameter:@"statusInfo" withObject:statusInfo];
		if (str) NSLog(@"%@",str);
	}

	[pool release];  pool = nil;
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ startScanWithURL:object:
// ---------------------------------------------------------------------------------
- (int)startScanWithURL:(NSString*)inURL object:(id)anObject
{
	int result = 0;
	NSString* text;
	// initialize test params
	[mStartTime release]; mStartTime = nil;
	[mLastSendTime release]; mLastSendTime = nil;
	mRetryLimit = 1;
	mListAll = NO;
	mRepeats = NO;
	mRepeatCount = 0;
    do {
        // extract scan parameters
        // scan://target;scanType=lookAround;limit=n
        mURL = [[PSURL alloc] init];
		[mURL setStringValue:inURL];
        if ([[mURL host] length] == 0) {
            [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Please specify a target",@"specify target")];
			result = -1;
            break;
        }
        mTarget = [[IPHost alloc] initWithName:[mURL host]];
		// limit
        mLimit = [[mURL paramValueForKey:@"limit"] intValue];
        if (!mLimit) {
			// Extract limit from address range or prefixLen
			IPValueFormatter* ipValueFormatter=nil;
			IPValue* ipValue;
			UInt32 start;
			UInt32 end;
			UInt32 netMask;
			int prefixLen;
			NSString* str;
			NSString* addressStr = [mURL host];
			NSString* path = [mURL path];
			if (path) addressStr = [addressStr stringByAppendingFormat:@"/%@",path];
			// parse address
			ipValueFormatter = [[[IPValueFormatter alloc] init] autorelease];
			if ([ipValueFormatter getObjectValue:&ipValue
					forString:addressStr errorDescription:&str]) {
				start = [ipValue ipAddress];
				end = [ipValue endAddress];
				prefixLen = [ipValue prefixLen];
				if (prefixLen != 0) {
					netMask = 0xFFFFFFFF << (32 - prefixLen);
					start = start & netMask;
					end = start + (0xFFFFFFFF & ~netMask);
					// skip network and broadcast address
					if (prefixLen < 31) {
						start += 1;
						end -= 1;
					}
					mLimit = end - start + 1;
				}
				else {
					mLimit = 32;
					if (end >= start) mLimit = end - start + 1;
				}
			}
		}
		// retry limit
		text = [mURL paramValueForKey:@"retryLimit"];
        if (text) {
			mRetryLimit = [text intValue];
			if (mRetryLimit > kMaxRetryLimit) mRetryLimit = kMaxRetryLimit;
		}
        // get scan type
        mScanType = 0;
        text = [mURL paramValueForKey:@"scanType"];
        if ([text isEqualTo:kScanTypeLookAroundStr]) mScanType = kScanTypeLookAround;
        else if ([text isEqualTo:kScanTypeLastSeenStr]) mScanType = kScanTypeLastSeen;
        else if ([text isEqualTo:kScanTypeDomainNameStr]) mScanType = kScanTypeDomainName;
        // get scan protocol
        mScanProtocol = 0;
        text = [mURL paramValueForKey:@"scanProtocol"];
        if ([text isEqualTo:kScanProtocolPingStr]) mScanProtocol = kScanProtocolPing;
        else if ([text isEqualTo:kScanProtocolUDPStr]) mScanProtocol = kScanProtocolUDP;
        else if ([text isEqualTo:kScanProtocolTCPStr]) mScanProtocol = kScanProtocolTCP;
        // list all option
        text = [mURL paramValueForKey:@"listAll"];
        if ([text isEqualTo:@"1"]) mListAll = YES;
        // continuousScan option
        text = [mURL paramValueForKey:kContinuousScanStr];
        if ([text isEqualTo:@"1"]) mRepeats = YES;
        // start test
        [self startTest];
    } while (false);
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ serverStop:
// ---------------------------------------------------------------------------------
- (int)serverStop:(NSDictionary *)plist
{
	// no longer checking for events
	[eventTimer invalidate];   eventTimer = nil;
	if ([[self connection] isValid]) {
		NSString* str = [NSString stringWithFormat:@"\n%@ Address Scan Stopped",
			[[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"
				timeZone:nil locale:nil]];
		[self updateParameter:@"logText" withObject:str];
	}
	// no longer want ICMP
	[[ICMPController sharedInstance] removeObserver:self];
	// give any server threads in progress a chance to exit cleanly
//	[NSThread  sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	[self serverTerminate:plist];
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ serverApply:
// ---------------------------------------------------------------------------------
- (int)serverApply:(NSDictionary *)plist
{
	NSString* str;
	if ((str = [plist objectForKey:kContinuousScanStr])) {
		if ([str isEqualTo:@"1"]) mRepeats = YES;
		else mRepeats = NO;
	}
	if ((str = [plist objectForKey:kRetryLimitStr])) {
		mRetryLimit = [str intValue];
		if (mRetryLimit > kMaxRetryLimit) mRetryLimit = kMaxRetryLimit;
	}
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ serverShowActive:
// ---------------------------------------------------------------------------------
- (int)serverShowActive:(NSDictionary *)plist
{
	[self updateStats];
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ serverTerminate:
// ---------------------------------------------------------------------------------
- (int)serverTerminate:(NSDictionary *)plist
{
	// no longer checking for events
	[eventTimer invalidate];   eventTimer = nil;
	// just finish and and cleanup when server dies
	[self finish];
	return 0;
}


// ---------------------------------------------------------------------------------
//	¥ setup
// ---------------------------------------------------------------------------------
- (BOOL)setup {
    int	bufferSize;
    int port = 0;
    BOOL result = YES;
    // clear any previous ping results
    if (mTableData == nil) mTableData = [[PSArrayTable alloc] init];
    if (mRepeatCount == 0) [mTableData removeAllObjects];
    bzero(&mScanStats, sizeof(ScanStatsT));
    mScanStats.min = 10;
    [self updateStats];
	mPingCount = 0;
    // get a UDP socket
    if (!mUDPSocket) mUDPSocket = [[IPUDPSocket alloc] init];
    if (!mUDPSocket || ([mUDPSocket socket]<0)) {
        [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"unix UDP socket error",@"unix UDP socket error")];
        result = NO;
    }    
    // get our send buffer
    bufferSize = 255;
    if (mSendBuf == nil) {
        mSendBuf = [NSMutableData dataWithCapacity:bufferSize];
        if (mSendBuf) [mSendBuf retain];
    }
    else [mSendBuf setLength:bufferSize];
    if (mSendBuf== nil) result = NO;
    
    // setup target address
    if (mTarget==nil) result=NO;
    else {
        if (!isIPAddress([mURL host], nil, nil)) {
            // not an IP address, do lookup and show result
            [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"looking...",@"looking...")];
            if (![mTarget nameToAddress]) {
                [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"No address found",@"No address found")];
                result=NO;
            }
            else {
                [self updateParameter:@"statusInfo" withObject:[mTarget addressString]];
            }
        }
        else {
            // just transfer address
            if ([mTarget name]) [mTarget nameToAddress];
        }
        mStartAddress = [mTarget v4Address];
    }    
    // if TCP or UDP, confirm that we have a port
    if ([mURL port]) {
        port = [[mURL port] intValue];
        [mTarget setPort:port];
    }
    switch (mScanProtocol) {
    default:
    case kScanProtocolPing:
        if (mRepeatCount) {
			NSString* scanStr = NSLocalizedString(@"Ping scan",@"Ping scan");
			NSString* passStr = NSLocalizedString(@"pass",@"pass");
			[self updateParameter:@"statusInfo" withObject:
				[NSString stringWithFormat:@"%@ (%@ %d)",scanStr,passStr,mRepeatCount+1]];
		}
		else
			[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Ping scan",@"Ping scan")];
        break;
    case kScanProtocolUDP:
        if (port) [self updateParameter:@"statusInfo"
            withObject:[NSString stringWithFormat:@"Scanning for UDP port %d",port]];
        else {
            [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Please enter UDP port",@"Please enter UDP port")];
            result = NO;
        }
        break;
    case kScanProtocolTCP:
        if (port) [self updateParameter:@"statusInfo"
            withObject:[NSString stringWithFormat:@"Scanning for TCP port %d",port]];
        else {
            [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Please enter TCP port",@"Please enter TCP port")];
            result = NO;
        }
        break;
    }
    // get a unique sequence number for this test
    {
        timeval_t timeValue;
        gettimeofday(&timeValue, NULL);
        mSequenceNumber = timeValue.tv_sec ^ timeValue.tv_usec;
    }
    return result;
}

- (void)startTest {
    do {
        // setup for new test
        int result = [self setup];
        if (!result) break;
		// message Queue
		if (!messageQ) messageQ = [[NSMutableArray alloc] init];
        // setup for receive from
        [[ICMPController sharedInstance] addObserver:self
            withSelector:@selector(messageNotification:)];
        
        // first test cycle
        mPingCount = 0;
			// start time
		if (mStartTime) [mStartTime release];
		mStartTime = [[NSDate psDate] retain];
		[self updateParameter:@"startTime" withObject:[mStartTime descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil]];
		NSString* str = [NSString stringWithFormat:@"\n%@ Address Scan Started", [mStartTime description]];
		[self updateParameter:@"logText" withObject:str];
			// send time
        if (mLastSendTime) [mLastSendTime release];
        mLastSendTime = [[NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)0] retain];

		// start periodic timer to check for events
		eventTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
			target:self
			selector:@selector(eventTimer:)
			userInfo:nil
			repeats:YES];					

		// pause to begin
		[eventTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        
    } while (false);
}

#pragma mark -- periodic next event --
// ---------------------------------------------------------------------------
//	¥ eventTimer:
// ---------------------------------------------------------------------------
// check for next probe or timeout at regular intervals
- (void)eventTimer:(id)timer
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSDate* nextSend;
	NSDate* nextTimeout;
	NSDate* next;
	IPNetMessage* message = nil;
	int count;
	
	@try {
		do {
			// process received data (if any)
			do {
				@synchronized(messageQ) {
					// eventTimer entered, clear data flag so we'll be rescheduled if more data arrives
					mDataFlag = NO;
					count = [messageQ count];
					if (count) {
						message = [[messageQ objectAtIndex:0] retain];
						[messageQ removeObjectAtIndex:0];
						count -= 1;
					}
				}
				if (message) {
					[self receiveData:message];
					[message release]; message = nil;
				}
			} while (count);
			
			// check for next send
			nextSend = [self checkSend];
			// check for next timeout
			nextTimeout = [self checkTimeout];

			// if nothing to send or timeout, we're done
			 if ((nextSend == nil) && (nextTimeout == nil)) {
				if (mScanType == kScanTypeLastSeen) {
					//  last seen scan, repeat after 60 seconds
					mRepeatCount++;
					mPingCount = 0;
					[mTarget setHAddress:mStartAddress];
					// resume in 60 seconds
					[eventTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:59]];
					break;
				}
				else if (mScanType == kScanTypeLookAround) {
					// pause for any last responses
					if (mRepeats) {
						// repeat after a brief delay
						// reset test parameters
						mRepeatCount++;
						// resume in 2 seconds
						[eventTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:2]];
						// record previous scan results
						[self updateParameter:@"logResult" withObject:@"logResult"];
						// setup for new test
						int result = [self setup];
						if (!result) [self serverStop:nil];
						break;
					}
					else {
						// test has completed, don't reschedule
						[self serverStop:nil];
						break;
					}
				}
				else {
					// test has completed, don't reschedule
					[self serverStop:nil];
					break;
				}
			}
			// sleep until next ping or timeout whichever comes sooner
				// if last ping sent, check back every second for timeout
			if (nextSend == nil) next = [NSDate dateWithTimeIntervalSinceNow:1];
			else if (nextTimeout == nil) next = nextSend;
			else next = [nextSend earlierDate:nextTimeout];
				// if time already past, use 20 ms
			if ([next psTimeIntervalSinceNow] <= 0) next = [NSDate dateWithTimeIntervalSinceNow:0.020];
			// set timer to fire for next event
			@synchronized(messageQ) {
				// if not already scheduled for pending data
				if (!mDataFlag) [eventTimer setFireDate:next];
			}
		} while (false);
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		NSLog(@"AddressScan Server exception during eventTimer");
	}
	[pool release];
}

// ---------------------------------------------------------------------------------
//	¥ checkSend
// ---------------------------------------------------------------------------------
- (NSDate *)checkSend {
    // send probe if needed and return time for next send or nil if done
    NSDate* returnValue = nil;
    NSTimeInterval delay;
    UInt32 address;
	int i, count;

    do {
		delay = 0.10;
		count = 5;
        if (mScanType == kScanTypeLookAround) {
			delay = 0.10;
			count = 10;
			if (mRepeats && mRepeatCount) {
				delay = 1.0;
			}
		}
		else if (mScanType == kScanTypeDomainName) {
			delay = 0.10;
			count = 5;
		}
		else if (mScanType == kScanTypeLastSeen) {
			delay = 0.50;
			count = 1;
		}
        // all pings have been sent?
        if ((mPingCount >= mLimit) && (mLimit != 0)) break;
        // time for next probe?
        if (-[mLastSendTime psTimeIntervalSinceNow] > delay) {
			// yes, send multiple probes each time thread awakes
			for (i=0; i<count; i++) {
				// record send time
				if (mLastSendTime) [mLastSendTime release];
				mLastSendTime = [[NSDate psDate] retain];
				mPingCount += 1;
				// send it
				[self doProbe];
				// increment address for next probe
				address = [mTarget v4Address];
				address += 1;
				[mTarget setHAddress:address];
				if ((mPingCount >= mLimit) && (mLimit != 0)) break;	// all pings sent?
			}
			[self updateStats];	// update window stats
        }
        // all pings sent?
        if ((mPingCount >= mLimit) && (mLimit != 0)) break;
        // calculate time to next ping
        returnValue = [mLastSendTime dateByAddingTimeInterval:(delay+0.02)];
    } while (false);
    return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ checkTimeout
// ---------------------------------------------------------------------------------
// Check if any probes have timed out and return time for next probe to timeout
// or nil if all probes have been acknowledged or timed out.
- (NSDate *)checkTimeout {
    NSDate* returnValue = nil;
	NSDate* next[kMaxRetryLimit];
    NSTimeInterval delay;
    int row;
	int i, retry;
	BOOL newStats = NO;
	
    delay = 2.5;
    if (mScanProtocol == kScanProtocolUDP) delay = 1.0;
	if (mScanProtocol == kScanProtocolPing) {
		// if start time was less than 7 seconds ago
		if ([mStartTime psTimeIntervalSinceNow] > -7.0) {
			// don't check any time outs until 7 seconds have elapsed
			return [mStartTime dateByAddingTimeInterval:7.0];
		}
		delay = 10.0;
		if ((mScanStats.returnPing > 1) && (mScanStats.latency < 5)) delay = 5.0;
	}
	for (i=0; i<kMaxRetryLimit; i++) {
		next[i] = nil;
	}
    for (row=0; row<[mTableData count]; row++) {
        AddressScanEntry* entry = [mTableData objectAtIndex:row];
        if ([entry status] == kPingSent) {
            if (-[[entry startDate] psTimeIntervalSinceNow] > delay) {
                // entry has timed out
                // if scan protocol is UDP, received echo response, UDP sent
                if ([entry type] == kScanProtocolUDP) {
                    [entry setStatus:kPingDestinationNotUnreachable];
					[entry setComment:NSLocalizedString(@"UDP listener or stealth port",
						@"kNotUnreachable")];
                    [self updateTableEntry:entry];
                }
				else {
					if (([entry type] == kScanProtocolPing) && ([entry retry] < mRetryLimit)) {
						retry = [entry retry];
						retry += 1;
						[entry setRetry:retry];
						[entry setStartDate:[NSDate psDate]];
						[self sendPingForEntry:entry];
						// still waiting for response or time out
						// remember timeout for first one found
						if (next[retry] == nil)
							next[retry] = [[entry startDate] dateByAddingTimeInterval:(delay+0.02)];
					}
					else {
						// we really lost this one
						BOOL statusChange = NO;
						if (mRepeatCount && ([entry pStatus] != kPingTimedOut)) statusChange = YES;
						[entry setStatus:kPingTimedOut];
						[entry setLost:[entry lost]+1];
						mScanStats.lost += 1;
						if (mListAll || statusChange || (mScanType == kScanTypeLastSeen)) {
							[self updateTableEntry:entry];
						}
						newStats = YES;
					}
				}
            }	// if (-[[entry startDate] psTimeIntervalSinceNow] > delay) {
            else {
            	// still waiting for response or time out
                // remember timeout for first one found
				retry = [entry retry];
				if (next[retry] == nil)
					next[retry] = [[entry startDate] dateByAddingTimeInterval:(delay+0.02)];
            }
        }	// if ([entry status] == kPingSent) {
    }	// for (row=0; row<[mTableData count]; row++) {
	if (newStats) [self updateStats];
	for (i=0; i<kMaxRetryLimit; i++) {
		if ((returnValue = next[i])) break;
	}
    return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ doProbe
// ---------------------------------------------------------------------------------
- (void)doProbe
{
    AddressScanEntry* probe = nil;
    int tcpResult = -1;

    // setup to capture probe info
        // get previous entry if any
    if ([mTableData count] >= mPingCount)
        probe = [mTableData objectAtIndex:mPingCount-1];
    else
        probe = [[[AddressScanEntry alloc] init] autorelease];
    [probe setStartDate:mLastSendTime];
    [probe setNumber:mPingCount];
    [probe setAddress:[mTarget addressString]];
    [probe setStatus:kPingSent];
	[probe setSent:[probe sent]+1];
    mScanStats.sent += 1;
    
    // send ping, UDP, or TCP connect if a port is specified
    switch (mScanProtocol) {
    default:
    case kScanProtocolPing:
    case kScanProtocolUDP:
        if ([self sendPingForEntry:probe] < 0) [self updateParameterD:@"statusInfo"
            withObject:[NSString stringWithFormat:@"%s", strerror(errno)]];
        // For UDP: send ping first to check if reachable
        // if ping responds, send UDP and set entry type to kScanProtocolUDP
        // wait for UDP to timeout or respond destination unreachable
        break;
    case kScanProtocolTCP:
        tcpResult = [self sendTCP]; 
		// 0=connection succeeded, -1=connection error, ETIMEDOUT, ECONNREFUSED
        if (tcpResult == 0) {
            // set elapsed time
            NSTimeInterval delta;
            delta = [[NSDate psDate] timeIntervalSinceDate:mLastSendTime];
            [probe setElapsedInterval:delta];
			//status
            [probe setStatus:kPingReturned];
			[probe setReceived:[probe received]+1];
			mScanStats.returnOpen += 1;
            if (mScanType == kScanTypeLastSeen) {
                if (![probe comment]) mScanStats.seen += 1;
                [probe setComment:[[NSDate psDate] description]];
            }
        }
        else if (tcpResult == ETIMEDOUT) {
            [probe setStatus:kPingTimedOut];
			[probe setLost:[probe lost]+1];
			mScanStats.lost += 1;
        }
		else if (tcpResult == ECONNREFUSED) {
            [probe setStatus:kPingDestinationUnreachable];
			if (mScanType != kScanTypeLastSeen) [probe setComment:NSLocalizedString(
				@"Connection Refused",@"Connection Refused")];
			[probe setReceived:[probe received]+1];
			mScanStats.returnClosed += 1;
		}
        break;
    }
    // add to table
    [mTableData addObject:probe];
    // notify controller with new AddressScanEntry
    if ((mListAll) || (mScanType == kScanTypeLastSeen) || !tcpResult) {
        [self updateTableEntry:probe];
		[self updateStats];
    }
}


- (int)sendPingForEntry:(AddressScanEntry *)entry {
    // setup to send packet
    icmp_header_t*	icmp_header;
    UInt8*		data;
    SInt32		tSize, iSize;
    int			result = 0; // number of bytes sent
    
    do {
        // confirm send buffer
		if (!mSendBuf) break;
        [mSendBuf retain];
        // determine packet size (must be an even number between 28 and 2048)
        tSize = 52;
        iSize = tSize - 20;	// icmp size less IP header
        // set buffer size
        [mSendBuf setLength:iSize];

        // setup access to send buffer
        icmp_header = [mSendBuf mutableBytes];
        data = (UInt8*)icmp_header;
        
        // Initialize ICMP header (8 bytes)
        icmp_header->type = ICMP_ECHO;	// 8=echo request
        icmp_header->code = 0;
        icmp_header->checksum = 0;
        icmp_header->identifier = htons([entry number]);
        icmp_header->seqNumber = htons(mSequenceNumber);
        
        // ICMP data
        memcpy((char*)&data[8], "©Sustainable Softworks ", 24);
        data[30] = 0;
        data[31] = 0;
        if (iSize > 32) {
                UInt16 i;
                for (i=32; i<iSize; i++) data[i] = i;
        }
        icmp_header->checksum = htons(IpSum((UInt16*)&data[0], (UInt16*)&data[iSize]));
		
		// target
		IPHost* target = [[[IPHost alloc] initWithName:[entry address]] autorelease];
		[target nameToAddress];
		
        // send data
        result = [[ICMPController sharedInstance] sendTo:target data:mSendBuf];
        if (result == 0) [self updateParameterD:@"statusInfo" withObject:NSLocalizedString(@"send failed",@"send failed")];
        [mSendBuf release];
    } while (false);
    return result;
}


- (int)sendUDP:(IPHost *)target;
{
    // setup to send packet
    UInt8*		data;
    int			returnValue=0;
    
    do {
        // setup access to send buffer
        if (!mSendBuf) break;
        [mSendBuf retain];
        data = (UInt8*)[mSendBuf mutableBytes];

		// 26 bytes UDP data (string data)
        memcpy((char*)&data[0], "IPNetMonitorX Port Scan.", 24);
        data[24] = 0;
        data[25] = 0;
    
        // send data
        returnValue = [mUDPSocket sendTo:target data:mSendBuf];
        if (returnValue == 0) [self updateParameterD:@"statusInfo" withObject:NSLocalizedString(@"send failed",@"send failed")];
        [mSendBuf release];
    } while (false);
    return returnValue;
}


- (int)sendTCP
{
    // probe for TCP listener
    // 0=connection succeeded, -1=connection error, ETIMEDOUT, ECONNREFUSED
    int returnValue = -1;
    IPTCPSocket* theSocket = nil;
    do {
        // get a TCP socket
        theSocket = [[IPTCPSocket alloc] init];
        if (!theSocket || ([theSocket socket]<0)) {
            [self updateParameterD:@"statusInfo" withObject:NSLocalizedString(@"unix TCP socket error",@"unix TCP socket error")];
            [self serverStop:nil];
            break;
        }    
        // try to connect
        returnValue = [theSocket connectTo:mTarget withTimeOut:(NSTimeInterval)0.2];
        [theSocket setRST];
    } while (false);
	[theSocket release];
    return returnValue;
}

- (void)messageNotification:(NSNotification *)aNotification {
	// receive ICMP message notification
    IPNetMessage* message;
    if ((message = [[aNotification userInfo] objectForKey:ICMPMessageNotification])) {
		// add message to inputQ;
		@synchronized(messageQ) {
			[messageQ addObject:message];
			// if no previous data since evenTimer last entered
			if (!mDataFlag) {
				// schedule timer to process it
				[eventTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.010]];
				mDataFlag = YES;
			}
		}
    }
}

// process receive network data
- (void)receiveData:(IPNetMessage *)inMessage {
    NSTimeInterval delta;
    UInt32 inDataSize;		// size of the data
    UInt8* dp;
    ip_header_t* ip_header;
    ip_header_t* ip_header2;	// triggering datagram
    icmp_header_t* icmp_header;
    icmp_header_t* icmp_header2;
    udp_header_t* udp_header2;

    dp = (UInt8*)[[inMessage data] bytes];
    inDataSize = [[inMessage data] length];
    // setup pointer to ip header
    ip_header = (ip_header_t*)dp;
    // setup pointer to icmp header
    icmp_header = (icmp_header_t*)&dp[(ip_header->hlen & 0x0F) * 4];
    // setup pointer to ip header of triggering datagram
    ip_header2 = (ip_header_t*)&icmp_header->data[0];
    // setup pointer to icmp header of triggering datagram
    icmp_header2 = (icmp_header_t*)&icmp_header->data[(ip_header2->hlen & 0x0F) * 4];
    // setup pointer to udp header of triggering datagram
    udp_header2 = (udp_header_t*)&icmp_header->data[(ip_header2->hlen & 0x0F) * 4];
    
    // did we get an echo response?
    if (
        (ntohs(icmp_header->identifier) <= mPingCount) &&
        (ntohs(icmp_header->seqNumber) == mSequenceNumber) &&	// correct sequence#
        (icmp_header->type == kIcmpEchoReply)) {		// echo reply?
        // find corresponding AddressScanEntry
        AddressScanEntry* entry;
        int row;
        row = ntohs(icmp_header->identifier);
        entry = [mTableData objectAtIndex:0];
		if (entry) {
			int offset = [entry number];	// offset of first entry
			row = row - offset;
		}
		else row = 0;
        entry = [mTableData objectAtIndex:row];
        if (entry) do {
			[[entry retain] autorelease];	// defensive
			NSTimeInterval latency = -[[inMessage timeStamp] timeIntervalSinceNow];
			if (latency > mScanStats.latency) mScanStats.latency = latency;
				// note we ignore prevously timed out responses rather than update
				// our lost count and corresponding record
            if (([entry status] == kPingTimedOut) || ([entry status] == kPingReturned)) break;
				// if a response claims to arrive before our last retry was sent, ignore it.
			delta = [[inMessage timeStamp] timeIntervalSinceDate:[entry startDate]];
			if (delta < 0) break;
			// update count stats
			[entry setReceived:[entry received]+1];
			mScanStats.returnPing += 1;
			if ([entry retry]) mScanStats.returnRetry += 1;
            // address matches ping target?            
            if ([[[inMessage fromHost] addressString] isEqualTo:[entry address]]) {
                [entry setStatus:kPingReturned];
                if (mScanType == kScanTypeLastSeen) {
                    if (![entry comment]) mScanStats.seen += 1;
                    [entry setComment:[[NSDate psDate] description]];
                }
                // if UDP scan, set type to UDP, send probe, and wait for timeout
                if (mScanProtocol == kScanProtocolUDP) {
                    IPHost* target;
                    NSString* targetStr;
                    [entry setType:kScanProtocolUDP];
                    [entry setStatus:kPingSent];
                    targetStr = [NSString stringWithFormat:@"%@:%@",[entry address],[mURL port]];
                    target = [[IPHost alloc] initWithName:targetStr];
                    [target nameToAddress];
                    [self sendUDP:target];
					mScanStats.sentUDP += 1;
                    [target release];
                }
            }
            else {
                [entry setStatus:kPingTargetDidNotMatch];
                [entry setComment:[[inMessage fromHost] addressString]];
            }
            // set elapsed time
            [entry setElapsedInterval:delta];
            // update time stats
            delta = [entry elapsedInterval];
            if (delta < mScanStats.min) mScanStats.min = delta;
            if (delta > mScanStats.max) mScanStats.max = delta;
            mScanStats.sum += delta;
			long returned = mScanStats.returnPing + mScanStats.returnOpen + mScanStats.returnClosed;
            if (returned) {	// no DIV/0
                mScanStats.ave = mScanStats.sum / returned;
            }
            // try to get MAC address for look around scan
            if ((mScanType == kScanTypeLookAround) &&
                ([entry status] == kPingReturned)) {
                NSString* ipAddress;
                NSString* macAddress = nil;
				NSString* org;
                ipAddress = [[inMessage fromHost] addressString];
                macAddress = hwAddressStringForIPString(ipAddress);
				if (macAddress) {
					[entry setMacAddress:macAddress];				
					org = [[PSEthernetDictionary sharedInstance] orgForEthernetAddress:macAddress];
					if (org) [entry setComment:org];
				}
            }
            // update display
            if ((mListAll) ||
                (mScanType == kScanTypeLastSeen) ||
                ([entry status] == kPingReturned)) {	// last seen or matches only
                [self updateTableEntry:entry];
            }
            [self updateStats];
        } while (false);   // if (entry)
    }	// end echo response

    // did we get a ICMP "destination unreachable"?
    else if (icmp_header->type == kIcmpTypeDestUnreachable) do {
        // find corresponding AddressScanEntry
        AddressScanEntry* entry = nil;
        int row;
        // check triggering datagram
        if (ip_header2->protocol == IPPROTO_ICMP) {
            if (ntohs(icmp_header2->seqNumber) != mSequenceNumber) break;
            row = ntohs(icmp_header->identifier);
            entry = [mTableData objectAtIndex:0];
			if (entry) {
				int offset = [entry number];	// offset of first entry
				row = row-offset;
			}
			else row = 0;
            entry = [mTableData objectAtIndex:row];
            // update stats
			[entry setLost:[entry lost]+1];
            mScanStats.lost += 1;
        }
        else if (ip_header2->protocol == IPPROTO_UDP) { 
            NSString *str;
			UInt32 address;
            // find address of first entry
            entry = [mTableData objectAtIndex:0];
			str = [entry address];
			address = ipForString(str);
            if (!address) break;
            // calculate offset from first entry based on address of triggering UDP probe
            row = ntohl(ip_header2->dstAddress) - address;
            if ((row < 0) || (row >= [mTableData count])) break;
            entry = [mTableData objectAtIndex:row];
			[entry setReceived:[entry received]+1];
			mScanStats.returnClosed += 1;
        }
        if (entry) {
            // mark as Destination Unreachable
            [entry setStatus:kPingDestinationUnreachable];
            // show ICMP Destination unreachable reason
            switch (icmp_header->code) {
                case kIcmpCodeNetworkUnreachable:
                    [entry setComment:NSLocalizedString(
                        @"Network unreachable",@"kIcmpCodeNetworkUnreachable")];
                    break;
                case kIcmpCodeHostUnreachable:
                    [entry setComment:NSLocalizedString(
                        @"Host unreachable",@"kIcmpCodeHostUnreachable")];
                    break;
                case kIcmpCodeDestNetworkUnknown:
                    [entry setComment:NSLocalizedString(
                        @"Destination network unknown",@"kIcmpCodeDestNetworkUnknown")];
                    break;
                case kIcmpCodeDestHostUnknown:
                    [entry setComment:NSLocalizedString(
                        @"Destination host unknown",@"kIcmpCodeDestHostUnknown")];
                    break;
                case kIcmpCodeDestNetworkAdmin:
                    [entry setComment:NSLocalizedString(
                        @"Communication with destination network administratively prohibited",
						@"kIcmpCodeDestNetworkAdmin")];
                    break;
                case kIcmpCodeDestHostAdmin:
                    [entry setComment:NSLocalizedString(
                        @"Communication with destination host administratively prohibited",
						@"kIcmpCodeDestHostAdmin")];
                    break;
               case kIcmpCodeCommAdminFilter:
                    [entry setComment:NSLocalizedString(
                        @"Communication administratively prohibited by filtering",
						@"kIcmpCodeCommAdminFilter")];
                    break;
                case kIcmpCodePortUnreachable:
                    // already marked entry as unreachable
                    break;
                default:
                    [entry setComment:NSLocalizedString(@"Destination unreachable",
                        @"Destination unreachable")];
                    break;
            }
            // update display
            //[mTableData replaceObjectAtIndex:row withObject:entry];
            if ((mListAll) || (mScanType == kScanTypeLastSeen)) {	// last seen or matches only
                [self updateTableEntry:entry];
            }
            [self updateStats];
        } // if (entry)
    } while (false);	// end destination unreachable
}


// update table entry and stats (to save a message cycle)
- (void)updateStats
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary* myDictionary = [NSMutableDictionary dictionaryWithCapacity:10];

	// do stats
	[myDictionary setObject:[NSString stringWithFormat:@"%ld",mScanStats.sent] forKey:@"sentInfo"];
	[myDictionary setObject:[NSString stringWithFormat:@"%ld",mScanStats.lost] forKey:@"lostInfo"];
	[myDictionary setObject:[NSString stringWithFormat:@"%ld",mScanStats.seen] forKey:@"seenInfo"];
	[myDictionary setObject:[NSString stringWithFormat:@"%1.3f",mScanStats.min] forKey:@"minInfo"];
	[myDictionary setObject:[NSString stringWithFormat:@"%1.3f",mScanStats.ave] forKey:@"aveInfo"];
	[myDictionary setObject:[NSString stringWithFormat:@"%1.3f",mScanStats.max] forKey:@"maxInfo"];
	[myDictionary setObject:[NSString stringWithFormat:@"%1.3f",mScanStats.latency] forKey:@"latencyInfo"];

	// protocol specific
	if (mScanProtocol == kScanProtocolPing) {
		if (mScanStats.returnRetry) 
			[myDictionary setObject:[NSString stringWithFormat:@"%ld ping (%ld retry)",mScanStats.returnPing,mScanStats.returnRetry]
				forKey:@"receivedInfo"];
		else
			[myDictionary setObject:[NSString stringWithFormat:@"%ld ping",mScanStats.returnPing]
				forKey:@"receivedInfo"];
	}
	else if (mScanProtocol == kScanProtocolTCP) {
		[myDictionary setObject:[NSString stringWithFormat:@"%ld open %ld closed", mScanStats.returnOpen,mScanStats.returnClosed]
			forKey:@"receivedInfo"];
	}
	else if (mScanProtocol == kScanProtocolUDP) {
		[myDictionary setObject:[NSString stringWithFormat:@"%ld ping %ld udp",mScanStats.sent,mScanStats.sentUDP]
			forKey:@"sentInfo"];
		[myDictionary setObject:[NSString stringWithFormat:@"%ld ping %ld closed", mScanStats.returnPing,mScanStats.returnClosed]
			forKey:@"receivedInfo"];
	}

	// remote object might have gone away, so check for exceptions
	@try {
		[mController receiveDictionary:myDictionary];
	}
	@catch( NSException *theException ) {
		//[theException printStackTrace];
		if (!mFinishFlag) NSLog(@"Exception during AddressScanServer updateStats");
		[self serverStop:nil];
	}
	[pool release];
}


// update table entry
- (void)updateTableEntry:(AddressScanEntry *)entry
{
    BOOL status = YES;
	if (entry) status = [self updateParameter:@"AddressScanEntry" withObject:entry];
	// connection to client still valid?
	if (status != YES) [self serverStop:nil];
}

- (void)cleanUp {
    // clean-up when server is killed
    if (!mCleanUpFlag) {	// don't allow multiples
        mCleanUpFlag = YES;
		[eventTimer invalidate];   eventTimer = nil;
		[messageQ release]; messageQ = nil;
        [[ICMPController sharedInstance] removeObserver:self];
        [mSendBuf release]; mSendBuf = nil;
        [mUDPSocket release];	mUDPSocket = nil;
        [mTarget release]; mTarget = nil;
        [mURL release]; mURL = nil;
        [mLastSendTime release]; mLastSendTime = nil;
        [mTableData release]; mTableData = nil;

		[self setController:nil];
    }
}

@end

