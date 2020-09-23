//
//  ConnectionLog.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Wed Aug 20 2003.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate saving connection log info

#import <Foundation/Foundation.h>


@interface ConnectionLog : NSObject {	
	NSMutableArray* connectionLogArray;
	NSCalendarDate*	connectionLogLastSaved;
	NSTimer*		connectionLogTimer;
}
+ (ConnectionLog *)sharedInstance;
- (void)connectionLogStart;
- (void)connectionLogStop;
- (void)connectionLogTimer:(id)timer;
- (void)connectionLogAppend:(NSDictionary *)connectionEntry;
- (void)connectionLogSaveForDate:(NSCalendarDate *)inDate;
- (void)writeToFile:(NSString *)inText forDate:(NSCalendarDate *)inDate;
@end

extern NSString *ConnectionLogNotification;
