//
//  AddressScanServer.h
//  IPNetMonitorX
//
//  Created by psichel on Fri Feb 01 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing an address scan in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
//

#import <Foundation/Foundation.h>
//#import <AppKit/AppKit.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class IPHost;
@class AddressScanEntry;
@class PSArrayTable;
@class PSURL;
@class IPNetMessage;
@class IPICMPSocket;
@class IPUDPSocket;

struct ScanStats {
    long sent;
	long sentUDP;
    long returnPing;
	long returnRetry;
	long returnOpen;
	long returnClosed;
    long lost;
    long seen;
    float min;
    float ave;
    float max;
    float sum;
	float latency;
};
typedef struct ScanStats ScanStatsT;

@interface AddressScanServer : PSServer
{
	NSTimer*		eventTimer;
	NSMutableArray*	messageQ;
	BOOL			mDataFlag;
	// test state
    int				mPingCount;
    UInt16			mSequenceNumber;
    PSArrayTable*	mTableData;	// track sent/received probes
    ScanStatsT		mScanStats;
    // Network I/O
    IPUDPSocket*	mUDPSocket;
    NSMutableData*	mSendBuf;
	NSDate*			mStartTime;
    NSDate*			mLastSendTime;
    // probe params
    PSURL*			mURL;
    IPHost*			mTarget;
    UInt32			mStartAddress;
    int				mLimit;
    int				mScanType;
    int				mScanProtocol;
	int				mRetryLimit;
    BOOL			mListAll;
	BOOL			mRepeats;
	int				mRepeatCount;
}
- (void)eventTimer:(id)timer;

@end

#define kScanTypeLookAroundStr	@"lookAround"
#define kScanTypeLastSeenStr @"lastSeen"
#define kScanTypeDomainNameStr @"domainName"

#define kScanTypeLookAround	0
#define kScanTypeLastSeen 1
#define kScanTypeDomainName 2

#define kScanProtocolTCPStr	@"TCP"
#define kScanProtocolUDPStr @"UDP"
#define kScanProtocolPingStr @"ping"

#define kScanProtocolPing	0
#define kScanProtocolUDP	1
#define kScanProtocolTCP	2

#define kContinuousScanStr	@"continuousScan"
#define kRetryLimitStr		@"retryLimit"