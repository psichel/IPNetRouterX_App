//
//  SentryLogger.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Sun Dec 29 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate recording firewall events (text messages)
//	Notify clients as new messages are added and recycle buffer as needed
//	(preferably by sending email and/or flushing to disk).

#import <Cocoa/Cocoa.h>
@class SentryModel;

@interface SentryLogger : NSObject {
	NSMutableString* mText;
	NSCalendarDate* logTextLastSaved;
	NSCalendarDate* logTextLastMessage;
	NSTimer*		sentryLogTimer;
	NSTimeInterval	sentryLogInterval;
}
+ (SentryLogger *)sharedInstance;
- (NSTimeInterval)sentryLogStart;
- (void)sentryLogTimer:(id)timer;
- (void)logMessage:(NSString *)message;
- (void)appendMessage:(NSString *)message;
- (void)logTextSaveForDate:(NSCalendarDate *)inDate;
- (void)writeToFile:(NSString *)inText forDate:(NSCalendarDate *)inDate;
- (void)writeToPFile:(NSString *)inText forDate:(NSCalendarDate *)inDate;
- (BOOL)sendEmail:(NSString *)inText withSubject:(NSString *)subject;
- (NSString *)string;
- (int)logFormat;
- (NSString *)formatLogMessage:(NSString *)inText;
- (NSString *)formatLogMessage:(NSString *)inText format:(int)logFormat;
- (NSString *)formatProtocol:(NSString *)inString;
@end

extern NSString *SentryLoggerNotification;

#ifdef IPNetRouter
#define kDefaultLogPath @"/Library/Logs/IPNetRouterX/"
#else
#define kDefaultLogPath @"/Library/Logs/IPNetSentryX/"
#endif
#define kTrafficDiscoveryPath @"Traffic Discovery"
