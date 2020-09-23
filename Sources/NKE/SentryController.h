//
//  SentryController.h
//  IPNetSentryX
//
//  Created by psichel on Mon Mar 25 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import <AppKit/NSWindowController.h>
#import "PsClient.h"
#import "PSServer.h"
#import "kftSupport.h"
#import "NKEController.h"

@class UDPServer;
@class PSURL;
@class SentryState;
@class SentryLogger;
@class TrafficDiscoveryModel;
@class IPNetMessage;

extern NSString* SentryControllerNotification;

@interface SentryController : NSObject
{
	NKEController*	nkeController;
	SentryLogger*   logger;
	TrafficDiscoveryModel* trafficDiscoveryModel;
	NSTimer*		mUpdateTimer;
	int				mAttachCount;
	int				mWarnCount;
	NSTimeInterval	mSyncInterval;		// NSTimeInterval or similar
	// URL Action
	PsClient*		mURLClient;

	IPNetMessage*	previousMessage; // remember previous filter update to remove delta's
}
+ (SentryController *)sharedInstance;
- (void)terminate;
- (int)connect;
- (int)disconnect;
- (BOOL)insertNKE;
- (void)removeNKE;
- (void)updateTimer:(id)timer;
- (int)sendURL:(NSString *)inString;
- (int)sendURL:(NSString *)inString withObject:(id)anObject;
- (int)sendSync:(NSTimeInterval)timeInterval;
- (NSTimeInterval)syncInterval;
- (int)attachCount;
- (void)setAttachCount:(int)value;
// receive from NKE
- (void)receiveNotification:(NSNotification *)aNotification;
- (void)receiveDictionary:(NSDictionary *)dictionary;
@end

// download conversion
int filterText2Table(PSData* inBuf, PSData* outBuf);
// upload conversion
int filterTable2Text(PSData* inBuf, PSData* outBuf);


#define kSentryName	@"Sentry"
#define kSentry_interface	@"Sentry_interface"
#define kSentry_isRunning @"Sentry_isRunning"

// command URL schemes
#define kSentryConnect		@"sentryConnect:"
#define kSentryDisconnect	@"sentryDisconnect:"
#define kSentryAttach		@"sentryAttach:"
#define kSentryDetach		@"sentryDetach:"
#define kSentryOn			@"sentryOn:"
#define kSentryOff			@"sentryOff:"
#define kKFTFilterDownload	@"kftFilterDownload:"
#define kKFTReceiveMessage	@"kftReceiveMessage:"
#define kKFTFilterUpload	@"kftFilterUpload:"
#define kKFTTriggerUpload	@"kftTriggerUpload:"
#define kKFTInterfaceUpload	@"kftInterfaceUpload:"
#define kKFTPortMapUpload	@"kftPortMapUpload:"
#define kKFTNatUpload		@"kftNatUpload:"
#define kKFTReset			@"kftReset:"
#define kKFTFilterCount		@"kftFilterCount:"
#define kKFTTriggerCount	@"kftTriggerCount:"
#define kKFTInterfaceCount  @"kftInterfaceCount:"
#define kKFTPortMapCount	@"kftPortMapCount:"
#define kKFTNatCount		@"kftNatCount:"
#define kKFTAlternateRouteCount	@"kftAlternateRouteCount:"
#define kKFTSetTime			@"kftSetTime:"
#define kKFTSetFlags		@"kftSetFlags:"
#define kKFTGetFlags		@"kftGetFlags:"
#define kKFTDropResponse	@"kftDropResponse:"
#define kTriggerDuration	@"triggerDuration:"
#define kTriggerAddress		@"triggerAddress:"
#define kSentryTerminate	@"sentryTerminate:"

#define kFlagId_automaticFailover	@"automaticFailover"
#define kFlagId_loadBalance			@"loadBalance"
#define kFlagId_sourceAwareRouting	@"sourceAwareRouting"
#define kFlagId_portMapLogging		@"portMapLogging"
#define kFlagId_unregisteredOnly	@"unregisteredOnly"
#define kFlagId_blockIPv6			@"blockIPv6"
#define kFlagId_trafficDiscovery	@"trafficDiscovery"
#define kFlagId_memStats			@"memStats"
