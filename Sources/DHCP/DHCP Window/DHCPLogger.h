//
//  DHCPLogger.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Nov 13 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate recording DHCP events (text messages)
//	Notify clients as new messages are added and recycle buffer as needed
//	(preferably by sending email and/or flushing to disk).

#import <Cocoa/Cocoa.h>
#import "SentryLogger.h"
@class SentryModel;

@interface DHCPLogger : NSObject {
	NSMutableString*	mText;
	NSCalendarDate*		logTextLastSaved;
	SentryModel*		sentryAction;
}
+ (DHCPLogger *)sharedInstance;
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
// logging
- (void)appendMessage:(NSString *)message;
- (void)logTextSaveForDate:(NSCalendarDate *)inDate;
- (void)writeToFile:(NSString *)inText forDate:(NSCalendarDate *)inDate;
- (NSString *)string;
@end

extern NSString *DHCPLoggerNotification;
