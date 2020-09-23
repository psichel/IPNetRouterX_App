//
//  BandwidthAccounting.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Aug 7 2003.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate recording firewall events (text messages)
//	Notify clients as new messages are added and recycle buffer as needed
//	(preferably by sending email and/or flushing to disk).

#import <Foundation/Foundation.h>


@interface BandwidthAccounting : NSObject {	
	// periodical timer used for bandwidth accounting
	NSTimer*				accountingTimer;
	NSMutableDictionary*	accountingDictionary;
	NSCalendarDate*			accountingLastSaved;
}
+ (BandwidthAccounting *)sharedInstance;
- (void)accountingStart;
- (void)accountingStop;
- (void)accountingTimer:(id)timer;
- (void)accountingSaveForDate:(NSCalendarDate *)inDate;
- (NSCalendarDate *)accountingLastSaved;
- (void)setAccountingLastSaved:(NSCalendarDate *)value;
- (void)writeToFile:(NSData *)inData forDate:(NSCalendarDate *)inDate;
@end

extern NSString *BandwidthAccountingNotification;
